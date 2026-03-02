/// Centralized API configuration.
///
/// All backend URLs are derived from [baseUrl]. Update it in one place
/// when the environment changes (dev / staging / prod).
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://ratemymantri.sallytion.qzz.io';
  static const String v2 = '$baseUrl/v2';
  static const String api = '$baseUrl/api';
}
