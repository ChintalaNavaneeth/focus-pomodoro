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

class Focus1x1WidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        val action = intent.action
        if (action == "com.antigravity.pomodoro.START_1X1_WIDGET_TIMER") {
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
            
            Log.d("Focus1x1Widget", "Starting focus session from 1x1 widget.")
            
            val serviceIntent = Intent(context, FocusSessionService::class.java).apply {
                putExtra("duration_seconds", durationSeconds.toInt())
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, Focus1x1WidgetProvider::class.java))
            updateWidgetUI(context, appWidgetManager, ids, true)
        } else if (action == "com.antigravity.pomodoro.WIDGET_1X1_UPDATE") {
            val isRunning = intent.getBooleanExtra("is_running", false)
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, Focus1x1WidgetProvider::class.java))
            
            updateWidgetUI(context, appWidgetManager, ids, isRunning)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgetUI(context, appWidgetManager, appWidgetIds, false)
    }

    private fun updateWidgetUI(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        isRunning: Boolean
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_1x1_layout)
            
            if (isRunning) {
                val emptyIntent = Intent()
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, emptyIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else
                        PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_btn_action_1x1, pendingIntent)
            } else {
                val startIntent = Intent(context, Focus1x1WidgetProvider::class.java).apply {
                    action = "com.antigravity.pomodoro.START_1X1_WIDGET_TIMER"
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 0, startIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else
                        PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_btn_action_1x1, pendingIntent)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
