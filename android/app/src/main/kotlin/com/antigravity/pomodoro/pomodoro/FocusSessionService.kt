package com.antigravity.pomodoro.pomodoro

import android.app.*
import android.app.admin.DevicePolicyManager
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.*
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.graphics.ColorUtils
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.telecom.TelecomManager
import java.util.Locale

class FocusSessionService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var timer: CountDownTimer? = null
    private var secondsRemaining = 0L
    private var isTimerRunning = false
    private var isOverlayVisible = false
    private var themeBgColor = 0xFF000000.toInt()
    private var themeAccentColor = 0xFFEC6530.toInt()

    private lateinit var telephonyManager: TelephonyManager
    private var phoneStateListener: PhoneStateListener? = null

    private var foregroundAppPoller: Runnable? = null
    private val foregroundAppHandler = Handler(Looper.getMainLooper())

    // Grace period handler: gives the user time to place a call from the dialer.
    // If no call is initiated within this time, the overlay is restored.
    private val dialerGraceHandler = Handler(Looper.getMainLooper())
    private val dialerGraceRunnable = Runnable {
        if (isTimerRunning && telephonyManager.callState == TelephonyManager.CALL_STATE_IDLE) {
            Log.d("FocusSessionService", "Dialer grace period expired with no call made. Restoring overlay.")
            showOverlay()
            lockHandler.postDelayed(lockRunnable, 1000)
        }
    }

    private var screenReceiver: BroadcastReceiver? = null
    private val lockHandler = Handler(Looper.getMainLooper())
    private val lockRunnable = Runnable {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, FocusDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(adminComponent)) {
                Log.d("FocusSessionService", "Strict lock triggered after unlock.")
                dpm.lockNow()
            } else {
                Log.w("FocusSessionService", "Device Admin is not active, cannot lock screen.")
            }
        } catch (e: Exception) {
            Log.e("FocusSessionService", "Error programmatically locking screen", e)
        }
    }

    companion object {
        private const val NOTIFICATION_ID = 8888
        private const val CHANNEL_ID = "focus_session_channel"
        
        // Broadcast actions
        const val TIMER_UPDATE_ACTION = "com.antigravity.pomodoro.TIMER_UPDATE"
        const val TIMER_FINISHED_ACTION = "com.antigravity.pomodoro.TIMER_FINISHED"

        var instance: FocusSessionService? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        setupCallListener()
        registerScreenStateReceiver()
    }

    fun getSecondsRemaining(): Long {
        return if (isTimerRunning) secondsRemaining else 0L
    }

    fun isSessionRunning(): Boolean = isTimerRunning

    fun isOverlayShowing(): Boolean = isOverlayVisible

    fun isPhoneInCall(): Boolean {
        val state = telephonyManager.callState
        return state == TelephonyManager.CALL_STATE_RINGING ||
               state == TelephonyManager.CALL_STATE_OFFHOOK
    }

    fun getDialerPackage(): String? {
        return try {
            val telecom = getSystemService(TELECOM_SERVICE) as android.telecom.TelecomManager
            telecom.defaultDialerPackage
        } catch (e: Exception) { null }
    }

    /** Called by FocusAccessibilityService when an unauthorized app is foregrounded while overlay is hidden. */
    fun onUnauthorizedAppDetected() {
        cancelDialerGrace()
        showOverlay()
        lockHandler.post(lockRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP_SESSION") {
            stopFocusSession()
            return START_NOT_STICKY
        }

        val durationSeconds = intent?.getIntExtra("duration_seconds", 1500) ?: 1500
        secondsRemaining = durationSeconds.toLong()
        
        themeBgColor = intent?.getIntExtra("background_color", 0xFF000000.toInt()) ?: 0xFF000000.toInt()
        themeAccentColor = intent?.getIntExtra("accent_color", 0xFFEC6530.toInt()) ?: 0xFFEC6530.toInt()

        startForegroundNotification()
        startFocusSession()

        return START_STICKY
    }

    private fun startForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Deep Focus Session",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Running focus lockdown timer"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Deep Focus Active")
            .setContentText("Your device is locked. Stay focused!")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startFocusSession() {
        if (isTimerRunning) return
        isTimerRunning = true

        // 1. Start the VPN blocking service
        val vpnIntent = Intent(this, FocusVpnService::class.java)
        startService(vpnIntent)

        // 2. Display the overlay lock screen
        showOverlay()

        // 3. Start the Countdown Timer
        timer = object : CountDownTimer(secondsRemaining * 1000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                secondsRemaining = millisUntilFinished / 1000
                val timeStr = formatTime(secondsRemaining)
                updateOverlayTime(timeStr)
                updateWidget(timeStr, true)
                broadcastTimeUpdate(secondsRemaining)
            }

            override fun onFinish() {
                stopFocusSession()
            }
        }.start()
        
        // 4. Automatically lock the device (turn screen off) after 3 seconds
        lockHandler.postDelayed(lockRunnable, 3000)
        
        Log.d("FocusSessionService", "Focus session started. Device will lock in 3 seconds.")
    }

    private fun stopForegroundAppPoller() {
        foregroundAppPoller?.let {
            foregroundAppHandler.removeCallbacks(it)
        }
        foregroundAppPoller = null
    }

    private fun cancelDialerGrace() {
        dialerGraceHandler.removeCallbacks(dialerGraceRunnable)
    }

    private fun stopFocusSession() {
        isTimerRunning = false
        timer?.cancel()
        timer = null

        // 1. Stop VPN
        val vpnIntent = Intent(this, FocusVpnService::class.java).apply {
            action = "STOP"
        }
        startService(vpnIntent)

        // 2. Remove Overlay
        hideOverlay()
        
        // 3. Cancel grace period and poller
        cancelDialerGrace()

        // 4. Update Widget
        updateWidget("Focus", false)

        // 4. Broadcast Finished state
        val finishedIntent = Intent(TIMER_FINISHED_ACTION)
        sendBroadcast(finishedIntent)

        Log.d("FocusSessionService", "Focus session finished/stopped.")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun showOverlay() {
        if (isOverlayVisible || !isTimerRunning) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )

        val container = object : android.widget.RelativeLayout(this) {
            private var lastCollapseTime = 0L
            override fun onWindowFocusChanged(hasWindowFocus: Boolean) {
                super.onWindowFocusChanged(hasWindowFocus)
                if (!hasWindowFocus && isTimerRunning) {
                    val now = System.currentTimeMillis()
                    if (now - lastCollapseTime > 1000) { // 1 second debounce
                        lastCollapseTime = now
                        Log.d("FocusSessionService", "Overlay lost focus. Collapsing status bar panels.")
                        try {
                            val statusBarService = getSystemService("statusbar")
                            val statusBarManager = Class.forName("android.app.StatusBarManager")
                            val collapsePanels = statusBarManager.getMethod("collapsePanels")
                            collapsePanels.invoke(statusBarService)
                        } catch (e: Exception) {
                            Log.e("FocusSessionService", "Failed to collapse status bar panels", e)
                        }
                        try {
                            val closeIntent = Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
                            sendBroadcast(closeIntent)
                        } catch (e: Exception) {
                            Log.e("FocusSessionService", "Failed to broadcast CLOSE_SYSTEM_DIALOGS", e)
                        }
                    }
                }
            }
        }

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        inflater.inflate(R.layout.overlay_layout, container, true)
        overlayView = container
        
        // Apply dynamic theme colors to overlay elements
        overlayView?.findViewById<View>(R.id.overlay_root)?.setBackgroundColor(themeBgColor)
        
        val isDarkBg = ColorUtils.calculateLuminance(themeBgColor) < 0.5
        val textColor = if (isDarkBg) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        
        overlayView?.findViewById<TextView>(R.id.overlay_title)?.setTextColor(themeAccentColor)
        overlayView?.findViewById<TextView>(R.id.overlay_timer_text)?.setTextColor(textColor)
        overlayView?.findViewById<TextView>(R.id.overlay_status_text)?.setTextColor(themeAccentColor)
        
        // Find text views and card safely via IDs
        val cardLayout = overlayView?.findViewById<View>(R.id.overlay_card)
        
        // Dynamically style the brutalist card
        val cardDrawable = cardLayout?.background as? GradientDrawable
        if (cardDrawable != null) {
            cardDrawable.setColor(themeBgColor)
            val strokeWidth = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics).toInt()
            cardDrawable.setStroke(strokeWidth, textColor)
        }
        
        overlayView?.findViewById<TextView>(R.id.overlay_minutes_text)?.setTextColor(themeAccentColor)
        overlayView?.findViewById<TextView>(R.id.overlay_blocked_text)?.setTextColor(textColor)
        
        val btnDialer = overlayView?.findViewById<android.widget.Button>(R.id.overlay_btn_dialer)
        btnDialer?.setTextColor(if (ColorUtils.calculateLuminance(themeAccentColor) < 0.5) 0xFFFFFFFF.toInt() else 0xFF000000.toInt())
        btnDialer?.backgroundTintList = android.content.res.ColorStateList.valueOf(themeAccentColor)

        // Setup dialer button
        overlayView?.findViewById<View>(R.id.overlay_btn_dialer)?.setOnClickListener {
            val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                // Cancel any pending screen lock so they have time to dial
                lockHandler.removeCallbacks(lockRunnable)
                cancelDialerGrace()
                
                hideOverlay()
                startActivity(dialIntent)
                
                // Give the user 5 seconds to place a call.
                // If a call starts, the PhoneStateListener cancels this grace period.
                // If no call is placed in time, the overlay is automatically restored.
                dialerGraceHandler.postDelayed(dialerGraceRunnable, 20_000)
            } catch (e: Exception) {
                Log.e("FocusSessionService", "Failed to launch dialer", e)
            }
        }

        // Hide navigation bar and status bar to prevent navigation/gestures during focus session
        overlayView?.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )

        // Prevent the Back button from closing the overlay by consuming key presses
        overlayView?.isFocusableInTouchMode = true
        overlayView?.requestFocus()
        overlayView?.setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_DOWN) {
                Log.d("FocusSessionService", "Back button press blocked.")
                true // Consume the back button press
            } else {
                false
            }
        }

        try {
            windowManager.addView(overlayView, params)
            isOverlayVisible = true
            updateOverlayTime(formatTime(secondsRemaining))
        } catch (e: Exception) {
            Log.e("FocusSessionService", "Failed to add overlay window", e)
        }
    }

    private fun hideOverlay() {
        if (!isOverlayVisible || overlayView == null) return
        try {
            windowManager.removeView(overlayView)
        } catch (e: Exception) {
            Log.e("FocusSessionService", "Failed to remove overlay window", e)
        }
        overlayView = null
        isOverlayVisible = false
    }

    private fun updateOverlayTime(timeStr: String) {
        overlayView?.let { view ->
            val timerText = view.findViewById<TextView>(R.id.overlay_timer_text)
            timerText?.text = timeStr
        }
    }

    private fun setupCallListener() {
        phoneStateListener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                when (state) {
                    TelephonyManager.CALL_STATE_RINGING,
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        // Active call: cancel grace period (call has started), keep overlay hidden
                        cancelDialerGrace()
                        hideOverlay()
                        Log.d("FocusSessionService", "Active Call: Hide Overlay")
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        // Call ended: cancel grace, restore overlay and re-lock
                        cancelDialerGrace()
                        if (isTimerRunning) {
                            showOverlay()
                            lockHandler.postDelayed(lockRunnable, 2000)
                        }
                        Log.d("FocusSessionService", "Phone Idle: Show Overlay")
                    }
                }
            }
        }
        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    private fun formatTime(seconds: Long): String {
        val mins = seconds / 60
        val secs = seconds % 60
        return String.format(Locale.getDefault(), "%02d:%02d", mins, secs)
    }

    private fun updateWidget(timerText: String, isRunning: Boolean) {
        // Update the main text widget
        val intent = Intent(this, FocusWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val ids = AppWidgetManager.getInstance(application).getAppWidgetIds(
            ComponentName(application, FocusWidgetProvider::class.java)
        )
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        intent.putExtra("timer_text", timerText)
        intent.putExtra("is_running", isRunning)
        sendBroadcast(intent)
        
        // Update the 1x1 widget
        val intent1x1 = Intent(this, Focus1x1WidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val ids1x1 = AppWidgetManager.getInstance(application).getAppWidgetIds(
            ComponentName(application, Focus1x1WidgetProvider::class.java)
        )
        intent1x1.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids1x1)
        intent1x1.putExtra("is_running", isRunning)
        sendBroadcast(intent1x1)
    }

    private fun broadcastTimeUpdate(secondsLeft: Long) {
        val intent = Intent(TIMER_UPDATE_ACTION).apply {
            putExtra("seconds_remaining", secondsLeft)
        }
        sendBroadcast(intent)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        instance = null
        phoneStateListener?.let {
            telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE)
        }
        unregisterScreenStateReceiver()
        lockHandler.removeCallbacks(lockRunnable)
        stopFocusSession()
        super.onDestroy()
    }

    private fun registerScreenStateReceiver() {
        if (screenReceiver != null) return
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_USER_PRESENT -> {
                        // User unlocked the device during focus session — lock after 3 seconds
                        if (isTimerRunning) {
                            Log.d("FocusSessionService", "Device unlocked during focus. Locking in 3 seconds.")
                            lockHandler.removeCallbacks(lockRunnable)
                            lockHandler.postDelayed(lockRunnable, 3000)
                        }
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        // Screen already off — cancel any pending delayed lock
                        Log.d("FocusSessionService", "Screen OFF. Canceling delayed lock.")
                        lockHandler.removeCallbacks(lockRunnable)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        // Android 14 (API 34) requires specifying the exported flag when registering receivers
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    private fun unregisterScreenStateReceiver() {
        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e("FocusSessionService", "Error unregistering receiver", e)
            }
        }
        screenReceiver = null
    }
}
