import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../services/platform_service.dart';

class FocusLockScreen extends ConsumerStatefulWidget {
  final int initialSeconds;

  const FocusLockScreen({super.key, required this.initialSeconds});

  @override
  ConsumerState<FocusLockScreen> createState() => _FocusLockScreenState();
}

class _FocusLockScreenState extends ConsumerState<FocusLockScreen> {
  late int _secondsRemaining;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSeconds;
    _startSyncTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final isRunning = await PlatformService.isFocusRunning();
      if (!isRunning) {
        if (mounted) {
          _syncTimer?.cancel();
          Navigator.of(context).pop();
        }
        return;
      }

      final seconds = await PlatformService.getSecondsRemaining();
      if (mounted) {
        setState(() {
          _secondsRemaining = seconds;
        });
        if (_secondsRemaining <= 0) {
          _syncTimer?.cancel();
          Navigator.of(context).pop();
        }
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final accent = theme.accent;

    return PopScope(
      canPop: false, // Strict lockdown
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'FOCUS ACTIVE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 52),
                // Timer card
                Center(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 40),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(_secondsRemaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'TIME REMAINING',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                const Text(
                  'Your device is in Strict Lockdown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Internet is locked. Apps are blocked.\nOnly voice calls are allowed.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
