import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/study_group.dart';
import '../../services/community_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';

class GroupMembersScreen extends StatefulWidget {
  final StudyGroup group;

  const GroupMembersScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = AuthService.getCurrentUser()?.id;
    _loadMembers();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin =
          await CommunityService.isGroupAdmin(widget.group.id, _currentUserId!);
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      // Error checking admin status handled silently
    }
  }

  Future<void> _loadMembers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final members = await CommunityService.getGroupMembers(widget.group.id);

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  // Helper method to get profile image URL from member data
  String? _getProfileImageUrl(Map<String, dynamic> member) {
    final profilePicUrl = member['profilePicUrl'] ?? member['profile_pic_url'];
    if (profilePicUrl != null && profilePicUrl.toString().isNotEmpty) {
      return profilePicUrl.toString();
    }
    return null;
  }

  // Helper method to get first letter of name for default avatar
  String _getFirstLetter(dynamic name) {
    if (name != null && name.toString().isNotEmpty) {
      return name.toString().substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    try {
      await CommunityService.removeGroupMember(widget.group.id, memberId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$memberName removed from group')),
        );
        _loadMembers(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  void _showRemoveMemberDialog(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Member'),
          content: Text(
              'Are you sure you want to remove $memberName from this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeMember(memberId, memberName);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Group Members'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        systemOverlayStyle: AppTheme.systemUiOverlayStyle,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMembersScreen(group: widget.group),
                  ),
                ).then((_) => _loadMembers());
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Member count header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(Icons.people, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '${_members.length} member${_members.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Members list
                Expanded(
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member['user_id'] == _currentUserId;
                      final isAdmin = member['role'] == 'admin';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _getProfileImageUrl(member) != null
                              ? NetworkImage(_getProfileImageUrl(member)!)
                              : null,
                          child: _getProfileImageUrl(member) == null
                              ? Text(
                                  _getFirstLetter(member['name']),
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member['name'] ?? 'Unknown User',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          member['email'] ?? 'No email',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: _isAdmin && !isCurrentUser && !isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () => _showRemoveMemberDialog(
                                  member['user_id'],
                                  member['name'] ?? 'Unknown User',
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class AddMembersScreen extends StatefulWidget {
  final StudyGroup group;

  const AddMembersScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedUsers = [];
  bool _isSearching = false;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      setState(() {
        _isSearching = true;
      });

      final results = await CommunityService.searchUsers(query);

      // Filter out users who are already members
      final currentMembers =
          await CommunityService.getGroupMembers(widget.group.id);
      final currentMemberIds = currentMembers.map((m) => m['user_id']).toSet();

      final filteredResults = results
          .where((user) => !currentMemberIds.contains(user['id']))
          .toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching users: $e')),
        );
      }
    }
  }

  void _toggleUserSelection(Map<String, dynamic> user) {
    setState(() {
      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
      if (isSelected) {
        _selectedUsers.removeWhere((u) => u['id'] == user['id']);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedUsers.isEmpty) return;

    try {
      setState(() {
        _isAdding = true;
      });

      for (final user in _selectedUsers) {
        await CommunityService.addGroupMember(
          widget.group.id,
          user['id'],
          'member', // Default role
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedUsers.length} member${_selectedUsers.length == 1 ? '' : 's'} added to group'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isAdding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding members: $e')),
        );
      }
    }
  }

  // Helper method to get profile image URL from user data
  String? _getProfileImageUrl(Map<String, dynamic> user) {
    final profilePicUrl = user['profilePicUrl'] ?? user['profile_pic_url'];
    if (profilePicUrl != null && profilePicUrl.toString().isNotEmpty) {
      return profilePicUrl.toString();
    }
    return null;
  }

  // Helper method to get first letter of name for default avatar
  String _getFirstLetter(dynamic name) {
    if (name != null && name.toString().isNotEmpty) {
      return name.toString().substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Add Members'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        systemOverlayStyle: AppTheme.systemUiOverlayStyle,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _isAdding ? null : _addSelectedMembers,
              child: _isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Add (${_selectedUsers.length})',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),

          // Selected users count
          if (_selectedUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedUsers.length} user${_selectedUsers.length == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Search results
          Expanded(
            child: _searchResults.isEmpty && _searchController.text.isNotEmpty
                ? Center(
                    child: Text(
                      _isSearching ? 'Searching...' : 'No users found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      final isSelected =
                          _selectedUsers.any((u) => u['id'] == user['id']);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _getProfileImageUrl(user) != null
                              ? NetworkImage(_getProfileImageUrl(user)!)
                              : null,
                          child: _getProfileImageUrl(user) == null
                              ? Text(
                                  _getFirstLetter(user['name']),
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(user['name'] ?? 'Unknown User'),
                        subtitle: Text(user['email'] ?? 'No email'),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleUserSelection(user),
                        ),
                        onTap: () => _toggleUserSelection(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
