import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'search_page.dart';
import 'rate_page.dart';
import 'news_page.dart';
import 'profile_page.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../services/prefs_service.dart';

class MainScreen extends StatefulWidget {
  final String userName;
  final bool isVerified;
  final String? userEmail;
  final String? userId;
  final String? photoUrl;

  const MainScreen({
    super.key,
    required this.userName,
    required this.isVerified,
    this.userEmail,
    this.userId,
    this.photoUrl,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // Track which tabs have been visited (lazy-build on first visit)
  final List<bool> _visited = [true, false, false, false, false];
  // Navigation history stack — pressing back traverses this
  final List<int> _tabHistory = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = PrefsService.instance.getInt('last_nav_index') ?? 0;
    // Ensure the initial tab is marked as visited
    if (_currentIndex >= 0 && _currentIndex < _visited.length) {
      _visited[_currentIndex] = true;
    }
    // If restoring to a non-home tab, seed history so back goes to Home first
    if (_currentIndex != 0) {
      _tabHistory.add(0);
    }
  }

  void _switchToTab(int index) {
    if (index == _currentIndex) return;
    _tabHistory.add(_currentIndex);
    PrefsService.instance.setInt('last_nav_index', index);
    setState(() {
      _visited[index] = true;
      _currentIndex = index;
    });
  }

  void _updateSystemUI(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDarkMode ? ThemeService.bgMain : ThemeService.lightBg,
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  /// Build pages lazily — only creates a page widget on first visit.
  /// Before first visit, a SizedBox placeholder is used so IndexedStack
  /// has the correct child count but doesn't inflate the real widget tree.
  List<Widget> _buildPages() {
    return [
      // 0 – Home (always visited on launch)
      HomePage(onNavigateToTab: _switchToTab),
      // 1 – Search
      if (_visited[1]) SearchPage(key: SearchPage.globalKey) else const SizedBox.shrink(),
      // 2 – Rate
      if (_visited[2]) RatePage(key: ValueKey('rate_${LanguageService.languageCode}'), isVerified: widget.isVerified) else const SizedBox.shrink(),
      // 3 – News
      if (_visited[3]) const NewsPage() else const SizedBox.shrink(),
      // 4 – Profile
      if (_visited[4])
        ProfilePage(
          userName: widget.userName,
          isVerified: widget.isVerified,
          userEmail: widget.userEmail,
          userId: widget.userId,
          photoUrl: widget.photoUrl,
        )
      else
        const SizedBox.shrink(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    // Read LanguageProvider so bottom nav labels rebuild on language change
    context.watch<LanguageProvider>();
    final isDarkMode = theme.isDarkMode;

    // Keep system chrome in sync
    _updateSystemUI(isDarkMode);

    return PopScope(
      canPop: _currentIndex == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // on Home with no history — system exits the app
        if (_tabHistory.isNotEmpty) {
          final prev = _tabHistory.removeLast();
          PrefsService.instance.setInt('last_nav_index', prev);
          setState(() => _currentIndex = prev);
        } else {
          // Not on Home but history is empty — go Home
          PrefsService.instance.setInt('last_nav_index', 0);
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
      backgroundColor: isDarkMode ? ThemeService.bgMain : ThemeService.lightBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _buildPages(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? ThemeService.bgMain : ThemeService.lightBg,
        ),
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? ThemeService.bgElev : ThemeService.lightCard,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
                ),
              ],
            ),
            child: GNav(
              rippleColor: isDarkMode
                  ? ThemeService.bgBorder
                  : ThemeService.lightBgAlt,
              hoverColor: isDarkMode
                  ? ThemeService.bgBorder
                  : ThemeService.lightBgAlt,
              gap: 6,
              activeColor: ThemeService.accent,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              textStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ThemeService.accent,
              ),
              duration: const Duration(milliseconds: 350),
              tabBackgroundColor: isDarkMode
                  ? ThemeService.bgBorder
                  : ThemeService.accent.withValues(alpha: 0.1),
              color: isDarkMode ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
              tabs: [
                GButton(
                  icon: Icons.home_rounded,
                  text: LanguageService.tr('nav_home'),
                ),
                GButton(
                  icon: Icons.search_rounded,
                  text: LanguageService.tr('nav_search'),
                ),
                GButton(
                  icon: Icons.star_rounded,
                  text: LanguageService.tr('nav_rate'),
                ),
                GButton(
                  icon: Icons.article_rounded,
                  text: LanguageService.tr('nav_news'),
                ),
                GButton(
                  icon: Icons.person_rounded,
                  text: LanguageService.tr('nav_profile'),
                ),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                if (index == 1 && _currentIndex == 1) {
                  SearchPage.globalKey.currentState?.focusSearchBar();
                }
                _switchToTab(index);
              },
            ),
          ),
        ),
      ),
      ),
    );
  }
}
