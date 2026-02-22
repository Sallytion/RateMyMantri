import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/representative.dart';
import '../models/representative_detail.dart';
import 'cache_service.dart';
import 'language_service.dart';

class RepresentativeService {
  static const String baseUrl = 'https://ratemymantri.sallytion.qzz.io/v2';
  static const Duration _cacheTtl = Duration(minutes: 5);

  Future<Map<String, dynamic>> searchRepresentatives(
    String query, {
    int? limit,
  }) async {
    final cacheKey = 'search_reps_${query}_${limit}_${LanguageService.languageCode}';
    try {
      // Check cache first
      final cached = await CacheService.getCachedData(cacheKey, maxAge: _cacheTtl);
      if (cached != null) {
        final results = (cached['results'] as List?)
            ?.map((json) => Representative.fromJson(json as Map<String, dynamic>))
            .toList() ?? [];
        return {'count': cached['count'] ?? results.length, 'results': results};
      }

      final uri = Uri.parse('$baseUrl/representatives/search').replace(
        queryParameters: {
          'q': query,
          if (limit != null) 'limit': limit.toString(),
          'lang': LanguageService.languageCode,
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final count = data['count'] ?? 0;
        final results =
            (data['results'] as List?)
                ?.map((json) {
                  try {
                    return Representative.fromJson(json);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<Representative>()
                .toList() ??
            [];
        final result = {'count': count, 'results': results};

        // Cache the raw JSON for future use
        CacheService.cacheData(cacheKey, {
          'count': count,
          'results': (data['results'] as List?) ?? [],
        }, ttl: _cacheTtl);

        return result;
      } else {
        throw Exception(
          'Failed to load representatives: ${response.statusCode}',
        );
      }
    } catch (_) {
      return {'count': 0, 'results': <Representative>[]};
    }
  }

  /// Fetch representatives for a given constituency/location name
  Future<Map<String, dynamic>> getMyRepresentatives(String location) async {
    try {
      final uri = Uri.parse('$baseUrl/my-representatives').replace(
        queryParameters: {
          'location': location,
          'lang': LanguageService.languageCode,
        },
      );
      final response = await http.get(uri);

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
              }
            }
          }

          // Parse Lok Sabha member
          if (reps['lokSabha'] != null && reps['lokSabha'] is Map) {
            try {
              allReps.add(Representative.fromJson(reps['lokSabha']));
            } catch (e) {
            }
          }

          // Parse Rajya Sabha members
          if (reps['rajyaSabha'] != null && reps['rajyaSabha'] is List) {
            for (var json in reps['rajyaSabha']) {
              try {
                allReps.add(Representative.fromJson(json));
              } catch (e) {
              }
            }
          }

          // Parse Vidhan Parishad members
          if (reps['vidhanParishad'] != null && reps['vidhanParishad'] is List) {
            for (var json in reps['vidhanParishad']) {
              try {
                allReps.add(Representative.fromJson(json));
              } catch (e) {
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
    } catch (_) {
      return {'success': false, 'representatives': <Representative>[]};
    }
  }

  Future<RepresentativeDetail?> getRepresentativeById(String id) async {
    final cacheKey = 'rep_detail_${id}_${LanguageService.languageCode}';
    try {
      // Check cache first
      final cached = await CacheService.getCachedData(cacheKey, maxAge: _cacheTtl);
      if (cached != null) {
        return RepresentativeDetail.fromJson(cached);
      }

      final uri = Uri.parse('$baseUrl/representatives/$id').replace(
        queryParameters: {'lang': LanguageService.languageCode},
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // V2 API returns {success: true, data: {...}}
        if (data['success'] == true && data['data'] != null) {
          final detailJson = data['data'] as Map<String, dynamic>;
          CacheService.cacheData(cacheKey, detailJson, ttl: _cacheTtl);
          return RepresentativeDetail.fromJson(detailJson);
        } else {
          CacheService.cacheData(cacheKey, data as Map<String, dynamic>, ttl: _cacheTtl);
          return RepresentativeDetail.fromJson(data);
        }
      } else {
        throw Exception(
          'Failed to load representative details: ${response.statusCode}',
        );
      }
    } catch (_) {
      return null;
    }
  }
}
