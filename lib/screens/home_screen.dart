import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/platform_service.dart';
import 'focus_lock_screen.dart';
import 'permissions_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;

  int _selectedHours = 0;
  int _selectedMinutes = 0;
  int _selectedSeconds = 0;

  bool _checkingStatus = true;
  bool _hasAllPermissions = false;

  @override
  void initState() {
    super.initState();
    _hoursController = FixedExtentScrollController(initialItem: 0);
    _minutesController = FixedExtentScrollController(initialItem: 0);
    _secondsController = FixedExtentScrollController(initialItem: 0);
    WidgetsBinding.instance.addObserver(this);
    _checkAppAndPermissionState();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAppAndPermissionState();
  }

  Future<void> _checkAppAndPermissionState() async {
    setState(() => _checkingStatus = true);
    
    // Load the user's actual saved first preset for the dial
    final prefs = await SharedPreferences.getInstance();
    final firstPresetSecs = prefs.getInt('preset_0_seconds') ?? 1500;
    if (mounted) {
      setState(() {
        _selectedHours = firstPresetSecs ~/ 3600;
        _selectedMinutes = (firstPresetSecs % 3600) ~/ 60;
        _selectedSeconds = firstPresetSecs % 60;
        _hoursController.dispose();
        _minutesController.dispose();
        _secondsController.dispose();
        _hoursController = FixedExtentScrollController(initialItem: _selectedHours);
        _minutesController = FixedExtentScrollController(initialItem: _selectedMinutes);
        _secondsController = FixedExtentScrollController(initialItem: _selectedSeconds);
      });
    }

    final isRunning = await PlatformService.isFocusRunning();
    if (isRunning && mounted) {
      final secondsLeft = await PlatformService.getSecondsRemaining();
      setState(() => _checkingStatus = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FocusLockScreen(initialSeconds: secondsLeft),
      ));
      return;
    }
    final hasOverlay = await PlatformService.hasOverlayPermission();
    final hasVpn = await PlatformService.hasVpnPermission();
    final hasPhone = await PlatformService.hasPhonePermission();
    final hasAdmin = await PlatformService.hasDeviceAdmin();
    if (mounted) {
      setState(() {
        _hasAllPermissions = hasOverlay && hasVpn && hasPhone && hasAdmin;
        _checkingStatus = false;
      });
    }
  }

  Future<void> _startFocusSession() async {
    final totalSeconds =
        _selectedHours * 3600 + _selectedMinutes * 60 + _selectedSeconds;
    if (totalSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a focus duration greater than 0.'),
        backgroundColor: Colors.black,
      ));
      return;
    }
    if (!_hasAllPermissions) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PermissionsScreen(
          onPermissionsGranted: () {
            Navigator.of(context).pop();
            _checkAppAndPermissionState();
          },
        ),
      ));
      return;
    }
    final success = await PlatformService.startFocus(totalSeconds);
    if (success && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FocusLockScreen(initialSeconds: totalSeconds),
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to initiate lock session. Please try again.'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  void _applyPreset(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    setState(() {
      _selectedHours = h;
      _selectedMinutes = m;
      _selectedSeconds = s;
    });
    _hoursController.animateToItem(h,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    _minutesController.animateToItem(m,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    _secondsController.animateToItem(s,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final presets = ref.watch(presetTimingsProvider);

    if (_checkingStatus) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: CircularProgressIndicator(color: theme.accent),
        ),
      );
    }

    if (!_hasAllPermissions) {
      return PermissionsScreen(
        onPermissionsGranted: () => setState(() => _hasAllPermissions = true),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'FOCUS',
          style: TextStyle(
            color: theme.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: theme.text, size: 26),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: theme.text.withOpacity(0.15), height: 1.5),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // ── Gen-Z Clock Picker ─────────────────────────────────
              _buildGenZClockPicker(theme),
              const SizedBox(height: 20),
              // Duration pill summary
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: theme.accent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Text(
                    _buildDurationLabel(),
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Quick Presets ──────────────────────────────────────
              Text(
                'QUICK PRESETS',
                style: TextStyle(
                  color: theme.text.withOpacity(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildPresetChip(presets.presets[0], theme)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildPresetChip(presets.presets[1], theme)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildPresetChip(presets.presets[2], theme)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildPresetChip(presets.presets[3], theme)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // ── Start Button ───────────────────────────────────────
              _buildStartButton(theme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDurationLabel() {
    final total =
        _selectedHours * 3600 + _selectedMinutes * 60 + _selectedSeconds;
    if (total == 0) return 'tap to set duration';
    final parts = <String>[];
    if (_selectedHours > 0) parts.add('${_selectedHours}h');
    if (_selectedMinutes > 0) parts.add('${_selectedMinutes}m');
    if (_selectedSeconds > 0) parts.add('${_selectedSeconds}s');
    return parts.join(' ');
  }

  Widget _buildGenZClockPicker(AppThemeOption theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.text.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Selection highlight bar
          Container(
            height: 200,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center glow band
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(0.08),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: theme.accent.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildWheel(
                      controller: _hoursController,
                      count: 24,
                      selected: _selectedHours,
                      theme: theme,
                      onChanged: (i) => setState(() => _selectedHours = i),
                    ),
                    _buildColon(theme),
                    _buildWheel(
                      controller: _minutesController,
                      count: 60,
                      selected: _selectedMinutes,
                      theme: theme,
                      onChanged: (i) => setState(() => _selectedMinutes = i),
                    ),
                    _buildColon(theme),
                    _buildWheel(
                      controller: _secondsController,
                      count: 60,
                      selected: _selectedSeconds,
                      theme: theme,
                      onChanged: (i) => setState(() => _selectedSeconds = i),
                    ),
                  ],
                ),
                // Top fade
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.surface,
                            theme.surface.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            theme.surface,
                            theme.surface.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Labels
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: theme.text.withOpacity(0.08), width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('HRS',
                      style: _labelStyle(theme), textAlign: TextAlign.center),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text('MIN',
                      style: _labelStyle(theme), textAlign: TextAlign.center),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text('SEC',
                      style: _labelStyle(theme), textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle(AppThemeOption theme) => TextStyle(
        color: theme.text.withOpacity(0.35),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      );

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required AppThemeOption theme,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 58,
        perspective: 0.002,
        diameterRatio: 1.8,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= count) return null;
            final isSel = index == selected;
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: isSel ? theme.accent : theme.text.withOpacity(0.2),
                  fontSize: isSel ? 42 : 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                child: Text(index.toString().padLeft(2, '0')),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }

  Widget _buildColon(AppThemeOption theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        ':',
        style: TextStyle(
          color: theme.text.withOpacity(0.3),
          fontSize: 32,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildPresetChip(PresetTiming preset, AppThemeOption theme) {
    final seconds = preset.seconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final totalSelected =
        _selectedHours * 3600 + _selectedMinutes * 60 + _selectedSeconds;
    final isSelected = totalSelected == seconds;

    // Build full time label: show each non-zero unit
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0) parts.add('${s}s');
    final timeLabel = parts.isEmpty ? '0s' : parts.join(' ');

    return GestureDetector(
      onTap: () => _applyPreset(seconds),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent : theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.accent : theme.text.withOpacity(0.12),
            width: isSelected ? 0 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              preset.name,
              style: TextStyle(
                color: isSelected ? (theme.isDark ? Colors.black : Colors.white) : theme.text.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeLabel,
              style: TextStyle(
                color: isSelected ? (theme.isDark ? Colors.black : Colors.white).withOpacity(0.8) : theme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(AppThemeOption theme) {
    final totalSelected =
        _selectedHours * 3600 + _selectedMinutes * 60 + _selectedSeconds;
    final isDisabled = totalSelected == 0;

    return GestureDetector(
      onTap: isDisabled ? null : _startFocusSession,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDisabled ? theme.text.withOpacity(0.1) : theme.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          'START FOCUS LOCK',
          style: TextStyle(
            color: isDisabled 
                ? theme.text.withOpacity(0.3) 
                : (theme.isDark ? Colors.black : Colors.white),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
