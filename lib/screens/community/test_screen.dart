import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/community_service.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final List<String> _testResults = [];
  bool _isRunningTests = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunningTests = true;
      _testResults.clear();
    });

    try {
      // Test 1: Check Supabase connection
      _addResult('🔍 Test 1: Checking Supabase connection...');
      final supabase = Supabase.instance.client;
      _addResult('✅ Supabase client initialized');

      // Test 2: Check authentication
      _addResult('🔍 Test 2: Checking authentication...');
      final user = supabase.auth.currentUser;
      if (user != null) {
        _addResult('✅ User authenticated: ${user.id}');
        _addResult('📧 Email: ${user.email}');
      } else {
        _addResult('❌ No user authenticated');
        _addResult('⚠️ Please login first');
        return;
      }

      // Test 3: Check database tables
      _addResult('🔍 Test 3: Checking database tables...');
      
      try {
        final studyGroupsResult = await supabase
            .from('study_groups')
            .select('count')
            .limit(1);
        _addResult('✅ study_groups table accessible');
      } catch (e) {
        _addResult('❌ study_groups table error: $e');
      }

      try {
        final forumTopicsResult = await supabase
            .from('forum_topics')
            .select('count')
            .limit(1);
        _addResult('✅ forum_topics table accessible');
      } catch (e) {
        _addResult('❌ forum_topics table error: $e');
      }

      try {
        final communityEventsResult = await supabase
            .from('community_events')
            .select('count')
            .limit(1);
        _addResult('✅ community_events table accessible');
      } catch (e) {
        _addResult('❌ community_events table error: $e');
      }

      try {
        final studyResourcesResult = await supabase
            .from('study_resources')
            .select('count')
            .limit(1);
        _addResult('✅ study_resources table accessible');
      } catch (e) {
        _addResult('❌ study_resources table error: $e');
      }

      // Test 4: Test creating a study group
      _addResult('🔍 Test 4: Testing study group creation...');
      try {
        final testGroupData = {
          'name': 'Test Group ${DateTime.now().millisecondsSinceEpoch}',
          'description': 'This is a test group',
          'subject': 'Test Subject',
          'is_private': false,
          'max_members': 50,
          'tags': ['test', 'debug'],
        };

        final groupId = await CommunityService.createStudyGroup(testGroupData);
        _addResult('✅ Study group created successfully! ID: $groupId');

        // Test 5: Test joining the group
        _addResult('🔍 Test 5: Testing group join...');
        await CommunityService.joinStudyGroup(groupId);
        _addResult('✅ Successfully joined the group');

        // Test 6: Test leaving the group
        _addResult('🔍 Test 6: Testing group leave...');
        await CommunityService.leaveStudyGroup(groupId);
        _addResult('✅ Successfully left the group');

      } catch (e) {
        _addResult('❌ Study group creation failed: $e');
      }

      // Test 7: Test creating a forum topic
      _addResult('🔍 Test 7: Testing forum topic creation...');
      try {
        final testTopicData = {
          'title': 'Test Topic ${DateTime.now().millisecondsSinceEpoch}',
          'content': 'This is a test forum topic',
          'category': 'Test Category',
          'tags': ['test', 'debug'],
        };

        final topicId = await CommunityService.createForumTopic(testTopicData);
        _addResult('✅ Forum topic created successfully! ID: $topicId');

      } catch (e) {
        _addResult('❌ Forum topic creation failed: $e');
      }

      // Test 8: Test getting data
      _addResult('🔍 Test 8: Testing data retrieval...');
      try {
        final myGroups = await CommunityService.getMyStudyGroups();
        _addResult('✅ Retrieved ${myGroups.length} my study groups');

        final discoverGroups = await CommunityService.getDiscoverStudyGroups();
        _addResult('✅ Retrieved ${discoverGroups.length} discover study groups');

        final forumTopics = await CommunityService.getForumTopics();
        _addResult('✅ Retrieved ${forumTopics.length} forum topics');

        final events = await CommunityService.getCommunityEvents();
        _addResult('✅ Retrieved ${events.length} community events');

        final resources = await CommunityService.getStudyResources();
        _addResult('✅ Retrieved ${resources.length} study resources');

      } catch (e) {
        _addResult('❌ Data retrieval failed: $e');
      }

      _addResult('🎉 All tests completed!');

    } catch (e) {
      _addResult('❌ Test failed with error: $e');
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add('${DateTime.now().toString().substring(11, 19)}: $result');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Test'),
        actions: [
          IconButton(
            onPressed: _isRunningTests ? null : _runTests,
            icon: _isRunningTests 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isRunningTests ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _isRunningTests ? Icons.sync : Icons.check_circle,
                  color: _isRunningTests ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isRunningTests ? 'Running tests...' : 'Tests completed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Results
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Text(
                    result,
                    style: TextStyle(
                      color: result.contains('❌') 
                        ? Colors.red 
                        : result.contains('✅') 
                          ? Colors.green 
                          : result.contains('⚠️') 
                            ? Colors.orange 
                            : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 