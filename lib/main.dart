import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/notifications/notification_test_screen.dart';
import 'config/supabase_config.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'screens/auth/reset_password_screen.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (message.data.isNotEmpty) {
    // Handle background notification data
    await NotificationService.handleBackgroundMessage(message);
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set global system UI overlay style for consistent status bar colors
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);

    // Handle app lifecycle to maintain status bar colors
    SystemChannels.platform.setMethodCallHandler((call) async {
      if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
        SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
      }
    });

    // Handle platform channel errors globally
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error to your error reporting service
      NotificationService.logError(details.exception, details.stack);
    };

    try {
      // Initialize Supabase
      await SupabaseConfig.initialize();

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize notification service
      await NotificationService.initialize();

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          NotificationService.showLocalNotification(
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? 'You have a new notification',
            payload: message.data.isNotEmpty ? message.data.toString() : '{}',
          );
        }
      });

      // Check for missed notifications
      await NotificationService.checkMissedNotifications();

      runApp(const MyApp());
    } catch (e, stackTrace) {
      NotificationService.logError(e, stackTrace);
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Error initializing app: $e'),
            ),
          ),
        ),
      );
    }
  }, (error, stackTrace) {
    NotificationService.logError(error, stackTrace);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for auth state changes
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        _handlePasswordRecovery();
      }
    });

    // Check initial deep link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialAuthState();
    });
  }

  void _handlePasswordRecovery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Use Future.delayed to ensure the context is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;

        try {
          Navigator.of(navigatorKey.currentContext!).pushNamedAndRemoveUntil(
            '/reset-password',
            (route) => false,
          );
        } catch (e, stackTrace) {
          NotificationService.logError(e, stackTrace);
        }
      });
    });
  }

  Future<void> _checkInitialAuthState() async {
    try {
      final session = await Supabase.instance.client.auth.currentSession;

      if (session != null) {
        final event =
            await Supabase.instance.client.auth.onAuthStateChange.first;

        if (event.event == AuthChangeEvent.passwordRecovery) {
          _handlePasswordRecovery();
        }
      }
    } catch (e, stackTrace) {
      NotificationService.logError(e, stackTrace);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure system UI overlay style is maintained
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
    });

    return MaterialApp(
      title: 'EduBazaar',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/notification-test': (context) => const NotificationTestScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        );
      },
    );
  }
}
