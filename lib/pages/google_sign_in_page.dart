import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import '../main.dart';
import '../config/api_config.dart';
import '../config/api_client.dart';
import '../services/auth_storage_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../widgets/language_sheet.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _tosAccepted = true;

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
        throw Exception(
          'Failed to get ID token. Please check Google Cloud Console OAuth setup.',
        );
      }

      // Authenticate with backend
      await _authenticateWithBackend(idToken, account);
    } catch (error) {
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
      final response = await ApiClient.instance.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Save tokens and user data locally
        await AuthStorageService.saveAuthResponse(responseData);


        // Fetch user profile to check Aadhaar verification status
        final userProfile = await AuthStorageService.fetchUserProfile();
        final isAadhaarVerified = userProfile?['is_verified'] == true;

        if (mounted) {
          _navigateToMainScreen(account, isVerified: isAadhaarVerified);
        }
      } else {
        throw Exception(
          'Backend authentication failed: ${response.statusCode} — ${response.body}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = LanguageService.tr('auth_failed');
          _isLoading = false;
        });
      }
      rethrow;
    }
  }

  void _navigateToMainScreen(
    GoogleSignInAccount account, {
    required bool isVerified,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthChecker(),
      ),
    );
  }

  void _showLanguageSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LanguageSheet(
        isDarkMode: isDark,
        cardBackground: isDark ? ThemeService.bgElev : const Color(0xFFF7F7F7),
        primaryText: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF222222),
        secondaryText: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF717171),
        onLanguageChanged: (code) {
          context.read<LanguageProvider>().setLanguage(code);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
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
                LanguageService.tr('welcome_title').replaceAll('\\n', '\n'),
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

              // TOS Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _tosAccepted,
                    activeColor: ThemeService.accent,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _tosAccepted = val ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final url = Uri.parse('https://ratemymantri.sallytion.qzz.io/TOS');
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('Error launching TOS URL: $e');
                        }
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'By signing in you agree to our ',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF717171),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'TOS',
                              style: TextStyle(
                                color: ThemeService.accent,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_tosAccepted) ? null : _handleSignIn,
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
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.language_rounded, color: isDark ? Colors.white70 : Colors.black87),
              onPressed: _showLanguageSheet,
              tooltip: LanguageService.tr('language'),
            ),
          ),
        ),
      ],
    ),
  ),
);
  }
}

