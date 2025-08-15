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
    print('🚀 [NOTIFICATION] Starting notification service initialization...');

    try {
      // Request permissions first
      print('🔧 [NOTIFICATION] Requesting notification permissions...');
      await requestPermission();
      print('✅ [NOTIFICATION] Permission request completed');

      // Initialize local notifications
      print('🔧 [NOTIFICATION] Initializing local notifications...');
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
          print(
              '🔔 [NOTIFICATION] Notification tapped! Payload: ${details.payload}');
          _handleNotificationTap(details.payload);
        },
      );
      print('✅ [NOTIFICATION] Local notifications initialized successfully');

      // Create Android notification channel
      print('🔧 [NOTIFICATION] Creating Android notification channel...');
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      print('✅ [NOTIFICATION] Android channel created: ${_channel.id}');

      // Get and save FCM token
      final token = await getDeviceToken();
      if (token != null) {
        await saveFCMTokenToSupabase(token);
      }

      // Listen for token refresh
      listenForTokenRefresh();

      print(
          '🎉 [NOTIFICATION] Notification service initialization completed successfully!');
    } catch (e) {
      print('❌ [NOTIFICATION] Error during initialization: $e');
      print('❌ [NOTIFICATION] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Request notification permissions
  static Future<NotificationSettings> requestPermission() async {
    print('🔐 [PERMISSION] Requesting FCM notification permissions...');

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print(
        '🔐 [PERMISSION] FCM permission result: ${settings.authorizationStatus}');
    print('🔐 [PERMISSION] Alert: ${settings.alert}');
    print('🔐 [PERMISSION] Badge: ${settings.badge}');
    print('🔐 [PERMISSION] Sound: ${settings.sound}');

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Request permissions for local notifications on iOS
    print('🔐 [PERMISSION] Requesting iOS local notification permissions...');
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    print('🔐 [PERMISSION] iOS local notification permissions requested');

    return settings;
  }

  /// Get the FCM device token
  static Future<String?> getDeviceToken() async {
    print('🔑 [FCM] Requesting FCM device token...');
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        print('✅ [FCM] FCM token received: ${token.substring(0, 30)}...');
        print('🔑 [FCM] Full token length: ${token.length} characters');
      } else {
        print('❌ [FCM] FCM token is null');
      }
      return token;
    } catch (e) {
      print('❌ [FCM] Error getting FCM token: $e');
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
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Show a local notification
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    print('🔔 [NOTIFICATION] Starting local notification...');
    print('🔔 [NOTIFICATION] Title: $title');
    print('🔔 [NOTIFICATION] Body: $body');
    print('🔔 [NOTIFICATION] Payload: $payload');

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

      print('🔔 [NOTIFICATION] Notification details created successfully');
      print('🔔 [NOTIFICATION] Android channel: ${_channel.id}');
      print(
          '🔔 [NOTIFICATION] iOS details: presentAlert=${iOSDetails.presentAlert}');

      final notificationId = DateTime.now().millisecond;
      print('🔔 [NOTIFICATION] Generated ID: $notificationId');

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('✅ [NOTIFICATION] Local notification sent successfully!');
      print('✅ [NOTIFICATION] ID: $notificationId');
      print('✅ [NOTIFICATION] Time: ${DateTime.now()}');

      // Verify notification was actually shown
      print('🔍 [NOTIFICATION] Verifying notification display...');
    } catch (e) {
      print('❌ [NOTIFICATION] Error showing local notification: $e');
      print('❌ [NOTIFICATION] Stack trace: ${StackTrace.current}');
      rethrow;
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

      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
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
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Save FCM token to Supabase
  static Future<void> saveFCMTokenToSupabase(String token) async {
    print('💾 [FCM] Starting to save FCM token to Supabase...');
    print('💾 [FCM] Token to save: ${token.substring(0, 30)}...');

    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ [FCM] No user ID found for FCM token');
        return;
      }

      print('💾 [FCM] User ID: $userId');

      // Delete any old tokens for this user first
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId);

      print('🗑️ [FCM] Deleted old tokens');

      // Insert new token
      await Supabase.instance.client.from('user_fcm_tokens').insert({
        'user_id': userId,
        'fcm_token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ [FCM] FCM token saved to Supabase successfully!');

      // Verify the token was saved
      final savedToken = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select()
          .eq('user_id', userId)
          .eq('fcm_token', token)
          .single();

      if (savedToken != null) {
        print('✅ [FCM] Token verification successful');
      } else {
        print(
            '⚠️ [FCM] Token verification failed - token not found in database');
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
      print('❌ [FCM] Exception saving FCM token: $e');
      print('❌ [FCM] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Listen for token refresh
  static void listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      print('🔄 FCM token refreshed, saving to Supabase...');
      await saveFCMTokenToSupabase(token);
    });
  }

  /// Check for missed notifications when app launches
  static Future<void> checkMissedNotifications() async {
    print('🔍 [NOTIFICATION] Checking for missed notifications...');

    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        print('❌ [NOTIFICATION] No user ID found for checking notifications');
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
        print(
            '✅ [NOTIFICATION] Found ${notifications.length} unread notifications');

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
      } else {
        print('ℹ️ [NOTIFICATION] No missed notifications found');
      }
    } catch (e) {
      print('❌ [NOTIFICATION] Error checking missed notifications: $e');
    }
  }
}
