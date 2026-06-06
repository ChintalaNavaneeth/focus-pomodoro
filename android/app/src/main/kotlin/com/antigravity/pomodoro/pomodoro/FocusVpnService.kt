package com.antigravity.pomodoro.pomodoro

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log

class FocusVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && "STOP" == intent.action) {
            stopVpn()
            return START_NOT_STICKY
        }
        startVpn()
        return START_STICKY
    }

    private fun startVpn() {
        if (vpnInterface != null) return
        try {
            val builder = Builder()
                .setSession("FocusVpn")
                // Add a dummy local IP address
                .addAddress("10.0.0.2", 32)
                // Route all IPv4 and IPv6 traffic to this dummy local interface
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                
            vpnInterface = builder.establish()
            Log.d("FocusVpnService", "VPN established, internet traffic blackholed.")
        } catch (e: Exception) {
            Log.e("FocusVpnService", "Failed to establish VPN", e)
        }
    }

    private fun stopVpn() {
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e("FocusVpnService", "Error closing VPN", e)
        }
        vpnInterface = null
        stopSelf()
        Log.d("FocusVpnService", "VPN stopped.")
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
