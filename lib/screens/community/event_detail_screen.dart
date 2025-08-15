import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/event.dart';
import '../../services/community_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _event;
  List<Map<String, dynamic>> _attendees = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  RealtimeChannel? _eventChannel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
    _subscribeRealtime();
    _addScrollListener();
  }

  void _addScrollListener() {
    _scrollController.addListener(() {
      // Maintain consistent system UI overlay style during scroll
      SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _eventChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      _eventChannel = client.channel('event_${widget.eventId}_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.eventId,
          ),
          callback: (payload) {
            if (mounted) _loadEventDetails();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.eventId,
          ),
          callback: (payload) {
            print('🗑️ Event deleted: ${widget.eventId}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This event has been deleted'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pop(); // Return to previous screen
            }
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_attendees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: widget.eventId,
          ),
          callback: (payload) {
            if (mounted) _loadEventDetails();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_attendees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: widget.eventId,
          ),
          callback: (payload) {
            if (mounted) _loadEventDetails();
          },
        )
        ..subscribe();
    } catch (e) {
      print('❌ Error setting up realtime subscription: $e');
    }
  }

  Future<void> _loadEventDetails() async {
    print('🔍 Loading event details for: ${widget.eventId}');
    setState(() => _isLoading = true);
    try {
      final event = await CommunityService.getEventById(widget.eventId);

      // If event is null (deleted), navigate back
      if (event == null) {
        print('❌ Event not found (likely deleted)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This event has been deleted'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _event = event;
      });

      // Load attendees
      final attendees =
          await CommunityService.getEventAttendees(widget.eventId);
      setState(() {
        _attendees = attendees;
      });

      // Load pending requests if user is organizer and event requires approval
      if (_event?.organizerId == CommunityService.currentUserId &&
          _event!.requiresApproval) {
        final pendingRequests =
            await CommunityService.getPendingRequests(widget.eventId);
        setState(() {
          _pendingRequests = pendingRequests;
        });
      }

      print('✅ Event loaded: ${event.title}');
      print('📊 Attendees count: ${attendees.length}');
    } catch (e) {
      print('❌ Error loading event details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
        // If there's an error loading the event, it might be deleted
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Event Details'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Event Details'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Event Not Found',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This event might have been deleted or you may not have permission to view it.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textHint,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  print('🔄 Retrying to load event: ${widget.eventId}');
                  _loadEventDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        top: false, // Let SliverAppBar handle the top safe area
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEventInfo(),
                    const SizedBox(height: 24),
                    _buildDescription(),
                    const SizedBox(height: 24),
                    _buildLocationInfo(),
                    const SizedBox(height: 24),
                    _buildOrganizerInfo(),
                    const SizedBox(height: 24),
                    _buildAttendeesSection(),
                    const SizedBox(height: 20),

                    // Pending Requests Section (for organizers only)
                    if (_event?.organizerId == CommunityService.currentUserId &&
                        _event!.requiresApproval)
                      _buildPendingRequestsSection(),
                    const SizedBox(height: 24),
                    if (_event!.tags != null && _event!.tags!.isNotEmpty)
                      _buildTagsSection(),
                    const SizedBox(height: 100),
                    // Extra padding to ensure bottom actions are visible
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      collapsedHeight: kToolbarHeight,
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: AppTheme.surfaceColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      systemOverlayStyle: AppTheme.systemUiOverlayStyle,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Add padding to keep image below status bar
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                child: ClipRect(
                  child: _event!.imageUrl != null
                      ? Image.network(
                          _event!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultHeader();
                          },
                        )
                      : _buildDefaultHeader(),
                ),
              ),
            ),
            // Add gradient overlay for better text visibility
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: (_event != null &&
                  _event!.organizerId == CommunityService.currentUserId)
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      _showDeleteEventDialog();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete Event',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDefaultHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.7)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.event, size: 64, color: Colors.white),
      ),
    );
  }

  Widget _buildEventInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Status
          Row(
            children: [
              Expanded(
                child: Text(
                  _event!.title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_event!.organizerId == CommunityService.currentUserId)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Organizer',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Category
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _event!.category,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date and Time
          _buildInfoRow(
            Icons.schedule,
            'Date & Time',
            _formatEventDateTime(_event!),
          ),
          const SizedBox(height: 12),

          // Duration
          if (_event!.endDateTime != null)
            _buildInfoRow(
              Icons.timelapse,
              'Duration',
              _formatDuration(_event!.duration),
            ),
          const SizedBox(height: 12),

          // Attendees
          _buildInfoRow(
            Icons.people,
            'Attendees',
            '${_event!.currentAttendees}/${_event!.maxAttendees} attending',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _event!.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Text(
                'Location',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _event!.location,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_event!.locationDetails != null) ...[
            const SizedBox(height: 8),
            Text(
              _event!.locationDetails!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            ..._buildCoordinatesBoxIfAny(_event!.locationDetails!),
          ],
          if (_event!.meetingLink != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // TODO: Open meeting link
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening meeting link...')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.video_call, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Join Online Meeting',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.launch, size: 16, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCoordinatesBoxIfAny(String details) {
    try {
      final idx = details.indexOf('coords=');
      if (idx == -1) return [];
      final coordStr =
          details.substring(idx + 7).split(RegExp(r'\s|\|\|')).first;
      final parts = coordStr.split(',');
      if (parts.length != 2) return [];
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat == null || lon == null) return [];
      return [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: GestureDetector(
            onTap: () {
              final url =
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Open in Maps',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    } catch (_) {
      return [];
    }
  }

  Widget _buildOrganizerInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organized by',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                backgroundImage: _event!.organizerAvatar != null
                    ? NetworkImage(_event!.organizerAvatar!)
                    : null,
                child: _event!.organizerAvatar == null
                    ? Text(
                        _event!.organizerName.isNotEmpty
                            ? _event!.organizerName
                                .substring(0, 1)
                                .toUpperCase()
                            : 'O',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _event!.organizerName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Event Organizer',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Attendees',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_attendees.length} attending',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (_event?.organizerId == CommunityService.currentUserId) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _showAllAttendeesList(),
                  child: Text(
                    'Manage',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_attendees.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No attendees yet',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _attendees.length > 15 ? 15 : _attendees.length,
              itemBuilder: (context, index) {
                if (index == 14 && _attendees.length > 15) {
                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          '+${_attendees.length - 14}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'more',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }

                final attendee = _attendees[index];
                final isOrganizer =
                    _event?.organizerId == CommunityService.currentUserId;

                return Stack(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: attendee['avatar'] != null
                              ? NetworkImage(attendee['avatar'])
                              : null,
                          child: attendee['avatar'] == null
                              ? Text(
                                  (attendee['name'] as String).isNotEmpty
                                      ? (attendee['name'] as String)
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          attendee['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Remove button for organizer (only show if not the organizer themselves)
                    if (isOrganizer &&
                        attendee['user_id'] != CommunityService.currentUserId)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: _isActionLoading
                              ? null
                              : () => _showRemoveAttendeeDialog(attendee),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color:
                                  _isActionLoading ? Colors.grey : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _isActionLoading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // Build pending requests section for organizers
  Widget _buildPendingRequestsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pending Requests',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingRequests.length} pending',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pendingRequests.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No pending requests',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                final request = _pendingRequests[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      // Profile picture
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: request['avatar'] != null
                            ? NetworkImage(request['avatar'])
                            : null,
                        child: request['avatar'] == null
                            ? Text(
                                (request['name'] as String).isNotEmpty
                                    ? (request['name'] as String)
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(width: 16),

                      // Request info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (request['university'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                request['university'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                            if (request['course'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                request['course'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Action buttons
                      Row(
                        children: [
                          // Accept button
                          IconButton(
                            onPressed: _isActionLoading
                                ? null
                                : () => _acceptRequest(request),
                            icon: Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 24,
                            ),
                            tooltip: 'Accept Request',
                          ),

                          // Reject button
                          IconButton(
                            onPressed: _isActionLoading
                                ? null
                                : () => _rejectRequest(request),
                            icon: Icon(
                              Icons.cancel,
                              color: Colors.red[600],
                              size: 24,
                            ),
                            tooltip: 'Reject Request',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tags',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _event!.tags!.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_event!.isPast) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Text(
            'This event has ended',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_event!.organizerId == CommunityService.currentUserId) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'You are the organizer',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else if (_event!.isAttending) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActionLoading ? null : _leaveEvent,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Leave Event',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                ),
              ),
            ] else if (_event!.attendeeStatus == 'pending') ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActionLoading ? null : _leaveEvent,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.orange, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Pending Approval',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                ),
              ),
            ] else if (_event!.canJoin) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _joinEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _event!.requiresApproval
                              ? 'Request to Join'
                              : 'Join Event',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Text(
                    _event!.isFull ? 'Event Full' : 'Cannot Join',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatEventDateTime(Event event) {
    final start = event.startDateTime;
    final end = event.endDateTime;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final day = start.day;
    final month = months[start.month - 1];
    final year = start.year;
    final startTime = _formatTime(start);

    if (end != null) {
      final endTime = _formatTime(end);
      return '$month $day, $year\n$startTime - $endTime';
    }

    return '$month $day, $year at $startTime';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $amPm';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  Future<void> _joinEvent() async {
    setState(() => _isActionLoading = true);
    try {
      final success = await CommunityService.joinEvent(_event!.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_event!.requiresApproval
                ? 'RSVP sent! Waiting for approval.'
                : 'Successfully joined the event!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadEventDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _leaveEvent() async {
    setState(() => _isActionLoading = true);
    try {
      final success = await CommunityService.leaveEvent(_event!.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully left the event'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadEventDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showDeleteEventDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(dialogContext);

              // Show loading
              if (!mounted) return;
              setState(() => _isActionLoading = true);

              try {
                final success = await CommunityService.deleteEvent(_event!.id);

                if (!mounted) return;

                if (success) {
                  print('✅ Event deleted successfully');

                  // Show success message and force navigation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Force navigation back with a slight delay
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  });
                } else {
                  print('❌ Failed to delete event');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete event'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                print('❌ Error deleting event: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (!mounted) return;
                setState(() => _isActionLoading = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Show attendee profile
  void _showAttendeeProfile(Map<String, dynamic> attendee) async {
    // Profile dialog removed - no action needed
    print('🔍 Profile dialog removed for attendee: ${attendee['name']}');
  }

  // Show remove attendee confirmation dialog
  void _showRemoveAttendeeDialog(Map<String, dynamic> attendee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Attendee',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${attendee['name']} from this event?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeAttendee(attendee);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remove attendee from event
  Future<void> _removeAttendee(Map<String, dynamic> attendee) async {
    try {
      setState(() => _isActionLoading = true);

      final success = await CommunityService.removeAttendee(
        widget.eventId,
        attendee['user_id'],
      );

      if (success) {
        // Refresh event details
        await _loadEventDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${attendee['name']} removed from event'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove attendee'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error removing attendee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing attendee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // Show all attendees in a list view for management
  void _showAllAttendeesList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Manage Attendees',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_attendees.length} attending',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Attendees list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _attendees.length,
                itemBuilder: (context, index) {
                  final attendee = _attendees[index];
                  final isCurrentUser =
                      attendee['user_id'] == CommunityService.currentUserId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        // Profile picture
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: attendee['avatar'] != null
                              ? NetworkImage(attendee['avatar'])
                              : null,
                          child: attendee['avatar'] == null
                              ? Text(
                                  (attendee['name'] as String).isNotEmpty
                                      ? (attendee['name'] as String)
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),

                        const SizedBox(width: 16),

                        // Attendee info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                attendee['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                attendee['status'] ?? 'approved',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        Row(
                          children: [
                            // Remove button (only for non-organizer attendees)
                            if (!isCurrentUser)
                              IconButton(
                                onPressed: _isActionLoading
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _showRemoveAttendeeDialog(attendee);
                                      },
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: 'Remove Attendee',
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveAttendee(Map<String, dynamic> attendee) async {
    setState(() => _isActionLoading = true);
    try {
      final success = await CommunityService.approveAttendee(
        widget.eventId,
        attendee['user_id'],
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${attendee['name']} approved for the event'),
            backgroundColor: Colors.green,
          ),
        );
        _loadEventDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving attendee: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _rejectAttendee(Map<String, dynamic> attendee) async {
    setState(() => _isActionLoading = true);
    try {
      final success = await CommunityService.rejectAttendee(
        widget.eventId,
        attendee['user_id'],
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${attendee['name']} rejected from the event'),
            backgroundColor: Colors.red,
          ),
        );
        _loadEventDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting attendee: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // Accept a pending request
  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      setState(() => _isActionLoading = true);

      final success = await CommunityService.acceptRequest(
        widget.eventId,
        request['user_id'],
      );

      if (success) {
        // Refresh event details
        await _loadEventDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${request['name']} accepted to event'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error accepting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // Reject a pending request
  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      setState(() => _isActionLoading = true);

      final success = await CommunityService.rejectRequest(
        widget.eventId,
        request['user_id'],
      );

      if (success) {
        // Refresh event details
        await _loadEventDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${request['name']} request rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reject request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error rejecting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }
}
