import 'package:flutter/material.dart';
import 'package:edubazaar/models/group_post.dart';
import 'package:edubazaar/services/community_service.dart';
import 'package:edubazaar/services/image_service.dart';
import 'package:edubazaar/core/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edubazaar/screens/community/post_comments_screen.dart';
import 'dart:io';

class GroupPostsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupPostsScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<GroupPostsScreen> createState() => _GroupPostsScreenState();
}

class _GroupPostsScreenState extends State<GroupPostsScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<GroupPost> _posts = [];
  bool _isLoading = true;
  String? _error;
  bool _isCreatingPost = false;
  String _selectedPostType = 'discussion';
  File? _selectedImage;
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;

    print('🔍 Loading posts for group: ${widget.groupId}');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 Calling CommunityService.getGroupPosts...');
      final posts = await CommunityService.getGroupPosts(widget.groupId);
      print('🔍 Posts loaded: ${posts.length} posts');

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
        print('✅ Posts loaded successfully');
      }
    } catch (e) {
      print('❌ Error loading posts: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load posts: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createPost() async {
    print('🔍 Creating post for group: ${widget.groupId}');
    print('🔍 Post type: $_selectedPostType');
    print('🔍 Content: ${_contentController.text}');

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content')),
      );
      return;
    }

    setState(() {
      _isCreatingPost = true;
    });

    try {
      String? imageUrl;
      String? fileUrl;
      String? fileName;
      int? fileSize;

      // Upload image if selected
      if (_selectedImage != null) {
        print('🔍 Uploading image...');
        imageUrl = await ImageService.uploadGroupCoverImage(_selectedImage!);
        print('🔍 Image uploaded: $imageUrl');
      }

      print('🔍 Calling CommunityService.createGroupPost...');
      await CommunityService.createGroupPost(
        groupId: widget.groupId,
        postType: _selectedPostType,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        content: _contentController.text.trim(),
        imageUrl: imageUrl,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      print('✅ Post created successfully');

      // Clear form
      _contentController.clear();
      _titleController.clear();
      _selectedImage = null;
      _selectedFile = null;
      _selectedPostType = 'discussion';

      // Reload posts
      await _loadPosts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      print('❌ Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPost = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      // File picker intentionally disabled in production (debug-only removed)

      // FilePickerResult? result = await FilePicker.platform.pickFiles(
      //   type: FileType.any,
      //   allowMultiple: false,
      // );

      // if (result != null) {
      //   setState(() {
      //     _selectedFile = result.files.first;
      //   });
      // }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _togglePostLike(GroupPost post) async {
    try {
      await CommunityService.togglePostLike(post.id);
      await _loadPosts(); // Reload to get updated like status
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle like: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Create Post Section
              _buildCreatePostSection(),

              // Posts List
              Container(
                height: MediaQuery.of(context).size.height *
                    0.6, // 60% of screen height
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorWidget()
                        : _posts.isEmpty
                            ? _buildEmptyWidget()
                            : _buildPostsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Type Selector
            DropdownButtonFormField<String>(
              value: _selectedPostType,
              decoration: const InputDecoration(
                labelText: 'Post Type',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'discussion', child: Text('Discussion')),
                DropdownMenuItem(
                    value: 'announcement', child: Text('Announcement')),
                DropdownMenuItem(value: 'question', child: Text('Question')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPostType = value!;
                });
              },
            ),

            const SizedBox(height: 8),

            // Title Field (for announcements and questions)
            if (_selectedPostType == 'announcement' ||
                _selectedPostType == 'question')
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),

            if (_selectedPostType == 'announcement' ||
                _selectedPostType == 'question')
              const SizedBox(height: 8),

            // Content Field
            TextField(
              controller: _contentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            const SizedBox(height: 8),

            // Attachment Options
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  tooltip: 'Add Image',
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isCreatingPost ? null : _createPost,
                  child: _isCreatingPost
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post'),
                ),
              ],
            ),

            // Selected Attachments
            if (_selectedImage != null || _selectedFile != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedImage != null)
                      Row(
                        children: [
                          const Icon(Icons.image, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text('Image selected',
                                  style: TextStyle(fontSize: 12))),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                            icon: const Icon(Icons.close, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    if (_selectedFile != null)
                      Row(
                        children: [
                          const Icon(Icons.attach_file, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(_selectedFile!.name,
                                  style: TextStyle(fontSize: 12))),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedFile = null;
                              });
                            },
                            icon: const Icon(Icons.close, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPosts,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to start a discussion!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(GroupPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.authorAvatar != null
                      ? NetworkImage(post.authorAvatar!)
                      : null,
                  child: post.authorAvatar == null
                      ? Text(post.authorName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.isPinned)
                  Icon(Icons.push_pin, color: Colors.orange, size: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPostTypeColor(post.postType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    post.postType.toUpperCase(),
                    style: TextStyle(
                      color: _getPostTypeColor(post.postType),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Post Title (if exists)
            if (post.title != null) ...[
              Text(
                post.title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Post Content
            Text(
              post.content,
              style: const TextStyle(fontSize: 14),
            ),

            // Post Image
            if (post.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    );
                  },
                ),
              ),
            ],

            // Post File
            if (post.fileUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.fileName ?? 'File',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (post.fileSize != null)
                            Text(
                              _formatFileSize(post.fileSize!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Removed debug-only download action
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Post Actions
            Row(
              children: [
                IconButton(
                  onPressed: () => _togglePostLike(post),
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : null,
                  ),
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostCommentsScreen(post: post),
                      ),
                    );
                    // Refresh posts to update comment count
                    _loadPosts();
                  },
                  icon: const Icon(Icons.comment),
                ),
                Text('${post.commentCount}'),
                const Spacer(),
                if (post.isEdited)
                  Text(
                    'Edited',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPostTypeColor(String postType) {
    switch (postType) {
      case 'announcement':
        return Colors.orange;
      case 'question':
        return Colors.blue;
      case 'resource':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
