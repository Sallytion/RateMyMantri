import 'package:flutter/material.dart';
import 'prefs_service.dart';

/// Supported dark mode options.
enum DarkModeOption {
  system,
  light,
  dark,
  amoled,
}

class ThemeService {
  static const _darkModeKey = 'theme_dark_mode';
  static const _accentColorKey = 'theme_accent_color';

  // ─── Live static state (set from MainScreen, read everywhere) ────
  static Color accent = const Color(0xFFFF385C);
  static bool _amoled = false;

  /// Call from MainScreen whenever theme changes.
  static void apply({
    required int accentIndex,
    required DarkModeOption darkMode,
    required Brightness platformBrightness,
  }) {
    accent = accentColors[accentIndex.clamp(0, accentColors.length - 1)];
    _amoled = darkMode == DarkModeOption.amoled &&
        resolveIsDark(darkMode, platformBrightness);
  }

  // ─── AMOLED-aware dark colors ────────────────────────────────────
  /// Main background  (#1A1A1A or #000000)
  static Color get bgMain => _amoled ? const Color(0xFF000000) : const Color(0xFF1A1A1A);
  /// Alt background   (#121212 or #000000)
  static Color get bgAlt => _amoled ? const Color(0xFF000000) : const Color(0xFF121212);
  /// Card / surface   (#1E1E1E or #0A0A0A)
  static Color get bgCard => _amoled ? const Color(0xFF0A0A0A) : const Color(0xFF1E1E1E);
  /// Elevated card     (#2A2A2A or #121212)
  static Color get bgElev => _amoled ? const Color(0xFF121212) : const Color(0xFF2A2A2A);
  /// Border / divider  (#3A3A3A or #1A1A1A)
  static Color get bgBorder => _amoled ? const Color(0xFF1A1A1A) : const Color(0xFF3A3A3A);

  // Available accent colors
  static const List<Color> accentColors = [
    Color(0xFFFF385C), // Default red/pink
    Color(0xFF6C5CE7), // Purple
    Color(0xFF0984E3), // Blue
    Color(0xFF00B894), // Green
    Color(0xFFE17055), // Coral
    Color(0xFFFDAA5E), // Orange
  ];

  static const List<String> accentColorNames = [
    'Rose',
    'Purple',
    'Blue',
    'Green',
    'Coral',
    'Orange',
  ];

  /// Load saved dark mode preference. Defaults to [DarkModeOption.system].
  static Future<DarkModeOption> loadDarkMode() async {
    final prefs = PrefsService.instance;
    final index = prefs.getInt(_darkModeKey) ?? 0;
    if (index >= 0 && index < DarkModeOption.values.length) {
      return DarkModeOption.values[index];
    }
    return DarkModeOption.system;
  }

  /// Persist dark mode preference.
  static Future<void> saveDarkMode(DarkModeOption option) async {
    final prefs = PrefsService.instance;
    await prefs.setInt(_darkModeKey, option.index);
  }

  /// Load saved accent color index. Defaults to 0 (Rose).
  static Future<int> loadAccentColorIndex() async {
    final prefs = PrefsService.instance;
    return prefs.getInt(_accentColorKey) ?? 0;
  }

  /// Persist accent color index.
  static Future<void> saveAccentColorIndex(int index) async {
    final prefs = PrefsService.instance;
    await prefs.setInt(_accentColorKey, index);
  }

  /// Resolve whether app should use dark mode based on [option] and platform brightness.
  static bool resolveIsDark(DarkModeOption option, Brightness platformBrightness) {
    switch (option) {
      case DarkModeOption.system:
        return platformBrightness == Brightness.dark;
      case DarkModeOption.light:
        return false;
      case DarkModeOption.dark:
      case DarkModeOption.amoled:
        return true;
    }
  }

  /// Whether current option is AMOLED (pure black backgrounds).
  static bool isAmoled(DarkModeOption option) => option == DarkModeOption.amoled;
}
