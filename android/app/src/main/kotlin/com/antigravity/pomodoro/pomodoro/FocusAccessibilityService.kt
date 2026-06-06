package com.antigravity.pomodoro.pomodoro

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class FocusAccessibilityService : AccessibilityService() {

    companion object {
        var instance: FocusAccessibilityService? = null

        // Packages that are always allowed even during a focus session
        private val ALWAYS_ALLOWED_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.incallui",
            "com.samsung.android.incallui",
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("FocusAccessibilityService", "Accessibility service connected.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val focusService = FocusSessionService.instance ?: return
        if (!focusService.isSessionRunning()) return
        if (focusService.isOverlayShowing()) return  // Overlay is already up, nothing to do

        // Overlay is hidden (dialer is open). Check if the user navigated away.
        val packageName = event.packageName?.toString() ?: return

        // Determine if the user is in an active call
        val isInCall = focusService.isPhoneInCall()

        // Determine what packages are allowed
        val dialerPackage = focusService.getDialerPackage()
        val ownPackage = packageName

        val isAllowed = ALWAYS_ALLOWED_PACKAGES.any { packageName.startsWith(it) } ||
                packageName == application.packageName ||
                packageName == dialerPackage ||
                packageName.contains("incallui") ||
                packageName.contains("dialer") && isInCall

        if (!isAllowed) {
            Log.w("FocusAccessibilityService", "Unauthorized app detected: $packageName. Restoring overlay immediately.")
            focusService.onUnauthorizedAppDetected()
        }
    }

    override fun onInterrupt() {
        Log.d("FocusAccessibilityService", "Accessibility service interrupted.")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
