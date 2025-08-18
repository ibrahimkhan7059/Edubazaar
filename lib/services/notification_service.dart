import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import 'auth_service.dart';
import '../main.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'edubazaar_messages',
    'Messages',
    description: 'Notifications for messages and conversations',
    importance: Importance.high,
    enableVibration: true,
    showBadge: true,
    playSound: true,
  );

  /// Initialize notification settings
  static Future<void> initialize() async {
    try {
      // Request permissions first
      await requestPermission();

      // Check and update FCM token
      await checkAndUpdateFCMToken();

      // Initialize local notifications
      await _localNotifications.initialize(
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );

      // Create Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Get and save FCM token
      final token = await getDeviceToken();
      if (token != null) {
        await saveFCMTokenToSupabase(token);
      }

      // Listen for token refresh
      listenForTokenRefresh();

      // Notification service initialization completed successfully
    } catch (e) {
      rethrow;
    }
  }

  /// Request notification permissions
  static Future<NotificationSettings> requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request permissions for local notifications on iOS
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return settings;
  }

  /// Get the FCM device token
  static Future<String?> getDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      return null;
    }
  }

  /// Handle notification tap
  static Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null) return;

    try {
      final data = json.decode(payload);
      final String type = data['type'];
      final String conversationId = data['conversationId'];

      if (type == 'message_inserted') {
        // Get navigation context
        final context = navigatorKey.currentContext;
        if (context != null) {
          // Navigate to chat screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conversationId,
                otherUserId: data['senderId'],
                otherUserName: data['senderName'],
                otherUserAvatar: data['senderAvatar'],
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Error handling notification tap handled silently
    }
  }

  /// Show a local notification
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      final iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final notificationId = DateTime.now().millisecond;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      // Local notification sent successfully
    } catch (e) {
      rethrow;
    }
  }

  /// Handles background messages
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (message.notification != null) {
      await showLocalNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? 'You have a new notification',
        payload: message.data.isNotEmpty ? message.data.toString() : '{}',
      );
    }
  }

  /// Logs errors to your error reporting service
  static void logError(dynamic error, StackTrace? stackTrace) {
    // TODO: Implement proper error reporting service
    // For now, just print to console in debug mode
    if (kDebugMode) {
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Subscribe to real-time chat notifications
  static Stream<List<Map<String, dynamic>>> subscribeToChatNotifications() {
    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      return Stream.empty();
    }

    return Supabase.instance.client
        .from('chat_notifications')
        .stream(primaryKey: ['id'])
        .neq('user_id', 'null')
        .order('created_at', ascending: false)
        .map((data) {
          return data
              .where((notification) =>
                  notification['user_id'] == userId &&
                  notification['is_read'] == false)
              .toList();
        });
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('chat_notifications')
          .update({'is_read': true}).eq('id', notificationId);

      // Notification marked as read successfully
    } catch (e) {
      // Error marking notification as read handled silently
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadNotificationCount() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) return 0;

      final response = await Supabase.instance.client
          .from('chat_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Save FCM token to Supabase
  static Future<void> saveFCMTokenToSupabase(String token) async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return;
      }

      // Delete any old tokens for this user first
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId);

      // Delete any old tokens for this user first
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId);

      // Insert new token
      await Supabase.instance.client.from('user_fcm_tokens').insert({
        'user_id': userId,
        'fcm_token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Verify the token was saved
      final savedToken = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select()
          .eq('user_id', userId)
          .eq('fcm_token', token)
          .single();

      if (savedToken != null) {
        // Token verification successful
      } else {
        // Try saving again
        await Supabase.instance.client.from('user_fcm_tokens').insert({
          'user_id': userId,
          'fcm_token': token,
          'device_type': Platform.isAndroid ? 'android' : 'ios',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Listen for token refresh
  static void listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      await saveFCMTokenToSupabase(token);
    });
  }

  /// Check for missed notifications when app launches
  static Future<void> checkMissedNotifications() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return;
      }

      // Get unread notifications from last 24 hours
      final response = await Supabase.instance.client
          .from('chat_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(hours: 24))
                  .toIso8601String())
          .order('created_at', ascending: false);

      final notifications = response as List;
      if (notifications.isNotEmpty) {
        // Show summary notification if there are unread notifications
        if (notifications.length > 1) {
          await showLocalNotification(
            title: 'Unread Notifications',
            body: 'You have ${notifications.length} unread notifications',
            payload:
                '{"type": "unread_summary", "count": ${notifications.length}}',
          );
        } else {
          // Show the single unread notification
          final notification = notifications.first;
          await showLocalNotification(
            title: notification['title'] ?? 'New Notification',
            body: notification['body'] ?? 'You have a new notification',
            payload: notification['data']?.toString() ?? '{}',
          );
        }
      }
    } catch (e) {
      // Error checking missed notifications handled silently
    }
  }

  /// Check FCM token status and re-register if needed
  static Future<void> checkAndUpdateFCMToken() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return;
      }

      // Check if token exists in database
      final existingToken = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existingToken == null) {
        final newToken = await getDeviceToken();
        if (newToken != null) {
          await saveFCMTokenToSupabase(newToken);
        }
      } else {
        // Verify token is still valid with Firebase
        final currentToken = await getDeviceToken();
        if (currentToken != existingToken['fcm_token']) {
          await saveFCMTokenToSupabase(currentToken!);
        }
      }
    } catch (e) {
      // Error checking FCM token status handled silently
    }
  }
}
