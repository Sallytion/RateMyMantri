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

  @override
  void initState() {
    super.initState();
    _currentIndex = PrefsService.instance.getInt('last_nav_index') ?? 0;
    // Ensure the initial tab is marked as visited
    if (_currentIndex >= 0 && _currentIndex < _visited.length) {
      _visited[_currentIndex] = true;
    }
  }

  void _updateSystemUI(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDarkMode ? ThemeService.bgMain : Colors.white,
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
      HomePage(onNavigateToTab: (index) {
        PrefsService.instance.setInt('last_nav_index', index);
        setState(() {
          _visited[index] = true;
          _currentIndex = index;
        });
      }),
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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _buildPages(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? ThemeService.bgMain : Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withValues(alpha: .1),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: isDarkMode
                  ? ThemeService.bgElev
                  : Colors.grey[300]!,
              hoverColor: isDarkMode
                  ? ThemeService.bgElev
                  : Colors.grey[100]!,
              gap: 6,
              activeColor: ThemeService.accent,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: isDarkMode
                  ? ThemeService.bgElev
                  : ThemeService.accent.withValues(alpha: 0.1),
              color: isDarkMode ? const Color(0xFF717171) : Colors.grey,
              tabs: [
                GButton(
                  icon: Icons.home,
                  text: LanguageService.tr('nav_home'),
                ),
                GButton(
                  icon: Icons.search,
                  text: LanguageService.tr('nav_search'),
                ),
                GButton(
                  icon: Icons.star,
                  text: LanguageService.tr('nav_rate'),
                ),
                GButton(
                  icon: Icons.article,
                  text: LanguageService.tr('nav_news'),
                ),
                GButton(
                  icon: Icons.person,
                  text: LanguageService.tr('nav_profile'),
                ),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                if (index == 1 && _currentIndex == 1) {
                  SearchPage.globalKey.currentState?.focusSearchBar();
                }
                PrefsService.instance.setInt('last_nav_index', index);
                setState(() {
                  _visited[index] = true;
                  _currentIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
