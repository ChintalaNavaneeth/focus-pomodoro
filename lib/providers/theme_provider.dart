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

  AppThemeOption({
    this.name = 'CUSTOM THEME',
    this.emoji = '🎨',
    required this.accent,
    required this.background,
  })  : isDark = background.computeLuminance() < 0.5,
        text = background.computeLuminance() < 0.5 ? Colors.white : Colors.black,
        surface = background.computeLuminance() < 0.5 
            ? Color.lerp(background, Colors.white, 0.08)!
            : Color.lerp(background, Colors.black, 0.06)!;
}

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

const String _kThemeBgKey = 'app_theme_bg_color';
const String _kThemeAccentKey = 'app_theme_accent_color';
const String _kEinkModeKey = 'app_eink_mode';
const String _kEinkDarkKey = 'app_eink_dark_mode';

String _presetNameKey(int i) => 'preset_${i}_name';
String _presetSecsKey(int i) => 'preset_${i}_seconds';

// ─── E-Ink Providers ──────────────────────────────────────────────────────────

class EInkModeNotifier extends StateNotifier<bool> {
  EInkModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kEinkModeKey) ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEinkModeKey, value);
  }
}

class EInkDarkModeNotifier extends StateNotifier<bool> {
  EInkDarkModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kEinkDarkKey) ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEinkDarkKey, value);
  }
}

final eInkModeProvider = StateNotifierProvider<EInkModeNotifier, bool>((ref) {
  return EInkModeNotifier();
});

final eInkDarkModeProvider = StateNotifierProvider<EInkDarkModeNotifier, bool>((ref) {
  return EInkDarkModeNotifier();
});

// ─── Theme Provider ───────────────────────────────────────────────────────────

class AppThemeNotifier extends StateNotifier<AppThemeOption> {
  AppThemeNotifier() : super(AppThemeOption(background: const Color(0xFF000000), accent: const Color(0xFFFFFFFF))) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final bgVal = prefs.getInt(_kThemeBgKey);
    final accVal = prefs.getInt(_kThemeAccentKey);
    
    final bg = bgVal != null ? Color(bgVal) : const Color(0xFF000000);
    final accent = accVal != null ? Color(accVal) : const Color(0xFFFFFFFF);
    
    state = AppThemeOption(background: bg, accent: accent);
  }

  Future<void> setTheme(Color background, Color accent) async {
    state = AppThemeOption(background: background, accent: accent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeBgKey, background.value);
    await prefs.setInt(_kThemeAccentKey, accent.value);
  }
}

final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeOption>((ref) {
  return AppThemeNotifier();
});

final activeThemeProvider = Provider<AppThemeOption>((ref) {
  final baseTheme = ref.watch(appThemeProvider);
  final isEink = ref.watch(eInkModeProvider);
  final isEinkDark = ref.watch(eInkDarkModeProvider);

  if (!isEink) return baseTheme;

  if (isEinkDark) {
    return AppThemeOption(
      name: 'E-INK DARK',
      emoji: '📓',
      background: Colors.black,
      accent: Colors.white,
    );
  } else {
    return AppThemeOption(
      name: 'E-INK LIGHT',
      emoji: '📰',
      background: Colors.white,
      accent: Colors.black,
    );
  }
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
