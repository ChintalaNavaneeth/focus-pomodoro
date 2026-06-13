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
import android.app.usage.UsageStatsManager
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
    private var themeAccentColor = 0xFFFFFFFF.toInt()

    private lateinit var telephonyManager: TelephonyManager
    private var phoneStateListener: PhoneStateListener? = null

    // Dialer poller: watches for unauthorized app switches while the dialer is open.
    // Runs every second between dialer tap and call start/end. Avoids needing an
    // Accessibility Service while still closing the Home-button escape hatch.
    private var dialerPoller: Runnable? = null
    private val dialerPollerHandler = Handler(Looper.getMainLooper())
    private var activeDialerPackage: String? = null

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


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP_SESSION") {
            stopFocusSession()
            return START_NOT_STICKY
        }

        val durationSeconds = intent?.getIntExtra("duration_seconds", 1500) ?: 1500
        secondsRemaining = durationSeconds.toLong()
        
        themeBgColor = intent?.getIntExtra("background_color", 0xFF000000.toInt()) ?: 0xFF000000.toInt()
        themeAccentColor = intent?.getIntExtra("accent_color", 0xFFFFFFFF.toInt()) ?: 0xFFFFFFFF.toInt()

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

    // ── Dialer Poller ─────────────────────────────────────────────────────────

    private fun startDialerPoller() {
        stopDialerPoller()
        dialerPoller = object : Runnable {
            override fun run() {
                if (!isTimerRunning) { stopDialerPoller(); return }
                val fg = getForegroundApp()
                val allowed = fg == null ||
                    fg == packageName ||
                    fg == activeDialerPackage ||
                    fg.contains("systemui", ignoreCase = true) ||
                    fg.contains("incallui", ignoreCase = true) ||
                    fg.contains("dialer", ignoreCase = true)
                if (!allowed) {
                    Log.w("FocusSessionService", "Dialer poller: unauthorized app '$fg'. Restoring overlay.")
                    stopDialerPoller()
                    showOverlay()
                    lockHandler.postDelayed(lockRunnable, 1000)
                } else {
                    dialerPollerHandler.postDelayed(this, 10)
                }
            }
        }
        dialerPollerHandler.post(dialerPoller!!)
    }

    private fun stopDialerPoller() {
        dialerPoller?.let { dialerPollerHandler.removeCallbacks(it) }
        dialerPoller = null
        activeDialerPackage = null
    }

    private fun getForegroundApp(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 5000, now)
            stats?.maxByOrNull { it.lastTimeUsed }?.packageName
        } catch (e: Exception) {
            Log.e("FocusSessionService", "Error getting foreground app", e)
            null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────

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

        // 3. Stop dialer poller
        stopDialerPoller()

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
        // Launch the dialer FIRST, then hide the overlay after a brief delay (~150ms).
        // This ensures the dialer is already rendered before the overlay disappears,
        // eliminating the home screen flash that occurs if you hide first then launch.
        overlayView?.findViewById<View>(R.id.overlay_btn_dialer)?.setOnClickListener {
            val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                // Capture the default dialer package so the poller can whitelist it
                activeDialerPackage = try {
                    (getSystemService(TELECOM_SERVICE) as TelecomManager).defaultDialerPackage
                } catch (e: Exception) { null }

                lockHandler.removeCallbacks(lockRunnable)

                // Launch dialer first so it renders behind the overlay
                startActivity(dialIntent)

                // Hide overlay after a short delay — by then the dialer is on screen,
                // so the transition is overlay → dialer with no home screen flash.
                dialerPollerHandler.postDelayed({
                    hideOverlay()
                    startDialerPoller()
                }, 150)

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
                        // Active call: stop the dialer poller, keep overlay hidden
                        stopDialerPoller()
                        hideOverlay()
                        Log.d("FocusSessionService", "Active Call: Hide Overlay")
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        // Call ended (or user backed out of dialer): stop poller, restore overlay
                        stopDialerPoller()
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
        // Update the main text widget using a CUSTOM action to avoid
        // conflict with the system's own ACTION_APPWIDGET_UPDATE broadcasts
        // (which carry no extras and would reset the widget to idle state).
        val intent = Intent("com.antigravity.pomodoro.WIDGET_UPDATE").apply {
            `package` = packageName
        }
        intent.putExtra("timer_text", timerText)
        intent.putExtra("is_running", isRunning)
        sendBroadcast(intent)
        
        // Update the 1x1 widget
        val intent1x1 = Intent("com.antigravity.pomodoro.WIDGET_1X1_UPDATE").apply {
            `package` = packageName
        }
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
        stopDialerPoller()
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
