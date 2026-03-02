import 'package:http/http.dart' as http;

/// Singleton HTTP client with connection keep-alive.
///
/// Use [ApiClient.instance] everywhere instead of calling `http.get()` /
/// `http.post()` directly. The single underlying [http.Client] reuses TCP
/// sockets across requests, avoiding the per-request socket overhead.
class ApiClient {
  ApiClient._() : _client = http.Client();

  static final ApiClient _instance = ApiClient._();

  /// The shared [ApiClient] instance.
  static ApiClient get instance => _instance;

  final http.Client _client;

  /// Direct access to the underlying [http.Client] for advanced use (e.g.
  /// streaming). Prefer the convenience methods below for typical calls.
  http.Client get client => _client;

  // ── Convenience wrappers ─────────────────────────────────────────

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _client.get(url, headers: headers);

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    encoding,
  }) =>
      _client.post(url, headers: headers, body: body, encoding: encoding);

  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    encoding,
  }) =>
      _client.put(url, headers: headers, body: body, encoding: encoding);

  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    encoding,
  }) =>
      _client.delete(url, headers: headers, body: body, encoding: encoding);

  /// Close the underlying client. Only call this on app termination.
  void close() => _client.close();
}
