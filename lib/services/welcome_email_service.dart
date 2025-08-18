import 'package:supabase_flutter/supabase_flutter.dart';

class WelcomeEmailService {
  static final _supabase = Supabase.instance.client;

  /// Send welcome email to user after successful login
  static Future<bool> sendWelcomeEmail({
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    try {
      // Call Supabase Edge Function to send welcome email
      final response = await _supabase.functions.invoke(
        'send-welcome-email',
        body: {
          'userId': userId,
          'userEmail': userEmail,
          'userName': userName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.status == 200) {
        return true;
      } else {
        // Log error but don't throw to avoid breaking login flow
        return false;
      }
    } catch (e) {
      // Log error but don't throw to avoid breaking login flow
      return false;
    }
  }

  /// Send welcome email for Google Sign-In users
  static Future<bool> sendGoogleWelcomeEmail({
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    try {
      // Call Supabase Edge Function to send Google welcome email
      final response = await _supabase.functions.invoke(
        'send-google-welcome-email',
        body: {
          'userId': userId,
          'userEmail': userEmail,
          'userName': userName,
          'loginMethod': 'Google',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.status == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if welcome email was already sent to user
  static Future<bool> hasWelcomeEmailBeenSent(String userId) async {
    try {
      final response = await _supabase
          .from('user_welcome_emails')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Mark welcome email as sent
  static Future<void> markWelcomeEmailSent(String userId) async {
    try {
      await _supabase.from('user_welcome_emails').insert({
        'user_id': userId,
        'sent_at': DateTime.now().toIso8601String(),
        'email_type': 'welcome',
      });
    } catch (e) {
      // Silently handle error
    }
  }
} 