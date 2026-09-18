import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/incident_report.dart';
import '../../../services/incident_service.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/auth_dialog.dart';
import '../../settings/settings_screen.dart';

class LovableProfileTab extends StatefulWidget {
  const LovableProfileTab({super.key});

  @override
  State<LovableProfileTab> createState() => _LovableProfileTabState();
}

class _LovableProfileTabState extends State<LovableProfileTab> {
  final _locationService = LocationService();
  final _picker = ImagePicker();
  final _descriptionController = TextEditingController();

  String? _imagePath;
  double? _latitude;
  double? _longitude;
  String _locationName = 'Infopark Expressway, Kakkanad';
  String _coordinates = '10.0159° N, 76.3419° E';
  bool _isGettingLocation = false;
  bool _isSubmitting = false;

  final List<String> _incidentTypes = [
    'Flood',
    'Landslide',
    'Fallen Tree',
    'Road Damage',
  ];
  String _selectedIncidentType = 'Flood';

  bool _autoReroute = true;
  bool _audioWarnings = true;
  bool _sosAlerts = true;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationName = 'Current GPS Position';
          _coordinates =
              '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E';
        });
      }
    } catch (_) {
      // Keep defaults
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1024);
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera/gallery.')),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      // Auto-authenticate as anonymous guest if not signed in (minimal effort demo)
      if (!SupabaseService.instance.isAuthenticated) {
        await SupabaseService.instance.signInAnonymously();
      }

      String? photoUrl;
      if (_imagePath != null) {
        photoUrl = await SupabaseService.instance.uploadIncidentPhoto(File(_imagePath!));
      }

      final report = IncidentReport(
        incidentType: _selectedIncidentType,
        description: _descriptionController.text.trim().isEmpty
            ? 'Hazard reported via Safety Hub'
            : _descriptionController.text.trim(),
        latitude: _latitude ?? 10.0159,
        longitude: _longitude ?? 76.3419,
        imagePath: _imagePath,
        photoUrl: photoUrl,
        locationName: _locationName,
        reportedAt: DateTime.now(),
      );

      await IncidentService.instance.submitReport(report);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _imagePath = null;
          _descriptionController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Hazard broadcast to Supabase PostGIS & Route Risk Engine!'),
                ),
              ],
            ),
            backgroundColor: AppColors.lovableGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved locally: $e'),
            backgroundColor: AppColors.riskModerate,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Traveler Profile Card
              _buildProfileCard(),
              const SizedBox(height: 18),

              // Safety Impact 3-Card Stat Bar
              _buildImpactStats(),
              const SizedBox(height: 26),

              // Integrated Incident Reporting Card (Lovable Report UI)
              _buildIncidentReportingSection(),
              const SizedBox(height: 26),

              // Safety Preferences & Toggles
              _buildSafetyPreferences(),
              const SizedBox(height: 20),

              // App Settings & Theme Card
              _buildSettingsActionCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRAVELER PROFILE & SAFETY HUB',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Midhun's Safety Hub",
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your driver safety profile, trip impact, and road hazard reports.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings & Theme',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          icon: const Icon(
            Icons.settings_outlined,
            color: AppColors.lovableTeal,
            size: 22,
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceFor(context),
            padding: const EdgeInsets.all(10),
            side: BorderSide(color: AppColors.borderFor(context)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.riskCritical, size: 22),
            SizedBox(width: 10),
            Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your active JourneyGuard session? You will be returned to the login screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.riskCritical,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await SupabaseService.instance.signOut();
    }
  }

  Widget _buildProfileCard() {
    final userEmail = SupabaseService.instance.userEmail;
    final isAnon = SupabaseService.instance.isAnonymous;
    final isAuthed = SupabaseService.instance.isAuthenticated;

    final displayName = isAuthed
        ? (isAnon ? 'Guest Commuter (Demo)' : (userEmail?.split('@').first ?? 'Commuter'))
        : 'Midhun';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  gradient: AppColors.lovableGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // User Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isAuthed ? AppColors.lovableGreen : AppColors.accentIndigo)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAuthed ? (isAnon ? 'Guest Demo' : 'Verified') : 'Demo',
                            style: TextStyle(
                              color: isAuthed ? AppColors.lovableGreen : AppColors.accentIndigo,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Logged in User's Email
                    if (userEmail != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 13, color: AppColors.lovableTeal),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              userEmail,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.lovableTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      isAuthed
                          ? (isAnon ? 'Anonymous Guest Session (SIH Demo)' : 'Authenticated Supabase User')
                          : 'Sedan · Kerala Highway Commuter',
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Safety Rating Bar
          const Row(
            children: [
              Icon(Icons.shield, size: 14, color: AppColors.lovableGreen),
              SizedBox(width: 5),
              Text(
                'Safety Rating: 98/100 (Safe Traveler)',
                style: TextStyle(
                  color: AppColors.lovableGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Logout or Switch Account Buttons
          if (isAuthed) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.riskCritical),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.riskCritical,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.riskCritical.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ] else ...[
            InkWell(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const AuthDialog(),
                );
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderFor(context)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.lovableTeal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sign In / 1-Tap Guest Access (Demo)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile('42', 'Journeys\nProtected', AppColors.lovableTeal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile('18', 'Hazards\nAvoided', AppColors.lovableGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile('3', 'Incidents\nReported', AppColors.accentIndigo),
        ),
      ],
    );
  }

  Widget _buildStatTile(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentReportingSection() {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPORT ROAD HAZARD',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Notify nearby drivers in real-time',
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.riskModerate.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.riskModerate,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Photo Upload Area
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C1322) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E3D56) : AppColors.borderFor(context),
                  style: BorderStyle.solid,
                ),
              ),
              child: _imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        File(_imagePath!),
                        width: double.infinity,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.lovableTeal,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add a clear photo of hazard',
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to open camera or gallery',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Location Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C1322) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : AppColors.borderFor(context),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: AppColors.lovableGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _locationName,
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _coordinates,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18, color: AppColors.lovableTeal),
                  onPressed: _isGettingLocation ? null : _fetchCurrentLocation,
                  tooltip: 'Update GPS',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Incident Type Chips
          const Text(
            'SELECT HAZARD CATEGORY',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _incidentTypes.map((type) {
              final isSelected = _selectedIncidentType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedIncidentType = type);
                  }
                },
                selectedColor: isDark
                    ? AppColors.lovableGreen.withValues(alpha: 0.2)
                    : AppColors.lightTeal.withValues(alpha: 0.15),
                backgroundColor: isDark ? const Color(0xFF0C1322) : const Color(0xFFF8FAFC),
                labelStyle: TextStyle(
                  color: isSelected
                      ? (isDark ? AppColors.lovableGreen : AppColors.lightTeal)
                      : (isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSecondary),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? (isDark ? AppColors.lovableGreen : AppColors.lightTeal)
                      : (isDark ? const Color(0xFF243248) : AppColors.borderFor(context)),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Optional Description
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: AppColors.textPrimaryFor(context), fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF0C1322) : Colors.white,
              hintText: 'Notes: e.g. Water depth ~1.5 ft, right lane blocked...',
              hintStyle: TextStyle(color: AppColors.textMutedFor(context), fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderFor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderFor(context)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.lovableTeal),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.lovableGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lovableGreen.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Submit Incident Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyPreferences() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SAFETY PREFERENCES',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          _buildSwitchTile(
            title: 'Auto-Reroute on Severe Weather',
            subtitle: 'Automatically select alternative corridor if flood risk > 50%',
            value: _autoReroute,
            onChanged: (val) => setState(() => _autoReroute = val),
          ),
          Divider(color: AppColors.borderFor(context), height: 16),
          _buildSwitchTile(
            title: 'Spoken Hazard Warnings',
            subtitle: 'Audio alerts before approaching hazardous curves or waterlogging',
            value: _audioWarnings,
            onChanged: (val) => setState(() => _audioWarnings = val),
          ),
          Divider(color: AppColors.borderFor(context), height: 16),
          _buildSwitchTile(
            title: 'Emergency SOS Broadcast',
            subtitle: 'Send live telemetry to emergency contacts if collision detected',
            value: _sosAlerts,
            onChanged: (val) => setState(() => _sosAlerts = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimaryFor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.lovableGreen,
          activeTrackColor: AppColors.lovableGreen.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildSettingsActionCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderFor(context)),
          boxShadow: AppColors.cardShadowFor(context),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lovableTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.palette_outlined,
                color: AppColors.lovableTeal,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Settings & Theme',
                    style: TextStyle(
                      color: AppColors.textPrimaryFor(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Dark / Light mode, alerts & preferences',
                    style: TextStyle(
                      color: AppColors.textSecondaryFor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryFor(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
