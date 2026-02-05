import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _aadhaarVerifiedKey = 'aadhaar_verified';
  static const String _baseUrl = 'https://ratemymantri.sallytion.qzz.io';

  // Save tokens after successful authentication
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Save user data
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, json.encode(userData));
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      return json.decode(userDataString) as Map<String, dynamic>;
    }
    return null;
  }

  // Check if user is authenticated (has valid tokens)
  static Future<bool> isAuthenticated() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Save Aadhaar verification status
  static Future<void> saveAadhaarVerificationStatus(bool isVerified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aadhaarVerifiedKey, isVerified);
  }

  // Get Aadhaar verification status from local storage
  static Future<bool> getAadhaarVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aadhaarVerifiedKey) ?? false;
  }

  // Clear all auth data (for logout)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear specific keys
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_aadhaarVerifiedKey);

    // Also clear everything to be safe
    await prefs.clear();

    print('All auth data and local storage cleared');
  }

  // Save complete auth response
  static Future<void> saveAuthResponse(
    Map<String, dynamic> authResponse,
  ) async {
    if (authResponse['tokens'] != null) {
      final tokens = authResponse['tokens'] as Map<String, dynamic>;
      await saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
    }

    if (authResponse['user'] != null) {
      await saveUserData(authResponse['user'] as Map<String, dynamic>);
    }
  }

  // Refresh access token using refresh token
  static Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        print('No refresh token available');
        return false;
      }

      final response = await http.post(
        Uri.parse('https://ratemymantri.sallytion.qzz.io/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Save new tokens
        if (responseData['tokens'] != null) {
          final tokens = responseData['tokens'] as Map<String, dynamic>;
          await saveTokens(
            accessToken: tokens['accessToken'] as String,
            refreshToken: tokens['refreshToken'] as String,
          );
          print('Tokens refreshed successfully');
          return true;
        }
      } else {
        print('Token refresh failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }

    return false;
  }

  // Get access token with automatic refresh if expired
  static Future<String?> getValidAccessToken() async {
    String? accessToken = await getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    // Try to decode JWT to check expiration
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        return accessToken; // Invalid JWT format, return as-is
      }

      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      final exp = payload['exp'] as int?;
      if (exp != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();

        // If token expires in less than 5 minutes, refresh it
        if (expiryDate.isBefore(now.add(const Duration(minutes: 5)))) {
          print('Access token expiring soon, refreshing...');
          final refreshed = await refreshAccessToken();
          if (refreshed) {
            accessToken = await getAccessToken();
          }
        }
      }
    } catch (e) {
      print('Error checking token expiration: $e');
      // If we can't parse, return the token anyway
    }

    return accessToken;
  }

  // Fetch user profile from /me endpoint and update local storage
  static Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final accessToken = await getValidAccessToken();

      if (accessToken == null) {
        print('No access token available');
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final userData = responseData['user'] as Map<String, dynamic>?;

        if (userData == null) {
          print('User data not found in response');
          return null;
        }

        // Save user data
        await saveUserData(userData);

        // Save Aadhaar verification status (check is_verified field)
        final isAadhaarVerified = userData['is_verified'] == true;
        await saveAadhaarVerificationStatus(isAadhaarVerified);

        print('User profile fetched successfully');
        print('Aadhaar verified: $isAadhaarVerified');

        return userData;
      } else if (response.statusCode == 401) {
        print('Unauthorized - token may be invalid');
        return null;
      } else {
        print('Failed to fetch user profile: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
