import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/constituency.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      final uri = Uri.parse(
        '$baseUrl/user/constituencies/search',
      ).replace(queryParameters: {'q': query});

      final response = await http.get(
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

        return {'constituencies': constituencies, 'count': data['count'] ?? 0};
      } else {
        throw Exception(
          'Failed to search constituencies: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {'constituencies': <Constituency>[], 'count': 0};
    }
  }

  Future<Constituency?> getCurrentConstituency() async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        return null;
      }

      final uri = Uri.parse('$baseUrl/user/constituency/current');

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

      final uri = Uri.parse('$baseUrl/user/constituency/current');

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
