import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/constituency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_service.dart';

class ConstituencyService {
  static const String baseUrl = 'https://ratemymantri.sallytion.qzz.io';

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
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

      debugPrint('[CSSearch] lang=$lang');
      debugPrint('[CSSearch] raw query="$query" (len=${query.length})');
      debugPrint('[CSSearch] query codepoints=${query.runes.toList()}');
      debugPrint('[CSSearch] full URL=${uri.toString()}');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('[CSSearch] HTTP status=${response.statusCode}');
      debugPrint('[CSSearch] response body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final constituencies =
            (data['constituencies'] as List?)
                ?.map((json) => Constituency.fromJson(json))
                .toList() ??
            [];

        debugPrint('[CSSearch] parsed ${constituencies.length} results');

        // Fallback: if Indic-script query returned nothing, retry with Latin
        // transliteration. Remove once backend supports native-script matching.
        if (constituencies.isEmpty && query.runes.any((c) => c > 127)) {
          final latin = LanguageService.translitToLatin(query);
          if (latin != query) {
            debugPrint('[CSSearch] 0 results for Indic query, retrying with latin="$latin"');
            final fallbackUri = Uri.parse('$baseUrl/user/constituencies/search')
                .replace(queryParameters: {'q': latin, if (lang != 'en') 'lang': lang});
            final fallbackResponse = await http.get(fallbackUri, headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            });
            debugPrint('[CSSearch] fallback status=${fallbackResponse.statusCode}');
            debugPrint('[CSSearch] fallback body=${fallbackResponse.body}');
            if (fallbackResponse.statusCode == 200) {
              final fallbackData = json.decode(fallbackResponse.body);
              final fallbackConstituencies =
                  (fallbackData['constituencies'] as List?)
                      ?.map((json) => Constituency.fromJson(json))
                      .toList() ??
                  [];
              debugPrint('[CSSearch] fallback parsed ${fallbackConstituencies.length} results');
              return {'constituencies': fallbackConstituencies, 'count': fallbackData['count'] ?? 0};
            }
          }
        }

        return {'constituencies': constituencies, 'count': data['count'] ?? 0};
      } else {
        debugPrint('[CSSearch] ERROR: ${response.statusCode} ${response.body}');
        throw Exception(
          'Failed to search constituencies: ${response.statusCode}',
        );
      }
    } catch (e, stack) {
      debugPrint('[CSSearch] EXCEPTION: $e\n$stack');
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

      final response = await http.get(
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

      final response = await http.post(
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
