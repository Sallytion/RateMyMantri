import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'home_page.dart';
import 'search_page.dart';
import 'rate_page.dart';
import 'news_page.dart';
import 'profile_page.dart';

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

  @override
  void initState() {
    super.initState();
    _updateSystemUI();
  }

  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
      _updateSystemUI();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(isDarkMode: _isDarkMode, onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          }),
          SearchPage(key: SearchPage.globalKey, isDarkMode: _isDarkMode),
          RatePage(isDarkMode: _isDarkMode, isVerified: widget.isVerified),
          NewsPage(isDarkMode: _isDarkMode),
          ProfilePage(
            isDarkMode: _isDarkMode,
            onDarkModeToggle: _toggleDarkMode,
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
          color: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
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
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey[300]!,
              hoverColor: _isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey[100]!,
              gap: 8,
              activeColor: _isDarkMode
                  ? const Color(0xFFFF385C)
                  : Colors.deepPurple,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: _isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : Colors.deepPurple.withValues(alpha: 0.1),
              color: _isDarkMode ? const Color(0xFF717171) : Colors.grey,
              tabs: const [
                GButton(
                  icon: Icons.home,
                  text: 'Home',
                ),
                GButton(
                  icon: Icons.search,
                  text: 'Search',
                ),
                GButton(
                  icon: Icons.star,
                  text: 'Rate',
                ),
                GButton(
                  icon: Icons.article,
                  text: 'News',
                ),
                GButton(
                  icon: Icons.person,
                  text: 'Profile',
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
