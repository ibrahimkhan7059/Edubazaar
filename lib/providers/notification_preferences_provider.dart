import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class NotificationPreferences extends ChangeNotifier {
  // General settings
  bool _pushNotificationsEnabled = true;
  bool _localNotificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Notification types
  bool _chatNotificationsEnabled = true;
  bool _marketplaceNotificationsEnabled = true;
  bool _communityNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;

  // Quiet hours
  bool _quietHoursEnabled = false;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';

  // Getters
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get localNotificationsEnabled => _localNotificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get chatNotificationsEnabled => _chatNotificationsEnabled;
  bool get marketplaceNotificationsEnabled => _marketplaceNotificationsEnabled;
  bool get communityNotificationsEnabled => _communityNotificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get quietHoursEnabled => _quietHoursEnabled;
  String get quietHoursStart => _quietHoursStart;
  String get quietHoursEnd => _quietHoursEnd;

  // Initialize preferences
  Future<void> initialize() async {
    await _loadPreferences();
  }

  // Load preferences from Supabase
  Future<void> _loadPreferences() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('user_notification_settings')
          .select()
          .eq('user_id', userId)
          .single();

      if (response != null) {
        _pushNotificationsEnabled = response['push_notifications'] ?? true;
        _localNotificationsEnabled = response['local_notifications'] ?? true;
        _soundEnabled = response['sound_enabled'] ?? true;
        _vibrationEnabled = response['vibration_enabled'] ?? true;
        _chatNotificationsEnabled = response['chat_notifications'] ?? true;
        _marketplaceNotificationsEnabled = response['marketplace_notifications'] ?? true;
        _communityNotificationsEnabled = response['community_notifications'] ?? true;
        _emailNotificationsEnabled = response['email_notifications'] ?? false;
        _quietHoursEnabled = response['quiet_hours_enabled'] ?? false;
        _quietHoursStart = response['quiet_hours_start'] ?? '22:00';
        _quietHoursEnd = response['quiet_hours_end'] ?? '08:00';

        notifyListeners();
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
      // Use default values if loading fails
    }
  }

  // Save preferences to Supabase
  Future<void> _savePreferences() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      await Supabase.instance.client
          .from('user_notification_settings')
          .upsert({
        'user_id': userId,
        'push_notifications': _pushNotificationsEnabled,
        'local_notifications': _localNotificationsEnabled,
        'sound_enabled': _soundEnabled,
        'vibration_enabled': _vibrationEnabled,
        'chat_notifications': _chatNotificationsEnabled,
        'marketplace_notifications': _marketplaceNotificationsEnabled,
        'community_notifications': _communityNotificationsEnabled,
        'email_notifications': _emailNotificationsEnabled,
        'quiet_hours_enabled': _quietHoursEnabled,
        'quiet_hours_start': _quietHoursStart,
        'quiet_hours_end': _quietHoursEnd,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving notification preferences: $e');
      rethrow;
    }
  }

  // Update general settings
  Future<void> updateGeneralSettings({
    bool? pushNotifications,
    bool? localNotifications,
    bool? sound,
    bool? vibration,
  }) async {
    if (pushNotifications != null) _pushNotificationsEnabled = pushNotifications;
    if (localNotifications != null) _localNotificationsEnabled = localNotifications;
    if (sound != null) _soundEnabled = sound;
    if (vibration != null) _vibrationEnabled = vibration;

    // If push notifications are disabled, also disable local notifications
    if (_pushNotificationsEnabled == false) {
      _localNotificationsEnabled = false;
    }

    notifyListeners();
    await _savePreferences();
  }

  // Update notification type settings
  Future<void> updateNotificationTypes({
    bool? chat,
    bool? marketplace,
    bool? community,
    bool? email,
  }) async {
    if (chat != null) _chatNotificationsEnabled = chat;
    if (marketplace != null) _marketplaceNotificationsEnabled = marketplace;
    if (community != null) _communityNotificationsEnabled = community;
    if (email != null) _emailNotificationsEnabled = email;

    notifyListeners();
    await _savePreferences();
  }

  // Update quiet hours settings
  Future<void> updateQuietHours({
    bool? enabled,
    String? start,
    String? end,
  }) async {
    if (enabled != null) _quietHoursEnabled = enabled;
    if (start != null) _quietHoursStart = start;
    if (end != null) _quietHoursEnd = end;

    notifyListeners();
    await _savePreferences();
  }

  // Check if notifications should be shown based on quiet hours
  bool shouldShowNotification() {
    if (!_quietHoursEnabled) return true;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Parse quiet hours
    final startParts = _quietHoursStart.split(':');
    final endParts = _quietHoursEnd.split(':');
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);

    final startTime = startHour * 60 + startMinute;
    final endTime = endHour * 60 + endMinute;
    final currentTimeMinutes = now.hour * 60 + now.minute;

    // Handle overnight quiet hours (e.g., 22:00 to 08:00)
    if (startTime > endTime) {
      // Quiet hours span midnight
      return currentTimeMinutes < startTime && currentTimeMinutes > endTime;
    } else {
      // Quiet hours within same day
      return currentTimeMinutes < startTime || currentTimeMinutes > endTime;
    }
  }

  // Check if specific notification type should be shown
  bool shouldShowNotificationType(String type) {
    // First check if notifications are globally enabled
    if (!_pushNotificationsEnabled) return false;

    // Check quiet hours
    if (!shouldShowNotification()) return false;

    // Check specific type permissions
    switch (type) {
      case 'chat':
      case 'message':
        return _chatNotificationsEnabled;
      case 'listing':
      case 'transaction':
      case 'marketplace':
        return _marketplaceNotificationsEnabled;
      case 'event':
      case 'group':
      case 'forum':
      case 'community':
        return _communityNotificationsEnabled;
      case 'system':
        return true; // System notifications are always allowed
      default:
        return true;
    }
  }

  // Reset to default preferences
  Future<void> resetToDefaults() async {
    _pushNotificationsEnabled = true;
    _localNotificationsEnabled = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _chatNotificationsEnabled = true;
    _marketplaceNotificationsEnabled = true;
    _communityNotificationsEnabled = true;
    _emailNotificationsEnabled = false;
    _quietHoursEnabled = false;
    _quietHoursStart = '22:00';
    _quietHoursEnd = '08:00';

    notifyListeners();
    await _savePreferences();
  }

  // Get preferences summary
  Map<String, dynamic> getPreferencesSummary() {
    return {
      'push_enabled': _pushNotificationsEnabled,
      'local_enabled': _localNotificationsEnabled,
      'sound_enabled': _soundEnabled,
      'vibration_enabled': _vibrationEnabled,
      'chat_enabled': _chatNotificationsEnabled,
      'marketplace_enabled': _marketplaceNotificationsEnabled,
      'community_enabled': _communityNotificationsEnabled,
      'email_enabled': _emailNotificationsEnabled,
      'quiet_hours_enabled': _quietHoursEnabled,
      'quiet_hours': _quietHoursEnabled ? '$_quietHoursStart - $_quietHoursEnd' : 'Disabled',
    };
  }

  // Check if any notifications are enabled
  bool get hasAnyNotificationsEnabled {
    return _pushNotificationsEnabled && (
      _chatNotificationsEnabled ||
      _marketplaceNotificationsEnabled ||
      _communityNotificationsEnabled
    );
  }

  // Check if all notifications are disabled
  bool get areAllNotificationsDisabled {
    return !_pushNotificationsEnabled;
  }
} 