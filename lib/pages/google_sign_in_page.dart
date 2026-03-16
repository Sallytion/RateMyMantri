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
import '../services/prefs_service.dart';

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

    // Check and show disclaimer on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimerPopup(force: false);
    });
  }

  Future<void> _trySilentSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final authentication = await account.authentication;
        final idToken = authentication.idToken;

        if (idToken != null && mounted) {
          await _authenticateWithBackend(idToken);
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
      await _authenticateWithBackend(idToken);
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

        if (mounted) {
          _navigateToMainScreen();
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

  void _navigateToMainScreen() {
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
        cardBackground: isDark ? ThemeService.bgElev : ThemeService.lightCardAlt,
        primaryText: isDark ? const Color(0xFFFFFFFF) : ThemeService.lightText,
        secondaryText: isDark ? const Color(0xFFB0B0B0) : ThemeService.lightSubtext,
        onLanguageChanged: (code) {
          context.read<LanguageProvider>().setLanguage(code);
          setState(() {});
        },
      ),
    );
  }

  void _showDisclaimerPopup({required bool force}) {
    final prefs = PrefsService.instance;
    final hasSeenDisclaimer = prefs.getBool('has_seen_login_disclaimer') ?? false;

    if (!force && hasSeenDisclaimer) {
      return; // Already seen it, don't auto-show
    }

    if (!force) {
      // Mark as seen so it doesn't auto-pop again
      prefs.setBool('has_seen_login_disclaimer', true);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? ThemeService.bgElev : ThemeService.lightCard;
    final primaryTxt = isDark ? const Color(0xFFFFFFFF) : ThemeService.lightText;
    final secondaryTxt = isDark ? const Color(0xFFB0B0B0) : ThemeService.lightSubtext;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(ThemeService.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF607D8B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF607D8B),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          LanguageService.tr('about_app_disclaimer'),
                          style: TextStyle(
                            color: primaryTxt,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    LanguageService.tr('disclaimer_title'),
                    style: TextStyle(
                      color: primaryTxt,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LanguageService.tr('disclaimer_text'),
                    style: TextStyle(
                      color: secondaryTxt,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    LanguageService.tr('data_sources_title'),
                    style: TextStyle(
                      color: primaryTxt,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LanguageService.tr('data_sources_text'),
                    style: TextStyle(
                      color: secondaryTxt,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isDark
                            ? ThemeService.bgElev
                            : ThemeService.lightBorder,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        LanguageService.tr('ok'),
                        style: TextStyle(
                          color: primaryTxt,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: isDark ? ThemeService.bgMain : const Color(0xFFF5F3EF),
      body: Stack(
        children: [
          // ── Top hero zone ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenH * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: isDark
                      ? [ThemeService.bgElev, ThemeService.bgMain]
                      : [ThemeService.pastelLavender.withValues(alpha: 0.3), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          isDark
                              ? 'lib/assets/logo/rate_my_mantri_dark.png'
                              : 'lib/assets/logo/rate_my_mantri_light.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rate My Mantri',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ThemeService.accent,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        LanguageService.tr('sign_in_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : ThemeService.lightSubtext,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom card zone ───────────────────────────────────
          Positioned(
            top: screenH * 0.42,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? ThemeService.bgElev : ThemeService.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome title
                    Text(
                      LanguageService.tr('welcome_title').replaceAll('\\n', '\n'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : ThemeService.lightText,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // TOS Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _tosAccepted,
                          activeColor: ThemeService.accent,
                          checkColor: Colors.white,
                          side: BorderSide(color: isDark ? Colors.white54 : Colors.black54),
                          onChanged: (val) => setState(() => _tosAccepted = val ?? false),
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
                                  color: isDark ? Colors.white70 : ThemeService.lightSubtext,
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

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                          border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
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
                        onPressed: (_isLoading || !_tosAccepted) ? null : _handleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? ThemeService.bgMain : ThemeService.lightBg,
                          foregroundColor: isDark ? Colors.white : ThemeService.lightText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isDark ? const Color(0xFF444444) : ThemeService.lightBorder),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isDark ? ThemeService.bgMain : ThemeService.lightBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          foreground: Paint()
                                            ..shader = const LinearGradient(
                                              colors: [Color(0xFF4285F4), Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853)],
                                            ).createShader(const Rect.fromLTWH(0, 0, 18, 18)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    LanguageService.tr('continue_google'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Language + Info row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _showLanguageSheet,
                          icon: Icon(Icons.language_rounded, size: 18, color: isDark ? Colors.white60 : ThemeService.lightSubtext),
                          label: Text(
                            LanguageService.tr('language'),
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : ThemeService.lightSubtext),
                          ),
                        ),
                        Text(' · ', style: TextStyle(color: isDark ? Colors.white30 : ThemeService.lightBorder)),
                        TextButton.icon(
                          onPressed: () => _showDisclaimerPopup(force: true),
                          icon: Icon(Icons.info_outline_rounded, size: 18, color: isDark ? Colors.white60 : ThemeService.lightSubtext),
                          label: Text(
                            LanguageService.tr('about_app_disclaimer'),
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : ThemeService.lightSubtext),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
