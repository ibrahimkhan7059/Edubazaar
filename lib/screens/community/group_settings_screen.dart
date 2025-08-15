import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/study_group.dart';
import '../../services/community_service.dart';
import '../../services/image_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';

class GroupSettingsScreen extends StatefulWidget {
  final StudyGroup group;

  const GroupSettingsScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _maxMembersController = TextEditingController();

  bool _isLoading = false;
  bool _isPrivate = false;
  List<String> _selectedTags = [];
  String? _newCoverImageUrl;
  String? _error;

  // Available tags for selection
  final List<String> _availableTags = [
    'Physics',
    'Chemistry',
    'Biology',
    'Mathematics',
    'Computer Science',
    'Engineering',
    'Medicine',
    'Business',
    'Economics',
    'Literature',
    'History',
    'Geography',
    'Psychology',
    'Sociology',
    'Philosophy',
    'Art',
    'Music',
    'Sports',
    'Technology',
    'Research'
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _nameController.text = widget.group.name;
    _descriptionController.text = widget.group.description ?? '';
    _subjectController.text = widget.group.subject ?? '';
    _maxMembersController.text = widget.group.maxMembers?.toString() ?? '50';
    _isPrivate = widget.group.isPrivate ?? false;
    _selectedTags = List<String>.from(widget.group.tags ?? []);

    // Debug information
    print('🔍 Group Settings - Initializing form');
    print('🔍 Group name: ${widget.group.name}');
    print('🔍 Group tags: ${widget.group.tags}');
    print('🔍 Selected tags: $_selectedTags');
    print('🔍 Available tags count: ${_availableTags.length}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isLoading = true;
        });

        final imageUrl =
            await ImageService.uploadGroupCoverImage(File(image.path));

        setState(() {
          _newCoverImageUrl = imageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error uploading image: $e';
      });
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        if (_selectedTags.length < 5) {
          // Limit to 5 tags
          _selectedTags.add(tag);
        }
      }
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final updatedGroup = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subject': _subjectController.text.trim(),
        'max_members': int.tryParse(_maxMembersController.text) ?? 50,
        'is_private': _isPrivate,
        'tags': _selectedTags,
        if (_newCoverImageUrl != null) 'cover_image_url': _newCoverImageUrl,
      };

      await CommunityService.updateStudyGroup(widget.group.id, updatedGroup);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group settings updated successfully!')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _error = 'Error updating group: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteGroup() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🗑️ [GROUP] Starting to delete group: ${widget.group.id}');
      final success = await CommunityService.deleteStudyGroup(widget.group.id);

      if (!mounted) return;

      if (success) {
        print('✅ [GROUP] Group deleted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop twice to go back to groups list
        Navigator.of(context).pop(); // Pop settings screen
        Navigator.of(context).pop(); // Pop group detail screen
      } else {
        print('❌ [GROUP] Failed to delete group');
        setState(() {
          _error = 'Failed to delete group. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [GROUP] Error deleting group: $e');
      if (!mounted) return;

      setState(() {
        _error = 'Error deleting group: $e';
        _isLoading = false;
      });
    }
  }

  void _showDeleteConfirmation() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete Group',
          style: TextStyle(color: Colors.red[700]),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this group? This action cannot be undone.',
            ),
            const SizedBox(height: 12),
            Text(
              'All group data, including posts and messages, will be permanently deleted.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteGroup();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Group Settings',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        systemOverlayStyle: AppTheme.systemUiOverlayStyle,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image Section
                    _buildCoverImageSection(),

                    const SizedBox(height: 24),

                    // Basic Information
                    _buildBasicInformationSection(),

                    const SizedBox(height: 24),

                    // Privacy Settings
                    _buildPrivacySection(),

                    const SizedBox(height: 24),

                    // Tags Section
                    _buildTagsSection(),

                    const SizedBox(height: 32),

                    // Delete Group Button
                    _buildDeleteButton(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCoverImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Image',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _newCoverImageUrl != null ||
                    widget.group.coverImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _newCoverImageUrl ?? widget.group.coverImageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 64),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Tap to add cover image',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Group Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Group name is required';
            }
            if (value.trim().length < 3) {
              return 'Group name must be at least 3 characters';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),

        const SizedBox(height: 16),

        // Subject
        TextFormField(
          controller: _subjectController,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 16),

        // Max Members
        TextFormField(
          controller: _maxMembersController,
          decoration: const InputDecoration(
            labelText: 'Maximum Members',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            final number = int.tryParse(value ?? '');
            if (number == null || number < 2 || number > 1000) {
              return 'Please enter a valid number between 2 and 1000';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Private Group'),
          subtitle: const Text('Only invited members can join'),
          value: _isPrivate,
          onChanged: (value) {
            setState(() {
              _isPrivate = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (${_selectedTags.length}/5)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select up to 5 tags to help others find your group',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Debug info
        if (_selectedTags.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              'Selected tags: ${_selectedTags.join(', ')}',
              style: TextStyle(color: Colors.blue[700], fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (_) => _toggleTag(tag),
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danger Zone',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Once you delete a group, there is no going back. Please be certain.',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showDeleteConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete Group',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red[900]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
