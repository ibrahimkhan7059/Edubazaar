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

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [BACKGROUND] Starting background message handler...');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ [BACKGROUND] Firebase initialized for background message');
  print('🔔 [BACKGROUND] Handling background message: ${message.messageId}');
  print('🔔 [BACKGROUND] Message data: ${message.data}');
  print('🔔 [BACKGROUND] Message notification: ${message.notification?.title}');

  // Handle notification data
  if (message.data.isNotEmpty) {
    print('🔔 [BACKGROUND] Processing message data: ${message.data}');

    // You can add custom logic here for background notifications
    // For example, updating local storage, showing local notifications, etc.

    print('✅ [BACKGROUND] Background message processed successfully');
  } else {
    print('⚠️ [BACKGROUND] No message data to process');
  }

  print('🏁 [BACKGROUND] Background message handler completed');
}

void main() async {
  // Ensure all errors are caught and don't crash the app
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set global system UI overlay style for consistent status bar colors
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);

    // Handle app lifecycle to maintain status bar colors
    SystemChannels.platform.setMethodCallHandler((call) async {
      if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
        // Maintain our custom status bar colors
        SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
      }
    });

    // Handle platform channel errors globally
    FlutterError.onError = (FlutterErrorDetails details) {
      print('Flutter Error: ${details.exception}');
      print('Stack trace: ${details.stack}');
    };

    try {
      // Initialize Supabase first
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      print('✅ Supabase initialized successfully');

      // Initialize Firebase with proper options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');

      // Initialize notification service
      await NotificationService.initialize();
      print('✅ Notification service initialized successfully');

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔔 [FOREGROUND] Got a message whilst in the foreground!');
        print('🔔 [FOREGROUND] Message ID: ${message.messageId}');
        print('🔔 [FOREGROUND] Message data: ${message.data}');
        print(
            '🔔 [FOREGROUND] Message notification: ${message.notification?.title}');

        if (message.notification != null) {
          print('🔔 [FOREGROUND] Processing notification...');
          print('🔔 [FOREGROUND] Title: ${message.notification!.title}');
          print('🔔 [FOREGROUND] Body: ${message.notification!.body}');

          // Show local notification
          NotificationService.showLocalNotification(
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? 'You have a new notification',
            payload: message.data.isNotEmpty ? message.data.toString() : '{}',
          );
          print(
              '✅ [FOREGROUND] Local notification triggered from foreground message');
        } else {
          print('⚠️ [FOREGROUND] Message has no notification');
        }
      });

      // Check for missed notifications after all initializations
      await NotificationService.checkMissedNotifications();
      print('✅ Checked for missed notifications');

      runApp(const MyApp());
    } catch (e, stackTrace) {
      print('❌ Error during app initialization: $e');
      print('Stack trace: $stackTrace');
      // Show error UI or handle gracefully
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
    print('❌ Uncaught error: $error');
    print('Stack trace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      },
      // Handle navigation errors
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        );
      },
    );
  }
}
