import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'pages/google_sign_in_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/main_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'services/auth_storage_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/prefs_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Pre-fetch SharedPreferences singleton (used by every service)
  await PrefsService.init();
  
  // Initialize language service (loads preference + inditrans engine)
  await LanguageService.init();
  
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize notifications and subscribe to 'general' topic
    await NotificationService.initialize();
  } catch (_) {
    // App will continue without push notifications
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Rate My Mantri',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: ThemeService.accent,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.white,
              canvasColor: Colors.white,
              cardColor: const Color(0xFFF7F7F7),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: ThemeService.accent,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: ThemeService.bgMain,
              canvasColor: ThemeService.bgMain,
              cardColor: ThemeService.bgElev,
              dialogTheme: DialogThemeData(backgroundColor: ThemeService.bgElev),
              useMaterial3: true,
            ),
            themeMode: ThemeMode.system,
            home: const AuthChecker(),
          );
        },
      ),
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
    // Wait for the initial frame to be built before attempting navigation
    await Future.delayed(Duration.zero);
    
    try {
      // Check if user has valid tokens
      final isAuthenticated = await AuthStorageService.isAuthenticated();

      if (isAuthenticated) {
        // Try to fetch user profile to verify token is still valid
        final userData = await AuthStorageService.fetchUserProfile();

        if (userData != null && mounted) {
          // User is authenticated, get verification status
          final isVerified =
              await AuthStorageService.getAadhaarVerificationStatus();
          
          if (!mounted) return;

          // Check if onboarding has been completed
          final prefs = PrefsService.instance;
          final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

          if (!onboardingCompleted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => OnboardingPage(
                userName: userData['name'] ?? 'User',
                isVerified: isVerified,
                userEmail: userData['email'],
                userId: userData['googleId'] ?? '',
                photoUrl: userData['picture'],
              )),
            );
            return;
          }

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
          if (!mounted) return;
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
    } catch (_) {
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
