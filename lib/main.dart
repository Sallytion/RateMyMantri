import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/google_sign_in_page.dart';
import 'pages/main_screen.dart';
import 'services/auth_storage_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase in the background (don't block app startup)
  _initializeFirebase();
  
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

Future<void> _initializeFirebase() async {
  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
    
    // Initialize notifications and subscribe to 'general' topic
    debugPrint('📲 Starting notification service initialization...');
    await NotificationService.initialize();
    debugPrint('✅ Notifications initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('⚠️ Firebase initialization error: $e');
    debugPrint('⚠️ Stack trace: $stackTrace');
    debugPrint('⚠️ App will continue without push notifications');
  }
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
      themeMode: ThemeMode.system,
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
    debugPrint('🔍 AuthChecker: Starting auth check...');
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      debugPrint('🔍 AuthChecker: Checking if authenticated...');
      // Check if user has valid tokens
      final isAuthenticated = await AuthStorageService.isAuthenticated();
      debugPrint('🔍 AuthChecker: isAuthenticated = $isAuthenticated');

      if (isAuthenticated) {
        debugPrint('🔍 AuthChecker: Fetching user profile...');
        // Try to fetch user profile to verify token is still valid
        final userData = await AuthStorageService.fetchUserProfile();
        debugPrint('🔍 AuthChecker: userData = $userData');

        if (userData != null && mounted) {
          // User is authenticated, get verification status
          final isVerified =
              await AuthStorageService.getAadhaarVerificationStatus();
          debugPrint('🔍 AuthChecker: Navigating to MainScreen...');

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
          debugPrint('🔍 AuthChecker: Token invalid, navigating to login...');
          // Token invalid or expired, clear auth and show login
          await AuthStorageService.clearAuthData();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const GoogleSignInPage()),
          );
        }
      } else if (mounted) {
        debugPrint('🔍 AuthChecker: Not authenticated, navigating to login...');
        // No tokens found, show login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GoogleSignInPage()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ AuthChecker error: $e');
      debugPrint('Stack trace: $stackTrace');
      // On error, go to login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GoogleSignInPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while checking auth
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
