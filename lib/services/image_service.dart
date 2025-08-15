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
      print('📱 Picking image from gallery...');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        print('✅ Image picked from gallery: ${image.path}');
        final file = File(image.path);
        final exists = await file.exists();
        print('📁 File exists: $exists, Size: ${await file.length()} bytes');
        return file;
      } else {
        print('⚠️ No image selected from gallery');
      }
      return null;
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      print('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Pick image from camera
  static Future<File?> pickImageFromCamera() async {
    try {
      print('📷 Taking photo with camera...');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        print('✅ Photo taken with camera: ${image.path}');
        final file = File(image.path);
        print('📁 File size: ${await file.length()} bytes');
        return file;
      }
      return null;
    } catch (e) {
      print('❌ Error taking photo with camera: $e');
      return null;
    }
  }

  // ============================================
  // IMAGE COMPRESSION
  // ============================================

  /// Compress image for chat upload
  static Future<File> compressImageForChat(File imageFile) async {
    try {
      print('📷 Compressing image for chat...');

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('📊 Original image size: ${imageBytes.length} bytes');

      // Decode image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        print('⚠️ Could not decode image, returning original');
        return imageFile;
      }

      print(
          '📐 Original dimensions: ${originalImage.width}x${originalImage.height}');

      // Resize if too large (max 1200px width/height)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 1200 || originalImage.height > 1200) {
        resizedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? 1200 : null,
          height: originalImage.height > originalImage.width ? 1200 : null,
        );
        print('📐 Resized to: ${resizedImage.width}x${resizedImage.height}');
      }

      // Encode as JPEG with quality 85
      final Uint8List compressedBytes =
          img.encodeJpg(resizedImage, quality: 85);
      print('📊 Compressed size: ${compressedBytes.length} bytes');

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      print('✅ Image compressed and saved to: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      print('❌ Error compressing image: $e');
      // Return original file if compression fails
      return imageFile;
    }
  }

  /// Compress image for group cover
  static Future<File> compressImageForGroupCover(File imageFile) async {
    try {
      print('📷 Compressing image for group cover...');

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('📊 Original image size: ${imageBytes.length} bytes');

      // Decode image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        print('⚠️ Could not decode image, returning original');
        return imageFile;
      }

      print(
          '📐 Original dimensions: ${originalImage.width}x${originalImage.height}');

      // Resize if too large (max 800px width/height for group covers)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 800 || originalImage.height > 800) {
        resizedImage = img.copyResize(originalImage, width: 800, height: 800);
        print('📐 Resized to: ${resizedImage.width}x${resizedImage.height}');
      }

      // Encode as JPEG with quality 80
      final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      print('📊 Compressed size: ${compressedBytes.length} bytes');

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/compressed_group_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      print('✅ Compressed image saved to: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      print('❌ Error compressing group cover image: $e');
      return imageFile; // Return original if compression fails
    }
  }

  // ============================================
  // SUPABASE UPLOAD
  // ============================================

  /// Upload chat image to Supabase Storage
  static Future<String> uploadChatImage(File imageFile) async {
    try {
      print('📤 Uploading chat image to Supabase Storage...');

      // Compress image for chat
      final compressedFile = await compressImageForChat(imageFile);
      final compressedBytes = await compressedFile.readAsBytes();
      print('📊 Compressed image size: ${compressedBytes.length} bytes');

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'chat_${timestamp}_${imageFile.path.split('/').last}';
      print('📝 Generated filename: $filename');

      // Upload to Supabase Storage
      final response = await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(filename, compressedBytes);

      print('✅ Upload response: $response');

      // Get public URL
      final publicUrl =
          _supabase.storage.from('chat-attachments').getPublicUrl(filename);

      print('🔗 Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading chat image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload group cover image to Supabase Storage
  static Future<String> uploadGroupCoverImage(File imageFile) async {
    try {
      print('📤 Uploading group cover image to Supabase Storage...');

      // Compress image for group cover
      final compressedFile = await compressImageForGroupCover(imageFile);
      final compressedBytes = await compressedFile.readAsBytes();
      print('📊 Compressed image size: ${compressedBytes.length} bytes');

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename =
          'group_cover_${timestamp}_${imageFile.path.split('/').last}';
      print('📝 Generated filename: $filename');

      // Upload to Supabase Storage using chat-attachments bucket (which definitely exists)
      final response = await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(filename, compressedBytes);

      print('✅ Upload response: $response');

      // Get public URL
      final publicUrl =
          _supabase.storage.from('chat-attachments').getPublicUrl(filename);

      print('🔗 Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading group cover image: $e');
      throw Exception('Failed to upload group cover image: $e');
    }
  }

  /// List available storage buckets (for debugging)
  static Future<List<String>> listAvailableBuckets() async {
    try {
      print('🔍 Listing available storage buckets...');
      final response = await _supabase.storage.listBuckets();
      final bucketNames = response.map((bucket) => bucket.id).toList();
      print('✅ Available buckets: $bucketNames');
      return bucketNames;
    } catch (e) {
      print('❌ Error listing buckets: $e');
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
                print('📱 Gallery option tapped');

                try {
                  // TEMPORARY: Skip permission check for testing
                  print(
                      '🧪 TEMPORARY: Skipping permission check for testing...');

                  final File? image = await pickImageFromGallery();
                  print('📸 Image picked: ${image?.path}');

                  // Return the image directly
                  Navigator.pop(context, image);
                } catch (e) {
                  print('❌ Error in gallery selection: $e');
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
                print(
                    '🧪 TEMPORARY: Skipping camera permission check for testing...');
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
      print('📤 Starting event image upload...');

      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No authenticated user for event image upload');
        return null;
      }

      // Convert XFile to File
      final file = File(imageFile.path);

      // Compress image
      final compressedFile = await compressImageForChat(file);
      print('🗜️ Event image compressed');

      // Read compressed file bytes
      final compressedBytes = await compressedFile.readAsBytes();
      print('📁 Compressed event image size: ${compressedBytes.length} bytes');

      // Generate unique filename
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      print('📝 Event image filename: $fileName');

      // Upload to chat-attachments bucket (reusing existing bucket)
      final uploadPath = await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(fileName, compressedBytes);

      print('✅ Event image uploaded to: $uploadPath');

      // Get public URL
      final publicUrl =
          _supabase.storage.from('chat-attachments').getPublicUrl(fileName);

      print('🌐 Event image public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading event image: $e');
      return null;
    }
  }
}
