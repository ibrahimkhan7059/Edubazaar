import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/study_group.dart';
import '../models/forum_topic.dart';
import '../models/community_event.dart';
import '../models/study_resource.dart';
import '../models/group_post.dart';
import '../models/event.dart';
import 'auth_service.dart';

class CommunityService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static String? get currentUserId => AuthService.getCurrentUserId();

  // STUDY GROUPS - Fixed version with proper membership filtering
  static Future<List<StudyGroup>> getMyStudyGroups() async {
    try {
      if (currentUserId == null) return [];

      // First, get user memberships
      final membershipsResponse = await _supabase
          .from('group_members')
          .select('group_id, role')
          .eq('user_id', currentUserId!);

      // Get groups where current user is a member
      final response = await _supabase
          .from('study_groups')
          .select('''
            *,
            group_members!inner(user_id, role)
          ''')
          .eq('group_members.user_id', currentUserId!)
          .order('created_at', ascending: false);

      final groups =
          (response as List).map((data) => StudyGroup.fromJson(data)).toList();

      return groups;
    } catch (e) {
      throw Exception('Failed to fetch my study groups: $e');
    }
  }

  static Future<List<StudyGroup>> getDiscoverStudyGroups() async {
    try {
      if (currentUserId == null) return [];

      // Get all groups first
      final response = await _supabase
          .from('study_groups')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      // Get user's memberships separately
      final membershipsResponse = await _supabase
          .from('group_members')
          .select('group_id')
          .eq('user_id', currentUserId!);

      final userGroupIds = Set<String>.from(
          (membershipsResponse as List).map((m) => m['group_id'] as String));

      final groups = (response as List)
          .where((json) => !userGroupIds.contains(json['id']))
          .map((json) {
            return {
              ...json,
              'is_member': false,
              'role': null,
            };
          })
          .map((json) => StudyGroup.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      // Calculate actual member counts for each group
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        final memberCountResponse = await _supabase
            .from('group_members')
            .select('id')
            .eq('group_id', group.id);

        final actualMemberCount = (memberCountResponse as List).length;

        // Create a new StudyGroup with the correct member count
        groups[i] = group.copyWith(memberCount: actualMemberCount);
      }

      return groups;
    } catch (e) {
      throw Exception('Failed to fetch discover study groups: $e');
    }
  }

  static Future<StudyGroup?> getStudyGroupById(String groupId) async {
    try {
      if (currentUserId == null) return null;

      // Get group details
      final groupResponse = await _supabase
          .from('study_groups')
          .select('*')
          .eq('id', groupId)
          .single();

      // Check if current user is a member
      final memberResponse = await _supabase
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      final isMember = memberResponse != null;
      final role = memberResponse?['role'] as String?;

      // Calculate actual member count
      final memberCountResponse = await _supabase
          .from('group_members')
          .select('id')
          .eq('group_id', groupId);

      final actualMemberCount = (memberCountResponse as List).length;

      final groupData = {
        ...groupResponse,
        'is_member': isMember,
        'role': role,
        'member_count': actualMemberCount, // Override with actual count
      };

      return StudyGroup.fromJson(Map<String, dynamic>.from(groupData));
    } catch (e) {
      throw Exception('Failed to fetch study group: $e');
    }
  }

  static Future<String> createStudyGroup(Map<String, dynamic> groupData) async {
    try {
      final response = await _supabase
          .from('study_groups')
          .insert({
            'name': groupData['name'],
            'description': groupData['description'],
            'subject': groupData['subject'],
            'is_private': groupData['is_private'] ?? false,
            'max_members': groupData['max_members'],
            'tags': groupData['tags'] ?? [],
            'cover_image_url': groupData['cover_image_url'],
            'creator_id': currentUserId,
          })
          .select()
          .single();

      // Add creator as admin member
      await _supabase.from('group_members').insert({
        'group_id': response['id'],
        'user_id': currentUserId,
        'role': 'admin',
      });

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create study group: ${e.toString()}');
    }
  }

  static Future<void> joinStudyGroup(String groupId) async {
    try {
      await _supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': currentUserId,
        'role': 'member',
      });
    } catch (e) {
      throw Exception('Failed to join study group: ${e.toString()}');
    }
  }

  static Future<void> leaveStudyGroup(String groupId) async {
    try {
      if (currentUserId == null) return;

      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', currentUserId!);
    } catch (e) {
      throw Exception('Failed to leave study group: ${e.toString()}');
    }
  }

  // FORUM OPERATIONS - Simplified
  static Future<List<ForumTopic>> getForumTopics() async {
    try {
      final response = await _supabase
          .from('forum_topics')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      final List<ForumTopic> topics = [];
      for (final raw in (response as List)) {
        final topic = Map<String, dynamic>.from(raw);

        // 1) Author profile enrichment
        Map<String, dynamic>? authorProfile;
        try {
          authorProfile = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url')
              .eq('id', topic['author_id'] as String)
              .maybeSingle();
        } catch (_) {
          authorProfile = null;
        }

        // 2) Accurate reply count from replies table
        int replyCount = 0;
        try {
          final replies = await _supabase
              .from('forum_replies')
              .select('id')
              .eq('topic_id', topic['id'] as String);
          if (replies is List) {
            replyCount = replies.length;
          }
        } catch (_) {}

        // 3) Accurate like count and is_liked for current user
        int likeCount = 0;
        bool isLiked = false;
        try {
          final likes = await _supabase
              .from('forum_topic_likes')
              .select('user_id')
              .eq('topic_id', topic['id'] as String);
          if (likes is List) {
            likeCount = likes.length;
            if (currentUserId != null) {
              isLiked = likes.any((l) => l['user_id'] == currentUserId);
            }
          }
        } catch (_) {}

        // 3b) Include likes on replies for aggregate likeCount shown in list
        try {
          final replyIdsResp = await _supabase
              .from('forum_replies')
              .select('id')
              .eq('topic_id', topic['id'] as String);
          if (replyIdsResp is List && replyIdsResp.isNotEmpty) {
            final replyIds = replyIdsResp
                .map((r) => r['id'] as String)
                .toList(growable: false);
            // Count likes across these replies
            final replyLikes = await _supabase
                .from('forum_reply_likes')
                .select('user_id')
                .inFilter('reply_id', replyIds);
            if (replyLikes is List) {
              likeCount += replyLikes.length;
            }
          }
        } catch (_) {}

        final topicWithExtras = {
          ...topic,
          'author_name': authorProfile != null
              ? (authorProfile['name'] as String? ?? 'Unknown')
              : 'Unknown',
          'author_avatar': authorProfile != null
              ? (authorProfile['profile_pic_url'] as String? ?? '')
              : '',
          'reply_count': replyCount,
          'like_count': likeCount,
          'is_liked': isLiked,
        };

        topics.add(ForumTopic.fromJson(topicWithExtras));
      }

      return topics;
    } catch (e) {
      throw Exception('Failed to fetch forum topics: $e');
    }
  }

  static Future<String> createForumTopic(Map<String, dynamic> topicData) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('forum_topics')
          .insert({
            'title': topicData['title'],
            'content': topicData['content'],
            'category': topicData['category'],
            'author_id': currentUserId,
            'tags': topicData['tags'] ?? [],
          })
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create forum topic: ${e.toString()}');
    }
  }

  static Future<ForumTopic?> getForumTopicById(String topicId) async {
    try {
      final topic = await _supabase
          .from('forum_topics')
          .select('*')
          .eq('id', topicId)
          .maybeSingle();

      if (topic == null) return null;

      // Fetch author profile for display fields
      Map<String, dynamic>? authorProfile;
      try {
        authorProfile = await _supabase
            .from('user_profiles')
            .select('name, profile_pic_url')
            .eq('id', topic['author_id'] as String)
            .maybeSingle();
      } catch (_) {
        authorProfile = null;
      }

      // Compute likes and replies
      int replyCount = 0;
      int likeCount = 0;
      bool isLiked = false;
      try {
        final replies = await _supabase
            .from('forum_replies')
            .select('id')
            .eq('topic_id', topicId);
        if (replies is List) replyCount = replies.length;
        // Also include reply likes in aggregate likeCount
        if (replies is List && replies.isNotEmpty) {
          final replyIds =
              replies.map((r) => r['id'] as String).toList(growable: false);
          final replyLikes = await _supabase
              .from('forum_reply_likes')
              .select('user_id')
              .inFilter('reply_id', replyIds);
          if (replyLikes is List) {
            likeCount += replyLikes.length;
          }
        }
      } catch (_) {}
      try {
        final likes = await _supabase
            .from('forum_topic_likes')
            .select('user_id')
            .eq('topic_id', topicId);
        if (likes is List) {
          likeCount = likeCount + likes.length;
          if (currentUserId != null) {
            isLiked = likes.any((l) => l['user_id'] == currentUserId);
          }
        }
      } catch (_) {}

      final topicWithAuthor = {
        ...topic,
        'author_name': authorProfile != null
            ? (authorProfile['name'] as String? ?? 'Unknown')
            : 'Unknown',
        'author_avatar': authorProfile != null
            ? (authorProfile['profile_pic_url'] as String? ?? '')
            : '',
        'reply_count': replyCount,
        'like_count': likeCount,
        'is_liked': isLiked,
      };

      return ForumTopic.fromJson(Map<String, dynamic>.from(topicWithAuthor));
    } catch (e) {
      throw Exception('Failed to fetch forum topic by id: $e');
    }
  }

  static Future<int?> incrementForumTopicViewCount(String topicId) async {
    try {
      final result = await _supabase
          .rpc('increment_forum_topic_view', params: {'p_topic_id': topicId});
      if (result == null) return null;
      if (result is int) return result;
      // Supabase might return as num
      if (result is num) return result.toInt();
      return null;
    } catch (e) {
      throw Exception('Failed to increment view count: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getTopicReplies(
      String topicId) async {
    try {
      final replies = await _supabase
          .from('forum_replies')
          .select('id, content, author_id, created_at')
          .eq('topic_id', topicId)
          .order('created_at', ascending: true);

      if (replies == null) return [];

      final List<Map<String, dynamic>> result = [];
      for (final r in (replies as List)) {
        final authorId = r['author_id'] as String;
        Map<String, dynamic>? authorProfile;
        try {
          authorProfile = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url')
              .eq('id', authorId)
              .maybeSingle();
        } catch (_) {
          authorProfile = null;
        }

        // Likes for this reply
        int likeCount = 0;
        bool isLiked = false;
        try {
          final replyLikes = await _supabase
              .from('forum_reply_likes')
              .select('user_id')
              .eq('reply_id', r['id'] as String);
          if (replyLikes is List) {
            likeCount = replyLikes.length;
            if (currentUserId != null) {
              isLiked = replyLikes.any((l) => l['user_id'] == currentUserId);
            }
          }
        } catch (_) {}

        result.add({
          'id': r['id'] as String,
          'content': r['content'] as String,
          'author': authorProfile != null
              ? (authorProfile['name'] as String? ?? 'Unknown')
              : 'Unknown',
          'authorId': authorId,
          'authorAvatar': authorProfile != null
              ? (authorProfile['profile_pic_url'] as String? ?? '')
              : '',
          'createdAt': DateTime.parse(r['created_at'] as String),
          'likeCount': likeCount,
          'isLiked': isLiked,
        });
      }
      return result;
    } catch (e) {
      throw Exception('Failed to fetch topic replies: $e');
    }
  }

  static Future<void> addTopicReply(String topicId, String content) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('forum_replies').insert({
        'topic_id': topicId,
        'author_id': currentUserId,
        'content': content,
      });
    } catch (e) {
      throw Exception('Failed to add reply: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> toggleForumTopicLike(
      String topicId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    // Check existing
    final existing = await _supabase
        .from('forum_topic_likes')
        .select('user_id')
        .eq('topic_id', topicId)
        .eq('user_id', currentUserId!)
        .maybeSingle();
    if (existing == null) {
      await _supabase.from('forum_topic_likes').insert({
        'topic_id': topicId,
        'user_id': currentUserId,
      });
    } else {
      await _supabase
          .from('forum_topic_likes')
          .delete()
          .eq('topic_id', topicId)
          .eq('user_id', currentUserId!);
    }
    // Return updated count and state
    final likes = await _supabase
        .from('forum_topic_likes')
        .select('user_id')
        .eq('topic_id', topicId);
    int likeCount = (likes is List) ? likes.length : 0;
    bool isLiked = (likes is List)
        ? likes.any((l) => l['user_id'] == currentUserId)
        : false;
    return {'likeCount': likeCount, 'isLiked': isLiked};
  }

  static Future<Map<String, dynamic>> toggleForumReplyLike(
      String replyId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    final existing = await _supabase
        .from('forum_reply_likes')
        .select('user_id')
        .eq('reply_id', replyId)
        .eq('user_id', currentUserId!)
        .maybeSingle();
    if (existing == null) {
      await _supabase.from('forum_reply_likes').insert({
        'reply_id': replyId,
        'user_id': currentUserId,
      });
    } else {
      await _supabase
          .from('forum_reply_likes')
          .delete()
          .eq('reply_id', replyId)
          .eq('user_id', currentUserId!);
    }
    final likes = await _supabase
        .from('forum_reply_likes')
        .select('user_id')
        .eq('reply_id', replyId);
    int likeCount = (likes is List) ? likes.length : 0;
    bool isLiked = (likes is List)
        ? likes.any((l) => l['user_id'] == currentUserId)
        : false;
    return {'likeCount': likeCount, 'isLiked': isLiked};
  }

  static Future<void> deleteForumTopic(String topicId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final deleted = await _supabase
          .from('forum_topics')
          .delete()
          .eq('id', topicId)
          .eq('author_id', currentUserId!)
          .select()
          .maybeSingle();

      if (deleted == null) {
        throw Exception('You are not allowed to delete this topic');
      }
    } catch (e) {
      throw Exception('Failed to delete topic: ${e.toString()}');
    }
  }

  // EVENTS OPERATIONS - Simplified
  static Future<List<CommunityEvent>> getCommunityEvents() async {
    try {
      final response = await _supabase
          .from('community_events')
          .select('*')
          .order('event_date', ascending: true)
          .limit(10);

      return (response as List)
          .map((json) =>
              CommunityEvent.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch community events: $e');
    }
  }

  static Future<void> createCommunityEvent(
      Map<String, dynamic> eventData) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('community_events').insert({
        'title': eventData['title'],
        'description': eventData['description'],
        'event_date': eventData['event_date'],
        'location': eventData['location'],
        'organizer_id': currentUserId,
        'max_participants': eventData['max_participants'],
        'is_online': eventData['is_online'] ?? false,
        'meeting_link': eventData['meeting_link'],
      });
    } catch (e) {
      throw Exception('Failed to create community event: ${e.toString()}');
    }
  }

  // RESOURCES OPERATIONS - Simplified
  static Future<List<StudyResource>> getStudyResources() async {
    try {
      final response = await _supabase
          .from('study_resources')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List)
          .map(
              (json) => StudyResource.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch study resources: $e');
    }
  }

  static Future<void> uploadStudyResource(
      Map<String, dynamic> resourceData) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('study_resources').insert({
        'title': resourceData['title'],
        'description': resourceData['description'],
        'subject': resourceData['subject'],
        'file_url': resourceData['file_url'],
        'file_size': resourceData['file_size'],
        'uploader_id': currentUserId,
        'tags': resourceData['tags'] ?? [],
      });
    } catch (e) {
      throw Exception('Failed to upload study resource: ${e.toString()}');
    }
  }

  // GROUP POSTS
  static Future<List<GroupPost>> getGroupPosts(String groupId) async {
    try {
      if (currentUserId == null) return [];

      final response = await _supabase
          .from('group_posts')
          .select('''
            *,
            group_post_likes(user_id)
          ''')
          .eq('group_id', groupId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      final posts = (response as List)
          .map((json) {
            // Check if current user has liked this post
            final likes = json['group_post_likes'] as List? ?? [];
            final isLiked =
                likes.any((like) => like['user_id'] == currentUserId);

            return {
              ...json,
              'is_liked': isLiked,
            };
          })
          .map((json) => GroupPost.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      return posts;
    } catch (e) {
      throw Exception('Failed to fetch group posts: $e');
    }
  }

  static Future<String> createGroupPost({
    required String groupId,
    required String postType,
    String? title,
    required String content,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get user profile for author name
      final userProfile = await _supabase
          .from('user_profiles')
          .select('name, profile_pic_url')
          .eq('id', currentUserId!)
          .single();

      final postData = {
        'group_id': groupId,
        'author_id': currentUserId!,
        'author_name': userProfile['name'] ?? 'Unknown User',
        'author_avatar': userProfile['profile_pic_url'],
        'post_type': postType,
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
      };

      final response = await _supabase
          .from('group_posts')
          .insert(postData)
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create group post: $e');
    }
  }

  static Future<void> togglePostLike(String postId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Check if user already liked the post
      final existingLike = await _supabase
          .from('group_post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike the post
        await _supabase
            .from('group_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUserId!);
      } else {
        // Like the post
        await _supabase.from('group_post_likes').insert({
          'post_id': postId,
          'user_id': currentUserId!,
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  static Future<List<GroupPostComment>> getPostComments(String postId) async {
    try {
      final response = await _supabase
          .from('group_post_comments')
          .select('*')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = (response as List)
          .map((json) =>
              GroupPostComment.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      return comments;
    } catch (e) {
      throw Exception('Failed to fetch post comments: $e');
    }
  }

  static Future<String> createPostComment({
    required String postId,
    required String content,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get user profile for author name
      final userProfile = await _supabase
          .from('user_profiles')
          .select('name, profile_pic_url')
          .eq('id', currentUserId!)
          .single();

      final commentData = {
        'post_id': postId,
        'author_id': currentUserId!,
        'author_name': userProfile['name'] ?? 'Unknown User',
        'author_avatar': userProfile['profile_pic_url'],
        'content': content,
      };

      final response = await _supabase
          .from('group_post_comments')
          .insert(commentData)
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create post comment: $e');
    }
  }

  static Future<void> deleteGroupPost(String postId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Check if user is the author or admin
      final post = await _supabase
          .from('group_posts')
          .select('author_id, group_id')
          .eq('id', postId)
          .single();

      final isAuthor = post['author_id'] == currentUserId;
      final isAdmin = await _isGroupAdmin(post['group_id']);

      if (!isAuthor && !isAdmin) {
        throw Exception('You can only delete your own posts');
      }

      await _supabase.from('group_posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  static Future<bool> _isGroupAdmin(String groupId) async {
    try {
      if (currentUserId == null) return false;

      final membership = await _supabase
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      return membership != null && membership['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  // MEMBER MANAGEMENT METHODS
  static Future<List<Map<String, dynamic>>> getGroupMembers(
      String groupId) async {
    try {
      // Get the group members
      final membersResponse = await _supabase
          .from('group_members')
          .select('user_id, role, joined_at')
          .eq('group_id', groupId)
          .order('joined_at', ascending: true);

      if (membersResponse == null || (membersResponse as List).isEmpty) {
        return [];
      }

      // Get user IDs
      final userIds =
          (membersResponse as List).map((m) => m['user_id'] as String).toList();

      // Get user profiles separately
      final profilesMap = <String, Map<String, dynamic>>{};

      for (final userId in userIds) {
        final profileResponse =
            await _supabase.from('profiles').select().eq('id', userId).single();

        if (profileResponse != null) {
          profilesMap[userId] = Map<String, dynamic>.from(profileResponse);
        }
      }

      // Combine member data with profiles
      return (membersResponse as List).map((member) {
        final userId = member['user_id'] as String;
        final profile = profilesMap[userId];
        return <String, dynamic>{
          ...Map<String, dynamic>.from(member),
          'name': profile?['full_name'] ?? 'Unknown User',
          'avatar_url': profile?['avatar_url'],
          'university': profile?['university'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch group members: $e');
    }
  }

  static Future<bool> isGroupAdmin(String groupId, String userId) async {
    try {
      final membership = await _supabase
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      return membership != null && membership['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  static Future<void> addGroupMember(
      String groupId, String userId, String role) async {
    try {
      // Check if current user is admin
      if (currentUserId == null) throw Exception('User not authenticated');

      final isAdmin = await _isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can add members to the group');
      }

      // Check if user is already a member
      final existingMember = await _supabase
          .from('group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingMember != null) {
        throw Exception('User is already a member of this group');
      }

      await _supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': role,
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  static Future<void> removeGroupMember(String groupId, String userId) async {
    try {
      // Check if current user is admin
      if (currentUserId == null) throw Exception('User not authenticated');

      final isAdmin = await _isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can remove members from the group');
      }

      // Check if user is admin (admins cannot be removed by other admins)
      final membership = await _supabase
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .single();

      if (membership['role'] == 'admin') {
        throw Exception('Cannot remove admin members');
      }

      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('id, name, email, profile_pic_url')
          .or('name.ilike.%$query%,email.ilike.%$query%')
          .limit(20);

      return (response as List)
          .map((user) => {
                'id': user['id'],
                'name': user['name'],
                'email': user['email'],
                'profile_pic_url': user['profile_pic_url'],
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Debug method
  static Future<bool> testDatabaseConnection() async {
    try {
      await _supabase.from('study_groups').select('count').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // GROUP MANAGEMENT METHODS
  static Future<void> updateStudyGroup(
      String groupId, Map<String, dynamic> updates) async {
    try {
      // Check if current user is admin
      if (currentUserId == null) throw Exception('User not authenticated');

      final isAdmin = await _isGroupAdmin(groupId);
      if (!isAdmin) {
        throw Exception('Only admins can update group settings');
      }

      // Add updated_at timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('study_groups').update(updates).eq('id', groupId);
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  static Future<bool> deleteStudyGroup(String groupId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // First verify the group exists and user is admin
      final group = await _supabase
          .from('study_groups')
          .select('*, group_members!inner(role)')
          .eq('id', groupId)
          .eq('group_members.user_id', currentUserId!)
          .eq('group_members.role', 'admin')
          .single();

      if (group == null) {
        return false;
      }

      // Delete in order to maintain referential integrity

      // 1. Delete group posts
      await _supabase.from('group_posts').delete().eq('group_id', groupId);

      // 2. Delete group members
      await _supabase.from('group_members').delete().eq('group_id', groupId);

      // 3. Finally delete the group
      await _supabase
          .from('study_groups')
          .delete()
          .eq('id', groupId)
          .eq('id', groupId); // Double check to prevent accidental deletion

      return true;
    } catch (e) {
      return false;
    }
  }

  // Add this method for debugging member count issues
  static Future<void> refreshGroupMemberCount(String groupId) async {
    try {
      final client = Supabase.instance.client;

      // Get actual member count
      final members = await client
          .from('group_members')
          .select('id')
          .eq('group_id', groupId);

      final actualCount = members.length;

      // Update the group's member_count
      await client
          .from('study_groups')
          .update({'member_count': actualCount}).eq('id', groupId);
    } catch (e) {
      throw Exception('Failed to refresh member count: $e');
    }
  }

  // ============================================================================
  // EVENTS METHODS
  // ============================================================================

  // Get all events (upcoming and past)
  static Future<List<Event>> getEvents() async {
    try {
      // First, get basic event data without joins
      final response = await _supabase
          .from('events')
          .select('*')
          .order('start_date_time', ascending: true);

      final events = <Event>[];

      for (final json in response as List) {
        try {
          // Get organizer info separately
          final organizerResponse = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url')
              .eq('id', json['organizer_id'])
              .maybeSingle();

          if (organizerResponse != null) {
            json['organizer_name'] = organizerResponse['name'] ?? '';
            json['organizer_avatar'] = organizerResponse['profile_pic_url'];
          } else {
            json['organizer_name'] = 'Unknown User';
            json['organizer_avatar'] = null;
          }

          // Get attendee count separately
          final attendeesResponse = await _supabase
              .from('event_attendees')
              .select('user_id, status')
              .eq('event_id', json['id']);

          final attendees = attendeesResponse as List? ?? [];
          json['current_attendees'] =
              attendees.where((a) => a['status'] == 'approved').length;

          final userAttendance = attendees.firstWhere(
            (a) => a['user_id'] == currentUserId,
            orElse: () => <String, dynamic>{},
          );
          json['is_attending'] = userAttendance.isNotEmpty &&
              userAttendance['status'] == 'approved';
          json['attendee_status'] = userAttendance['status'];

          events.add(Event.fromJson(Map<String, dynamic>.from(json)));
        } catch (e) {
          // Skip this event and continue
          continue;
        }
      }

      return events;
    } catch (e) {
      throw Exception('Failed to load events: $e');
    }
  }

  // Get upcoming events only
  static Future<List<Event>> getUpcomingEvents() async {
    try {
      final now = DateTime.now().toIso8601String();

      // Get basic event data without joins
      final response = await _supabase
          .from('events')
          .select('*')
          .gte('start_date_time', now)
          .order('start_date_time', ascending: true);

      final events = <Event>[];

      for (final json in response as List) {
        try {
          // Get organizer info separately
          final organizerResponse = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url')
              .eq('id', json['organizer_id'])
              .maybeSingle();

          if (organizerResponse != null) {
            json['organizer_name'] = organizerResponse['name'] ?? '';
            json['organizer_avatar'] = organizerResponse['profile_pic_url'];
          } else {
            json['organizer_name'] = 'Unknown User';
            json['organizer_avatar'] = null;
          }

          // Get attendee count separately
          final attendeesResponse = await _supabase
              .from('event_attendees')
              .select('user_id, status')
              .eq('event_id', json['id']);

          final attendees = attendeesResponse as List? ?? [];
          json['current_attendees'] =
              attendees.where((a) => a['status'] == 'approved').length;

          final userAttendance = attendees.firstWhere(
            (a) => a['user_id'] == currentUserId,
            orElse: () => <String, dynamic>{},
          );
          json['is_attending'] = userAttendance.isNotEmpty &&
              userAttendance['status'] == 'approved';
          json['attendee_status'] = userAttendance['status'];

          events.add(Event.fromJson(Map<String, dynamic>.from(json)));
        } catch (e) {
          continue;
        }
      }

      return events;
    } catch (e) {
      throw Exception('Failed to load upcoming events: $e');
    }
  }

  // Get events by category
  static Future<List<Event>> getEventsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('events')
          .select('''
            *,
            user_profiles!organizer_id(name, profile_pic_url),
            event_attendees(user_id, status)
          ''')
          .eq('category', category)
          .order('start_date_time', ascending: true);

      final events = (response as List).map((json) {
        final organizer = json['user_profiles'];
        if (organizer != null) {
          json['organizer_name'] = organizer['name'] ?? '';
          json['organizer_avatar'] = organizer['profile_pic_url'];
        }

        final attendees = json['event_attendees'] as List? ?? [];
        json['current_attendees'] =
            attendees.where((a) => a['status'] == 'approved').length;

        final userAttendance = attendees.firstWhere(
          (a) => a['user_id'] == currentUserId,
          orElse: () => <String, dynamic>{},
        );
        json['is_attending'] =
            userAttendance.isNotEmpty && userAttendance['status'] == 'approved';
        json['attendee_status'] = userAttendance['status'];

        return Event.fromJson(Map<String, dynamic>.from(json));
      }).toList();

      return events;
    } catch (e) {
      throw Exception('Failed to load events: $e');
    }
  }

  // Get event by ID - Simplified version
  static Future<Event?> getEventById(String eventId) async {
    try {
      // Get basic event data first
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('id', eventId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // Get organizer info separately
      try {
        final organizerResponse = await _supabase
            .from('user_profiles')
            .select('name, profile_pic_url')
            .eq('id', response['organizer_id'])
            .maybeSingle();

        if (organizerResponse != null) {
          response['organizer_name'] = organizerResponse['name'] ?? '';
          response['organizer_avatar'] = organizerResponse['profile_pic_url'];
        } else {
          response['organizer_name'] = 'Event Organizer';
          response['organizer_avatar'] = null;
        }
      } catch (e) {
        response['organizer_name'] = 'Event Organizer';
        response['organizer_avatar'] = null;
      }

      // Get attendees separately
      try {
        final attendeesResponse = await _supabase
            .from('event_attendees')
            .select('user_id, status')
            .eq('event_id', eventId);

        final attendees = attendeesResponse as List? ?? [];
        response['current_attendees'] =
            attendees.where((a) => a['status'] == 'approved').length;

        final userAttendance = attendees.firstWhere(
          (a) => a['user_id'] == currentUserId,
          orElse: () => <String, dynamic>{},
        );
        final hasAttendance = userAttendance.isNotEmpty;
        response['is_attending'] =
            hasAttendance && userAttendance['status'] == 'approved';
        response['attendee_status'] =
            hasAttendance ? userAttendance['status'] : null;
      } catch (e) {
        response['current_attendees'] = 0;
        response['is_attending'] = false;
        response['attendee_status'] = null;
      }

      return Event.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      return null;
    }
  }

  // Create new event
  static Future<Event?> createEvent({
    required String title,
    required String description,
    required DateTime startDateTime,
    DateTime? endDateTime,
    required String location,
    String? locationDetails,
    required String category,
    required int maxAttendees,
    bool isPublic = true,
    bool requiresApproval = false,
    List<String>? tags,
    String? meetingLink,
    String? imageUrl,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final eventData = {
        'title': title,
        'description': description,
        'start_date_time': startDateTime.toIso8601String(),
        'end_date_time': endDateTime?.toIso8601String(),
        'location': location,
        'location_details': locationDetails,
        'organizer_id': currentUserId,
        'category': category,
        'max_attendees': maxAttendees,
        'is_public': isPublic,
        'requires_approval': requiresApproval,
        'tags': tags,
        'meeting_link': meetingLink,
        'image_url': imageUrl,
      };

      final response =
          await _supabase.from('events').insert(eventData).select().single();

      // Create a simple Event object without complex joins to avoid recursion
      final eventJson = Map<String, dynamic>.from(response);
      eventJson['organizer_name'] =
          'You'; // Since current user is the organizer
      eventJson['organizer_avatar'] = null;
      eventJson['current_attendees'] = 0;
      eventJson['is_attending'] = false; // Organizer is not counted as attendee
      eventJson['attendee_status'] = 'organizer';

      return Event.fromJson(eventJson);
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  // Update event
  static Future<Event?> updateEvent(
      String eventId, Map<String, dynamic> updates) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Add updated_at timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('events')
          .update(updates)
          .eq('id', eventId)
          .eq('organizer_id', currentUserId!); // Only organizer can update

      return await getEventById(eventId);
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete event
  static Future<bool> deleteEvent(String eventId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // First verify the event exists and user is organizer
      final event = await _supabase
          .from('events')
          .select()
          .eq('id', eventId)
          .eq('organizer_id', currentUserId!)
          .single();

      if (event == null) {
        return false;
      }

      // Delete all attendees first
      await _supabase.from('event_attendees').delete().eq('event_id', eventId);

      // Delete the event
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId)
          .eq('organizer_id', currentUserId!);

      return true;
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  // Join event (RSVP)
  static Future<bool> joinEvent(String eventId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Check if user is already attending
      final existingAttendance = await _supabase
          .from('event_attendees')
          .select('status')
          .eq('event_id', eventId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (existingAttendance != null) {
        throw Exception('You are already registered for this event');
      }

      // Check if event exists and get requirements
      final event = await getEventById(eventId);
      if (event == null) throw Exception('Event not found');

      if (event.isFull) throw Exception('Event is full');
      if (event.isPast) throw Exception('Cannot join past events');

      final status = event.requiresApproval ? 'pending' : 'approved';

      await _supabase.from('event_attendees').insert({
        'event_id': eventId,
        'user_id': currentUserId,
        'status': status,
      });

      return true;
    } catch (e) {
      throw Exception('Failed to join event: $e');
    }
  }

  // Leave event
  static Future<bool> leaveEvent(String eventId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await _supabase
          .from('event_attendees')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      throw Exception('Failed to leave event: $e');
    }
  }

  // Get event attendees - Simplified
  static Future<List<Map<String, dynamic>>> getEventAttendees(
      String eventId) async {
    try {
      // Get basic attendee data
      final response = await _supabase
          .from('event_attendees')
          .select('user_id, status, created_at')
          .eq('event_id', eventId)
          .eq('status', 'approved');

      final attendees = <Map<String, dynamic>>[];

      for (final json in response as List) {
        try {
          // Get user profile separately
          final profileResponse = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url')
              .eq('id', json['user_id'])
              .maybeSingle();

          attendees.add({
            'user_id': json['user_id'],
            'name': profileResponse?['name'] ?? 'Unknown User',
            'avatar': profileResponse?['profile_pic_url'],
            'joined_at': json['created_at'],
          });
        } catch (e) {
          // Add with default values
          attendees.add({
            'user_id': json['user_id'],
            'name': 'Unknown User',
            'avatar': null,
            'joined_at': json['created_at'],
          });
        }
      }

      return attendees;
    } catch (e) {
      throw Exception('Failed to fetch event attendees: $e');
    }
  }

  // Get my events (organized by current user) - Simplified
  static Future<List<Event>> getMyEvents() async {
    try {
      if (currentUserId == null) return [];

      final response = await _supabase
          .from('events')
          .select('*')
          .eq('organizer_id', currentUserId!)
          .order('start_date_time', ascending: false);

      final events = (response as List).map((json) {
        // Set default organizer info since current user is the organizer
        json['organizer_name'] = 'You';
        json['organizer_avatar'] = null;
        json['current_attendees'] = 0; // We'll update this later if needed
        json['is_attending'] = false; // Organizer is not counted as attendee
        json['attendee_status'] = 'organizer';

        return Event.fromJson(Map<String, dynamic>.from(json));
      }).toList();

      return events;
    } catch (e) {
      throw Exception('Failed to fetch my events: $e');
    }
  }

  // Get events I'm attending
  static Future<List<Event>> getMyAttendingEvents() async {
    try {
      if (currentUserId == null) return [];

      final response = await _supabase
          .from('events')
          .select('''
            *,
            user_profiles!organizer_id(name, profile_pic_url),
            event_attendees!inner(user_id, status)
          ''')
          .eq('event_attendees.user_id', currentUserId!)
          .eq('event_attendees.status', 'approved')
          .order('start_date_time', ascending: true);

      final events = (response as List).map((json) {
        final organizer = json['user_profiles'];
        if (organizer != null) {
          json['organizer_name'] = organizer['name'] ?? '';
          json['organizer_avatar'] = organizer['profile_pic_url'];
        }

        json['is_attending'] = true;
        json['attendee_status'] = 'approved';

        return Event.fromJson(Map<String, dynamic>.from(json));
      }).toList();

      return events;
    } catch (e) {
      throw Exception('Failed to fetch attending events: $e');
    }
  }

  // ============================================================================
  // EVENTS METHODS - SIMPLIFIED VERSION FOR TESTING
  // ============================================================================

  // Get all events (simplified version without user_profiles dependency)
  static Future<List<Event>> getEventsSimple() async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .order('start_date_time', ascending: true);

      final events = <Event>[];

      for (final json in response as List) {
        try {
          // Get organizer info separately
          final organizerResponse = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url')
              .eq('id', json['organizer_id'])
              .maybeSingle();

          if (organizerResponse != null) {
            json['organizer_name'] = organizerResponse['name'] ?? '';
            json['organizer_avatar'] = organizerResponse['profile_pic_url'];
          } else {
            json['organizer_name'] = 'Unknown User';
            json['organizer_avatar'] = null;
          }

          // Get attendee count separately
          final attendeesResponse = await _supabase
              .from('event_attendees')
              .select('user_id, status')
              .eq('event_id', json['id']);

          final attendees = attendeesResponse as List? ?? [];
          json['current_attendees'] =
              attendees.where((a) => a['status'] == 'approved').length;

          // Check if current user is attending
          if (currentUserId != null) {
            final userAttendance = attendees.firstWhere(
              (a) => a['user_id'] == currentUserId,
              orElse: () => <String, dynamic>{},
            );
            json['is_attending'] = userAttendance.isNotEmpty &&
                userAttendance['status'] == 'approved';
            json['attendee_status'] = userAttendance['status'];
          } else {
            json['is_attending'] = false;
            json['attendee_status'] = null;
          }

          final event = Event.fromJson(Map<String, dynamic>.from(json));
          events.add(event);
        } catch (e) {
          // Skip this event and continue
          continue;
        }
      }

      return events;
    } catch (e) {
      throw Exception('Failed to fetch events (simple): $e');
    }
  }

  // ============================================================================
  // ORGANIZER CONTROLS - NEW METHODS
  // ============================================================================

  // Remove an attendee from an event (organizer only)
  static Future<bool> removeAttendee(String eventId, String attendeeId) async {
    try {
      // First, verify that current user is the organizer
      final eventResponse = await _supabase
          .from('events')
          .select('organizer_id')
          .eq('id', eventId)
          .maybeSingle();

      if (eventResponse == null) {
        return false;
      }

      if (eventResponse['organizer_id'] != currentUserId) {
        return false;
      }

      // Remove the attendee
      final response = await _supabase
          .from('event_attendees')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', attendeeId);

      return true;
    } catch (e) {
      throw Exception('Failed to remove attendee: $e');
    }
  }

  // Get detailed attendee information for profile viewing
  static Future<Map<String, dynamic>?> getAttendeeDetails(
      String attendeeId) async {
    try {
      final response = await _supabase.from('user_profiles').select('''
            id,
            name,
            email,
            profile_pic_url,
            bio,
            university,
            course,
            semester,
            phone_number,
            interests,
            joined_date,
            created_at
          ''').eq('id', attendeeId).maybeSingle();

      if (response != null) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      throw Exception('Failed to get attendee details: $e');
    }
  }

  // Check if current user can manage an event (is organizer)
  static Future<bool> canManageEvent(String eventId) async {
    try {
      if (currentUserId == null) return false;

      final response = await _supabase
          .from('events')
          .select('organizer_id')
          .eq('id', eventId)
          .maybeSingle();

      return response != null && response['organizer_id'] == currentUserId;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // PRIVATE EVENT REQUEST MANAGEMENT - NEW METHODS
  // ============================================================================

  // Get pending requests for an event (organizer only)
  static Future<List<Map<String, dynamic>>> getPendingRequests(
      String eventId) async {
    try {
      if (currentUserId == null) {
        return [];
      }

      // First, verify that current user is the organizer
      final eventResponse = await _supabase
          .from('events')
          .select('organizer_id')
          .eq('id', eventId)
          .maybeSingle();

      if (eventResponse == null) {
        return [];
      }

      if (eventResponse['organizer_id'] != currentUserId) {
        return [];
      }

      // Get pending requests
      final response = await _supabase
          .from('event_attendees')
          .select('user_id, status, created_at')
          .eq('event_id', eventId)
          .eq('status', 'pending');

      final pendingRequests = <Map<String, dynamic>>[];

      for (final json in response as List) {
        try {
          // Get user profile
          final profileResponse = await _supabase
              .from('user_profiles')
              .select('name, profile_pic_url, university, course')
              .eq('id', json['user_id'])
              .maybeSingle();

          pendingRequests.add({
            'user_id': json['user_id'],
            'name': profileResponse?['name'] ?? 'Unknown User',
            'avatar': profileResponse?['profile_pic_url'],
            'university': profileResponse?['university'],
            'course': profileResponse?['course'],
            'requested_at': json['created_at'],
          });
        } catch (e) {
          // Add with default values
          pendingRequests.add({
            'user_id': json['user_id'],
            'name': 'Unknown User',
            'avatar': null,
            'university': null,
            'course': null,
            'requested_at': json['created_at'],
          });
        }
      }

      return pendingRequests;
    } catch (e) {
      throw Exception('Failed to get pending requests: $e');
    }
  }

  // Accept a pending request (organizer only)
  static Future<bool> acceptRequest(String eventId, String userId) async {
    try {
      if (currentUserId == null) {
        return false;
      }

      // First, verify that current user is the organizer
      final eventResponse = await _supabase
          .from('events')
          .select('organizer_id')
          .eq('id', eventId)
          .maybeSingle();

      if (eventResponse == null) {
        return false;
      }

      if (eventResponse['organizer_id'] != currentUserId) {
        return false;
      }

      // Update status to approved
      final response = await _supabase
          .from('event_attendees')
          .update({'status': 'approved'})
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'pending');

      return true;
    } catch (e) {
      throw Exception('Failed to accept request: $e');
    }
  }

  // Reject a pending request (organizer only)
  static Future<bool> rejectRequest(String eventId, String userId) async {
    try {
      if (currentUserId == null) {
        return false;
      }

      // First, verify that current user is the organizer
      final eventResponse = await _supabase
          .from('events')
          .select('organizer_id')
          .eq('id', eventId)
          .maybeSingle();

      if (eventResponse == null) {
        return false;
      }

      if (eventResponse['organizer_id'] != currentUserId) {
        return false;
      }

      // Delete the rejected request
      final response = await _supabase
          .from('event_attendees')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'pending');

      return true;
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // Alias methods for backward compatibility
  static Future<bool> approveAttendee(String eventId, String userId) async {
    return acceptRequest(eventId, userId);
  }

  static Future<bool> rejectAttendee(String eventId, String userId) async {
    return rejectRequest(eventId, userId);
  }
}
