import 'package:flutter/foundation.dart';
import '../services/prefs_service.dart';

/// Centralized API configuration.
///
/// All backend URLs are derived from [baseUrl]. Update it in one place
/// when the environment changes (dev / staging / prod).
class ApiConfig {
  ApiConfig._();

  static const String _defaultBaseUrl = 'https://ratemymantri.sallytion.qzz.io';
  static const String _debugOverrideKey = 'debug_api_base_url';

  static String _baseUrl = _defaultBaseUrl;

  static String get defaultBaseUrl => _defaultBaseUrl;
  static bool get canOverrideInDebug => kDebugMode;

  static String get baseUrl => _baseUrl;
  static String get v2 => '$baseUrl/v2';
  static String get v3 => '$baseUrl/v3';
  static String get api => '$baseUrl/api';

  /// Loads debug URL override from local preferences.
  /// In release/profile builds this always falls back to default.
  static void loadFromPrefs() {
    if (!kDebugMode) {
      _baseUrl = _defaultBaseUrl;
      return;
    }

    final raw = PrefsService.instance.getString(_debugOverrideKey);
    _baseUrl = _sanitizeBaseUrl(raw) ?? _defaultBaseUrl;
  }

  /// Saves a debug-only base URL override.
  /// Returns false when [rawUrl] is invalid.
  static Future<bool> setDebugBaseUrl(String rawUrl) async {
    if (!kDebugMode) return false;

    final sanitized = _sanitizeBaseUrl(rawUrl);
    if (sanitized == null) return false;

    await PrefsService.instance.setString(_debugOverrideKey, sanitized);
    _baseUrl = sanitized;
    return true;
  }

  /// Clears debug override and reverts to the default base URL.
  static Future<void> resetDebugBaseUrl() async {
    if (!kDebugMode) return;
    await PrefsService.instance.remove(_debugOverrideKey);
    _baseUrl = _defaultBaseUrl;
  }

  static String? _sanitizeBaseUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.isAbsolute) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;

    final normalized = uri.replace(path: '', query: null, fragment: null);
    return normalized.toString().replaceAll(RegExp(r'/+$'), '');
  }
}
