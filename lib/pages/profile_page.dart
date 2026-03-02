import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'google_sign_in_page.dart';
import 'aadhar_verification_page.dart';
import 'constituency_search_page.dart';
import 'rate_page.dart';
import 'saved_articles_page.dart';
import '../services/auth_storage_service.dart';
import '../services/constituency_service.dart';
import '../services/constituency_notifier.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../config/api_config.dart';
import '../models/constituency.dart';
import '../widgets/language_sheet.dart';

class ProfilePage extends StatefulWidget {
  final String userName;
  final bool isVerified;
  final String? userEmail;
  final String? userId;
  final String? photoUrl;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.isVerified,
    this.userEmail,
    this.userId,
    this.photoUrl,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ConstituencyService _constituencyService = ConstituencyService();
  Constituency? _currentConstituency;
  bool _isLoadingConstituency = true;

  /// Reads the current dark-mode flag from the provider.
  bool get isDarkMode => context.read<ThemeProvider>().isDarkMode;

  Color get _backgroundColor =>
      isDarkMode ? ThemeService.bgMain : Colors.white;
  Color get _primaryText =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF222222);
  Color get _secondaryText =>
      isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171);
  Color get _cardBackground =>
      isDarkMode ? ThemeService.bgElev : const Color(0xFFF7F7F7);
  Color get _dividerColor =>
      isDarkMode ? ThemeService.bgElev : const Color(0xFFEEEEEE);

  @override
  void initState() {
    super.initState();
    _loadCurrentConstituency();
    // Listen for constituency changes made on the Home page
    ConstituencyNotifier.instance.notifier.addListener(_onConstituencyNotified);
  }

  @override
  void dispose() {
    ConstituencyNotifier.instance.notifier.removeListener(_onConstituencyNotified);
    super.dispose();
  }

  void _onConstituencyNotified() {
    final c = ConstituencyNotifier.instance.current;
    if (c != null && c.id != _currentConstituency?.id && mounted) {
      setState(() {
        _currentConstituency = c;
      });
    }
  }

  Future<void> _loadCurrentConstituency() async {
    final constituency = await _constituencyService.getCurrentConstituency();
    if (mounted) {
      setState(() {
        _currentConstituency = constituency;
        _isLoadingConstituency = false;
      });
    }
  }

  Future<void> _navigateToConstituencySearch() async {
    final result = await Navigator.push<Constituency>(
      context,
      MaterialPageRoute(
        builder: (context) => ConstituencySearchPage(
          isDarkMode: isDarkMode,
          currentConstituency: _currentConstituency,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentConstituency = result;
      });
      // Notify HomePage (and any other listeners) of the change
      ConstituencyNotifier.instance.set(result);
    }
  }

  void _showCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomizationSheet(
        isDarkMode: isDarkMode,
        darkModeOption: this.context.read<ThemeProvider>().darkModeOption,
        accentColorIndex: this.context.read<ThemeProvider>().accentColorIndex,
        onDarkModeOptionChanged: this.context.read<ThemeProvider>().setDarkModeOption,
        onAccentColorChanged: this.context.read<ThemeProvider>().setAccentColorIndex,
        cardBackground: _cardBackground,
        primaryText: _primaryText,
        secondaryText: _secondaryText,
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LanguageSheet(
        isDarkMode: isDarkMode,
        cardBackground: _cardBackground,
        primaryText: _primaryText,
        secondaryText: _secondaryText,
        onLanguageChanged: (code) {
          this.context.read<LanguageProvider>().setLanguage(code);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDarkMode = theme.isDarkMode;
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  LanguageService.tr('profile'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF222222),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              // Header - Identity & Tenure
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: widget.photoUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: widget.photoUrl!,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                    errorWidget: (_, _, _) => Container(
                                      color: ThemeService.accent.withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.person,
                                        size: 50,
                                        color: ThemeService.accent,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: ThemeService.accent.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      size: 50,
                                      color: ThemeService.accent,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ThemeService.accent,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LanguageService.translitName(widget.userName),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Verification Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isVerified
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.isVerified
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isVerified
                                ? Icons.verified_user
                                : Icons.info_outline,
                            size: 16,
                            color: widget.isVerified
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isVerified
                                ? LanguageService.tr('verified_user')
                                : LanguageService.tr('unverified_user'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.isVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),
              ),

              Divider(height: 1, thickness: 1, color: _dividerColor),

              // My Contributions
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.tr('my_activity'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildListItem(
                      icon: Icons.star,
                      iconColor: const Color(0xFFFFC107),
                      title: LanguageService.tr('my_ratings_reviews'),
                      subtitle: LanguageService.tr('ratings_count'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RatePage(
                              isVerified: widget.isVerified,
                            ),
                          ),
                        );
                      },
                      showArrow: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Divider(height: 1, thickness: 8, color: _cardBackground),
              const SizedBox(height: 24),

              // Political Context
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.tr('my_location'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildListItem(
                      icon: Icons.location_on,
                      iconColor: ThemeService.accent,
                      title: LanguageService.tr('constituency_label'),
                      subtitle: _isLoadingConstituency
                          ? LanguageService.tr('loading')
                          : _currentConstituency?.name ?? LanguageService.tr('not_set'),
                      onTap: _navigateToConstituencySearch,
                      showArrow: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Divider(height: 1, thickness: 8, color: _cardBackground),
              const SizedBox(height: 24),

              // General Settings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.tr('settings_support'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Add Verify Account option for unverified users
                    if (!widget.isVerified) ...[
                      _buildListItem(
                        icon: Icons.verified_user,
                        iconColor: Colors.green,
                        title: LanguageService.tr('verify_account'),
                        subtitle: LanguageService.tr('verify_subtitle'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AadharVerificationPage(
                                userEmail: widget.userEmail ?? '',
                                userName: widget.userName,
                                userId: widget.userId ?? '',
                                photoUrl: widget.photoUrl,
                              ),
                            ),
                          );
                        },
                        showArrow: true,
                      ),
                      Divider(height: 1, indent: 56, color: _dividerColor),
                    ],
                    _buildListItem(
                      icon: Icons.palette_outlined,
                      iconColor: ThemeService.accentColors[context.read<ThemeProvider>().accentColorIndex],
                      title: LanguageService.tr('customization'),
                      subtitle: LanguageService.tr('theme_accent_dark'),
                      onTap: _showCustomizationSheet,
                      showArrow: true,
                    ),
                    Divider(height: 1, indent: 56, color: _dividerColor),
                    _buildListItem(
                      icon: Icons.language,
                      iconColor: const Color(0xFF9C27B0),
                      title: LanguageService.tr('language'),
                      subtitle: LanguageService.currentLanguageName,
                      onTap: _showLanguageSheet,
                      showArrow: true,
                    ),
                    Divider(height: 1, indent: 56, color: _dividerColor),
                    _buildListItem(
                      icon: Icons.bookmark_outline,
                      iconColor: const Color(0xFF00BCD4),
                      title: LanguageService.tr('saved_articles'),
                      subtitle: LanguageService.tr('view_bookmarks'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SavedArticlesPage(
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        );
                      },
                      showArrow: true,
                    ),
                    Divider(height: 1, indent: 56, color: _dividerColor),
                    _buildListItem(
                      icon: Icons.support_agent,
                      iconColor: const Color(0xFF4CAF50),
                      title: LanguageService.tr('support'),
                      subtitle: LanguageService.tr('contact_dev'),
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.6),
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 400),
                              decoration: BoxDecoration(
                                color: _cardBackground,
                                borderRadius: BorderRadius.circular(24),
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with Icon
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Icon(
                                            Icons.support_agent_rounded,
                                            color: Color(0xFF4CAF50),
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                LanguageService.tr('contact_support'),
                                                style: TextStyle(
                                                  color: _primaryText,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                LanguageService.tr('we_help'),
                                                style: TextStyle(
                                                  color: _secondaryText,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    // Email Container
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? ThemeService.bgElev
                                            : const Color(0xFFF0F0F0),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDarkMode
                                              ? ThemeService.bgBorder
                                              : const Color(0xFFE0E0E0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.email_rounded,
                                              color: Color(0xFF4CAF50),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  LanguageService.tr('email_us_at'),
                                                  style: TextStyle(
                                                    color: _secondaryText,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'sallytionmakes@gmail.com',
                                                  style: TextStyle(
                                                    color: _primaryText,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Action Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              backgroundColor: isDarkMode
                                                  ? ThemeService.bgElev
                                                  : const Color(0xFFF0F0F0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              LanguageService.tr('close'),
                                              style: TextStyle(
                                                color: _secondaryText,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                                              final isDark = isDarkMode;
                                              Navigator.pop(context);
                                              final Uri emailUri = Uri(
                                                scheme: 'mailto',
                                                path: 'sallytionmakes@gmail.com',
                                                query: 'subject=Rate My Mantri - Support Request',
                                              );
                                              
                                              try {
                                                await launchUrl(
                                                  emailUri,
                                                  mode: LaunchMode.externalApplication,
                                                );
                                              } catch (e) {
                                                if (mounted) {
                                                  scaffoldMessenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text('${LanguageService.tr('please_email_at')}: sallytionmakes@gmail.com'),
                                                      backgroundColor: isDark
                                                          ? ThemeService.bgElev
                                                          : const Color(0xFF323232),
                                                      duration: const Duration(seconds: 4),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              backgroundColor: const Color(0xFF4CAF50),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              LanguageService.tr('send_email'),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      showArrow: true,
                    ),
                    Divider(height: 1, indent: 56, color: _dividerColor),
                    _buildListItem(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: const Color(0xFF795548),
                      title: LanguageService.tr('legal_privacy'),
                      subtitle: LanguageService.tr('terms_data'),
                      onTap: () async {
                        final uri = Uri.parse('${ApiConfig.baseUrl}/privacypolicy');
                        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(LanguageService.tr('could_not_open_privacy'))),
                            );
                          }
                        }
                      },
                      showArrow: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      // Show confirmation dialog
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.6),
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              color: _cardBackground,
                              borderRadius: BorderRadius.circular(24),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with Icon
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: ThemeService.accent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.logout_rounded,
                                          color: ThemeService.accent,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              LanguageService.tr('log_out'),
                                              style: TextStyle(
                                                color: _primaryText,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              LanguageService.tr('come_back_soon'),
                                              style: TextStyle(
                                                color: _secondaryText,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    LanguageService.tr('log_out_confirm'),
                                    style: TextStyle(
                                      color: _secondaryText,
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            backgroundColor: isDarkMode
                                                ? ThemeService.bgElev
                                                : const Color(0xFFF0F0F0),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            LanguageService.tr('cancel'),
                                            style: TextStyle(
                                              color: _primaryText,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            backgroundColor: ThemeService.accent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            LanguageService.tr('log_out'),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      if (shouldLogout == true && mounted) {
                        // Show loading indicator
                        showDialog(
                          context: navigator.context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          // Sign out and disconnect from Google (full logout)
                          final googleSignIn = GoogleSignIn();
                          await googleSignIn.signOut();
                          await googleSignIn.disconnect();

                          // Clear all local storage
                          await AuthStorageService.clearAuthData();

                          if (mounted) {
                            // Close loading dialog
                            navigator.pop();

                            // Navigate to login page
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const GoogleSignInPage(),
                              ),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            // Close loading dialog
                            navigator.pop();

                            // Still navigate to login even if there's an error
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const GoogleSignInPage(),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      LanguageService.tr('log_out'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: _secondaryText),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showArrow)
              Icon(Icons.chevron_right, color: _secondaryText),
          ],
        ),
      ),
    );
  }
}
// â”€â”€â”€ Customization Bottom Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CustomizationSheet extends StatefulWidget {
  final bool isDarkMode;
  final DarkModeOption darkModeOption;
  final int accentColorIndex;
  final Function(DarkModeOption) onDarkModeOptionChanged;
  final Function(int) onAccentColorChanged;
  final Color cardBackground;
  final Color primaryText;
  final Color secondaryText;

  const _CustomizationSheet({
    required this.isDarkMode,
    required this.darkModeOption,
    required this.accentColorIndex,
    required this.onDarkModeOptionChanged,
    required this.onAccentColorChanged,
    required this.cardBackground,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  State<_CustomizationSheet> createState() => _CustomizationSheetState();
}

class _CustomizationSheetState extends State<_CustomizationSheet> {
  late DarkModeOption _selectedMode;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.darkModeOption;
    _selectedColor = widget.accentColorIndex;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? ThemeService.bgCard : Colors.white;
    final textColor = widget.primaryText;
    final subtextColor = widget.secondaryText;
    final accent = ThemeService.accentColors[_selectedColor];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: subtextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            LanguageService.tr('customization'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // â”€â”€ Accent Color â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Text(
            LanguageService.tr('accent_color'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: subtextColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(ThemeService.accentColors.length, (i) {
              final color = ThemeService.accentColors[i];
              final isSelected = i == _selectedColor;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = i);
                    widget.onAccentColorChanged(i);
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: textColor, width: 2.5)
                              : Border.all(color: Colors.transparent, width: 2.5),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ThemeService.accentColorNames[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? textColor : subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 28),

          // â”€â”€ Dark Mode â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Text(
            LanguageService.tr('appearance'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: subtextColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            label: LanguageService.tr('system'),
            subtitle: LanguageService.tr('follow_device'),
            icon: Icons.settings_suggest_outlined,
            option: DarkModeOption.system,
            accent: accent,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          _buildModeOption(
            label: LanguageService.tr('light'),
            subtitle: LanguageService.tr('always_light'),
            icon: Icons.light_mode_outlined,
            option: DarkModeOption.light,
            accent: accent,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          _buildModeOption(
            label: LanguageService.tr('dark'),
            subtitle: LanguageService.tr('always_dark'),
            icon: Icons.dark_mode_outlined,
            option: DarkModeOption.dark,
            accent: accent,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          _buildModeOption(
            label: LanguageService.tr('amoled') + ' ' + LanguageService.tr('dark'),
            subtitle: LanguageService.tr('pure_black_bg'),
            icon: Icons.brightness_2_outlined,
            option: DarkModeOption.amoled,
            accent: accent,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required DarkModeOption option,
    required Color accent,
    required Color textColor,
    required Color subtextColor,
  }) {
    final isSelected = _selectedMode == option;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = option);
        widget.onDarkModeOptionChanged(option);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? accent : subtextColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accent : subtextColor.withValues(alpha: 0.4),
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

