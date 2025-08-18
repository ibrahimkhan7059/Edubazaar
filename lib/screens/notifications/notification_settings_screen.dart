import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
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
  bool _isSaving = false;

  // Notification settings
  bool _pushNotifications = true;
  bool _localNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Type-specific settings
  bool _chatNotifications = true;
  bool _marketplaceNotifications = true;
  bool _communityNotifications = true;
  bool _emailNotifications = false;

  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);

      final userId = AuthService.getCurrentUserId();
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      try {
        final response = await Supabase.instance.client
            .from('user_notification_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null && mounted) {
          setState(() {
            _pushNotifications = response['push_notifications'] ?? true;
            _localNotifications = response['local_notifications'] ?? true;
            _soundEnabled = response['sound_enabled'] ?? true;
            _vibrationEnabled = response['vibration_enabled'] ?? true;
            _chatNotifications = response['chat_notifications'] ?? true;
            _marketplaceNotifications =
                response['marketplace_notifications'] ?? true;
            _communityNotifications =
                response['community_notifications'] ?? true;
            _emailNotifications = response['email_notifications'] ?? false;
            _quietHoursEnabled = response['quiet_hours_enabled'] ?? false;

            // Parse quiet hours if available
            if (response['quiet_hours_start'] != null) {
              final startTime = response['quiet_hours_start'] as String;
              final startParts = startTime.split(':');
              _quietHoursStart = TimeOfDay(
                hour: int.parse(startParts[0]),
                minute: int.parse(startParts[1]),
              );
            }

            if (response['quiet_hours_end'] != null) {
              final endTime = response['quiet_hours_end'] as String;
              final endParts = endTime.split(':');
              _quietHoursEnd = TimeOfDay(
                hour: int.parse(endParts[0]),
                minute: int.parse(endParts[1]),
              );
            }
          });
        }
      } catch (e) {
        print('Error loading notification settings: $e');
        // Continue with default values if database error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Using default settings. Database may need setup.'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _loadSettings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _isSaving = true);

      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      // Save all settings at once (after running the SQL fix)
      final settings = {
        'user_id': userId,
        'push_notifications': _pushNotifications,
        'local_notifications': _localNotifications,
        'sound_enabled': _soundEnabled,
        'vibration_enabled': _vibrationEnabled,
        'chat_notifications': _chatNotifications,
        'marketplace_notifications': _marketplaceNotifications,
        'community_notifications': _communityNotifications,
        'email_notifications': _emailNotifications,
        'quiet_hours_enabled': _quietHoursEnabled,
        'quiet_hours_start':
            '${_quietHoursStart.hour.toString().padLeft(2, '0')}:${_quietHoursStart.minute.toString().padLeft(2, '0')}',
        'quiet_hours_end':
            '${_quietHoursEnd.hour.toString().padLeft(2, '0')}:${_quietHoursEnd.minute.toString().padLeft(2, '0')}',
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client
            .from('user_notification_settings')
            .upsert(settings);

        print('✅ All notification settings saved successfully!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('All settings saved successfully!'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        print('❌ Error saving notification settings: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to save settings. Please run the SQL fix first.'),
              backgroundColor: AppTheme.errorColor,
              action: SnackBarAction(
                label: 'Info',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Run COMPLETE_NOTIFICATION_SETTINGS_FIX.sql in Supabase'),
                      backgroundColor: AppTheme.infoColor,
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _saveSettings: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // Add padding to separate status bar and app bar
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            // Custom App Bar with separation
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppTheme.textPrimary,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    Icon(
                      Icons.tune,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notification Settings',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionCard(
                          'General Settings',
                          Icons.settings,
                          [
                            _buildSwitchTile(
                              'Push Notifications',
                              'Receive notifications on this device',
                              Icons.notifications_active,
                              _pushNotifications,
                              (value) =>
                                  setState(() => _pushNotifications = value),
                            ),
                            _buildSwitchTile(
                              'Local Notifications',
                              'Show notifications within the app',
                              Icons.notifications,
                              _localNotifications,
                              (value) =>
                                  setState(() => _localNotifications = value),
                            ),
                            _buildSwitchTile(
                              'Sound',
                              'Play sound for notifications',
                              Icons.volume_up,
                              _soundEnabled,
                              (value) => setState(() => _soundEnabled = value),
                            ),
                            _buildSwitchTile(
                              'Vibration',
                              'Vibrate for notifications',
                              Icons.vibration,
                              _vibrationEnabled,
                              (value) =>
                                  setState(() => _vibrationEnabled = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          'Notification Types',
                          Icons.category,
                          [
                            _buildSwitchTile(
                              'Chat Messages',
                              'New messages from other users',
                              Icons.chat_bubble,
                              _chatNotifications,
                              (value) =>
                                  setState(() => _chatNotifications = value),
                            ),
                            _buildSwitchTile(
                              'Marketplace',
                              'Updates about your listings',
                              Icons.store,
                              _marketplaceNotifications,
                              (value) => setState(
                                  () => _marketplaceNotifications = value),
                            ),
                            _buildSwitchTile(
                              'Community',
                              'Study groups and forum activity',
                              Icons.groups,
                              _communityNotifications,
                              (value) => setState(
                                  () => _communityNotifications = value),
                            ),
                            _buildSwitchTile(
                              'Email Notifications',
                              'Receive notifications via email',
                              Icons.email,
                              _emailNotifications,
                              (value) =>
                                  setState(() => _emailNotifications = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          'Quiet Hours',
                          Icons.do_not_disturb_on,
                          [
                            _buildSwitchTile(
                              'Enable Quiet Hours',
                              'Silence notifications during set hours',
                              Icons.do_not_disturb,
                              _quietHoursEnabled,
                              (value) =>
                                  setState(() => _quietHoursEnabled = value),
                            ),
                            if (_quietHoursEnabled) ...[
                              const SizedBox(height: 8),
                              _buildTimeTile(
                                'Start Time',
                                'When to start quiet hours',
                                Icons.bedtime,
                                _quietHoursStart,
                                (time) =>
                                    setState(() => _quietHoursStart = time),
                              ),
                              _buildTimeTile(
                                'End Time',
                                'When to end quiet hours',
                                Icons.wb_sunny,
                                _quietHoursEnd,
                                (time) => setState(() => _quietHoursEnd = time),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label:
                                Text(_isSaving ? 'Saving...' : 'Save Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: value ? AppTheme.primaryColor : Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTile(
    String title,
    String subtitle,
    IconData icon,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final newTime = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (newTime != null) {
              onChanged(newTime);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time.format(context),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
