import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _pushNotificationsEnabled = true;
  bool _localNotificationsEnabled = true;
  bool _chatNotificationsEnabled = true;
  bool _marketplaceNotificationsEnabled = true;
  bool _communityNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';
  bool _quietHoursEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      // Load settings from Supabase
      final response = await Supabase.instance.client
          .from('user_notification_settings')
          .select()
          .eq('user_id', userId)
          .single();

      if (response != null) {
        setState(() {
          _pushNotificationsEnabled = response['push_notifications'] ?? true;
          _localNotificationsEnabled = response['local_notifications'] ?? true;
          _chatNotificationsEnabled = response['chat_notifications'] ?? true;
          _marketplaceNotificationsEnabled =
              response['marketplace_notifications'] ?? true;
          _communityNotificationsEnabled =
              response['community_notifications'] ?? true;
          _emailNotificationsEnabled = response['email_notifications'] ?? false;
          _soundEnabled = response['sound_enabled'] ?? true;
          _vibrationEnabled = response['vibration_enabled'] ?? true;
          _quietHoursStart = response['quiet_hours_start'] ?? '22:00';
          _quietHoursEnd = response['quiet_hours_end'] ?? '08:00';
          _quietHoursEnabled = response['quiet_hours_enabled'] ?? false;
        });
      }
    } catch (e) {
      // Error loading notification settings handled silently
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      await Supabase.instance.client.from('user_notification_settings').upsert({
        'user_id': userId,
        'push_notifications': _pushNotificationsEnabled,
        'local_notifications': _localNotificationsEnabled,
        'chat_notifications': _chatNotificationsEnabled,
        'marketplace_notifications': _marketplaceNotificationsEnabled,
        'community_notifications': _communityNotificationsEnabled,
        'email_notifications': _emailNotificationsEnabled,
        'sound_enabled': _soundEnabled,
        'vibration_enabled': _vibrationEnabled,
        'quiet_hours_start': _quietHoursStart,
        'quiet_hours_end': _quietHoursEnd,
        'quiet_hours_enabled': _quietHoursEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService.showLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification to verify your settings!',
        payload: '{"type": "test"}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveNotificationSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Settings Card
                  _buildSettingsCard(
                    title: 'General Settings',
                    children: [
                      _buildSwitchTile(
                        title: 'Push Notifications',
                        subtitle: 'Receive notifications from the app',
                        value: _pushNotificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _pushNotificationsEnabled = value;
                            if (!value) {
                              _localNotificationsEnabled = false;
                            }
                          });
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Local Notifications',
                        subtitle: 'Show notifications when app is open',
                        value: _localNotificationsEnabled,
                        onChanged: _pushNotificationsEnabled
                            ? (value) {
                                setState(() {
                                  _localNotificationsEnabled = value;
                                });
                              }
                            : null,
                      ),
                      _buildSwitchTile(
                        title: 'Sound',
                        subtitle: 'Play sound for notifications',
                        value: _soundEnabled,
                        onChanged: (value) {
                          setState(() {
                            _soundEnabled = value;
                          });
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Vibration',
                        subtitle: 'Vibrate device for notifications',
                        value: _vibrationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _vibrationEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Notification Types Card
                  _buildSettingsCard(
                    title: 'Notification Types',
                    children: [
                      _buildSwitchTile(
                        title: 'Chat Messages',
                        subtitle: 'New messages and conversation requests',
                        value: _chatNotificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _chatNotificationsEnabled = value;
                          });
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Marketplace',
                        subtitle: 'New listings, offers, and transactions',
                        value: _marketplaceNotificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _marketplaceNotificationsEnabled = value;
                          });
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Community',
                        subtitle: 'Group posts, events, and forum updates',
                        value: _communityNotificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _communityNotificationsEnabled = value;
                          });
                        },
                      ),
                      _buildSwitchTile(
                        title: 'Email Notifications',
                        subtitle: 'Receive notifications via email',
                        value: _emailNotificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _emailNotificationsEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quiet Hours Card
                  _buildSettingsCard(
                    title: 'Quiet Hours',
                    children: [
                      _buildSwitchTile(
                        title: 'Enable Quiet Hours',
                        subtitle: 'Mute notifications during specified hours',
                        value: _quietHoursEnabled,
                        onChanged: (value) {
                          setState(() {
                            _quietHoursEnabled = value;
                          });
                        },
                      ),
                      if (_quietHoursEnabled) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimePicker(
                                label: 'Start Time',
                                time: _quietHoursStart,
                                onTimeChanged: (time) {
                                  setState(() {
                                    _quietHoursStart = time;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTimePicker(
                                label: 'End Time',
                                time: _quietHoursEnd,
                                onTimeChanged: (time) {
                                  setState(() {
                                    _quietHoursEnd = time;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Test Notification Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon:
                          const Icon(Icons.notifications, color: Colors.white),
                      label: Text(
                        'Test Notification',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveNotificationSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        'Save Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required String time,
    required ValueChanged<String> onTimeChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: _parseTimeString(time),
            );
            if (picked != null) {
              onTimeChanged(
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                const Icon(Icons.access_time, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}
