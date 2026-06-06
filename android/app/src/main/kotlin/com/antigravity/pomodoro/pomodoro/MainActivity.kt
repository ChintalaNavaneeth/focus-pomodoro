package com.antigravity.pomodoro.pomodoro

import android.Manifest
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AppOpsManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.antigravity.pomodoro/lock"
    private val PHONE_STATE_REQ_CODE = 101
    private val VPN_REQ_CODE = 102

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startFocus" -> {
                    val durationSeconds = call.argument<Number>("duration_seconds")?.toInt() ?: 1500
                    val bgColor = call.argument<Number>("background_color")?.toLong()?.toInt() ?: 0xFF000000.toInt()
                    val accentColor = call.argument<Number>("accent_color")?.toLong()?.toInt() ?: 0xFFFFFFFF.toInt()
                    val intent = Intent(this, FocusSessionService::class.java).apply {
                        putExtra("duration_seconds", durationSeconds)
                        putExtra("background_color", bgColor)
                        putExtra("accent_color", accentColor)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopFocus" -> {
                    val intent = Intent(this, FocusSessionService::class.java).apply {
                        action = "STOP_SESSION"
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "isFocusRunning" -> {
                    result.success(isServiceRunning(FocusSessionService::class.java))
                }
                "getSecondsRemaining" -> {
                    val service = FocusSessionService.instance
                    result.success(service?.getSecondsRemaining() ?: 0L)
                }
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "hasVpnPermission" -> {
                    result.success(hasVpnPermission())
                }
                "hasPhonePermission" -> {
                    result.success(hasPhonePermission())
                }
                "hasDeviceAdmin" -> {
                    result.success(hasDeviceAdmin())
                }
                "requestDeviceAdmin" -> {
                    requestDeviceAdmin()
                    result.success(null)
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(null)
                }
                "hasAccessibilityPermission" -> {
                    result.success(hasAccessibilityPermission())
                }
                "requestAccessibilityPermission" -> {
                    requestAccessibilityPermission()
                    result.success(null)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "requestVpnPermission" -> {
                    requestVpnPermission()
                    result.success(null)
                }
                "requestPhonePermission" -> {
                    requestPhonePermission()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun hasVpnPermission(): Boolean {
        return VpnService.prepare(this) == null
    }

    private fun hasPhonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun requestVpnPermission() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_REQ_CODE)
        }
    }

    private fun requestPhonePermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_PHONE_STATE),
            PHONE_STATE_REQ_CODE
        )
    }

    private fun hasDeviceAdmin(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, FocusDeviceAdminReceiver::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    private fun requestDeviceAdmin() {
        val adminComponent = ComponentName(this, FocusDeviceAdminReceiver::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Required to lock the screen automatically during focus lockdown.")
        }
        startActivity(intent)
    }

    private fun hasAccessibilityPermission(): Boolean {
        // Use the official API instead of parsing the settings string, which uses
        // the full class name format (com.pkg/com.pkg.ClassName) that's easy to mismatch.
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
        val enabled = am.getEnabledAccessibilityServiceList(
            android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )
        return enabled.any {
            it.resolveInfo.serviceInfo.packageName == packageName &&
            it.resolveInfo.serviceInfo.name.contains("FocusAccessibilityService")
        }
    }

    private fun requestAccessibilityPermission() {
        // Try to deep-link directly to our service's accessibility settings page
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                val bundle = android.os.Bundle()
                bundle.putString(":settings:fragment_args_key",
                    "$packageName/.FocusAccessibilityService")
                putExtra(":settings:show_fragment_args", bundle)
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to generic accessibility settings
            val fallback = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallback)
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val uri = Uri.fromParts("package", packageName, null)
            data = uri
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback if specific package intent fails
            val fallbackIntent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallbackIntent)
        }
    }
}
