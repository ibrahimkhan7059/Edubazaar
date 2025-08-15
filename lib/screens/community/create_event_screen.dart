import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Added for File
import '../../core/theme.dart';
import '../../services/community_service.dart';
import '../../services/image_service.dart';
import 'package:geolocator/geolocator.dart';
import 'map_picker_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationDetailsController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _maxAttendeesController = TextEditingController(text: '50');
  final _meetingLinkController = TextEditingController();

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String _selectedCategory = 'Study Session';
  bool _isPublic = true;
  bool _requiresApproval = false;
  XFile? _selectedImage;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  bool _isCreating = false;

  final List<String> _categories = [
    'Study Session',
    'Workshop',
    'Seminar',
    'Career Fair',
    'Networking',
    'Social',
    'Competition',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _locationDetailsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _maxAttendeesController.dispose();
    _meetingLinkController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createEvent,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Create',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Image
              _buildImageSection(),
              const SizedBox(height: 24),

              // Basic Information
              _buildSectionTitle('Event Details'),
              const SizedBox(height: 16),
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildCategoryField(),
              const SizedBox(height: 24),

              // Date and Time
              _buildSectionTitle('Date & Time'),
              const SizedBox(height: 16),
              _buildDateTimeFields(),
              const SizedBox(height: 24),

              // Location
              _buildSectionTitle('Location'),
              const SizedBox(height: 16),
              _buildLocationFields(),
              const SizedBox(height: 24),

              // Event Settings
              _buildSectionTitle('Event Settings'),
              const SizedBox(height: 16),
              _buildSettingsFields(),
              const SizedBox(height: 24),

              // Tags
              _buildSectionTitle('Tags (Optional)'),
              const SizedBox(height: 16),
              _buildTagsSection(),
              const SizedBox(height: 24),

              // Meeting Link (Optional)
              _buildSectionTitle('Online Meeting Link (Optional)'),
              const SizedBox(height: 16),
              _buildMeetingLinkField(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_selectedImage!.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImagePlaceholder();
                  },
                ),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'Add Event Photo',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'Tap to upload image',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Event Title *',
        hintText: 'Enter event title',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter event title';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Description *',
        hintText: 'Describe your event...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter event description';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryField() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedCategory = value!);
      },
    );
  }

  Widget _buildDateTimeFields() {
    return Column(
      children: [
        // Start Date & Time
        GestureDetector(
          onTap: () => _selectDateTime(isStart: true),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date & Time *',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _startDateTime != null
                            ? _formatDateTime(_startDateTime!)
                            : 'Select start date and time',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _startDateTime != null
                              ? AppTheme.textPrimary
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // End Date & Time (Optional)
        GestureDetector(
          onTap: () => _selectDateTime(isStart: false),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date & Time (Optional)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _endDateTime != null
                            ? _formatDateTime(_endDateTime!)
                            : 'Select end date and time',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _endDateTime != null
                              ? AppTheme.textPrimary
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      children: [
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Location *',
            hintText: 'Enter event location',
            prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter event location';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g., 33.6844',
                  prefixIcon:
                      Icon(Icons.gps_fixed, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g., 73.0479',
                  prefixIcon:
                      Icon(Icons.gps_fixed, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location, size: 18),
            label: Text(
              'Get Current Location',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapPickerScreen(
                    initialLat: double.tryParse(_latitudeController.text),
                    initialLon: double.tryParse(_longitudeController.text),
                  ),
                ),
              );
              if (result is Map && mounted) {
                final lat = (result['lat'] as num).toDouble();
                final lon = (result['lon'] as num).toDouble();
                setState(() {
                  _latitudeController.text = lat.toStringAsFixed(6);
                  _longitudeController.text = lon.toStringAsFixed(6);
                });
              }
            },
            icon: const Icon(Icons.map, size: 18),
            label: Text(
              'Pick on Map',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsFields() {
    return Column(
      children: [
        TextFormField(
          controller: _maxAttendeesController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Maximum Attendees *',
            hintText: 'Enter maximum number of attendees',
            prefixIcon: Icon(Icons.people, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter maximum attendees';
            }
            final number = int.tryParse(value);
            if (number == null || number < 1) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Privacy Settings
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(
                'Public Event',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Anyone can see and join this event',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                  // If making public, disable requires approval
                  if (value) {
                    _requiresApproval = false;
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primaryColor,
            ),
            SwitchListTile(
              title: Text(
                'Requires Approval',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _isPublic
                    ? 'Public events cannot require approval'
                    : 'You need to approve attendees',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _isPublic ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              value: _requiresApproval,
              onChanged: _isPublic
                  ? null
                  : (value) {
                      setState(() {
                        _requiresApproval = value;
                        // If requiring approval, make private
                        if (value) {
                          _isPublic = false;
                        }
                      });
                    },
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primaryColor,
              inactiveThumbColor: _isPublic ? Colors.grey[300] : null,
              inactiveTrackColor: _isPublic ? Colors.grey[200] : null,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPublic
                          ? 'Public events allow anyone to join immediately without approval.'
                          : 'Private events require your approval before attendees can join.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            Expanded(
              child: TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Add Tag',
                  hintText: 'Type tag and press Enter',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onFieldSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagController.text),
              icon: Icon(Icons.add, color: AppTheme.primaryColor),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tags.isNotEmpty) ...[
          Text(
            'Selected Tags:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                deleteIcon: Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                onDeleted: () => _removeTag(tag),
                side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMeetingLinkField() {
    return TextFormField(
      controller: _meetingLinkController,
      decoration: InputDecoration(
        labelText: 'Meeting Link',
        hintText: 'Zoom, Google Meet, Teams link...',
        prefixIcon: Icon(Icons.video_call, color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final uri = Uri.tryParse(value);
          if (uri == null || !uri.hasAbsolutePath) {
            return 'Please enter a valid URL';
          }
        }
        return null;
      },
    );
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null && mounted) {
      final TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null && mounted) {
        final dateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        setState(() {
          if (isStart) {
            _startDateTime = dateTime;
            // Clear end time if it's before start time
            if (_endDateTime != null && _endDateTime!.isBefore(dateTime)) {
              _endDateTime = null;
            }
          } else {
            if (_startDateTime != null && dateTime.isAfter(_startDateTime!)) {
              _endDateTime = dateTime;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('End time must be after start time'),
                ),
              );
            }
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
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

    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$month $day, $year at ${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $amPm';
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate privacy settings
    if (_isPublic && _requiresApproval) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Public events cannot require approval. Please adjust your settings.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date and time')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        // Upload image
        imageUrl = await ImageService.uploadEventImage(_selectedImage!);
      }

      final event = await CommunityService.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startDateTime: _startDateTime!,
        endDateTime: _endDateTime,
        location: _locationController.text.trim(),
        locationDetails: _composeLocationDetails(),
        category: _selectedCategory,
        maxAttendees: int.parse(_maxAttendeesController.text),
        isPublic: _isPublic,
        requiresApproval: _requiresApproval,
        tags: _tags.isEmpty ? null : _tags,
        meetingLink: _meetingLinkController.text.trim().isEmpty
            ? null
            : _meetingLinkController.text.trim(),
        imageUrl: imageUrl,
      );

      if (event != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  String? _composeLocationDetails() {
    final details = _locationDetailsController.text.trim();
    final lat = _latitudeController.text.trim();
    final lon = _longitudeController.text.trim();
    if (lat.isNotEmpty && lon.isNotEmpty) {
      final coords = 'coords=$lat,$lon';
      return details.isEmpty ? coords : '$details || $coords';
    }
    return details.isEmpty ? null : details;
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final opened = await Geolocator.openLocationSettings();
        if (!opened) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable Location Services to continue.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission denied. Please allow to auto-fill coordinates.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission permanently denied. Enable it from app settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        await Geolocator.openAppSettings();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _latitudeController.text = pos.latitude.toStringAsFixed(6);
          _longitudeController.text = pos.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordinates filled from current location.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
