import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_section.dart';

/// Fetches and caches the dynamic home sections from the backend.
///
/// Caching strategy (matches §9 of the API spec):
///  - In-memory per (lang, theme) key — zero-latency on same-session re-opens.
///  - SharedPreferences persistence — survives cold starts.
///  - TTL is driven by the `ttl` field in the API response.
///  - On error (4xx / 5xx / network) → return last persisted cache if any.
class HomeSectionsService {
  static const String _baseUrl = 'https://ratemymantri.sallytion.qzz.io';
  static const String _prefPrefix = 'home_sections_';

  // In-memory cache: "(lang)_(theme)" → list of sections
  static final Map<String, List<HomeSection>> _memCache = {};
  // Tracks when each in-memory cache entry was stored (epoch ms)
  static final Map<String, int> _memCacheTs = {};
  // TTL per key in seconds (from last successful fetch)
  static final Map<String, int> _memCacheTtl = {};

  /// Fetch sections for the given [lang] and [theme].
  ///
  /// Returns a (possibly empty) list of [HomeSection] objects that are:
  ///  - visible == true
  ///  - have a recognised type (currently only `webview_banner`)
  ///  - have all required fields present
  ///
  /// Never throws — returns an empty list on unrecoverable failure.
  static Future<List<HomeSection>> fetchSections({
    required String lang,
    required String theme,
    String? appVersion,
  }) async {
    final cacheKey = '${lang}_$theme';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // ① Check in-memory cache
    if (_memCache.containsKey(cacheKey)) {
      final age = nowMs - (_memCacheTs[cacheKey] ?? 0);
      final ttlMs = (_memCacheTtl[cacheKey] ?? 300) * 1000;
      if (age < ttlMs) {
        // Still fresh — return immediately; background refresh happens below
        _backgroundRefresh(lang: lang, theme: theme, appVersion: appVersion);
        return _memCache[cacheKey]!;
      }
    }

    // ② Try a live fetch
    try {
      final uri = Uri.parse('$_baseUrl/api/home/sections').replace(
        queryParameters: {
          'lang': lang,
          'theme': theme,
          if (appVersion != null) 'v': appVersion,
        },
      );
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final parsed = _parse(response.body);
        final ttl = parsed['ttl'] as int? ?? 300;
        final sections = (parsed['sections'] as List<HomeSection>);

        // Update in-memory cache
        _memCache[cacheKey] = sections;
        _memCacheTs[cacheKey] = nowMs;
        _memCacheTtl[cacheKey] = ttl;

        // Persist to SharedPreferences for cold-start survival
        _persist(cacheKey, response.body, ttl);

        return sections;
      }
      // Non-200 → fall through to persisted cache
    } catch (_) {
      // Network unavailable → fall through to persisted cache
    }

    // ③ Fall back to persisted SharedPreferences cache
    return await _loadPersisted(cacheKey);
  }

  // ─── Helpers ────────────────────────────────────────────────────

  /// Fire-and-forget background refresh (called when in-memory cache is stale-ish).
  /// Does NOT update the caller's result — that update will land on next widget rebuild.
  static void _backgroundRefresh({
    required String lang,
    required String theme,
    String? appVersion,
  }) {
    // Only trigger if TTL for in-memory is within 30 s of expiry
    final cacheKey = '${lang}_$theme';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final age = nowMs - (_memCacheTs[cacheKey] ?? 0);
    final ttlMs = (_memCacheTtl[cacheKey] ?? 300) * 1000;
    if (age < ttlMs - 30000) return; // Still fresh enough

    // Kick off a background fetch — ignore result here
    fetchSections(lang: lang, theme: theme, appVersion: appVersion);
  }

  /// Parse the raw JSON body into a map with `sections` as `List<HomeSection>`
  /// and `ttl` as int.  Invalid sections are silently skipped.
  static Map<String, dynamic> _parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final raw = json['sections'] as List<dynamic>? ?? [];
      final ttl = json['ttl'] as int? ?? 300;

      final sections = raw
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return HomeSection.fromJson(e);
            } catch (_) {
              return null;
            }
          })
          .whereType<HomeSection>()
          .where((s) => s.visible && s.isComplete && s.type == 'webview_banner')
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      return {'sections': sections, 'ttl': ttl};
    } catch (_) {
      return {'sections': <HomeSection>[], 'ttl': 300};
    }
  }

  /// Write the raw JSON body + epoch timestamp to SharedPreferences.
  static Future<void> _persist(String cacheKey, String rawBody, int ttl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefPrefix${cacheKey}_body', rawBody);
      await prefs.setInt(
        '$_prefPrefix${cacheKey}_ts',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setInt('$_prefPrefix${cacheKey}_ttl', ttl);
    } catch (_) {}
  }

  /// Read + parse the persisted SharedPreferences cache.
  /// Returns an empty list if nothing is stored or the stored data is corrupt.
  static Future<List<HomeSection>> _loadPersisted(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString('$_prefPrefix${cacheKey}_body');
      if (body == null) return [];

      final parsed = _parse(body);
      final sections = parsed['sections'] as List<HomeSection>;

      // Warm in-memory cache from persisted data (ttl carried over)
      final ttl = prefs.getInt('$_prefPrefix${cacheKey}_ttl') ?? 300;
      final ts = prefs.getInt('$_prefPrefix${cacheKey}_ts') ?? 0;
      _memCache[cacheKey] = sections;
      _memCacheTs[cacheKey] = ts;
      _memCacheTtl[cacheKey] = ttl;

      return sections;
    } catch (_) {
      return [];
    }
  }

  /// Clears both in-memory and persisted caches.
  /// Call this when lang or theme changes so stale translated URLs are evicted.
  static Future<void> clearAll() async {
    _memCache.clear();
    _memCacheTs.clear();
    _memCacheTtl.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefPrefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
