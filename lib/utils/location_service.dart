import 'package:ip_detector/ip_detector.dart';
import '../services/prefs_service.dart';

/// Singleton service for detecting the user's city from their IP address.
/// Results are cached in SharedPreferences with a configurable TTL.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Returns `{'city': '...', 'country': '...'}` or `null` on failure.
  /// Results are cached for [ttlSeconds] (default: 24 h).
  Future<Map<String, String>?> getCityFromIp({int ttlSeconds = 86400}) async {
    try {
      final prefs = PrefsService.instance;
      final ts = prefs.getInt('geo_ts') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - ts < ttlSeconds) {
        final city = prefs.getString('geo_city');
        final country = prefs.getString('geo_country');
        if (city != null && country != null) {
          return {'city': city, 'country': country};
        }
      }

      final ipDetector = IpDetector(timeout: const Duration(seconds: 10));
      final response = await ipDetector.fetch(enableLog: false);

      if (response.type == IpDetectorResponseType.succeedResponse) {
        final city = ipDetector.city()?.trim();
        final country = ipDetector.countryCode()?.trim();

        if (city != null &&
            city.isNotEmpty &&
            country != null &&
            country.isNotEmpty) {
          await prefs.setString('geo_city', city);
          await prefs.setString('geo_country', country);
          await prefs.setInt('geo_ts', now);
          return {'city': city, 'country': country};
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
