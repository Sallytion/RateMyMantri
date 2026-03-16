import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'google_sign_in_page.dart';
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
  final String? userEmail;
  final String? userId;
  final String? photoUrl;

  const ProfilePage({
    super.key,
    required this.userName,
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
      isDarkMode ? ThemeService.bgMain : ThemeService.lightBg;
  Color get _primaryText =>
      isDarkMode ? const Color(0xFFFFFFFF) : ThemeService.lightText;
  Color get _secondaryText =>
      isDarkMode ? const Color(0xFFB0B0B0) : ThemeService.lightSubtext;
  Color get _cardBackground =>
      isDarkMode ? ThemeService.bgElev : ThemeService.lightCard;
  Color get _dividerColor =>
      isDarkMode ? ThemeService.bgElev : ThemeService.lightBorder;

  @override
  void initState() {
    super.initState();
    _loadCurrentConstituency();
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

  void _showDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDarkMode ? _cardBackground : ThemeService.lightCard,
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
                          color: _primaryText,
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
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService.tr('disclaimer_text'),
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  LanguageService.tr('data_sources_title'),
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService.tr('data_sources_text'),
                  style: TextStyle(
                    color: _secondaryText,
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
                      backgroundColor: isDarkMode
                          ? ThemeService.bgElev
                          : ThemeService.lightCardAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                      ),
                    ),
                    child: Text(
                      LanguageService.tr('ok'),
                      style: TextStyle(
                        color: _primaryText,
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
    );
  }

  // ─── NEW LAYOUT ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDarkMode = theme.isDarkMode;
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Profile header ────────────────────────────
              _buildProfileHeader(isDarkMode),

              const SizedBox(height: 16),

              // ── Account section ───────────────────────────
              _buildSectionCard(
                title: LanguageService.tr('my_activity'),
                items: [
                  _SettingItem(
                    icon: Icons.location_on_rounded,
                    iconBgColor: isDarkMode
                        ? ThemeService.accent.withValues(alpha: 0.15)
                        : ThemeService.pastelBlue,
                    iconColor: ThemeService.accent,
                    title: LanguageService.tr('constituency_label'),
                    onTap: _navigateToConstituencySearch,
                  ),
                  _SettingItem(
                    icon: Icons.bookmark_rounded,
                    iconBgColor: isDarkMode
                        ? const Color(0xFF00BCD4).withValues(alpha: 0.15)
                        : ThemeService.pastelMint,
                    iconColor: const Color(0xFF00BCD4),
                    title: LanguageService.tr('saved_articles'),
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
                  ),
                ],
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 16),

              // ── Customization section ───────────────────────
              _buildSectionCard(
                title: LanguageService.tr('customization'),
                items: [
                  _SettingItem(
                    icon: Icons.palette_rounded,
                    iconBgColor: isDarkMode
                        ? ThemeService.accentColors[context.read<ThemeProvider>().accentColorIndex].withValues(alpha: 0.15)
                        : ThemeService.pastelLavender,
                    iconColor: ThemeService.accentColors[context.read<ThemeProvider>().accentColorIndex],
                    title: LanguageService.tr('customization'),
                    onTap: _showCustomizationSheet,
                  ),
                  _SettingItem(
                    icon: Icons.language_rounded,
                    iconBgColor: isDarkMode
                        ? const Color(0xFF9C27B0).withValues(alpha: 0.15)
                        : ThemeService.pastelPeach,
                    iconColor: const Color(0xFF9C27B0),
                    title: LanguageService.tr('language'),
                    onTap: _showLanguageSheet,
                  ),
                ],
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 16),

              // ── Help & Info section ─────────────────────────
              _buildSectionCard(
                title: LanguageService.tr('support'),
                items: [
                  _SettingItem(
                    icon: Icons.info_outline_rounded,
                    iconBgColor: isDarkMode
                        ? const Color(0xFF607D8B).withValues(alpha: 0.15)
                        : ThemeService.pastelBlue,
                    iconColor: const Color(0xFF607D8B),
                    title: LanguageService.tr('about_app_disclaimer'),
                    onTap: () => _showDisclaimerDialog(context),
                  ),
                  _SettingItem(
                    icon: Icons.support_agent_rounded,
                    iconBgColor: isDarkMode
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                        : ThemeService.pastelGreen,
                    iconColor: const Color(0xFF4CAF50),
                    title: LanguageService.tr('support'),
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
                              color: isDarkMode ? _cardBackground : ThemeService.lightCard,
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? ThemeService.bgElev
                                          : ThemeService.lightCardAlt,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? ThemeService.bgBorder
                                            : ThemeService.lightBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(ThemeService.chipRadius),
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            backgroundColor: isDarkMode
                                                ? ThemeService.bgElev
                                                : ThemeService.lightCardAlt,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(ThemeService.smallRadius),
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
                                              borderRadius: BorderRadius.circular(ThemeService.smallRadius),
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
                  ),
                  _SettingItem(
                    icon: Icons.star_rounded,
                    iconBgColor: isDarkMode
                        ? const Color(0xFFFFC107).withValues(alpha: 0.15)
                        : ThemeService.pastelYellow,
                    iconColor: const Color(0xFFFFC107),
                    title: LanguageService.tr('my_ratings_reviews'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RatePage(),
                        ),
                      );
                    },
                  ),
                ],
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 32),

              // ── Sign Out button ───────────────────────────
              _buildSignOutButton(isDarkMode),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Profile Header ─────────────────────────────────────────────

  Widget _buildProfileHeader(bool isDarkMode) {
    final constituencyName = _isLoadingConstituency
        ? LanguageService.tr('loading')
        : _currentConstituency?.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ThemeService.accent.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: widget.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.photoUrl!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorWidget: (_, _, _) => Container(
                        color: ThemeService.accent.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: ThemeService.accent,
                        ),
                      ),
                    )
                  : Container(
                      color: ThemeService.accent.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: ThemeService.accent,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            LanguageService.translitName(widget.userName),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _primaryText,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (widget.userEmail != null && widget.userEmail!.isNotEmpty)
            Text(
              widget.userEmail!,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? const Color(0xFFB0B0B0) : ThemeService.lightSubtext,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (constituencyName != null)
                _buildStatPill(
                  icon: Icons.location_on_rounded,
                  label: constituencyName,
                  color: ThemeService.accent,
                  isDarkMode: isDarkMode,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Card ───────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required List<_SettingItem> items,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? ThemeService.bgElev : ThemeService.lightCard,
        borderRadius: BorderRadius.circular(ThemeService.cardRadius),
        border: isDarkMode
            ? null
            : Border.all(color: ThemeService.lightBorder, width: 1),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _secondaryText,
                letterSpacing: 0.2,
              ),
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            _buildSettingRow(items[i], isDarkMode),
            if (i < items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 68),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: _dividerColor,
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSettingRow(_SettingItem item, bool isDarkMode) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(ThemeService.cardRadius),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: item.iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _primaryText,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _secondaryText.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sign Out Button ────────────────────────────────────────────

  Widget _buildSignOutButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () async {
          final navigator = Navigator.of(context);
          final shouldLogout = await showDialog<bool>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.6),
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isDarkMode ? _cardBackground : ThemeService.lightCard,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: isDarkMode
                                    ? ThemeService.bgElev
                                    : ThemeService.lightCardAlt,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ThemeService.smallRadius),
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
                                  borderRadius: BorderRadius.circular(ThemeService.smallRadius),
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
            showDialog(
              context: navigator.context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              final googleSignIn = GoogleSignIn();
              await googleSignIn.signOut();
              await googleSignIn.disconnect();
              await AuthStorageService.clearAuthData();

              if (mounted) {
                navigator.pop();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const GoogleSignInPage(),
                  ),
                  (route) => false,
                );
              }
            } catch (e) {
              if (mounted) {
                navigator.pop();
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
          backgroundColor: Colors.transparent,
          side: const BorderSide(
            color: Color(0xFFD32F2F),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeService.smallRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFD32F2F)),
            const SizedBox(width: 8),
            Text(
              LanguageService.tr('log_out'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper data class for setting items ──────────────────────────

class _SettingItem {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _SettingItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });
}

// --- Customization Bottom Sheet ---

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
  late final TextEditingController _debugBaseUrlController;

  bool _isApplyingDebugUrl = false;
  bool _isResettingDebugUrl = false;
  String? _debugBaseUrlError;

  bool get _showDebugServerOption => kDebugMode && ApiConfig.canOverrideInDebug;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.darkModeOption;
    _selectedColor = widget.accentColorIndex;
    _debugBaseUrlController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _debugBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _applyDebugBaseUrl() async {
    if (_isApplyingDebugUrl) return;
    setState(() {
      _isApplyingDebugUrl = true;
      _debugBaseUrlError = null;
    });

    final ok = await ApiConfig.setDebugBaseUrl(_debugBaseUrlController.text);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isApplyingDebugUrl = false;
        _debugBaseUrlError = 'Enter a valid http(s) URL';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isApplyingDebugUrl = false;
      _debugBaseUrlError = null;
      _debugBaseUrlController.text = ApiConfig.baseUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug server URL updated')),
    );
  }

  Future<void> _resetDebugBaseUrl() async {
    if (_isResettingDebugUrl) return;
    setState(() {
      _isResettingDebugUrl = true;
      _debugBaseUrlError = null;
    });

    await ApiConfig.resetDebugBaseUrl();
    if (!mounted) return;

    setState(() {
      _isResettingDebugUrl = false;
      _debugBaseUrlController.text = ApiConfig.baseUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug server URL reset to default')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? ThemeService.bgCard : ThemeService.lightCard;
    final textColor = widget.primaryText;
    final subtextColor = widget.secondaryText;
    final accent = ThemeService.accentColors[_selectedColor];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThemeService.cardRadius)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              fontSize: ThemeService.sectionSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? ThemeService.bgElev
                  : ThemeService.lightCardAlt,
              borderRadius: BorderRadius.circular(ThemeService.cardRadius),
              border: widget.isDarkMode
                  ? null
                  : Border.all(color: ThemeService.lightBorder, width: 1),
            ),
            child: Row(
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
          ),
          const SizedBox(height: 28),
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
            label: '${LanguageService.tr('amoled')} ${LanguageService.tr('dark')}',
            subtitle: LanguageService.tr('pure_black_bg'),
            icon: Icons.brightness_2_outlined,
            option: DarkModeOption.amoled,
            accent: accent,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          if (_showDebugServerOption) ...[
            const SizedBox(height: 28),
            Text(
              'Debug Server',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subtextColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only available in debug builds',
              style: TextStyle(
                fontSize: 12,
                color: subtextColor.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _debugBaseUrlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://your-server.com',
                hintStyle: TextStyle(color: subtextColor.withValues(alpha: 0.6)),
                errorText: _debugBaseUrlError,
                filled: true,
                fillColor: widget.isDarkMode ? ThemeService.bgElev : ThemeService.lightCardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.isDarkMode ? ThemeService.bgBorder : ThemeService.lightBorder,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.isDarkMode ? ThemeService.bgBorder : ThemeService.lightBorder,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isResettingDebugUrl ? null : _resetDebugBaseUrl,
                    child: _isResettingDebugUrl
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isApplyingDebugUrl ? null : _applyDebugBaseUrl,
                    child: _isApplyingDebugUrl
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Apply'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Default: ${ApiConfig.defaultBaseUrl}',
              style: TextStyle(
                fontSize: 11,
                color: subtextColor.withValues(alpha: 0.85),
              ),
            ),
          ],
          ],
        ),
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ThemeService.smallRadius),
          border: isSelected
              ? Border.all(color: accent.withValues(alpha: 0.3), width: 1)
              : Border.all(
                  color: widget.isDarkMode
                      ? Colors.transparent
                      : ThemeService.lightBorder.withValues(alpha: 0.5),
                  width: 1,
                ),
        ),
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
