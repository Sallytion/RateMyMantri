import 'dart:convert';
import '../models/constituency.dart';
import 'prefs_service.dart';
import '../config/api_config.dart';
import '../config/api_client.dart';
import 'language_service.dart';

class ConstituencyService {
  static String get baseUrl => ApiConfig.baseUrl;

  Future<String?> _getAccessToken() async {
    final prefs = PrefsService.instance;
    return prefs.getString('access_token');
  }

  Future<Map<String, dynamic>> searchConstituencies(String query) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final lang = LanguageService.languageCode;
      final uri = Uri.parse(
        '$baseUrl/user/constituencies/search',
      ).replace(queryParameters: {'q': query, if (lang != 'en') 'lang': lang});


      final response = await ApiClient.instance.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final constituencies =
            (data['constituencies'] as List?)
                ?.map((json) => Constituency.fromJson(json))
                .toList() ??
            [];


        // Fallback: if Indic-script query returned nothing, retry with Latin
        // transliteration. Remove once backend supports native-script matching.
        if (constituencies.isEmpty && query.runes.any((c) => c > 127)) {
          final latin = LanguageService.translitToLatin(query);
          if (latin != query) {
            final fallbackUri = Uri.parse('$baseUrl/user/constituencies/search')
                .replace(queryParameters: {'q': latin, if (lang != 'en') 'lang': lang});
            final fallbackResponse = await ApiClient.instance.get(fallbackUri, headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
            if (fallbackResponse.statusCode == 200) {
              final fallbackData = json.decode(fallbackResponse.body);
              final fallbackConstituencies =
                  (fallbackData['constituencies'] as List?)
                      ?.map((json) => Constituency.fromJson(json))
                      .toList() ??
                  [];
              return {'constituencies': fallbackConstituencies, 'count': fallbackData['count'] ?? 0};
            }
          }
        }

        return {'constituencies': constituencies, 'count': data['count'] ?? 0};
      } else {
        throw Exception(
          'Failed to search constituencies: ${response.statusCode}',
        );
      }
    } catch (_) {
      return {'constituencies': <Constituency>[], 'count': 0};
    }
  }

  Future<Constituency?> getCurrentConstituency() async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        return null;
      }

      final lang = LanguageService.languageCode;
      final uri = Uri.parse('$baseUrl/user/constituency/current')
          .replace(queryParameters: {if (lang != 'en') 'lang': lang});

      final response = await ApiClient.instance.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['constituency'] != null) {
          return Constituency.fromJson(data['constituency']);
        }
        return null;
      } else {
        throw Exception(
          'Failed to get current constituency: ${response.statusCode}',
        );
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> setCurrentConstituency(
    String constituencyId,
  ) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final lang = LanguageService.languageCode;
      final uri = Uri.parse('$baseUrl/user/constituency/current')
          .replace(queryParameters: {if (lang != 'en') 'lang': lang});

      final response = await ApiClient.instance.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'constituencyId': constituencyId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'constituency': data['constituency'] != null
              ? Constituency.fromJson(data['constituency'])
              : null,
        };
      } else {
        throw Exception('Failed to set constituency: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'constituency': null};
    }
  }
}
