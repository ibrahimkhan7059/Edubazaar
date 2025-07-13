import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile userProfile;

  const EditProfileScreen({super.key, required this.userProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late TextEditingController _nameController;
  late TextEditingController _universityController;
  late TextEditingController _courseController;
  late TextEditingController _semesterController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  File? _profilePicture;
  File? _coverPhoto;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile.name);
    _universityController =
        TextEditingController(text: widget.userProfile.university);
    _courseController = TextEditingController(text: widget.userProfile.course);
    _semesterController =
        TextEditingController(text: widget.userProfile.semester);
    _bioController = TextEditingController(text: widget.userProfile.bio);
    _phoneController =
        TextEditingController(text: widget.userProfile.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _courseController.dispose();
    _semesterController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isProfilePic) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: isProfilePic ? 500 : 1000,
        maxHeight: isProfilePic ? 500 : 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (isProfilePic) {
            _profilePicture = File(pickedFile.path);
          } else {
            _coverPhoto = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? profilePicUrl = widget.userProfile.profilePicUrl;
      String? coverPhotoUrl = widget.userProfile.coverPhotoUrl;

      // Upload new profile picture if selected
      if (_profilePicture != null) {
        profilePicUrl =
            await ProfileService.uploadProfilePicture(_profilePicture!);
      }

      // Upload new cover photo if selected
      if (_coverPhoto != null) {
        coverPhotoUrl = await ProfileService.uploadCoverPhoto(_coverPhoto!);
      }

      // Update profile
      final updatedProfile = widget.userProfile.copyWith(
        name: _nameController.text,
        university: _universityController.text.isNotEmpty
            ? _universityController.text
            : null,
        course:
            _courseController.text.isNotEmpty ? _courseController.text : null,
        semester: _semesterController.text.isNotEmpty
            ? _semesterController.text
            : null,
        bio: _bioController.text.isNotEmpty ? _bioController.text : null,
        phoneNumber:
            _phoneController.text.isNotEmpty ? _phoneController.text : null,
        profilePicUrl: profilePicUrl,
        coverPhotoUrl: coverPhotoUrl,
      );

      await ProfileService.updateProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating profile: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showImagePickerModal(bool isProfilePic) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, isProfilePic);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(
                  'Take a Photo',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, isProfilePic);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Cover Photo
              GestureDetector(
                onTap: () => _showImagePickerModal(false),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    image: _coverPhoto != null
                        ? DecorationImage(
                            image: FileImage(_coverPhoto!),
                            fit: BoxFit.cover,
                          )
                        : widget.userProfile.coverPhotoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(
                                    widget.userProfile.coverPhotoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.camera_alt,
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      size: 40,
                    ),
                  ),
                ),
              ),

              // Profile Picture
              Transform.translate(
                offset: const Offset(0, -40),
                child: GestureDetector(
                  onTap: () => _showImagePickerModal(true),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      image: _profilePicture != null
                          ? DecorationImage(
                              image: FileImage(_profilePicture!),
                              fit: BoxFit.cover,
                            )
                          : widget.userProfile.profilePicUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                      widget.userProfile.profilePicUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: (_profilePicture == null &&
                            widget.userProfile.profilePicUrl == null)
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),

              // Form Fields
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _universityController,
                      label: 'University',
                      icon: Icons.school,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _courseController,
                      label: 'Course',
                      icon: Icons.book,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _semesterController,
                      label: 'Semester',
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      icon: Icons.info,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.errorColor,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.errorColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
