import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/theme_service.dart';

/// Centralised theme state. Replaces isDarkMode / callback drilling.
class ThemeProvider extends ChangeNotifier {
  DarkModeOption _darkModeOption = DarkModeOption.system;
  int _accentColorIndex = 0;
  bool _isDarkMode = false;

  DarkModeOption get darkModeOption => _darkModeOption;
  int get accentColorIndex => _accentColorIndex;
  bool get isDarkMode => _isDarkMode;

  /// Call once after construction (from main.dart or first build).
  Future<void> init() async {
    _darkModeOption = await ThemeService.loadDarkMode();
    _accentColorIndex = await ThemeService.loadAccentColorIndex();
    _resolve();
    _apply();
    notifyListeners();
  }

  void setDarkModeOption(DarkModeOption option) {
    _darkModeOption = option;
    ThemeService.saveDarkMode(option);
    _resolve();
    _apply();
    notifyListeners();
  }

  void toggleDarkMode(bool value) {
    setDarkModeOption(value ? DarkModeOption.dark : DarkModeOption.light);
  }

  void setAccentColorIndex(int index) {
    _accentColorIndex = index;
    ThemeService.saveAccentColorIndex(index);
    _apply();
    notifyListeners();
  }

  // ── private helpers ──────────────────────────────────────────
  void _resolve() {
    _isDarkMode = ThemeService.resolveIsDark(
      _darkModeOption,
      SchedulerBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  void _apply() {
    ThemeService.apply(
      accentIndex: _accentColorIndex,
      darkMode: _darkModeOption,
      platformBrightness:
          SchedulerBinding.instance.platformDispatcher.platformBrightness,
    );
  }
}
