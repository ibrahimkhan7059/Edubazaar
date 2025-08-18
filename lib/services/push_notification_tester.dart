import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'auth_service.dart';

class PushNotificationTester {
  static const String testChannelId = 'test_notifications';

  /// Test the complete push notification flow
  static Future<Map<String, dynamic>> testPushNotificationFlow() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
    };

    try {
      // Test 1: Check if FCM token exists
      final tokenTest = await _testFCMToken();
      results['tests']['fcm_token'] = tokenTest;

      // Test 2: Check database connection
      final dbTest = await _testDatabaseConnection();
      results['tests']['database'] = dbTest;

      // Test 3: Check Edge Function
      final edgeFunctionTest = await _testEdgeFunction();
      results['tests']['edge_function'] = edgeFunctionTest;

      // Test 4: Test notification settings
      final settingsTest = await _testNotificationSettings();
      results['tests']['notification_settings'] = settingsTest;

      // Test 5: Send test notification
      final testNotificationTest = await _sendTestNotification();
      results['tests']['test_notification'] = testNotificationTest;

      // Overall result
      final allPassed =
          results['tests'].values.every((test) => test['success'] == true);
      results['overall_success'] = allPassed;
      results['summary'] = allPassed
          ? 'All push notification tests passed! 🎉'
          : 'Some tests failed. Check individual test results.';
    } catch (e) {
      results['error'] = e.toString();
      results['overall_success'] = false;
      results['summary'] = 'Push notification test failed: $e';
    }

    return results;
  }

  /// Test FCM token functionality
  static Future<Map<String, dynamic>> _testFCMToken() async {
    try {
      // Check if token can be retrieved
      final token = await NotificationService.getDeviceToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Failed to get FCM token',
          'details': 'FCM token is null'
        };
      }

      // Check if token can be saved
      await NotificationService.saveFCMTokenToSupabase(token);

      // Verify token was saved
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'message': 'No user logged in',
          'details': 'Cannot test without authenticated user'
        };
      }

      final savedToken = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select()
          .eq('user_id', userId)
          .eq('fcm_token', token)
          .maybeSingle();

      return {
        'success': savedToken != null,
        'message': savedToken != null
            ? 'FCM token saved successfully'
            : 'FCM token not found in database',
        'details': {
          'token_length': token.length,
          'token_prefix': token.substring(0, 20),
          'saved_in_db': savedToken != null,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'FCM token test failed',
        'details': e.toString()
      };
    }
  }

  /// Test database connection and tables
  static Future<Map<String, dynamic>> _testDatabaseConnection() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'message': 'No user logged in',
          'details': 'Cannot test database without authenticated user'
        };
      }

      // Test required tables exist
      final tables = [
        'user_fcm_tokens',
        'notification_queue',
        'chat_notifications',
        'user_notification_settings'
      ];

      final tableTests = <String, bool>{};

      for (final table in tables) {
        try {
          await Supabase.instance.client.from(table).select('id').limit(1);
          tableTests[table] = true;
        } catch (e) {
          tableTests[table] = false;
        }
      }

      final allTablesExist = tableTests.values.every((exists) => exists);

      return {
        'success': allTablesExist,
        'message': allTablesExist
            ? 'All required tables exist'
            : 'Some required tables are missing',
        'details': {
          'tables': tableTests,
          'user_id': userId,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Database connection test failed',
        'details': e.toString()
      };
    }
  }

  /// Test Edge Function connectivity
  static Future<Map<String, dynamic>> _testEdgeFunction() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'notify-chat',
      );

      if (response.status == 200) {
        return {
          'success': true,
          'message': 'Edge Function is responsive',
          'details': {
            'status_code': response.status,
            'response_data': response.data,
          }
        };
      } else {
        return {
          'success': false,
          'message': 'Edge Function returned error',
          'details': {
            'status_code': response.status,
            'response_data': response.data,
          }
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Edge Function test failed',
        'details': e.toString()
      };
    }
  }

  /// Test notification settings
  static Future<Map<String, dynamic>> _testNotificationSettings() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'message': 'No user logged in',
          'details': 'Cannot test settings without authenticated user'
        };
      }

      // Check if settings exist, create if not
      var settings = await Supabase.instance.client
          .from('user_notification_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (settings == null) {
        // Create default settings
        await Supabase.instance.client
            .from('user_notification_settings')
            .insert({
          'user_id': userId,
          'push_notifications': true,
          'chat_notifications': true,
          'marketplace_notifications': true,
          'community_notifications': true,
        });

        settings = await Supabase.instance.client
            .from('user_notification_settings')
            .select()
            .eq('user_id', userId)
            .single();
      }

      final notificationsEnabled = settings['push_notifications'] == true &&
          settings['chat_notifications'] == true;

      return {
        'success': notificationsEnabled,
        'message': notificationsEnabled
            ? 'Notification settings are enabled'
            : 'Notifications are disabled in settings',
        'details': {
          'push_notifications': settings['push_notifications'],
          'chat_notifications': settings['chat_notifications'],
          'settings_exist': true,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Notification settings test failed',
        'details': e.toString()
      };
    }
  }

  /// Send a test notification
  static Future<Map<String, dynamic>> _sendTestNotification() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'message': 'No user logged in',
          'details': 'Cannot send test notification without authenticated user'
        };
      }

      // Insert a test notification directly into chat_notifications
      final testNotification = {
        'user_id': userId,
        'type': 'test_notification',
        'title': '🧪 Test Notification',
        'body': 'This is a test notification to verify the system is working!',
        'data': {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        }
      };

      await Supabase.instance.client
          .from('chat_notifications')
          .insert(testNotification);

      // Try to trigger Edge Function to process notifications
      final edgeResponse = await Supabase.instance.client.functions.invoke(
        'notify-chat',
        body: {'action': 'process_queue'},
      );

      // Show local notification as fallback
      await NotificationService.showLocalNotification(
        title: '🧪 Test Notification',
        body:
            'Local notification test - if you see this, local notifications work!',
        payload: 'test_notification',
      );

      return {
        'success': true,
        'message': 'Test notification sent successfully',
        'details': {
          'notification_inserted': true,
          'edge_function_called': edgeResponse.status == 200,
          'local_notification_shown': true,
          'edge_response': edgeResponse.data,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Test notification failed',
        'details': e.toString()
      };
    }
  }

  /// Get detailed notification system status
  static Future<Map<String, dynamic>> getSystemStatus() async {
    final userId = AuthService.getCurrentUserId();

    try {
      // Get FCM token info
      final fcmTokens = userId != null
          ? await Supabase.instance.client
              .from('user_fcm_tokens')
              .select()
              .eq('user_id', userId)
          : [];

      // Get notification settings
      final settings = userId != null
          ? await Supabase.instance.client
              .from('user_notification_settings')
              .select()
              .eq('user_id', userId)
              .maybeSingle()
          : null;

      // Get recent notifications
      final recentNotifications = userId != null
          ? await Supabase.instance.client
              .from('chat_notifications')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(5)
          : [];

      // Get notification queue status
      final queueStatus = await Supabase.instance.client
          .from('notification_queue')
          .select('status')
          .order('created_at', ascending: false)
          .limit(10);

      return {
        'user_authenticated': userId != null,
        'user_id': userId,
        'fcm_tokens': {
          'count': fcmTokens.length,
          'tokens': fcmTokens,
        },
        'notification_settings': settings,
        'recent_notifications': {
          'count': recentNotifications.length,
          'notifications': recentNotifications,
        },
        'queue_status': {
          'recent_items': queueStatus.length,
          'status_breakdown': _getStatusBreakdown(queueStatus),
        },
        'permissions': await _getPermissionStatus(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'user_authenticated': userId != null,
      };
    }
  }

  static Map<String, int> _getStatusBreakdown(List<dynamic> queueItems) {
    final breakdown = <String, int>{};
    for (final item in queueItems) {
      final status = item['status'] ?? 'unknown';
      breakdown[status] = (breakdown[status] ?? 0) + 1;
    }
    return breakdown;
  }

  static Future<Map<String, bool>> _getPermissionStatus() async {
    try {
      // This would need to be implemented based on your notification service
      return {
        'notifications_enabled': true,
        'sound_enabled': true,
        'vibration_enabled': true,
      };
    } catch (e) {
      return {
        'error': true,
      };
    }
  }

  /// Display test results in a dialog
  static void showTestResults(
      BuildContext context, Map<String, dynamic> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              results['overall_success'] == true
                  ? Icons.check_circle
                  : Icons.error,
              color: results['overall_success'] == true
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('Push Notification Test'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                results['summary'] ?? 'Test completed',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...((results['tests'] as Map<String, dynamic>? ?? {}).entries.map(
                    (entry) => _buildTestResultTile(entry.key, entry.value),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildTestResultTile(
      String testName, Map<String, dynamic> result) {
    final success = result['success'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  testName.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  result['message'] ?? 'No message',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
