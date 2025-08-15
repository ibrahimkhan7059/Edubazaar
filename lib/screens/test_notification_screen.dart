import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../services/notification_service.dart';

class TestNotificationScreen extends StatefulWidget {
  const TestNotificationScreen({super.key});

  @override
  State<TestNotificationScreen> createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Test Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Status',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage.isEmpty
                          ? 'Ready to test notifications'
                          : _statusMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _statusMessage.contains('✅')
                            ? Colors.green
                            : _statusMessage.contains('❌')
                                ? Colors.red
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Test Local Notification Button
            ElevatedButton(
              onPressed: _isLoading ? null : _testLocalNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Test Local Notification',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Test FCM Token Button
            ElevatedButton(
              onPressed: _isLoading ? null : _testFCMToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Test FCM Token',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Save FCM Token Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveFCMToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Save FCM Token to Supabase',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Check Database Access Button
            ElevatedButton(
              onPressed: _isLoading ? null : _checkDatabaseAccess,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Check Database Access',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Test Chat Notification Button
            ElevatedButton(
              onPressed: _isLoading ? null : _testChatNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Test Chat Notification',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Instructions Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Testing Instructions:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Test Local Notification: Shows a local notification\n'
                      '2. Test FCM Token: Gets and displays FCM token\n'
                      '3. Save FCM Token: Saves token to Supabase\n'
                      '4. Check console logs for detailed information',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        body: 'This is a test notification from EduBazaar!',
        payload: json.encode({'type': 'test', 'message': 'Test notification'}),
      );
      setState(() {
        _statusMessage = '✅ Local notification sent successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error sending local notification: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFCMToken() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting FCM token...';
    });

    try {
      final token = await NotificationService.getDeviceToken();
      if (token != null) {
        setState(() {
          _statusMessage = '✅ FCM Token: ${token.substring(0, 30)}...';
        });
        print('🔑 Full FCM Token: $token');
      } else {
        setState(() {
          _statusMessage = '❌ Failed to get FCM token';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error getting FCM token: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFCMToken() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving FCM token to Supabase...';
    });

    try {
      final token = await NotificationService.getDeviceToken();
      if (token != null) {
        await NotificationService.saveFCMTokenToSupabase(token);
        setState(() {
          _statusMessage = '✅ FCM token saved to Supabase successfully!';
        });
      } else {
        setState(() {
          _statusMessage = '❌ No FCM token available to save';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error saving FCM token: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkDatabaseAccess() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking database access...';
    });

    try {
      final response = await Supabase.instance.client
          .from('chat_notifications')
          .select()
          .limit(1);

      setState(() {
        _statusMessage = '✅ Database access successful!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error checking database access: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testChatNotification() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing chat notification system...';
    });

    try {
      // This will test the complete notification flow
      // First check if we can access the database
      final response = await Supabase.instance.client
          .from('chat_notifications')
          .select()
          .limit(1);
      if (response == null) {
        setState(() {
          _statusMessage = '❌ Database not accessible. Fix database first.';
        });
        return;
      }

      // Check if FCM token is available
      final token = await NotificationService.getDeviceToken();
      if (token == null) {
        setState(() {
          _statusMessage = '❌ No FCM token available. Check FCM setup.';
        });
        return;
      }

      // Check if token is saved in Supabase
      setState(() {
        _statusMessage = '🔄 Verifying FCM token in database...';
      });

      await NotificationService.saveFCMTokenToSupabase(token);

      setState(() {
        _statusMessage =
            '✅ Chat notification system ready! All components working.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Chat notification test failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
