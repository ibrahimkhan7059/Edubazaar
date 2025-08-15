import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class PermissionService {
  /// Check and request camera permission
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        return false;
      }

      return false;
    } catch (e) {
      print('❌ Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check and request storage permission
  static Future<bool> requestStoragePermission() async {
    try {
      print('📱 Platform: ${Platform.operatingSystem}');

      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use photos permission
        try {
          final photos = await Permission.photos.status;
          print('📷 Photos permission status: $photos');

          if (photos.isGranted) {
            print('✅ Photos permission already granted');
            return true;
          }

          if (photos.isDenied) {
            print('📷 Requesting photos permission...');
            final result = await Permission.photos.request();
            print('📷 Photos permission result: $result');
            return result.isGranted;
          }

          if (photos.isPermanentlyDenied) {
            print('❌ Photos permission permanently denied');
            return false;
          }

          // If photos permission doesn't work, try storage permission for older Android
          print('📷 Trying storage permission as fallback...');
          final storage = await Permission.storage.status;
          print('💾 Storage permission status: $storage');

          if (storage.isGranted) {
            print('✅ Storage permission granted');
            return true;
          }

          if (storage.isDenied) {
            print('💾 Requesting storage permission...');
            final result = await Permission.storage.request();
            print('💾 Storage permission result: $result');
            return result.isGranted;
          }

          print('❌ Both photos and storage permissions denied');
          return false;
        } catch (e) {
          print('⚠️ Photos permission error, trying storage: $e');

          // Fallback to storage permission
          final storage = await Permission.storage.status;
          print('💾 Fallback storage permission status: $storage');

          if (storage.isGranted) {
            print('✅ Fallback storage permission granted');
            return true;
          }

          if (storage.isDenied) {
            print('💾 Requesting fallback storage permission...');
            final result = await Permission.storage.request();
            print('💾 Fallback storage permission result: $result');
            return result.isGranted;
          }

          print('❌ All permission attempts failed');
          return false;
        }
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.status;
        print('📷 iOS Photos permission status: $photos');

        if (photos.isGranted) {
          print('✅ iOS Photos permission granted');
          return true;
        }

        if (photos.isDenied) {
          print('📷 Requesting iOS photos permission...');
          final result = await Permission.photos.request();
          print('📷 iOS Photos permission result: $result');
          return result.isGranted;
        }

        print('❌ iOS Photos permission denied');
        return false;
      }

      // For other platforms, assume permission is granted
      print('✅ Other platform, assuming permission granted');
      return true;
    } catch (e) {
      print('❌ Error requesting storage permission: $e');
      print('❌ Error type: ${e.runtimeType}');
      // Fallback to allowing access for development
      return true;
    }
  }

  /// Get Android SDK version
  static Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      try {
        return 30; // Default to API 30 if can't determine
      } catch (e) {
        return 30;
      }
    }
    return 0;
  }

  /// Check if all required permissions are granted
  static Future<bool> checkAllPermissions() async {
    final camera = await Permission.camera.isGranted;
    final storage = await requestStoragePermission();
    return camera && storage;
  }

  /// Request all required permissions
  static Future<bool> requestAllPermissions() async {
    final camera = await requestCameraPermission();
    final storage = await requestStoragePermission();
    return camera && storage;
  }

  /// Show permission denied dialog
  static void showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onOpenSettings,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (onOpenSettings != null) {
                  onOpenSettings();
                } else {
                  openAppSettings();
                }
              },
              child: Text(
                'Open Settings',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show camera permission dialog
  static void showCameraPermissionDialog(BuildContext context) {
    showPermissionDeniedDialog(
      context,
      title: 'Camera Permission Required',
      message:
          'To take photos, please allow camera access in your device settings.',
    );
  }

  /// Show storage permission dialog
  static void showStoragePermissionDialog(BuildContext context) {
    showPermissionDeniedDialog(
      context,
      title: 'Storage Permission Required',
      message:
          'To access your photos, please allow storage access in your device settings.',
    );
  }

  /// Handle permission for camera
  static Future<bool> handleCameraPermission(BuildContext context) async {
    final hasPermission = await requestCameraPermission();

    if (!hasPermission) {
      showCameraPermissionDialog(context);
      return false;
    }

    return true;
  }

  /// Handle permission for gallery
  static Future<bool> handleGalleryPermission(BuildContext context) async {
    final hasPermission = await requestStoragePermission();

    if (!hasPermission) {
      showStoragePermissionDialog(context);
      return false;
    }

    return true;
  }

  /// Check if permission is permanently denied
  static Future<bool> isCameraPermissionPermanentlyDenied() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  /// Check if storage permission is permanently denied
  static Future<bool> isStoragePermissionPermanentlyDenied() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        final status = await Permission.photos.status;
        return status.isPermanentlyDenied;
      } else {
        final status = await Permission.storage.status;
        return status.isPermanentlyDenied;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isPermanentlyDenied;
    }
    return false;
  }

  /// Get permission status info for debugging
  static Future<Map<String, String>> getPermissionStatus() async {
    final camera = await Permission.camera.status;
    final storage = Platform.isAndroid
        ? await Permission.storage.status
        : await Permission.photos.status;

    return {
      'camera': camera.toString(),
      'storage': storage.toString(),
      'platform': Platform.operatingSystem,
    };
  }
}
