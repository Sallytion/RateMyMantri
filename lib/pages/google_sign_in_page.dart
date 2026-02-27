import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'aadhar_verification_page.dart';
import 'main_screen.dart';
import '../services/auth_storage_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

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
    }
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get the authentication token
      final authentication = await account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null) {
        debugPrint('[AUTH] ERROR: idToken is null. Check Web OAuth Client ID in serverClientId.');
        throw Exception(
          'Failed to get ID token. Please check Google Cloud Console OAuth setup.',
        );
      }

      debugPrint('[AUTH] Got idToken (first 40 chars): ${idToken.substring(0, 40)}...');

      // ── Domain reachability probe ──────────────────────────────────────────
      // Tests a plain GET on the same domain BEFORE the auth POST.
      // If this also fails with hostname mismatch → cert issue affects everything.
      // If this SUCCEEDS → problem is specific to the POST /auth/google path.
      try {
        final probe = await http.get(
          Uri.parse('https://ratemymantri.sallytion.qzz.io/health'),
        ).timeout(const Duration(seconds: 5));
        debugPrint('[AUTH] /health probe status: ${probe.statusCode}');
        debugPrint('[AUTH] /health probe body: ${probe.body}');
      } catch (e) {
        debugPrint('[AUTH] /health probe FAILED: $e');
      }
      // ──────────────────────────────────────────────────────────────────────

      // Authenticate with backend
      await _authenticateWithBackend(idToken, account);
    } catch (error) {
      debugPrint('[AUTH] _handleSignIn caught error: $error');
      if (mounted) {
        setState(() {
          _errorMessage = LanguageService.tr('sign_in_failed');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBackend(
    String idToken,
    GoogleSignInAccount account,
  ) async {
    try {
      debugPrint('[AUTH] Posting idToken to /auth/google...');
      final response = await http.post(
        Uri.parse('https://ratemymantri.sallytion.qzz.io/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idToken': idToken}),
      );

      debugPrint('[AUTH] /auth/google response status: ${response.statusCode}');
      debugPrint('[AUTH] /auth/google response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Save tokens and user data locally
        await AuthStorageService.saveAuthResponse(responseData);

        // ðŸ” DEBUG: Decode and check JWT token
        if (responseData['tokens'] != null &&
            responseData['tokens']['accessToken'] != null) {
          // Token decoding removed (was only used for debug logging)
        }

        // Fetch user profile to check Aadhaar verification status
        final userProfile = await AuthStorageService.fetchUserProfile();
        final isAadhaarVerified = userProfile?['is_verified'] == true;

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
        debugPrint('[AUTH] Backend rejected with ${response.statusCode}: ${response.body}');
        throw Exception(
          'Backend authentication failed: ${response.statusCode} — ${response.body}',
        );
      }
    } catch (error) {
      debugPrint('[AUTH] _authenticateWithBackend caught error: $error');
      if (mounted) {
        setState(() {
          _errorMessage = LanguageService.tr('auth_failed');
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
          userName: account.displayName ?? LanguageService.tr('user'),
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
          userName: account.displayName ?? LanguageService.tr('user'),
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
                LanguageService.tr('welcome_title'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF222222),
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                LanguageService.tr('sign_in_desc'),
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
                    color: isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50,
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
                    backgroundColor: isDark ? ThemeService.bgElev : Colors.white,
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
                                color: isDark ? ThemeService.bgElev : Colors.white,
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
                            Text(
                              LanguageService.tr('continue_google'),
                              style: const TextStyle(
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
                    LanguageService.tr('terms_agree'),
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
