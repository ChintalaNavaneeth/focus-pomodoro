package com.antigravity.pomodoro.pomodoro

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class FocusDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("FocusDeviceAdminReceiver", "Focus Device Admin Enabled.")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("FocusDeviceAdminReceiver", "Focus Device Admin Disabled.")
    }
}
