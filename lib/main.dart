import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/google_sign_in_page.dart';
import 'pages/main_screen.dart';
import 'services/auth_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style to dark by default
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rate My Mantri',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        cardColor: const Color(0xFFF7F7F7),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        canvasColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2A2A2A),
        dialogBackgroundColor: const Color(0xFF2A2A2A),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Container(
          color: const Color(0xFF1A1A1A),
          child: child,
        );
      },
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Check if user has valid tokens
    final isAuthenticated = await AuthStorageService.isAuthenticated();

    if (isAuthenticated) {
      // Try to fetch user profile to verify token is still valid
      final userData = await AuthStorageService.fetchUserProfile();

      if (userData != null && mounted) {
        // User is authenticated, get verification status
        final isVerified =
            await AuthStorageService.getAadhaarVerificationStatus();

        // Navigate to main screen with user data
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(
              userName: userData['name'] ?? 'User',
              isVerified: isVerified,
              userEmail: userData['email'],
              userId: userData['googleId'],
              photoUrl: userData['picture'],
            ),
          ),
        );
      } else if (mounted) {
        // Token invalid or expired, clear auth and show login
        await AuthStorageService.clearAuthData();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GoogleSignInPage()),
        );
      }
    } else if (mounted) {
      // No tokens found, show login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GoogleSignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while checking auth
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
