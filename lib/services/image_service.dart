import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'permission_service.dart';
import '../core/theme.dart';

class ImageService {
  static final _supabase = Supabase.instance.client;
  static final ImagePicker _picker = ImagePicker();

  // ============================================
  // IMAGE PICKING
  // ============================================

  /// Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pick image from camera
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // IMAGE COMPRESSION
  // ============================================

  /// Compress image for chat upload
  static Future<File> compressImageForChat(File imageFile) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        return imageFile;
      }

      // Resize if too large (max 1200px width/height)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 1200 || originalImage.height > 1200) {
        resizedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? 1200 : null,
          height: originalImage.height > originalImage.width ? 1200 : null,
        );
      }

      // Encode as JPEG with quality 85
      final Uint8List compressedBytes =
          img.encodeJpg(resizedImage, quality: 85);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      // Return original file if compression fails
      return imageFile;
    }
  }

  /// Compress image for group cover
  static Future<File> compressImageForGroupCover(File imageFile) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        return imageFile;
      }

      // Resize if too large (max 800px width/height for group covers)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 800 || originalImage.height > 800) {
        resizedImage = img.copyResize(originalImage, width: 800, height: 800);
      }

      // Encode as JPEG with quality 80
      final compressedBytes = img.encodeJpg(resizedImage, quality: 80);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/compressed_group_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      return imageFile; // Return original if compression fails
    }
  }

  // ============================================
  // SUPABASE UPLOAD
  // ============================================

  /// Upload chat image to Supabase Storage
  static Future<String> uploadChatImage(File imageFile) async {
    try {
      // Compress image for chat
      final compressedFile = await compressImageForChat(imageFile);
      final compressedBytes = await compressedFile.readAsBytes();

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'chat_${timestamp}_${imageFile.path.split('/').last}';

      // Upload to Supabase Storage
      final response = await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(filename, compressedBytes);

      // Get public URL
      final publicUrl =
          _supabase.storage.from('chat-attachments').getPublicUrl(filename);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload group cover image to Supabase Storage
  static Future<String> uploadGroupCoverImage(File imageFile) async {
    try {
      // Compress image for group cover
      final compressedFile = await compressImageForGroupCover(imageFile);
      final compressedBytes = await compressedFile.readAsBytes();

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename =
          'group_cover_${timestamp}_${imageFile.path.split('/').last}';

      // Upload to Supabase Storage using chat-attachments bucket (which definitely exists)
      final response = await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(filename, compressedBytes);

      // Get public URL
      final publicUrl =
          _supabase.storage.from('chat-attachments').getPublicUrl(filename);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload group cover image: $e');
    }
  }

  /// List available storage buckets (for debugging)
  static Future<List<String>> listAvailableBuckets() async {
    try {
      final response = await _supabase.storage.listBuckets();
      final bucketNames = response.map((bucket) => bucket.id).toList();
      return bucketNames;
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // UI DIALOGS
  // ============================================

  /// Show image source dialog (Gallery/Camera)
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    return showModalBottomSheet<File?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Image Source',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                'Gallery',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Choose from your photos',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () async {
                try {
                  // TEMPORARY: Skip permission check for testing
                  final File? image = await pickImageFromGallery();

                  // Return the image directly
                  Navigator.pop(context, image);
                } catch (e) {
                  Navigator.pop(context, null);
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                'Camera',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Take a new photo',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () async {
                // TEMPORARY: Skip permission check for testing
                final File? image = await pickImageFromCamera();

                // Return the image directly
                Navigator.pop(context, image);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================
  // EVENT IMAGE UPLOAD
  // ============================================

  /// Upload event image to Supabase storage
  static Future<String?> uploadEventImage(XFile imageFile) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        return null;
      }

      // Convert XFile to File
      final file = File(imageFile.path);

      // Compress image
      final compressedFile = await compressImageForChat(file);

      // Read compressed file bytes
      final compressedBytes = await compressedFile.readAsBytes();

      // Generate unique filename
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Upload to chat-attachments bucket (reusing existing bucket)
      final uploadPath = await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(fileName, compressedBytes);

      // Get public URL
      final publicUrl =
          _supabase.storage.from('chat-attachments').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}
