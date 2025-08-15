import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Test Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage.isEmpty ? 'Ready to test' : _statusMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _statusMessage.contains('✅')
                        ? Colors.green
                        : _statusMessage.contains('❌')
                            ? Colors.red
                            : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Test Buttons
          _buildTestButton(
            'Test Local Notification',
            Colors.blue,
            _testLocalNotification,
          ),
          const SizedBox(height: 16),

          _buildTestButton(
            'Test FCM Token',
            Colors.orange,
            _testFCMToken,
          ),
          const SizedBox(height: 16),

          _buildTestButton(
            'Save FCM Token',
            Colors.green,
            _saveFCMToken,
          ),
          const SizedBox(height: 16),

          _buildTestButton(
            'Test Complete System',
            Colors.purple,
            _testNotificationService,
          ),
          const SizedBox(height: 16),

          _buildTestButton(
            'Test Push Notification',
            Colors.teal,
            _testPushNotificationSimulation,
          ),
          const SizedBox(height: 16),

          _buildTestButton(
            'Test Different Types',
            Colors.indigo,
            _testDifferentNotificationTypes,
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
    );
  }

  Future<void> _testLocalNotification() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing local notification...';
    });

    try {
      await NotificationService.showLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification!',
        payload: '{"type": "test"}',
      );
      setState(() => _statusMessage = '✅ Local notification sent!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testFCMToken() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting FCM token...';
    });

    try {
      final token = await NotificationService.getDeviceToken();
      setState(() => _statusMessage = token != null
          ? '✅ FCM Token: ${token.substring(0, 20)}...'
          : '❌ No FCM token available');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFCMToken() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving FCM token...';
    });

    try {
      final token = await NotificationService.getDeviceToken();
      if (token == null) {
        setState(() => _statusMessage = '❌ No token to save');
        return;
      }

      await NotificationService.saveFCMTokenToSupabase(token);
      setState(() => _statusMessage = '✅ Token saved to database!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotificationService() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing complete system...';
    });

    try {
      final token = await NotificationService.getDeviceToken();
      if (token == null) {
        setState(() => _statusMessage = '❌ FCM token not available');
        return;
      }

      await NotificationService.saveFCMTokenToSupabase(token);
      await NotificationService.showLocalNotification(
        title: 'System Test',
        body: 'Testing complete notification system',
        payload: '{"type": "system_test"}',
      );

      setState(() => _statusMessage = '✅ Complete system test passed!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPushNotificationSimulation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing push notifications...';
    });

    try {
      final notifications = [
        {
          'title': 'New Message',
          'body': 'You have a message from John',
          'payload': '{"type": "chat"}'
        },
        {
          'title': 'New Listing',
          'body': 'New book listed: Flutter Development',
          'payload': '{"type": "marketplace"}'
        },
        {
          'title': 'Event Update',
          'body': 'Study group meeting today',
          'payload': '{"type": "event"}'
        }
      ];

      for (var notification in notifications) {
        await NotificationService.showLocalNotification(
          title: notification['title']!,
          body: notification['body']!,
          payload: notification['payload']!,
        );
        await Future.delayed(const Duration(seconds: 2));
      }

      setState(() => _statusMessage = '✅ Push notifications simulated!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testDifferentNotificationTypes() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing different notification types...';
    });

    try {
      await NotificationService.showLocalNotification(
        title: '💬 Chat Message',
        body: 'New message from Sarah',
        payload: '{"type": "chat"}',
      );
      await Future.delayed(const Duration(seconds: 1));

      await NotificationService.showLocalNotification(
        title: '🛒 Marketplace',
        body: 'New item listed: \$100',
        payload: '{"type": "marketplace"}',
      );
      await Future.delayed(const Duration(seconds: 1));

      await NotificationService.showLocalNotification(
        title: '📅 Event',
        body: 'Study group meeting in 30 minutes',
        payload: '{"type": "event"}',
      );

      setState(() => _statusMessage = '✅ All notification types tested!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
