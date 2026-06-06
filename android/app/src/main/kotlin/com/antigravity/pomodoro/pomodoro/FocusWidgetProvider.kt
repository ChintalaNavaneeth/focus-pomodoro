package com.antigravity.pomodoro.pomodoro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.RemoteViews

class FocusWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        val action = intent.action
        Log.d("FocusWidgetProvider", "Widget onReceive action: $action")
        
        if (action == "com.antigravity.pomodoro.START_WIDGET_TIMER") {
            // Read widget duration in seconds from Shared Preferences (written by Flutter)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val durationSeconds = try {
                prefs.getLong("flutter.widget_duration_seconds", 1500)
            } catch (e: Exception) {
                try {
                    prefs.getInt("flutter.widget_duration_seconds", 1500).toLong()
                } catch (e2: Exception) {
                    1500L
                }
            }
            
            Log.d("FocusWidgetProvider", "Starting focus session from widget with duration: $durationSeconds seconds.")
            
            // Start the foreground focus service
            val serviceIntent = Intent(context, FocusSessionService::class.java).apply {
                putExtra("duration_seconds", durationSeconds.toInt())
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            // Give instant feedback on the widget that we are starting
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, FocusWidgetProvider::class.java))
            updateWidgetUI(context, appWidgetManager, ids, "STARTING...", true)
        } else if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val timerText = intent.getStringExtra("timer_text") ?: "Focus"
            val isRunning = intent.getBooleanExtra("is_running", false)
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, FocusWidgetProvider::class.java))
            
            updateWidgetUI(context, appWidgetManager, ids, timerText, isRunning)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Normal update callback from system
        updateWidgetUI(context, appWidgetManager, appWidgetIds, "Focus", false)
    }

    private fun updateWidgetUI(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        timerText: String,
        isRunning: Boolean
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            views.setTextViewText(R.id.widget_timer_text, timerText)
            
            if (isRunning) {
                // Disable clicking during active session
                val emptyIntent = Intent()
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, emptyIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else
                        PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_btn_action, pendingIntent)
            } else {
                // Clicking starts focus lock broadcast
                val startIntent = Intent(context, FocusWidgetProvider::class.java).apply {
                    action = "com.antigravity.pomodoro.START_WIDGET_TIMER"
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 0, startIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else
                        PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_btn_action, pendingIntent)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
