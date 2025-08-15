import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'study_groups_screen.dart';
import 'forums_screen.dart';
import 'events_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex; // 0: Groups, 1: Forums, 2: Events

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: AppTheme.surfaceColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Groups'),
            Tab(text: 'Forums'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: TabBarView(
          controller: _tabController,
          children: const [
            StudyGroupsScreen(),
            ForumsScreen(),
            EventsScreen(),
          ],
        ),
      ),
    );
  }
}
