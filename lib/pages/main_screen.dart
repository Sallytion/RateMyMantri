import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'home_page.dart';
import 'search_page.dart';
import 'rate_page.dart';
import 'news_page.dart';
import 'profile_page.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

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
  bool _isDarkMode = false;
  DarkModeOption _darkModeOption = DarkModeOption.system;
  int _accentColorIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

  Future<void> _loadThemePreferences() async {
    final option = await ThemeService.loadDarkMode();
    final colorIndex = await ThemeService.loadAccentColorIndex();
    if (mounted) {
      setState(() {
        _darkModeOption = option;
        _accentColorIndex = colorIndex;
        _isDarkMode = ThemeService.resolveIsDark(
          option,
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        );
      });
      _applyTheme();
    }
  }

  void _applyTheme() {
    ThemeService.apply(
      accentIndex: _accentColorIndex,
      darkMode: _darkModeOption,
      platformBrightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    _updateSystemUI();
  }

  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _isDarkMode ? ThemeService.bgMain : Colors.white,
        systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void _toggleDarkMode(bool value) {
    // Legacy toggle — maps to dark/light
    _setDarkModeOption(value ? DarkModeOption.dark : DarkModeOption.light);
  }

  void _setDarkModeOption(DarkModeOption option) {
    ThemeService.saveDarkMode(option);
    setState(() {
      _darkModeOption = option;
      _isDarkMode = ThemeService.resolveIsDark(
        option,
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );
    });
    _applyTheme();
  }

  void _setAccentColor(int index) {
    ThemeService.saveAccentColorIndex(index);
    setState(() {
      _accentColorIndex = index;
    });
    _applyTheme();
  }

  void _setLanguage(String code) {
    LanguageService.setLanguage(code);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(isDarkMode: _isDarkMode, languageCode: LanguageService.languageCode, onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          }),
          SearchPage(key: SearchPage.globalKey, isDarkMode: _isDarkMode),
          RatePage(isDarkMode: _isDarkMode, isVerified: widget.isVerified),
          NewsPage(isDarkMode: _isDarkMode, languageCode: LanguageService.languageCode),
          ProfilePage(
            isDarkMode: _isDarkMode,
            onDarkModeToggle: _toggleDarkMode,
            darkModeOption: _darkModeOption,
            accentColorIndex: _accentColorIndex,
            onDarkModeOptionChanged: _setDarkModeOption,
            onAccentColorChanged: _setAccentColor,
            onLanguageChanged: _setLanguage,
            userName: widget.userName,
            isVerified: widget.isVerified,
            userEmail: widget.userEmail,
            userId: widget.userId,
            photoUrl: widget.photoUrl,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? ThemeService.bgMain : Colors.white,
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
              rippleColor: _isDarkMode
                  ? ThemeService.bgElev
                  : Colors.grey[300]!,
              hoverColor: _isDarkMode
                  ? ThemeService.bgElev
                  : Colors.grey[100]!,
              gap: 8,
              activeColor: ThemeService.accent,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: _isDarkMode
                  ? ThemeService.bgElev
                  : ThemeService.accent.withValues(alpha: 0.1),
              color: _isDarkMode ? const Color(0xFF717171) : Colors.grey,
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
                  // Double-tap on Search tab: focus the search bar
                  SearchPage.globalKey.currentState?.focusSearchBar();
                }
                setState(() {
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
