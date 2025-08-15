import 'package:flutter/material.dart';
import 'package:edubazaar/services/community_service.dart';
import '../../core/theme.dart';

class CreateForumTopicScreen extends StatefulWidget {
  const CreateForumTopicScreen({Key? key}) : super(key: key);

  @override
  State<CreateForumTopicScreen> createState() => _CreateForumTopicScreenState();
}

class _CreateForumTopicScreenState extends State<CreateForumTopicScreen> {
  final _formKey = GlobalKey<FormState>();
  final CommunityService _communityService = CommunityService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedCategory = 'General Discussion';
  List<String> _selectedTags = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'General Discussion',
    'Academic Help',
    'Study Tips',
    'Career Advice',
    'Technology',
    'Science',
    'Literature',
    'History',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Engineering',
    'Business',
    'Arts',
    'Sports',
    'Entertainment',
    'News & Events',
    'Off Topic',
  ];

  final List<String> _availableTags = [
    'Question',
    'Discussion',
    'Help Needed',
    'Study Group',
    'Assignment',
    'Exam',
    'Project',
    'Research',
    'Tutorial',
    'Resource',
    'Announcement',
    'Event',
    'Job',
    'Internship',
    'Scholarship',
    'Workshop',
    'Conference',
    'Book Review',
    'Article',
    'Video',
    'Podcast',
    'Webinar',
    'Online Course',
    'Free',
    'Paid',
    'Beginner',
    'Advanced',
    'Expert',
    'Urgent',
    'Important',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

  Future<void> _createTopic() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create the topic
      final topicId = await CommunityService.createForumTopic({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'tags': _selectedTags,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Topic created successfully!')),
        );

        // Navigate back to forums screen
        Navigator.pop(context, topicId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create topic: $e')),
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
        title: const Text('Create New Topic'),
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
                    // Basic Information
                    _buildBasicInformationSection(),
                    const SizedBox(height: 24),

                    // Category Selection
                    _buildCategorySection(),
                    const SizedBox(height: 24),

                    // Tags Section
                    _buildTagsSection(),
                    const SizedBox(height: 24),

                    // Guidelines
                    _buildGuidelinesSection(),
                    const SizedBox(height: 32),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _createTopic,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Create Topic',
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

  Widget _buildBasicInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topic Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Topic Title *',
            hintText: 'Enter a clear and descriptive title',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Title is required';
            }
            if (value.trim().length < 5) {
              return 'Title must be at least 5 characters';
            }
            if (value.trim().length > 100) {
              return 'Title must be less than 100 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Content
        TextFormField(
          controller: _contentController,
          decoration: const InputDecoration(
            labelText: 'Topic Content *',
            hintText: 'Write your topic content here...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Content is required';
            }
            if (value.trim().length < 10) {
              return 'Content must be at least 10 characters';
            }
            if (value.trim().length > 5000) {
              return 'Content must be less than 5000 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the most appropriate category for your topic',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Category *',
            border: OutlineInputBorder(),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value!;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
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
          'Select up to 5 tags to help others find your topic',
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
              elevation: isSelected ? 4 : 0,
              pressElevation: 1,
            );
          }).toList(),
        ),
        if (_selectedTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Selected Tags',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags.map((tag) {
              return InputChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: true,
                onDeleted: () => _toggleTag(tag),
                deleteIconColor: AppTheme.primaryColor,
                selectedColor: AppTheme.primaryColor.withOpacity(0.12),
                side: BorderSide(color: AppTheme.primaryColor),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildGuidelinesSection() {
    return Container(
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
              Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Topic Guidelines',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Write clear, descriptive titles\n'
            '• Provide detailed and helpful content\n'
            '• Be respectful and constructive\n'
            '• Use appropriate categories and tags\n'
            '• Avoid spam or promotional content\n'
            '• Check for similar topics before posting',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
