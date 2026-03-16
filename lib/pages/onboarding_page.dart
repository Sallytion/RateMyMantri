import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../main.dart';
import '../models/constituency.dart';
import '../providers/language_provider.dart';
import '../services/constituency_service.dart';
import '../services/language_service.dart';
import '../services/prefs_service.dart';
import '../services/theme_service.dart';

class OnboardingPage extends StatefulWidget {
  final String userName;
  final String? userEmail;
  final String? userId;
  final String? photoUrl;

  const OnboardingPage({
    super.key,
    required this.userName,
    this.userEmail,
    this.userId,
    this.photoUrl,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedLanguage = LanguageService.languageCode;

  // Constituency search state
  final TextEditingController _searchController = TextEditingController();
  final ConstituencyService _constituencyService = ConstituencyService();
  Timer? _debounceTimer;
  List<Constituency> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _selectedConstituencyName;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    const totalPages = 2;

    if (_currentPage == 0) {
      // Save language preference
      context.read<LanguageProvider>().setLanguage(_selectedLanguage);
    }

    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = PrefsService.instance;
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthChecker(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final result = await _constituencyService.searchConstituencies(query);
    if (mounted) {
      setState(() {
        _searchResults = result['constituencies'] as List<Constituency>;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectConstituency(Constituency constituency) async {
    setState(() => _isSearching = true);
    final result =
        await _constituencyService.setCurrentConstituency(constituency.id);
    if (mounted) {
      setState(() {
        _isSearching = false;
        if (result['success'] == true) {
          _selectedConstituencyName = constituency.name;
          _searchController.clear();
          _searchResults = [];
          _hasSearched = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ThemeService.bgMain : ThemeService.lightBg;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: List.generate(2, (index) {
                    final isActive = index <= _currentPage;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        height: 3,
                        margin: EdgeInsets.only(right: index == 0 ? 6 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: isActive
                              ? ThemeService.accent
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : ThemeService.lightBorder),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) =>
                      setState(() => _currentPage = page),
                  children: [
                    _buildLanguagePage(isDark),
                    _buildConstituencyPage(isDark),
                  ],
                ),
              ),

              // Bottom button
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentPage == 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextButton(
                            onPressed: _completeOnboarding,
                            child: Text(
                              LanguageService.tr('skip'),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : ThemeService.lightSubtext,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_currentPage == 1 &&
                                  _selectedConstituencyName == null)
                            ? null
                            : _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeService.accent,
                          disabledBackgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          disabledForegroundColor: isDark
                              ? Colors.white30
                              : Colors.black26,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                          ),
                        ),
                        child: Text(
                          _currentPage == 0
                              ? LanguageService.tr('continue_text')
                              : LanguageService.tr('get_started'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Language Selection Page ────────────────────────────────────

  Widget _buildLanguagePage(bool isDark) {
    final textColor = isDark ? Colors.white : ThemeService.lightText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeService.accent.withValues(alpha: 0.1)
                  : ThemeService.pastelLavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.translate_rounded,
              color: ThemeService.accent,
              size: 28,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            LanguageService.tr('onboarding_lang_title'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            LanguageService.tr('onboarding_lang_subtitle'),
            style: TextStyle(
              fontSize: 15,
              color: isDark ? textColor.withValues(alpha: 0.5) : ThemeService.lightSubtext,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Language grid
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: LanguageService.supportedLanguages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final lang = LanguageService.supportedLanguages[index];
                final code = lang['code']!;
                final isSelected = code == _selectedLanguage;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedLanguage = code);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ThemeService.accent.withValues(alpha: 0.08)
                          : (isDark
                              ? ThemeService.bgElev
                              : ThemeService.lightCard),
                      borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                      border: Border.all(
                        color: isSelected
                            ? ThemeService.accent.withValues(alpha: 0.4)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : ThemeService.lightBorder),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Native name
                        Text(
                          lang['nativeName']!,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? ThemeService.accent : textColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          lang['name']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? textColor.withValues(alpha: 0.4)
                                : ThemeService.lightSubtext,
                          ),
                        ),
                        const Spacer(),
                        // Check icon
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: ThemeService.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Constituency Selection Page ───────────────────────────────

  Widget _buildConstituencyPage(bool isDark) {
    final textColor = isDark ? Colors.white : ThemeService.lightText;
    final cardColor = isDark ? ThemeService.bgElev : ThemeService.lightCard;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeService.accent.withValues(alpha: 0.1)
                  : ThemeService.pastelLavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: ThemeService.accent,
              size: 28,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            LanguageService.tr('onboarding_loc_title'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            LanguageService.tr('onboarding_loc_subtitle'),
            style: TextStyle(
              fontSize: 15,
              color: isDark ? textColor.withValues(alpha: 0.5) : ThemeService.lightSubtext,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Selected constituency indicator
          if (_selectedConstituencyName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: ThemeService.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                border: Border.all(
                    color: ThemeService.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: ThemeService.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.tr('current_constituency'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? textColor.withValues(alpha: 0.5)
                                : ThemeService.lightSubtext,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedConstituencyName!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Search input
          TextField(
            controller: _searchController,
            style: TextStyle(color: textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: LanguageService.tr('search_constituency_hint'),
              hintStyle: TextStyle(
                color: isDark
                    ? textColor.withValues(alpha: 0.35)
                    : ThemeService.lightSubtext,
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark
                    ? textColor.withValues(alpha: 0.4)
                    : ThemeService.lightSubtext,
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark
                              ? textColor.withValues(alpha: 0.4)
                              : ThemeService.lightSubtext,
                          size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _hasSearched = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? ThemeService.bgElev
                  : ThemeService.lightCard,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : ThemeService.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                borderSide:
                    BorderSide(color: ThemeService.accent, width: 1.5),
              ),
            ),
            onChanged: _onSearchChanged,
          ),

          const SizedBox(height: 16),

          // Search results
          Expanded(
            child: _isSearching
                ? Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ThemeService.accent,
                      ),
                    ),
                  )
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 48,
                              color: isDark
                                  ? textColor.withValues(alpha: 0.15)
                                  : ThemeService.lightBorder,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              LanguageService.tr('search_constituency'),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? textColor.withValues(alpha: 0.35)
                                    : ThemeService.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 48,
                                    color: isDark
                                        ? textColor.withValues(alpha: 0.15)
                                        : ThemeService.lightBorder),
                                const SizedBox(height: 12),
                                Text(
                                  LanguageService.tr('no_constituencies'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? textColor.withValues(alpha: 0.35)
                                        : ThemeService.lightSubtext,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final c = _searchResults[index];
                              final isSelected =
                                  _selectedConstituencyName == c.name;

                              return GestureDetector(
                                onTap: () => _selectConstituency(c),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? ThemeService.accent
                                            .withValues(alpha: 0.08)
                                        : cardColor,
                                    borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                                    border: Border.all(
                                      color: isSelected
                                          ? ThemeService.accent
                                              .withValues(alpha: 0.3)
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.06)
                                              : ThemeService.lightBorder),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? ThemeService.accent
                                                  .withValues(alpha: 0.1)
                                              : ThemeService.pastelLavender,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: ThemeService.accent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c.type ==
                                                      'lok_sabha_constituency'
                                                  ? LanguageService.tr(
                                                      'lok_sabha')
                                                  : c.type ==
                                                          'vidhan_sabha_constituency'
                                                      ? LanguageService.tr(
                                                          'vidhan_sabha')
                                                      : c.displayType,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? textColor
                                                        .withValues(alpha: 0.45)
                                                    : ThemeService.lightSubtext,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded,
                                            color: ThemeService.accent,
                                            size: 22),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
