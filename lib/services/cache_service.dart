import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cache service for storing images and data on device
/// Cache is cleared when app is closed from recent apps
class CacheService {
  static const String _imagesCacheDir = 'images_cache';
  static const String _dataCacheDir = 'data_cache';

  /// Get cache directory for images
  static Future<Directory> _getImagesCacheDir() async {
    final appDir = await getTemporaryDirectory();
    final cacheDir = Directory('${appDir.path}/$_imagesCacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Get cache directory for data
  static Future<Directory> _getDataCacheDir() async {
    final appDir = await getTemporaryDirectory();
    final cacheDir = Directory('${appDir.path}/$_dataCacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate cache key from URL
  static String _getCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Cache an image from URL
  static Future<String?> cacheImage(String imageUrl) async {
    try {
      final cacheDir = await _getImagesCacheDir();
      final cacheKey = _getCacheKey(imageUrl);
      final extension = imageUrl.split('.').last.split('?').first;
      final cachedFile = File('${cacheDir.path}/$cacheKey.$extension');

      // Check if already cached
      if (await cachedFile.exists()) {
        return cachedFile.path;
      }

      // Download and cache
      final response = await http
          .get(
            Uri.parse(imageUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await cachedFile.writeAsBytes(response.bodyBytes);
        return cachedFile.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get cached image path if exists
  static Future<String?> getCachedImage(String imageUrl) async {
    try {
      final cacheDir = await _getImagesCacheDir();
      final cacheKey = _getCacheKey(imageUrl);

      // Try common image extensions
      for (final ext in ['jpg', 'jpeg', 'png', 'webp', 'gif']) {
        final cachedFile = File('${cacheDir.path}/$cacheKey.$ext');
        if (await cachedFile.exists()) {
          return cachedFile.path;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cache JSON data with optional TTL metadata
  static Future<bool> cacheData(String key, Map<String, dynamic> data, {Duration? ttl}) async {
    try {
      final cacheDir = await _getDataCacheDir();
      final cacheKey = _getCacheKey(key);
      final cachedFile = File('${cacheDir.path}/$cacheKey.json');

      final wrapper = {
        'data': data,
        'cachedAt': DateTime.now().toIso8601String(),
        if (ttl != null) 'ttlMs': ttl.inMilliseconds,
      };
      await cachedFile.writeAsString(jsonEncode(wrapper));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get cached JSON data. Returns null if expired or not found.
  static Future<Map<String, dynamic>?> getCachedData(String key, {Duration? maxAge}) async {
    try {
      final cacheDir = await _getDataCacheDir();
      final cacheKey = _getCacheKey(key);
      final cachedFile = File('${cacheDir.path}/$cacheKey.json');

      if (await cachedFile.exists()) {
        final content = await cachedFile.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;

        // Check if it's a wrapped format with TTL
        if (decoded.containsKey('cachedAt') && decoded.containsKey('data')) {
          final cachedAt = DateTime.parse(decoded['cachedAt'] as String);
          final ttlMs = decoded['ttlMs'] as int?;
          final effectiveMaxAge = maxAge ?? (ttlMs != null ? Duration(milliseconds: ttlMs) : null);

          if (effectiveMaxAge != null && DateTime.now().difference(cachedAt) > effectiveMaxAge) {
            // Expired — delete and return null
            await cachedFile.delete();
            return null;
          }
          return decoded['data'] as Map<String, dynamic>;
        }

        // Legacy format (no wrapper) — return as-is
        return decoded;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cache a JSON list with optional TTL metadata
  static Future<bool> cacheListData(String key, List<dynamic> data, {Duration? ttl}) async {
    try {
      final cacheDir = await _getDataCacheDir();
      final cacheKey = _getCacheKey(key);
      final cachedFile = File('${cacheDir.path}/$cacheKey.json');

      final wrapper = {
        'listData': data,
        'cachedAt': DateTime.now().toIso8601String(),
        if (ttl != null) 'ttlMs': ttl.inMilliseconds,
      };
      await cachedFile.writeAsString(jsonEncode(wrapper));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get cached JSON list. Returns null if expired or not found.
  static Future<List<dynamic>?> getCachedListData(String key, {Duration? maxAge}) async {
    try {
      final cacheDir = await _getDataCacheDir();
      final cacheKey = _getCacheKey(key);
      final cachedFile = File('${cacheDir.path}/$cacheKey.json');

      if (await cachedFile.exists()) {
        final content = await cachedFile.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;

        if (decoded.containsKey('cachedAt') && decoded.containsKey('listData')) {
          final cachedAt = DateTime.parse(decoded['cachedAt'] as String);
          final ttlMs = decoded['ttlMs'] as int?;
          final effectiveMaxAge = maxAge ?? (ttlMs != null ? Duration(milliseconds: ttlMs) : null);

          if (effectiveMaxAge != null && DateTime.now().difference(cachedAt) > effectiveMaxAge) {
            await cachedFile.delete();
            return null;
          }
          return decoded['listData'] as List<dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clear all cache (called when app is closed)
  static Future<void> clearAllCache() async {
    try {
      final imagesCacheDir = await _getImagesCacheDir();
      final dataCacheDir = await _getDataCacheDir();

      if (await imagesCacheDir.exists()) {
        await imagesCacheDir.delete(recursive: true);
      }
      if (await dataCacheDir.exists()) {
        await dataCacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear only images cache
  static Future<void> clearImagesCache() async {
    try {
      final imagesCacheDir = await _getImagesCacheDir();
      if (await imagesCacheDir.exists()) {
        await imagesCacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear only data cache
  static Future<void> clearDataCache() async {
    try {
      final dataCacheDir = await _getDataCacheDir();
      if (await dataCacheDir.exists()) {
        await dataCacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Invalidate a specific cache key
  static Future<void> invalidate(String key) async {
    try {
      final cacheDir = await _getDataCacheDir();
      final cacheKey = _getCacheKey(key);
      final cachedFile = File('${cacheDir.path}/$cacheKey.json');
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Invalidate all cache keys matching a prefix (scans directory)
  static Future<void> invalidateByPrefix(String prefix) async {
    try {
      final cacheDir = await _getDataCacheDir();
      if (!await cacheDir.exists()) return;
      // Since we hash keys, we can't match by prefix on hashed keys.
      // Instead, maintain a simple approach: clear all data cache when needed.
      // For targeted invalidation, callers should use invalidate() with exact keys.
      await cacheDir.delete(recursive: true);
    } catch (e) {
      // Silently fail
    }
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      int totalSize = 0;
      final imagesCacheDir = await _getImagesCacheDir();
      final dataCacheDir = await _getDataCacheDir();

      if (await imagesCacheDir.exists()) {
        await for (final file in imagesCacheDir.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      if (await dataCacheDir.exists()) {
        await for (final file in dataCacheDir.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
