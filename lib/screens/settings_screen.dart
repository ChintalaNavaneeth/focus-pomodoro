import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/platform_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;

  int _widgetHours = 0;
  int _widgetMinutes = 25;
  int _widgetSeconds = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    if (!_loading) {
      _hoursController.dispose();
      _minutesController.dispose();
      _secondsController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final totalSeconds = prefs.getInt('widget_duration_seconds') ?? 1500;
    setState(() {
      _widgetHours = totalSeconds ~/ 3600;
      _widgetMinutes = (totalSeconds % 3600) ~/ 60;
      _widgetSeconds = totalSeconds % 60;
      _hoursController = FixedExtentScrollController(initialItem: _widgetHours);
      _minutesController = FixedExtentScrollController(initialItem: _widgetMinutes);
      _secondsController = FixedExtentScrollController(initialItem: _widgetSeconds);
      _loading = false;
    });
  }

  Future<void> _savePreferences() async {
    final totalSeconds = _widgetHours * 3600 + _widgetMinutes * 60 + _widgetSeconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('widget_duration_seconds', totalSeconds);
    if (mounted) {
      final theme = ref.read(appThemeProvider);
      final h = _widgetHours.toString().padLeft(2, '0');
      final m = _widgetMinutes.toString().padLeft(2, '0');
      final s = _widgetSeconds.toString().padLeft(2, '0');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Widget default timer set to $h:$m:$s'),
        backgroundColor: theme.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final presets = ref.watch(presetTimingsProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SETTINGS',
          style: TextStyle(
            color: theme.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(color: theme.text.withOpacity(0.15), height: 1.5),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // ── APP THEME ──────────────────────────────────────────
                  _sectionLabel('CUSTOM THEME', theme),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to choose custom hex colors or use the color slider.',
                    style: TextStyle(color: theme.text.withOpacity(0.45), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _buildCustomThemePicker(theme),

                  _divider(theme),

                  // ── QUICK PRESETS ──────────────────────────────────────
                  _sectionLabel('QUICK PRESETS', theme),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a preset to edit its name and duration. These appear on the home screen.',
                    style: TextStyle(color: theme.text.withOpacity(0.45), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(4, (i) => _buildPresetRow(i, presets.presets[i], theme)),

                  _divider(theme),

                  // ── WIDGET TIMER ───────────────────────────────────────
                  _sectionLabel('WIDGET DEFAULT TIMER', theme),
                  const SizedBox(height: 4),
                  Text(
                    'Duration used when the home screen widget START button is tapped.',
                    style: TextStyle(color: theme.text.withOpacity(0.45), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _buildClockPicker(theme),
                  const SizedBox(height: 28),

                  // Save button
                  GestureDetector(
                    onTap: () async {
                      await _savePreferences();
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      alignment: Alignment.center,
                      child: Text(
                        'SAVE CONFIGURATION',
                        style: TextStyle(
                          color: theme.isDark ? Colors.black : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, AppThemeOption theme) => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Text(
          text,
          style: TextStyle(
            color: theme.accent,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      );

  Widget _divider(AppThemeOption theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Divider(color: theme.text.withOpacity(0.1), thickness: 1),
      );

  // ── Custom Theme Picker ──────────────────────────────────────────────────
  Widget _buildCustomThemePicker(AppThemeOption theme) {
    return Column(
      children: [
        _buildColorRow('Background Color', theme.background, theme, (color) {
          ref.read(appThemeProvider.notifier).setTheme(color, theme.accent);
        }),
        const SizedBox(height: 10),
        _buildColorRow('Accent & Text Color', theme.accent, theme, (color) {
          ref.read(appThemeProvider.notifier).setTheme(theme.background, color);
        }),
      ],
    );
  }

  Widget _buildColorRow(String title, Color color, AppThemeOption theme, ValueChanged<Color> onColorChanged) {
    return GestureDetector(
      onTap: () => _showColorPicker(title, color, theme, onColorChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.text.withOpacity(0.08), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.text.withOpacity(0.2), width: 1),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: theme.text.withOpacity(0.55),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                color: theme.accent,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.colorize_rounded, color: theme.text.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(String title, Color currentColor, AppThemeOption theme, ValueChanged<Color> onSaved) {
    Color tempColor = currentColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.text.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title.toUpperCase(),
                style: TextStyle(color: theme.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(height: 20),
              ColorPicker(
                pickerColor: tempColor,
                onColorChanged: (c) => tempColor = c,
                colorPickerWidth: 300,
                pickerAreaHeightPercent: 0.7,
                enableAlpha: false,
                displayThumbColor: true,
                hexInputBar: true,
                labelTypes: const [],
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.text.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text('Cancel', style: TextStyle(color: theme.text, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      onSaved(tempColor);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('Save', style: TextStyle(color: theme.isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  // ── Preset Row ──────────────────────────────────────────────────────────────
  Widget _buildPresetRow(int index, PresetTiming preset, AppThemeOption theme) {
    final currentSeconds = preset.seconds;
    final h = currentSeconds ~/ 3600;
    final m = (currentSeconds % 3600) ~/ 60;
    final s = currentSeconds % 60;
    String label;
    if (h > 0 && m > 0) label = '${h}h ${m}m';
    else if (h > 0) label = '${h}h';
    else if (m > 0 && s > 0) label = '${m}m ${s}s';
    else if (m > 0) label = '${m}m';
    else label = '${s}s';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showPresetEditor(index, preset, theme),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.text.withOpacity(0.08), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                preset.name,
                style: TextStyle(
                  color: theme.text.withOpacity(0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_rounded, color: theme.text.withOpacity(0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetEditor(int index, PresetTiming preset, AppThemeOption theme) {
    int h = preset.seconds ~/ 3600;
    int m = (preset.seconds % 3600) ~/ 60;
    int s = preset.seconds % 60;
    String newName = preset.name;

    final hCtrl = FixedExtentScrollController(initialItem: h);
    final mCtrl = FixedExtentScrollController(initialItem: m);
    final sCtrl = FixedExtentScrollController(initialItem: s);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.text.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'EDIT PRESET ${index + 1}',
                  style: TextStyle(color: theme.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 20),
                // Name editor
                TextField(
                  controller: TextEditingController(text: newName),
                  onChanged: (val) => newName = val,
                  style: TextStyle(color: theme.text, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Preset Name',
                    labelStyle: TextStyle(color: theme.text.withOpacity(0.5), fontSize: 12),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.text.withOpacity(0.2)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.accent, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Mini wheel picker
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(height: 50, color: theme.accent.withOpacity(0.08)),
                      Row(
                        children: [
                          _miniWheel(hCtrl, 24, h, theme, (i) { setSheetState(() => h = i); }),
                          Text(':', style: TextStyle(color: theme.text.withOpacity(0.3), fontSize: 28, fontWeight: FontWeight.w900)),
                          _miniWheel(mCtrl, 60, m, theme, (i) { setSheetState(() => m = i); }),
                          Text(':', style: TextStyle(color: theme.text.withOpacity(0.3), fontSize: 28, fontWeight: FontWeight.w900)),
                          _miniWheel(sCtrl, 60, s, theme, (i) { setSheetState(() => s = i); }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.text.withOpacity(0.1)),
                        ),
                        alignment: Alignment.center,
                        child: Text('Cancel', style: TextStyle(color: theme.text, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final newSecs = h * 3600 + m * 60 + s;
                        ref.read(presetTimingsProvider.notifier).setPreset(index, newName.trim(), newSecs);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(12),
                          // no shadow
                        ),
                        alignment: Alignment.center,
                        child: Text('Save', style: TextStyle(color: theme.isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          );
        });
      },
    ).whenComplete(() {
      hCtrl.dispose(); mCtrl.dispose(); sCtrl.dispose();
    });
  }

  Widget _miniWheel(FixedExtentScrollController ctrl, int count, int selected, AppThemeOption theme, ValueChanged<int> onChanged) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 48,
        perspective: 0.002,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (_, i) {
            if (i < 0 || i >= count) return null;
            final isSel = i == selected;
            return Center(
              child: Text(
                i.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: isSel ? theme.accent : theme.text.withOpacity(0.2),
                  fontSize: isSel ? 34 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }

  // ── Widget Clock Picker ─────────────────────────────────────────────────────
  Widget _buildClockPicker(AppThemeOption theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.text.withOpacity(0.08), width: 1.5),
        // no shadow
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(height: 54, color: theme.accent.withOpacity(0.08)),
                Row(
                  children: [
                    _wheelCol(_hoursController, 24, _widgetHours, theme, (i) => setState(() => _widgetHours = i)),
                    _colon(theme),
                    _wheelCol(_minutesController, 60, _widgetMinutes, theme, (i) => setState(() => _widgetMinutes = i)),
                    _colon(theme),
                    _wheelCol(_secondsController, 60, _widgetSeconds, theme, (i) => setState(() => _widgetSeconds = i)),
                  ],
                ),
                // Top/bottom fades
                Positioned(top: 0, left: 0, right: 0, height: 56,
                  child: IgnorePointer(child: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [theme.surface, theme.surface.withOpacity(0)],
                    )),
                  ))),
                Positioned(bottom: 0, left: 0, right: 0, height: 56,
                  child: IgnorePointer(child: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [theme.surface, theme.surface.withOpacity(0)],
                    )),
                  ))),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.text.withOpacity(0.08))),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['HRS', 'MIN', 'SEC'].map((l) => Expanded(
                child: Text(l, textAlign: TextAlign.center,
                  style: TextStyle(color: theme.text.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheelCol(FixedExtentScrollController ctrl, int count, int sel, AppThemeOption theme, ValueChanged<int> onChange) =>
      Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: ctrl,
          itemExtent: 52,
          perspective: 0.002,
          diameterRatio: 1.8,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChange,
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (_, i) {
              if (i < 0 || i >= count) return null;
              final isSel = i == sel;
              return Center(
                child: Text(i.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isSel ? theme.accent : theme.text.withOpacity(0.18),
                    fontSize: isSel ? 38 : 24,
                    fontWeight: FontWeight.w900,
                  )),
              );
            },
            childCount: count,
          ),
        ),
      );

  Widget _colon(AppThemeOption theme) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(':', style: TextStyle(color: theme.text.withOpacity(0.25), fontSize: 30, fontWeight: FontWeight.w900)),
  );
}
