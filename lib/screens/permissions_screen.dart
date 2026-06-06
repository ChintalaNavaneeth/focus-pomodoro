import 'package:flutter/material.dart';
import '../services/platform_service.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionsScreen({super.key, required this.onPermissionsGranted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _hasOverlay = false;
  bool _hasVpn = false;
  bool _hasPhone = false;
  bool _hasAdmin = false;
  bool _hasUsage = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _checking = true);
    final hasOverlay = await PlatformService.hasOverlayPermission();
    final hasVpn = await PlatformService.hasVpnPermission();
    final hasPhone = await PlatformService.hasPhonePermission();
    final hasAdmin = await PlatformService.hasDeviceAdmin();
    final hasUsage = await PlatformService.hasUsageStatsPermission();

    if (mounted) {
      setState(() {
        _hasOverlay = hasOverlay;
        _hasVpn = hasVpn;
        _hasPhone = hasPhone;
        _hasAdmin = hasAdmin;
        _hasUsage = hasUsage;
        _checking = false;
      });

      if (hasOverlay && hasVpn && hasPhone && hasAdmin && hasUsage) {
        widget.onPermissionsGranted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE3E3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                "SYSTEM SETUP",
                style: TextStyle(
                  color: Color(0xFFEC6530),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Lock Permissions",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "These permissions are strictly required to lock down internet, overlay screens, and automatically re-lock the screen if unlocked.",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _checking
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC6530)),
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildBrutalistCard(
                            title: "Overlay Window",
                            description: "Draws the strict Focus locker screen over other apps.",
                            isGranted: _hasOverlay,
                            onRequest: () => PlatformService.requestOverlayPermission(),
                          ),
                          const SizedBox(height: 20),
                          _buildBrutalistCard(
                            title: "VPN Access",
                            description: "Blocks internet access globally during the session.",
                            isGranted: _hasVpn,
                            onRequest: () => PlatformService.requestVpnPermission(),
                          ),
                          const SizedBox(height: 20),
                          _buildBrutalistCard(
                            title: "Telephony Hook",
                            description: "Allows answering standard calls by hiding the overlay temporarily.",
                            isGranted: _hasPhone,
                            onRequest: () => PlatformService.requestPhonePermission(),
                          ),
                          const SizedBox(height: 20),
                          _buildBrutalistCard(
                            title: "Strict Screen Lock",
                            description: "Enables automatic screen locking (Device Admin) if you unlock your phone.",
                            isGranted: _hasAdmin,
                            onRequest: () => PlatformService.requestDeviceAdmin(),
                          ),
                          const SizedBox(height: 20),
                          _buildBrutalistCard(
                            title: "App Usage Access",
                            description: "Detects if you open another app to enforce the lockdown rules.",
                            isGranted: _hasUsage,
                            onRequest: () => PlatformService.requestUsageStatsPermission(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: (_hasOverlay && _hasVpn && _hasPhone && _hasAdmin && _hasUsage)
                    ? widget.onPermissionsGranted
                    : _checkAllPermissions,
                child: Container(
                  decoration: BoxDecoration(
                    color: (_hasOverlay && _hasVpn && _hasPhone && _hasAdmin && _hasUsage)
                        ? const Color(0xFFEC6530)
                        : const Color(0xFF8FDDDF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Text(
                    (_hasOverlay && _hasVpn && _hasPhone && _hasAdmin && _hasUsage)
                        ? "PROCEED TO FOCUS"
                        : "REFRESH STATUS",
                    style: TextStyle(
                      color: (_hasOverlay && _hasVpn && _hasPhone && _hasAdmin && _hasUsage)
                          ? Colors.white
                          : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrutalistCard({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isGranted ? Icons.check_box_outlined : Icons.check_box_outline_blank_outlined,
            color: isGranted ? const Color(0xFF4CAF50) : Colors.black,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                if (!isGranted)
                  GestureDetector(
                    onTap: onRequest,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF8FDDDF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2.5, 2.5),
                            blurRadius: 0,
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: const Text(
                        "GRANT",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 4),
                      Text(
                        "ACTIVE",
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
