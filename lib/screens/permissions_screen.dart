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

  bool get _allGranted =>
      _hasOverlay && _hasVpn && _hasPhone && _hasAdmin && _hasUsage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
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
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Lock Permissions",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "These permissions are strictly required to lock down internet, overlay screens, and automatically re-lock the screen if unlocked.",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: _checking
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildPermissionRow(
                            title: "Overlay Window",
                            description: "Draws the strict Focus locker screen over other apps.",
                            isGranted: _hasOverlay,
                            onRequest: () => PlatformService.requestOverlayPermission(),
                          ),
                          _buildPermissionRow(
                            title: "VPN Access",
                            description: "Blocks internet access globally during the session.",
                            isGranted: _hasVpn,
                            onRequest: () => PlatformService.requestVpnPermission(),
                          ),
                          _buildPermissionRow(
                            title: "Telephony Hook",
                            description: "Allows answering standard calls by hiding the overlay temporarily.",
                            isGranted: _hasPhone,
                            onRequest: () => PlatformService.requestPhonePermission(),
                          ),
                          _buildPermissionRow(
                            title: "Strict Screen Lock",
                            description: "Enables automatic screen locking (Device Admin) if you unlock your phone.",
                            isGranted: _hasAdmin,
                            onRequest: () => PlatformService.requestDeviceAdmin(),
                          ),
                          _buildPermissionRow(
                            title: "App Usage Access",
                            description: "Detects if you open another app to enforce the lockdown rules.",
                            isGranted: _hasUsage,
                            onRequest: () => PlatformService.requestUsageStatsPermission(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _allGranted ? widget.onPermissionsGranted : _checkAllPermissions,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _allGranted ? Colors.white : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _allGranted ? Colors.white : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: Text(
                    _allGranted ? "PROCEED TO FOCUS" : "REFRESH STATUS",
                    style: TextStyle(
                      color: _allGranted ? Colors.black : Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
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

  Widget _buildPermissionRow({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGranted ? Colors.white12 : Colors.white12,
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isGranted ? Colors.white : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check : Icons.lock_outline,
              color: isGranted ? Colors.black : Colors.white38,
              size: 18,
            ),
          ),
          title: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: isGranted ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          trailing: isGranted
              ? const Text(
                  "ACTIVE",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                )
              : GestureDetector(
                  onTap: onRequest,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: const Text(
                      "GRANT",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
