import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../models/listing.dart';
import '../../services/marketplace_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _editionController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _pickupLocationController =
      TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // Form Data
  ListingType? _selectedType;
  ListingCategory? _selectedCategory;
  ListingCondition? _selectedCondition;
  bool _isDonation = false;
  // Shipping removed per requirements
  final List<File> _selectedImages = [];
  List<String> _tags = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _authorController.dispose();
    _editionController.dispose();
    _courseCodeController.dispose();
    _universityController.dispose();
    _pickupLocationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _tagsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Listing',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildStepIndicator(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentStep = index);
          },
          children: [
            _buildBasicInfoStep(),
            _buildDetailsStep(),
            _buildImagesAndLocationStep(),
            _buildReviewStep(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.successColor
                        : isActive
                            ? AppTheme.primaryColor
                            : AppTheme.textHint.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: index < _currentStep
                          ? AppTheme.successColor
                          : AppTheme.textHint.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your item',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          _buildTextFormField(
            controller: _titleController,
            label: 'Title',
            hint: 'e.g., Calculus Textbook',
            isRequired: true,
          ),
          const SizedBox(height: 20),

          // Description
          _buildTextFormField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your item...',
            maxLines: 4,
            isRequired: true,
          ),
          const SizedBox(height: 20),

          // Type Selection
          _buildDropdownField<ListingType>(
            label: 'Type',
            value: _selectedType,
            items: ListingType.values,
            onChanged: (value) => setState(() => _selectedType = value),
            itemBuilder: (type) => Text(type.displayName),
            isRequired: true,
          ),
          const SizedBox(height: 20),

          // Category Selection
          _buildDropdownField<ListingCategory>(
            label: 'Category',
            value: _selectedCategory,
            items: ListingCategory.values,
            onChanged: (value) => setState(() => _selectedCategory = value),
            itemBuilder: (category) => Text(category.displayName),
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item Details',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide specific details about your item',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Donation Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.textHint.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism,
                    color: AppTheme.donationColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Donation',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Give away for free to help fellow students',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isDonation,
                  onChanged: (value) {
                    setState(() {
                      _isDonation = value;
                      if (value) {
                        _priceController.clear();
                      }
                    });
                  },
                  activeColor: AppTheme.donationColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Price (if not donation)
          if (!_isDonation) ...[
            _buildTextFormField(
              controller: _priceController,
              label: 'Price (Rs.)',
              hint: '0.00',
              keyboardType: TextInputType.number,
              isRequired: !_isDonation,
            ),
            const SizedBox(height: 20),
          ],

          // Condition
          _buildDropdownField<ListingCondition>(
            label: 'Condition',
            value: _selectedCondition,
            items: ListingCondition.values,
            onChanged: (value) => setState(() => _selectedCondition = value),
            itemBuilder: (condition) => Text(condition.displayName),
            isRequired: true,
          ),
          const SizedBox(height: 20),

          // Additional fields based on type
          if (_selectedType == ListingType.book) ...[
            _buildTextFormField(
              controller: _authorController,
              label: 'Author',
              hint: 'Book author',
            ),
            const SizedBox(height: 20),
            _buildTextFormField(
              controller: _editionController,
              label: 'Edition',
              hint: 'e.g., 3rd Edition',
            ),
            const SizedBox(height: 20),
          ],

          if (_selectedType == ListingType.notes ||
              _selectedType == ListingType.pastPapers) ...[
            _buildTextFormField(
              controller: _courseCodeController,
              label: 'Course Code',
              hint: 'e.g., MATH 101',
            ),
            const SizedBox(height: 20),
            _buildTextFormField(
              controller: _universityController,
              label: 'University',
              hint: 'Your university name',
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildImagesAndLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos & Location',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add photos and pickup details',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Image Upload Section
          Text(
            'Photos (Required)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'At least one photo is required to create a listing',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Image Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                return _buildAddImageCard();
              }
              return _buildImageCard(_selectedImages[index], index);
            },
          ),

          // Warning message when no photos selected
          if (_selectedImages.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please add at least one photo to continue',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Pickup Location
          _buildTextFormField(
            controller: _pickupLocationController,
            label: 'Pickup Location',
            hint: 'e.g., Main Library, Engineering Building',
            isRequired: true,
          ),
          const SizedBox(height: 20),

          // Location Coordinates
          Text(
            'Location Coordinates (Optional)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add exact coordinates for precise location',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Coordinates Row
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _latitudeController,
                  label: 'Latitude',
                  hint: 'e.g., 33.6844',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextFormField(
                  controller: _longitudeController,
                  label: 'Longitude',
                  hint: 'e.g., 73.0479',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Get Current Location Button
          Center(
            child: OutlinedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(
                'Get Current Location',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Shipping option removed
          const SizedBox(height: 0),

          // Tags
          _buildTextFormField(
            controller: _tagsController,
            label: 'Tags (Optional)',
            hint: 'physics, textbook, calculus (separate with commas)',
            onChanged: (value) {
              _tags = value
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Submit',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your listing before publishing',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Preview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _titleController.text,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Price
                Text(
                  _isDonation ? 'FREE' : 'Rs. ${_priceController.text}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isDonation
                        ? AppTheme.donationColor
                        : AppTheme.priceColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Type and Category
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedType?.displayName ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedCategory?.displayName ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Condition
                if (_selectedCondition != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppTheme.textHint),
                      const SizedBox(width: 8),
                      Text(
                        'Condition: ${_selectedCondition!.displayName}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                Text(
                  _descriptionController.text,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: AppTheme.textHint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickupLocationController.text,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ),
                  ],
                ),

                // Coordinates (if provided)
                if (_latitudeController.text.isNotEmpty &&
                    _longitudeController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Coordinates: ${_latitudeController.text}, ${_longitudeController.text}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Shipping info removed

                // Images count
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library,
                            size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedImages.length} photo${_selectedImages.length > 1 ? 's' : ''} added',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tags
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.textHint.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$tag',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageCard() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        decoration: BoxDecoration(
          color: _selectedImages.isEmpty
              ? Colors.red.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedImages.isEmpty
                ? Colors.red.withOpacity(0.5)
                : AppTheme.primaryColor.withOpacity(0.3),
            style: BorderStyle.solid,
            width: _selectedImages.isEmpty ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedImages.isEmpty
                  ? Icons.warning
                  : Icons.add_photo_alternate,
              color: _selectedImages.isEmpty
                  ? Colors.red[700]
                  : AppTheme.primaryColor,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              _selectedImages.isEmpty ? 'Photo Required' : 'Add Photo',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _selectedImages.isEmpty
                    ? Colors.red[700]
                    : AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(File image, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: FileImage(image),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImages.removeAt(index);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$label is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required Widget Function(T) itemBuilder,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: itemBuilder(item),
                  ))
              .toList(),
          validator: isRequired
              ? (value) {
                  if (value == null) {
                    return '$label is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == 3 ? 'Publish Listing' : 'Next',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textOnPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _submitListing();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _titleController.text.isNotEmpty &&
            _descriptionController.text.isNotEmpty &&
            _selectedType != null &&
            _selectedCategory != null;
      case 1:
        return (_isDonation || _priceController.text.isNotEmpty) &&
            _selectedCondition != null;
      case 2:
        return _pickupLocationController.text.isNotEmpty &&
            _selectedImages.isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Get current location coordinates
  Future<void> _getCurrentLocation() async {
    try {
      // 1) Ensure location services are enabled
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

      // 2) Check permission
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

      // 3) Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
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

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for required photos
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one photo is required to create a listing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images using MarketplaceService with proper error handling
      List<String> imageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        try {
          final imageUrl =
              await MarketplaceService.uploadImage(_selectedImages[i]);

          // Only add non-empty URLs (in case storage bucket doesn't exist)
          if (imageUrl.isNotEmpty) {
            imageUrls.add(imageUrl);
          }
        } catch (e) {
          // Continue with other images even if one fails
        }
      }

      // Show a warning if some images failed to upload
      if (_selectedImages.isNotEmpty && imageUrls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Images could not be uploaded. Creating listing without images.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Create listing object
      final listing = Listing(
        id: '', // Will be set by Supabase
        userId: Supabase.instance.client.auth.currentUser?.id ?? 'anonymous',
        title: _titleController.text,
        description: _descriptionController.text,
        price: _isDonation ? null : double.tryParse(_priceController.text),
        type: _selectedType!,
        category: _selectedCategory!,
        condition: _selectedCondition,
        images: imageUrls,
        tags: _tags,
        subject: _selectedCategory!.displayName,
        author:
            _authorController.text.isNotEmpty ? _authorController.text : null,
        edition:
            _editionController.text.isNotEmpty ? _editionController.text : null,
        courseCode: _courseCodeController.text.isNotEmpty
            ? _courseCodeController.text
            : null,
        university: _universityController.text.isNotEmpty
            ? _universityController.text
            : null,
        pickupLocation: _pickupLocationController.text,
        latitude: _latitudeController.text.isNotEmpty
            ? double.tryParse(_latitudeController.text)
            : null,
        longitude: _longitudeController.text.isNotEmpty
            ? double.tryParse(_longitudeController.text)
            : null,
        allowShipping: false,
        status: ListingStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        views: 0,
        favorites: 0,
      );

      // Submit to Supabase
      await MarketplaceService.createListing(listing);

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating listing: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
