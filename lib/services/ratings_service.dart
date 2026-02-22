import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rating.dart';
import '../models/rating_statistics.dart';
import 'auth_storage_service.dart';
import 'cache_service.dart';
import 'language_service.dart';

class RatingsService {
  static const String baseUrl = 'https://ratemymantri.sallytion.qzz.io/api';
  static const Duration _cacheTtl = Duration(minutes: 5);

  // Helper method to get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthStorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Invalidate cached rating data for a representative after a mutation
  void _invalidateRatingCaches(int representativeId) {
    // Invalidate the specific stats cache key
    CacheService.invalidate('rating_stats_$representativeId');
    // Also clear any ratings list caches (multiple sort/page combos possible)
    // Since we can't match by prefix with hashed keys, clear all data cache
    CacheService.clearDataCache();
  }

  /// Create a new rating for a representative
  /// Returns the created rating or throws an exception
  Future<Rating> createRating({
    required int representativeId,
    required int question1Stars,
    required int question2Stars,
    required int question3Stars,
    bool anonymous = false,
    String? reviewText,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'representativeId': representativeId,
        'question1Stars': question1Stars,
        'question2Stars': question2Stars,
        'question3Stars': question3Stars,
        'anonymous': anonymous,
        if (reviewText != null && reviewText.isNotEmpty)
          'reviewText': reviewText,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/ratings'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['rating'] != null) {
          final ratingData = data['rating'];
          // Invalidate cached stats for this representative
          _invalidateRatingCaches(representativeId);
          return Rating.fromJson(ratingData);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create rating');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing rating
  /// Returns the updated rating or throws an exception
  Future<Rating> updateRating({
    required String ratingId,
    int? question1Stars,
    int? question2Stars,
    int? question3Stars,
    bool? anonymous,
    String? reviewText,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};

      if (question1Stars != null) body['question1Stars'] = question1Stars;
      if (question2Stars != null) body['question2Stars'] = question2Stars;
      if (question3Stars != null) body['question3Stars'] = question3Stars;
      if (anonymous != null) body['anonymous'] = anonymous;
      if (reviewText != null) body['reviewText'] = reviewText;
      final response = await http.put(
        Uri.parse('$baseUrl/ratings/$ratingId'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['rating'] != null) {
          final rating = Rating.fromJson(data['rating']);
          // Invalidate caches after update
          CacheService.clearDataCache();
          return rating;
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update rating');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a rating
  /// Returns true if successful
  Future<bool> deleteRating(String ratingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/ratings/$ratingId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'] == true;
        if (success) {
          // Invalidate caches after deletion
          CacheService.clearDataCache();
        }
        return success;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete rating');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get ratings for a representative (public)
  /// Returns a map with ratings list and pagination info
  Future<Map<String, dynamic>> getRatingsForRepresentative({
    required int representativeId,
    int limit = 50,
    int offset = 0,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    final cacheKey = 'ratings_${representativeId}_${limit}_${offset}_${sortBy}_$sortOrder';
    try {
      // Check cache first
      final cached = await CacheService.getCachedData(cacheKey, maxAge: _cacheTtl);
      if (cached != null) {
        final ratings = (cached['ratings'] as List?)
            ?.map((json) => Rating.fromJson(json as Map<String, dynamic>))
            .toList() ?? [];
        return {
          'representativeId': cached['representativeId'],
          'statistics': cached['statistics'] != null
              ? RatingStatistics.fromJson(cached['statistics'] as Map<String, dynamic>)
              : null,
          'ratings': ratings,
          'pagination': cached['pagination'],
        };
      }

      final uri = Uri.parse('$baseUrl/ratings/representative/$representativeId')
          .replace(
            queryParameters: {
              'limit': limit.toString(),
              'offset': offset.toString(),
              'sortBy': sortBy,
              'sortOrder': sortOrder,
            },
          );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final ratings =
              (data['ratings'] as List?)
                  ?.map((json) => Rating.fromJson(json))
                  .toList() ??
              [];

          // Cache the raw JSON for future use
          CacheService.cacheData(cacheKey, {
            'representativeId': data['representativeId'],
            'statistics': data['statistics'],
            'ratings': data['ratings'],
            'pagination': data['pagination'],
          }, ttl: _cacheTtl);

          return {
            'representativeId': data['representativeId'],
            'statistics': data['statistics'] != null
                ? RatingStatistics.fromJson(data['statistics'])
                : null,
            'ratings': ratings,
            'pagination': data['pagination'],
          };
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load ratings: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get rating statistics for a representative (public)
  Future<RatingStatistics?> getRatingStatistics(int representativeId) async {
    final cacheKey = 'rating_stats_${representativeId}_${LanguageService.languageCode}';
    try {
      // Check cache first
      final cached = await CacheService.getCachedData(cacheKey, maxAge: _cacheTtl);
      if (cached != null) {
        return RatingStatistics.fromJson(cached);
      }

      final uri = Uri.parse('$baseUrl/ratings/statistics/$representativeId').replace(
        queryParameters: {'lang': LanguageService.languageCode},
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['statistics'] != null) {
          final statsJson = data['statistics'] as Map<String, dynamic>;
          CacheService.cacheData(cacheKey, statsJson, ttl: _cacheTtl);
          return RatingStatistics.fromJson(statsJson);
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 404) {
        // No ratings yet
        return null;
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      return null;
    }
  }

  /// Get current user's ratings (requires authentication)
  Future<List<Rating>> getCurrentUserRatings() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/ratings/user/me').replace(
        queryParameters: {'lang': LanguageService.languageCode},
      );
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['ratings'] != null) {
          return (data['ratings'] as List)
              .map((json) => Rating.fromJson(json))
              .toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load user ratings: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user has rated a representative (requires authentication)
  /// Returns null if not rated, otherwise returns the rating
  Future<Rating?> getUserRatingForRepresentative(int representativeId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '$baseUrl/ratings/user/me/representative/$representativeId',
      );
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data['hasRated'] == true && data['rating'] != null) {
            return Rating.fromJson(data['rating']);
          } else {
            return null;
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 404) {
        // User hasn't rated this representative
        return null;
      } else {
        throw Exception('Failed to check rating: ${response.statusCode}');
      }
    } catch (e) {
      return null;
    }
  }

  /// Get rating questions based on office type
  static List<String> getRatingQuestions(String officeType) {
    switch (officeType.toUpperCase()) {
      case 'STATE_ASSEMBLY':
      case 'MLA':
        return [
          'How effectively has this MLA addressed local constituency issues (roads, water, safety, basic services)?',
          'How active and effective has this MLA been in the State Assembly (attendance, debates, questions, bills)?',
          'How accessible, responsive, and trustworthy has this MLA been toward citizens?',
        ];

      case 'LOK_SABHA':
      case 'MP':
        return [
          'How well has this MP represented and developed their parliamentary constituency?',
          'How effective has this MP been in Parliament (questions, debates, laws, national issues)?',
          'How honest, transparent, and accountable do you believe this MP is?',
        ];

      case 'RAJYA_SABHA':
      case 'MP-RS':
        return [
          'How meaningful has this MP\'s contribution been to national laws and policies?',
          'How strong has this MP been in debates, committees, and subject-matter discussions?',
          'How independent, ethical, and accountable has this MP been in their role?',
        ];

      case 'VIDHAN_PARISHAD':
      case 'MLC':
        return [
          'How effectively has this MLC reviewed, questioned, and improved legislation?',
          'How valuable has this MLC\'s expertise or experience been in legislative discussions?',
          'How responsible, ethical, and accountable has this MLC been in public life?',
        ];

      default:
        return [
          'How effectively has this representative addressed constituency issues?',
          'How active and effective has this representative been in their legislative role?',
          'How accessible, responsive, and trustworthy has this representative been?',
        ];
    }
  }
}
