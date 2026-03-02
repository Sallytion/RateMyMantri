import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Centralized UI string translations for 10 Indian languages.
/// Translations are loaded lazily from assets/l10n/{code}.json files.
/// Keys are used via LanguageService.tr('key').
class AppTranslations {
  // Cache of loaded translations: langCode -> { key: value }
  static final Map<String, Map<String, String>> _cache = {};

  // Whether _ensureLoaded has been called for a given lang
  static final Set<String> _loading = {};

  /// Pre-load a language (call during splash / language change).
  /// Safe to call multiple times - second call is a no-op.
  static Future<void> load(String langCode) async {
    if (_cache.containsKey(langCode)) return;
    if (_loading.contains(langCode)) return;
    _loading.add(langCode);

    try {
      final jsonStr =
          await rootBundle.loadString('assets/l10n/$langCode.json');
      final Map<String, dynamic> map = json.decode(jsonStr);
      _cache[langCode] =
          map.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      // If the file doesn't exist, store an empty map so we don't retry.
      _cache[langCode] = {};
    } finally {
      _loading.remove(langCode);
    }
  }

  /// Ensure both English (fallback) and the requested language are loaded.
  static Future<void> ensureLoaded(String langCode) async {
    await Future.wait([load('en'), load(langCode)]);
  }

  /// Look up a UI string. Returns the translated value, English fallback,
  /// or the raw key if neither is found.
  ///
  /// **Important:** Call [ensureLoaded] at least once before using [get].
  /// After that, [get] is synchronous-safe from the in-memory cache.
  static String get(String key, String lang) {
    return _cache[lang]?[key] ?? _cache['en']?[key] ?? key;
  }

  /// Clear the cache (useful for hot-reload / tests).
  static void clearCache() {
    _cache.clear();
    _loading.clear();
  }
}
