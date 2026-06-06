import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Option ────────────────────────────────────────────────────────────

class AppThemeOption {
  final String name;
  final String emoji;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final bool isDark;

  const AppThemeOption({
    required this.name,
    required this.emoji,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    this.isDark = false,
  });
}

const List<AppThemeOption> kThemeOptions = [
  AppThemeOption(
    name: 'ELECTRIC BLUE',
    emoji: '⚡',
    accent: Color(0xFF2563EB),
    background: Color(0xFFE8F0FF),
    surface: Color(0xFFD8E6FF),
    text: Colors.black,
  ),
  AppThemeOption(
    name: 'FOCUS ORANGE',
    emoji: '🔥',
    accent: Color(0xFFEC6530),
    background: Color(0xFFFFE3E3),
    surface: Color(0xFFFFD0C0),
    text: Colors.black,
  ),
  AppThemeOption(
    name: 'CYBER GREEN',
    emoji: '🌿',
    accent: Color(0xFF16A34A),
    background: Color(0xFFE4F7EC),
    surface: Color(0xFFCCF0D8),
    text: Colors.black,
  ),
  AppThemeOption(
    name: 'VIOLET PULSE',
    emoji: '💜',
    accent: Color(0xFF7C3AED),
    background: Color(0xFFF0E8FF),
    surface: Color(0xFFE2D5FF),
    text: Colors.black,
  ),
  AppThemeOption(
    name: 'VOID BLACK',
    emoji: '🖤',
    accent: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    surface: Color(0xFF111111),
    text: Colors.white,
    isDark: true,
  ),
];

// ─── Preset Timings ───────────────────────────────────────────────────────────

class PresetTiming {
  final String name;
  final int seconds;

  const PresetTiming({required this.name, required this.seconds});
}

class PresetTimings {
  final List<PresetTiming> presets; // list of 4 presets

  const PresetTimings(this.presets);

  static const defaults = PresetTimings([
    PresetTiming(name: "Pomodoro", seconds: 1500),
    PresetTiming(name: "Short Break", seconds: 300),
    PresetTiming(name: "Long Break", seconds: 900),
    PresetTiming(name: "Deep Work", seconds: 3600),
  ]);

  PresetTimings copyWith(int index, String name, int seconds) {
    final list = List<PresetTiming>.from(presets);
    list[index] = PresetTiming(name: name, seconds: seconds);
    return PresetTimings(list);
  }
}

// ─── Persistence Keys ─────────────────────────────────────────────────────────

const String _kThemeIndexKey = 'app_theme_index';

String _presetNameKey(int i) => 'preset_${i}_name';
String _presetSecsKey(int i) => 'preset_${i}_seconds';

// ─── Theme Provider ───────────────────────────────────────────────────────────

class AppThemeNotifier extends StateNotifier<AppThemeOption> {
  AppThemeNotifier() : super(kThemeOptions[0]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kThemeIndexKey) ?? 0;
    final clamped = index.clamp(0, kThemeOptions.length - 1);
    state = kThemeOptions[clamped];
  }

  Future<void> setTheme(AppThemeOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeIndexKey, kThemeOptions.indexOf(option));
  }
}

final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeOption>((ref) {
  return AppThemeNotifier();
});

// ─── Preset Timings Provider ──────────────────────────────────────────────────

class PresetTimingsNotifier extends StateNotifier<PresetTimings> {
  PresetTimingsNotifier() : super(PresetTimings.defaults) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedPresets = <PresetTiming>[];
    for (int i = 0; i < 4; i++) {
      final name = prefs.getString(_presetNameKey(i)) ?? PresetTimings.defaults.presets[i].name;
      final secs = prefs.getInt(_presetSecsKey(i)) ?? PresetTimings.defaults.presets[i].seconds;
      loadedPresets.add(PresetTiming(name: name, seconds: secs));
    }
    state = PresetTimings(loadedPresets);
  }

  Future<void> setPreset(int index, String name, int seconds) async {
    state = state.copyWith(index, name, seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetNameKey(index), name);
    await prefs.setInt(_presetSecsKey(index), seconds);
  }
}

final presetTimingsProvider =
    StateNotifierProvider<PresetTimingsNotifier, PresetTimings>((ref) {
  return PresetTimingsNotifier();
});
