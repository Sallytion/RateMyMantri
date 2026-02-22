import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'auth_storage_service.dart';

class AadhaarVerificationService {
  static const String _baseUrl = 'https://ratemymantri.sallytion.qzz.io';

  /// Hash the raw Aadhaar QR data using SHA-256
  /// This ensures that the original Aadhaar data is never stored
  static String hashAadhaarData(String rawQrData) {
    // Convert the raw QR data to bytes
    final bytes = utf8.encode(rawQrData);

    // Generate SHA-256 hash
    final digest = sha256.convert(bytes);

    // Return as hex string (64 characters)
    return digest.toString();
  }

  /// Verify Aadhaar hash with backend
  /// Returns true if verification successful, false otherwise
  static Future<Map<String, dynamic>> verifyAadhaarHash(
    String aadhaarHash,
  ) async {
    try {
      // Get access token
      final accessToken = await AuthStorageService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {
          'success': false,
          'error': 'User not authenticated. Please login first.',
        };
      }

      // Validate hash length (SHA-256 produces 64 hex characters)
      if (aadhaarHash.length != 64) {
        return {
          'success': false,
          'error': 'Invalid Aadhaar hash format. Expected 64 characters.',
        };
      }

      // Make API request
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/aadhaar'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'aadhaarHash': aadhaarHash}),
      );

      // Parse response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        // Update local storage with verification status
        await AuthStorageService.saveAadhaarVerificationStatus(true);

        // ✅ NEW: Save new tokens if provided by backend
        if (responseData['tokens'] != null) {
          final tokens = responseData['tokens'];
          await AuthStorageService.saveTokens(
            accessToken: tokens['accessToken'] as String,
            refreshToken: tokens['refreshToken'] as String,
          );
        }

        return {
          'success': true,
          'data': responseData,
          'message': 'Aadhaar verification successful',
        };
      } else if (response.statusCode == 400) {
        // Aadhaar already used
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'error':
              responseData['message'] ??
              'This Aadhaar has already been verified by another user.',
          'alreadyUsed': true,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed. Please login again.',
          'needsReauth': true,
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'error':
              responseData['message'] ??
              'Verification failed. Please try again.',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Complete flow: Scan QR -> Hash -> Verify
  static Future<Map<String, dynamic>> processAadhaarQR(String rawQrData) async {
    try {
      // 1. Hash the raw QR data
      final aadhaarHash = hashAadhaarData(rawQrData);

      // 2. Verify with backend
      final verificationResult = await verifyAadhaarHash(aadhaarHash);

      return verificationResult;
    } catch (e) {
      return {'success': false, 'error': 'Processing error: ${e.toString()}'};
    }
  }

  /// Check if user has verified Aadhaar
  static Future<bool> isAadhaarVerified() async {
    try {
      final accessToken = await AuthStorageService.getAccessToken();

      if (accessToken == null) return false;

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['aadhaarVerified'] == true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
