import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'aadhar_verification_page.dart';
import 'main_screen.dart';
import '../services/auth_storage_service.dart';

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key});

  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
    // IMPORTANT: Add your Web OAuth Client ID here from Google Cloud Console
    serverClientId:
        '917168657465-0900dtkf7tl7quimne5c8djre9iejr3d.apps.googleusercontent.com',
  );

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Try silent sign-in on app start
    _trySilentSignIn();
  }

  Future<void> _trySilentSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final authentication = await account.authentication;
        final idToken = authentication.idToken;

        if (idToken != null && mounted) {
          await _authenticateWithBackend(idToken, account);
        }
      }
    } catch (e) {
      // Silent sign-in failed, user needs to sign in manually
      debugPrint('Silent sign-in failed: $e');
    }
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Starting Google Sign-In...');
      final account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('Sign-in cancelled by user');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      debugPrint('Google Sign-In successful: ${account.email}');
      debugPrint('User ID: ${account.id}');
      debugPrint('Display Name: ${account.displayName}');

      // Get the authentication token
      debugPrint('Getting authentication token...');
      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      final accessToken = authentication.accessToken;

      debugPrint(
        'ID Token: ${idToken != null ? "Available (${idToken.substring(0, 50)}...)" : "NULL"}',
      );
      debugPrint('Access Token: ${accessToken != null ? "Available" : "NULL"}');
      debugPrint('Full ID Token for debugging: $idToken');

      if (idToken == null) {
        debugPrint(
          'ERROR: ID token is null. Check OAuth client configuration in Google Cloud Console.',
        );
        throw Exception(
          'Failed to get ID token. Please check Google Cloud Console OAuth setup.',
        );
      }

      // Authenticate with backend
      await _authenticateWithBackend(idToken, account);
    } catch (error) {
      debugPrint('Sign-in error details: $error');
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed. Please try again.';
          _isLoading = false;
        });
      }
      debugPrint('Sign-in error: $error');
    }
  }

  Future<void> _authenticateWithBackend(
    String idToken,
    GoogleSignInAccount account,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://ratemymantri.sallytion.qzz.io/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idToken': idToken}),
      );

      debugPrint('Backend auth response status: ${response.statusCode}');
      debugPrint('Backend auth response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Authentication successful: $responseData');

        // Save tokens and user data locally
        await AuthStorageService.saveAuthResponse(responseData);
        debugPrint('Tokens and user data saved locally');

        // ðŸ” DEBUG: Decode and check JWT token
        if (responseData['tokens'] != null &&
            responseData['tokens']['accessToken'] != null) {
          final accessToken = responseData['tokens']['accessToken'] as String;
          try {
            final parts = accessToken.split('.');
            if (parts.length == 3) {
              final payload = json.decode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              );
              debugPrint('ðŸ” JWT TOKEN PAYLOAD: $payload');
              debugPrint(
                'ðŸ” is_verified claim in token: ${payload['is_verified']}',
              );
            }
          } catch (e) {
            debugPrint('Could not decode JWT: $e');
          }
        }

        // Fetch user profile to check Aadhaar verification status
        debugPrint('Checking Aadhaar verification status...');
        final userProfile = await AuthStorageService.fetchUserProfile();
        final isAadhaarVerified = userProfile?['is_verified'] == true;

        debugPrint('Aadhaar verified status: $isAadhaarVerified');

        if (mounted) {
          if (isAadhaarVerified) {
            // Skip Aadhaar verification, go directly to main screen
            _navigateToMainScreen(account, isVerified: true);
          } else {
            // Show Aadhaar verification page
            _navigateToAadharVerification(account);
          }
        }
      } else {
        debugPrint('Backend authentication failed!');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('Error: ${response.body}');
        debugPrint('Possible issues:');
        debugPrint('1. Backend might expect a different OAuth Client ID');
        debugPrint(
          '2. Token audience (aud) claim might not match backend expectations',
        );
        debugPrint('3. Backend server time might be out of sync');
        throw Exception(
          'Backend authentication failed: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('Backend auth error: $error');
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
          _isLoading = false;
        });
      }
      rethrow;
    }
  }

  void _navigateToAadharVerification(GoogleSignInAccount account) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AadharVerificationPage(
          userEmail: account.email,
          userName: account.displayName ?? 'User',
          userId: account.id,
          photoUrl: account.photoUrl,
        ),
      ),
    );
  }

  void _navigateToMainScreen(
    GoogleSignInAccount account, {
    required bool isVerified,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          userName: account.displayName ?? 'User',
          isVerified: isVerified,
          userEmail: account.email,
          userId: account.id,
          photoUrl: account.photoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              // App Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  isDark
                      ? 'lib/assets/logo/rate_my_mantri_dark.png'
                      : 'lib/assets/logo/rate_my_mantri_light.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Welcome to\nRate My Mantri',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF222222),
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Sign in to rate and review your elected representatives.',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : const Color(0xFF717171),
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.red.shade700 : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    foregroundColor: isDark ? Colors.white : const Color(0xFF222222),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                      ),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF4285F4),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google "G" Logo
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    foreground: Paint()
                                      ..shader =
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFF4285F4),
                                              Color(0xFFEA4335),
                                              Color(0xFFFBBC05),
                                              Color(0xFF34A853),
                                            ],
                                          ).createShader(
                                            const Rect.fromLTWH(0, 0, 18, 18),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Terms text
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF717171),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
