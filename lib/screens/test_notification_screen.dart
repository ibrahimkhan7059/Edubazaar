import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/push_notification_tester.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestNotificationScreen extends StatefulWidget {
  const TestNotificationScreen({super.key});

  @override
  State<TestNotificationScreen> createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _systemStatus;
  Map<String, dynamic>? _lastTestResults;

  @override
  void initState() {
    super.initState();
    _loadSystemStatus();
  }

  Future<void> _loadSystemStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await PushNotificationTester.getSystemStatus();
      setState(() => _systemStatus = status);
    } catch (e) {
      // Error loading system status handled silently
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runFullTest() async {
    setState(() => _isLoading = true);
    try {
      final results = await PushNotificationTester.testPushNotificationFlow();
      setState(() => _lastTestResults = results);

      if (mounted) {
        PushNotificationTester.showTestResults(context, results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.showLocalNotification(
        title: '🧪 Local Test Notification',
        body:
            'This is a test of local notifications. Time: ${DateTime.now().toString().substring(11, 19)}',
        payload: 'test_local',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local test notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testEdgeFunction() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'notify-chat',
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Edge Function Response'),
            content: SingleChildScrollView(
              child: Text(response.data.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Edge Function test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFCMToken() async {
    setState(() => _isLoading = true);
    try {
      await NotificationService.checkAndUpdateFCMToken();
      final token = await NotificationService.getDeviceToken();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('FCM Token'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Token (first 50 chars):'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    token?.substring(0, 50) ?? 'No token',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Length: ${token?.length ?? 0} characters'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('FCM token check failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Notification Testing',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSystemStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // System Status Card
                _buildSystemStatusCard(),
                const SizedBox(height: 16),

                // Quick Actions Card
                _buildQuickActionsCard(),
                const SizedBox(height: 16),

                // Test Results Card
                if (_lastTestResults != null) ...[
                  _buildTestResultsCard(),
                  const SizedBox(height: 16),
                ],

                // Advanced Testing Card
                _buildAdvancedTestingCard(),
              ],
            ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                  children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                    Text(
                  'System Status',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            if (_systemStatus != null) ...[
              _buildStatusItem(
                'User Authenticated',
                _systemStatus!['user_authenticated'] == true,
              ),
              _buildStatusItem(
                'FCM Tokens',
                (_systemStatus!['fcm_tokens']?['count'] ?? 0) > 0,
                subtitle:
                    '${_systemStatus!['fcm_tokens']?['count'] ?? 0} tokens',
              ),
              _buildStatusItem(
                'Notification Settings',
                _systemStatus!['notification_settings'] != null,
                subtitle: _systemStatus!['notification_settings'] != null
                    ? 'Configured'
                    : 'Not configured',
              ),
              _buildStatusItem(
                'Recent Notifications',
                (_systemStatus!['recent_notifications']?['count'] ?? 0) >= 0,
                subtitle:
                    '${_systemStatus!['recent_notifications']?['count'] ?? 0} notifications',
              ),
            ] else
              const Text('Loading system status...'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_arrow, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                      style: GoogleFonts.poppins(
                    fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  'Run Full Test',
                  Icons.play_circle_filled,
                  Colors.green,
                  _runFullTest,
                ),
                _buildActionButton(
                  'Local Notification',
                  Icons.notifications,
                  Colors.blue,
                  _sendTestNotification,
                ),
                _buildActionButton(
                  'Check FCM Token',
                  Icons.token,
                  Colors.orange,
                  _checkFCMToken,
                ),
                _buildActionButton(
                  'Test Edge Function',
                  Icons.cloud,
                  Colors.purple,
                  _testEdgeFunction,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    final results = _lastTestResults!;
    final success = results['overall_success'] == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last Test Results',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              results['summary'] ?? 'No summary available',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: success ? Colors.green[700] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Test time: ${results['timestamp']}',
                      style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTestingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Advanced Testing',
                      style: GoogleFonts.poppins(
                    fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAdvancedTestTile(
              'Database Tables',
              'Check if all required tables exist',
              Icons.storage,
              () => _showDatabaseInfo(),
            ),
            _buildAdvancedTestTile(
              'Notification Queue',
              'Check pending notifications in queue',
              Icons.queue,
              () => _showQueueInfo(),
            ),
            _buildAdvancedTestTile(
              'User Settings',
              'View current notification preferences',
              Icons.tune,
              () => _showSettingsInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, bool isGood, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.error,
            color: isGood ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                if (subtitle != null)
                    Text(
                    subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildAdvancedTestTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showDatabaseInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Information'),
        content: Text(_systemStatus.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQueueInfo() async {
    try {
      final queueData = await Supabase.instance.client
          .from('notification_queue')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notification Queue'),
            content: SingleChildScrollView(
              child: Text(queueData.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showSettingsInfo() {
    final settings = _systemStatus?['notification_settings'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Text(settings?.toString() ?? 'No settings found'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
