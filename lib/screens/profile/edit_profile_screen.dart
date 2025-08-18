import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile userProfile;

  const EditProfileScreen({super.key, required this.userProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _universityController;
  late TextEditingController _courseController;
  late TextEditingController _semesterController;

  // State variables
  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _selectedProfileImage;
  bool _imageRemoved = false; // Track if user explicitly removed image

  List<String> _interests = [];
  final List<String> _availableInterests = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Engineering',
    'Medicine',
    'Business',
    'Economics',
    'Psychology',
    'History',
    'Literature',
    'Arts',
    'Music',
    'Sports',
    'Programming',
    'Design',
    'Photography',
    'Writing',
    'Reading',
    'Gaming',
    'Cooking',
    'Travel',
    'Fitness',
    'Languages',
    'Movies',
    'Technology',
    'Science'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.userProfile.name);
    _bioController = TextEditingController(text: widget.userProfile.bio ?? '');
    _phoneController =
        TextEditingController(text: widget.userProfile.phoneNumber ?? '');
    _universityController =
        TextEditingController(text: widget.userProfile.university ?? '');
    _courseController =
        TextEditingController(text: widget.userProfile.course ?? '');
    _semesterController =
        TextEditingController(text: widget.userProfile.semester ?? '');
    _interests = List.from(widget.userProfile.interests ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _universityController.dispose();
    _courseController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
                if (_selectedProfileImage != null ||
                    widget.userProfile.profilePicUrl?.isNotEmpty == true)
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Remove Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _removeImage();
                    },
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedProfileImage = File(image.path);
          _imageRemoved = false; // Reset removal flag when new image selected
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedProfileImage = null;
      _imageRemoved = true; // Mark that user explicitly removed image
    });
  }

  ImageProvider? _getProfileImageProvider() {
    if (_selectedProfileImage != null) {
      return FileImage(_selectedProfileImage!);
    }
    if (widget.userProfile.profilePicUrl?.isNotEmpty == true) {
      if (widget.userProfile.profilePicUrl!.startsWith('/')) {
        final file = File(widget.userProfile.profilePicUrl!);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } else if (widget.userProfile.profilePicUrl!.startsWith('http')) {
        return NetworkImage(widget.userProfile.profilePicUrl!);
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) throw Exception('User not logged in');

      // Handle profile image upload
      String? profileImageUrl =
          widget.userProfile.profilePicUrl; // Preserve existing URL

      if (_selectedProfileImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        // Upload new image and get new URL
        profileImageUrl = await ProfileService.uploadProfilePicture(
            userId, _selectedProfileImage!);
        // New image uploaded successfully
      } else {
        // No new image, preserving existing
      }

      // Prepare update data
      final updateData = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        'phone_number': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'university': _universityController.text.trim().isNotEmpty
            ? _universityController.text.trim()
            : null,
        'course': _courseController.text.trim().isNotEmpty
            ? _courseController.text.trim()
            : null,
        'semester': _semesterController.text.trim().isNotEmpty
            ? _semesterController.text.trim()
            : null,
        'interests': _interests,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Handle profile image URL properly
      if (_imageRemoved) {
        // User explicitly removed the image - delete it from storage
        await ProfileService.deleteProfilePicture(userId);
        updateData['profile_pic_url'] = null;
        // Image removed by user and deleted from storage
      } else {
        // Preserve existing image URL or use new uploaded image URL
        updateData['profile_pic_url'] = profileImageUrl;
      }

      // Update profile in database
      await _supabase.from('user_profiles').update(updateData).eq('id', userId);

      // Update auth user metadata
      await AuthService.updateProfile(
        fullName: _nameController.text.trim(),
        avatarUrl: profileImageUrl,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate successful update
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Images Section
              _buildImageSection(),

              const SizedBox(height: 24),

              // Basic Information
              _buildBasicInfoSection(),

              const SizedBox(height: 24),

              // Contact Information
              _buildContactSection(),

              const SizedBox(height: 24),

              // Academic Information
              _buildAcademicSection(),

              const SizedBox(height: 24),

              // Interests Section
              _buildInterestsSection(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Picture',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Profile Picture
          Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primaryColor,
                        backgroundImage: _getProfileImageProvider(),
                        child: _getProfileImageProvider() == null
                            ? Text(
                                widget.userProfile.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _isUploadingImage
                              ? const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Profile Picture',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to change your profile picture',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Name Field
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Bio Field
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Bio',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
              hintText: 'Tell others about yourself...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Email Field (Read-only)
          TextFormField(
            initialValue: widget.userProfile.email,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.lock, color: Colors.grey),
            ),
            readOnly: true,
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),

          // Phone Field
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              hintText: '+92 300 1234567',
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[\+]?[0-9\s\-\(\)]+$').hasMatch(value)) {
                  return 'Enter a valid phone number';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // University Field
          TextFormField(
            controller: _universityController,
            decoration: const InputDecoration(
              labelText: 'University',
              prefixIcon: Icon(Icons.school),
              border: OutlineInputBorder(),
              hintText: 'e.g., University of Punjab',
            ),
          ),

          const SizedBox(height: 16),

          // Course Field
          TextFormField(
            controller: _courseController,
            decoration: const InputDecoration(
              labelText: 'Course/Program',
              prefixIcon: Icon(Icons.book),
              border: OutlineInputBorder(),
              hintText: 'e.g., Computer Science',
            ),
          ),

          const SizedBox(height: 16),

          // Semester Field
          TextFormField(
            controller: _semesterController,
            decoration: const InputDecoration(
              labelText: 'Semester/Year',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
              hintText: 'e.g., 5th Semester',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interests',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select topics you\'re interested in to connect with like-minded students',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),

          // Selected Interests
          if (_interests.isNotEmpty) ...[
            Text(
              'Selected (${_interests.length})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests.map((interest) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        interest,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _interests.remove(interest);
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Available Interests
          Text(
            'Available Interests',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests
                .where((interest) => !_interests.contains(interest))
                .map((interest) {
              return GestureDetector(
                onTap: () {
                  if (_interests.length < 10) {
                    setState(() {
                      _interests.add(interest);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Maximum 10 interests allowed')),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        interest,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.add,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
