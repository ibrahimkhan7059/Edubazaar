import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edubazaar/services/community_service.dart';
import 'package:edubazaar/services/image_service.dart';
import 'package:edubazaar/core/theme.dart';
import 'dart:io';

class CreateStudyGroupScreen extends StatefulWidget {
  const CreateStudyGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateStudyGroupScreen> createState() => _CreateStudyGroupScreenState();
}

class _CreateStudyGroupScreenState extends State<CreateStudyGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final CommunityService _communityService = CommunityService();
  final ImageService _imageService = ImageService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _maxMembersController = TextEditingController();

  String _selectedSubject = 'General';
  bool _isPrivate = false;
  List<String> _selectedTags = [];
  File? _coverImage;
  bool _isLoading = false;

  final List<String> _subjects = [
    'General',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Engineering',
    'Business',
    'Arts',
    'Literature',
    'History',
    'Geography',
    'Economics',
    'Psychology',
    'Medicine',
    'Law',
    'Other'
  ];

  final List<String> _availableTags = [
    'Study Group',
    'Homework Help',
    'Exam Prep',
    'Project Work',
    'Research',
    'Discussion',
    'Tutorial',
    'Lab Work',
    'Field Trip',
    'Online Study',
    'In-Person',
    'Beginner Friendly',
    'Advanced Level',
    'Collaborative',
    'Competitive',
    'Casual',
    'Structured',
    'Flexible Schedule',
    'Weekend Only',
    'Evening Sessions',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _coverImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImage = null;
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        if (_selectedTags.length < 5) {
          _selectedTags.add(tag);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 tags allowed')),
          );
        }
      }
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? coverImageUrl;

      // Upload cover image if selected
      if (_coverImage != null) {
        try {
          coverImageUrl =
              await ImageService.uploadGroupCoverImage(_coverImage!);
        } catch (e) {
          // Continue without cover image
        }
      }

      final groupData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subject': _selectedSubject,
        'is_private': _isPrivate,
        'max_members': int.tryParse(_maxMembersController.text) ?? 50,
        'tags': _selectedTags,
        'cover_image_url': coverImageUrl,
      };

      // Create the group
      final groupId = await CommunityService.createStudyGroup(groupData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Study group created successfully! ID: $groupId')),
        );

        // Navigate back to groups screen
        Navigator.pop(context, groupId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Study Group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image Section
                    _buildCoverImageSection(),
                    const SizedBox(height: 24),

                    // Basic Information
                    _buildBasicInformationSection(),
                    const SizedBox(height: 24),

                    // Group Settings
                    _buildGroupSettingsSection(),
                    const SizedBox(height: 24),

                    // Tags Section
                    _buildTagsSection(),
                    const SizedBox(height: 32),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _createGroup,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Create Study Group',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
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
          'Cover Image (Optional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_coverImage != null) ...[
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_coverImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: _removeCoverImage,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickCoverImage,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
                _coverImage == null ? 'Add Cover Image' : 'Change Cover Image'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
            labelText: 'Group Name *',
            hintText: 'Enter group name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Group name is required';
            }
            if (value.trim().length < 3) {
              return 'Group name must be at least 3 characters';
            }
            if (value.trim().length > 50) {
              return 'Group name must be less than 50 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText: 'Describe your study group',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Description is required';
            }
            if (value.trim().length < 10) {
              return 'Description must be at least 10 characters';
            }
            if (value.trim().length > 500) {
              return 'Description must be less than 500 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Subject
        DropdownButtonFormField<String>(
          value: _selectedSubject,
          decoration: const InputDecoration(
            labelText: 'Subject *',
            border: OutlineInputBorder(),
          ),
          items: _subjects.map((subject) {
            return DropdownMenuItem(
              value: subject,
              child: Text(subject),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubject = value!;
            });
          },
        ),
        const SizedBox(height: 16),

        // Max Members
        TextFormField(
          controller: _maxMembersController,
          decoration: const InputDecoration(
            labelText: 'Maximum Members',
            hintText: '50',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final number = int.tryParse(value);
              if (number == null || number < 2 || number > 1000) {
                return 'Must be between 2 and 1000';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGroupSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Privacy Setting
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

        const SizedBox(height: 16),

        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Group Guidelines',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• Keep discussions relevant to the subject\n'
                '• Be respectful to all members\n'
                '• No spam or inappropriate content\n'
                '• Help each other learn and grow',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_selectedTags.length}/5)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Select up to 5 tags to help others find your group',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(
                tag,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _toggleTag(tag),
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.grey[200],
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              elevation: isSelected ? 4 : 1,
              pressElevation: 2,
            );
          }).toList(),
        ),
        if (_selectedTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Selected Tags:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags.map((tag) {
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
                      tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _toggleTag(tag),
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
        ],
      ],
    );
  }
}
