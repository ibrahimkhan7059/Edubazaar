import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // First check connectivity status
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Try to connect to a reliable host
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if Supabase is reachable
  static Future<bool> isSupabaseReachable() async {
    try {
      // Try to connect to your Supabase URL
      final response = await http.get(
        Uri.parse('https://jpsgjzprweboqnbjlfhh.supabase.co'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200 ||
          response.statusCode ==
              401; // 401 means auth required, but server is reachable
    } on SocketException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed network status
  static Future<Map<String, dynamic>> getDetailedNetworkStatus() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasInternet = await hasInternetConnection();
      final supabaseReachable = await isSupabaseReachable();

      return {
        'connectivity': connectivityResult.toString(),
        'hasInternet': hasInternet,
        'supabaseReachable': supabaseReachable,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'connectivity': 'unknown',
        'hasInternet': false,
        'supabaseReachable': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get network status message
  static Future<String> getNetworkStatusMessage() async {
    try {
      final status = await getDetailedNetworkStatus();

      if (status['connectivity'] == 'ConnectivityResult.none') {
        return '🌐 No network connection detected. Please check your WiFi or mobile data.';
      }

      if (!status['hasInternet']) {
        return '🌐 No internet connection. Please check your network settings.';
      }

      if (!status['supabaseReachable']) {
        return '🔌 Cannot connect to server. Please try again later.';
      }

      return '✅ Network connection is working.';
    } catch (e) {
      return '❓ Unable to determine network status.';
    }
  }

  /// Retry mechanism for network operations with exponential backoff
  static Future<T> retryOperation<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (attempts < maxRetries) {
      try {
        // Check network before attempting operation
        if (!await hasInternetConnection()) {
          throw Exception('No internet connection');
        }

        return await operation();
      } catch (e) {
        attempts++;
        // Attempt failed, retrying...

        if (attempts >= maxRetries) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);

        // Increase delay for next attempt (exponential backoff)
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            initialDelay.inMilliseconds,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    throw Exception('Operation failed after $maxRetries attempts');
  }

  /// Check if error is network-related
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('host') ||
        errorString.contains('network') ||
        errorString.contains('unreachable');
  }

  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (isNetworkError(error)) {
      return '🌐 Network Error: Please check your internet connection and try again.';
    }

    if (error.toString().contains('timeout')) {
      return '⏰ Request timed out. Please try again.';
    }

    if (error.toString().contains('unauthorized')) {
      return '🔐 Authentication required. Please sign in again.';
    }

    return '❌ An error occurred. Please try again.';
  }
}
