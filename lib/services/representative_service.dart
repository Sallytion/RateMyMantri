import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/representative.dart';
import '../models/representative_detail.dart';

class RepresentativeService {
  static const String baseUrl = 'https://ratemymantri.sallytion.qzz.io/v2';

  Future<Map<String, dynamic>> searchRepresentatives(
    String query, {
    int? limit,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/representatives/search').replace(
        queryParameters: {
          'q': query,
          if (limit != null) 'limit': limit.toString(),
        },
      );

      print('Searching representatives: $uri');
      final response = await http.get(uri);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed data: $data');

        final count = data['count'] ?? 0;
        final results =
            (data['results'] as List?)
                ?.map((json) {
                  try {
                    return Representative.fromJson(json);
                  } catch (e) {
                    print('Error parsing representative: $e');
                    print('JSON data: $json');
                    return null;
                  }
                })
                .whereType<Representative>()
                .toList() ??
            [];

        print('Parsed ${results.length} results');
        return {'count': count, 'results': results};
      } else {
        print('API error: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Failed to load representatives: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('Error searching representatives: $e');
      print('Stack trace: $stackTrace');
      return {'count': 0, 'results': <Representative>[]};
    }
  }

  /// Fetch representatives for a given constituency/location name
  Future<Map<String, dynamic>> getMyRepresentatives(String location) async {
    try {
      final uri = Uri.parse('$baseUrl/my-representatives').replace(
        queryParameters: {'location': location},
      );

      print('Fetching my representatives: $uri');
      final response = await http.get(uri);
      print('My-representatives response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final reps = data['representatives'] ?? {};
          final List<Representative> allReps = [];

          // Parse MLA list
          if (reps['mla'] != null && reps['mla'] is List) {
            for (var json in reps['mla']) {
              try {
                allReps.add(Representative.fromJson(json));
              } catch (e) {
                print('Error parsing MLA: $e');
              }
            }
          }

          // Parse Lok Sabha member
          if (reps['lokSabha'] != null && reps['lokSabha'] is Map) {
            try {
              allReps.add(Representative.fromJson(reps['lokSabha']));
            } catch (e) {
              print('Error parsing Lok Sabha: $e');
            }
          }

          // Parse Rajya Sabha members
          if (reps['rajyaSabha'] != null && reps['rajyaSabha'] is List) {
            for (var json in reps['rajyaSabha']) {
              try {
                allReps.add(Representative.fromJson(json));
              } catch (e) {
                print('Error parsing Rajya Sabha: $e');
              }
            }
          }

          // Parse Vidhan Parishad members
          if (reps['vidhanParishad'] != null && reps['vidhanParishad'] is List) {
            for (var json in reps['vidhanParishad']) {
              try {
                allReps.add(Representative.fromJson(json));
              } catch (e) {
                print('Error parsing Vidhan Parishad: $e');
              }
            }
          }

          return {
            'success': true,
            'representatives': allReps,
            'location': data['location'],
          };
        }
      }

      return {'success': false, 'representatives': <Representative>[]};
    } catch (e, stackTrace) {
      print('Error fetching my representatives: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'representatives': <Representative>[]};
    }
  }

  Future<RepresentativeDetail?> getRepresentativeById(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/representatives/$id');
      print('Fetching representative detail: $uri');
      final response = await http.get(uri);
      print('Detail response status: ${response.statusCode}');
      print('Detail response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed detail data: $data');
        // V2 API returns {success: true, data: {...}}
        if (data['success'] == true && data['data'] != null) {
          return RepresentativeDetail.fromJson(data['data']);
        } else {
          return RepresentativeDetail.fromJson(data);
        }
      } else {
        print('Detail API error: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Failed to load representative details: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('Error fetching representative details: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
