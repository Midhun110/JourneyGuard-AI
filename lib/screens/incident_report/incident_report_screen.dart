import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/incident_report.dart';
import '../../services/location_service.dart';
import '../../services/incident_service.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_card.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _locationService = LocationService();
  final _picker = ImagePicker();
  final _descriptionController = TextEditingController();

  String? _imagePath;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  String _selectedType = IncidentReport.incidentTypes.first;
  bool _isGettingLocation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    final pos = await _locationService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationName =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    }
    if (mounted) setState(() => _isGettingLocation = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (_) {}
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Photo', style: AppTypography.headlineMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedType.isEmpty) {
      _showError('Please select an incident type.');
      return;
    }

    setState(() => _isSubmitting = true);

    // Create report object
    final report = IncidentReport(
      imagePath: _imagePath,
      latitude: _latitude,
      longitude: _longitude,
      incidentType: _selectedType,
      description: _descriptionController.text.trim(),
      reportedAt: DateTime.now(),
      locationName: _locationName,
    );

    // Register with Module B & D incident service
    IncidentService.instance.addReport(report);

    // TODO: Submit to Supabase
    // await supabase.from('incidents').insert(report.toJson());
    debugPrint('Incident report added to IncidentService: ${report.toJson()}');

    await Future.delayed(const Duration(seconds: 1)); // Simulate API call

    if (mounted) {
      setState(() => _isSubmitting = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.riskLow.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.riskLow, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Report Submitted!', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Thank you for helping keep other travelers safe.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.riskHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Report Incident', style: AppTypography.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            _buildImageSection().animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 20),

            // Incident type
            _buildIncidentTypeSection()
                .animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // Location
            _buildLocationSection()
                .animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // Description
            _buildDescriptionSection()
                .animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 28),

            // Submit
            GradientButton(
              label: 'Submit Report',
              icon: Icons.send_rounded,
              onPressed: _isSubmitting ? null : _submitReport,
              isLoading: _isSubmitting,
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Incident Photo', style: AppTypography.headlineSmall),
        const SizedBox(height: 4),
        Text('Add a photo to help identify the hazard',
            style: AppTypography.bodySmall),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImageSourceSheet,
          child: _imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentIndigo.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.accentIndigo,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Tap to add photo',
                          style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildIncidentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Incident Type', style: AppTypography.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: IncidentReport.incidentTypes.map((type) {
            final isSelected = _selectedType == type;
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedType = type),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentIndigo.withOpacity(0.2),
              checkmarkColor: AppColors.accentIndigo,
              side: BorderSide(
                color: isSelected ? AppColors.accentIndigo : AppColors.border,
              ),
              labelStyle: AppTypography.labelLarge.copyWith(
                color: isSelected ? AppColors.accentIndigo : AppColors.textPrimary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Location', style: AppTypography.headlineSmall),
            GestureDetector(
              onTap: _getLocation,
              child: Text(
                'Refresh',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.accentIndigo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentIndigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isGettingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on_rounded,
                        color: AppColors.accentIndigo, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isGettingLocation ? 'Getting location...' : 'GPS Location',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _locationName ?? 'Location not available',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    if (_latitude != null && _longitude != null)
                      Text(
                        '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                        style: AppTypography.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: AppTypography.headlineSmall),
        const SizedBox(height: 4),
        Text('Briefly describe the incident (optional)',
            style: AppTypography.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: 'e.g., Major pothole on highway causing accidents...',
            hintStyle:
                AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.accentIndigo, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper ────────────────────────────────────────────────────────────────

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentIndigo, size: 28),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.labelLarge),
          ],
        ),
      ),
    );
  }
}
