import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  final bool checkLocationPermission;

  const SettingsScreen({
    super.key,
    this.checkLocationPermission = true,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _permissionStatus = 'Checking...';
  bool _isCheckingPermission = false;

  @override
  void initState() {
    super.initState();
    if (widget.checkLocationPermission) {
      _checkPermission();
    } else {
      _permissionStatus = 'Granted (High Accuracy)';
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        switch (permission) {
          case LocationPermission.always:
          case LocationPermission.whileInUse:
            _permissionStatus = 'Granted (High Accuracy)';
            break;
          case LocationPermission.denied:
            _permissionStatus = 'Denied (Tap to Grant)';
            break;
          case LocationPermission.deniedForever:
            _permissionStatus = 'Permanently Denied';
            break;
          case LocationPermission.unableToDetermine:
            _permissionStatus = 'Not Determined';
            break;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _permissionStatus = 'Standard GPS Available');
    } finally {
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (mounted) {
        setState(() {
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            _permissionStatus = 'Granted (High Accuracy)';
          } else {
            _permissionStatus = 'Denied';
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    final bgColor = AppColors.backgroundFor(context);
    final cardColor = AppColors.surfaceFor(context);
    final borderColor = AppColors.borderFor(context);
    final textPrimary = AppColors.textPrimaryFor(context);
    final textSecondary = AppColors.textSecondaryFor(context);
    final textMuted = AppColors.textMutedFor(context);
    final shadows = AppColors.cardShadowFor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: AppTypography.headlineMedium.copyWith(color: textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Live Theme Toggle',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey<bool>(isDark),
                color: AppColors.lovableTeal,
              ),
            ),
            onPressed: () {
              final next = isDark ? ThemeMode.light : ThemeMode.dark;
              themeProvider.setThemeMode(next);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle
            Text(
              'Customize your JourneyGuard safety experience, notification thresholds, and display theme.',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
            const SizedBox(height: 24),

            // 1. APPEARANCE SECTION
            _buildSectionHeader('APPEARANCE & THEME'),
            const SizedBox(height: 10),
            _buildAppearanceCard(
              context: context,
              themeProvider: themeProvider,
              isDark: isDark,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              shadows: shadows,
            ),
            const SizedBox(height: 24),

            // 2. NOTIFICATIONS SECTION
            _buildSectionHeader('NOTIFICATIONS & ALERTS'),
            const SizedBox(height: 10),
            _buildNotificationsCard(
              themeProvider: themeProvider,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              shadows: shadows,
            ),
            const SizedBox(height: 24),

            // 3. LOCATION & SENSORS SECTION
            _buildSectionHeader('LOCATION & HAZARD SENSORS'),
            const SizedBox(height: 10),
            _buildLocationCard(
              themeProvider: themeProvider,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              shadows: shadows,
            ),
            const SizedBox(height: 24),

            // 4. ABOUT JOURNEYGUARD
            _buildSectionHeader('ABOUT JOURNEYGUARD AI'),
            const SizedBox(height: 10),
            _buildAboutCard(
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              shadows: shadows,
            ),
            const SizedBox(height: 24),

            // 5. SUPPORT & FEEDBACK
            _buildSectionHeader('SUPPORT & COMMUNITY'),
            const SizedBox(height: 10),
            _buildSupportCard(
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              shadows: shadows,
            ),
            const SizedBox(height: 36),

            // Footer note
            Center(
              child: Text(
                'JourneyGuard AI · Smart India Hackathon 2026\nPredictive Road Accessibility & Weather-Risk Engine',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: textMuted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAppearanceCard({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow> shadows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lovableTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: AppColors.lovableTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      _getThemeDescription(themeProvider.themeMode, isDark),
                      style: AppTypography.bodySmall.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3-Way Segmented Selector: Dark, Light, System
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                _buildThemeSegmentOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  isSelected: themeProvider.themeMode == ThemeMode.dark,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  isDark: isDark,
                ),
                _buildThemeSegmentOption(
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  isSelected: themeProvider.themeMode == ThemeMode.light,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  isDark: isDark,
                ),
                _buildThemeSegmentOption(
                  label: 'System',
                  icon: Icons.phone_android_rounded,
                  mode: ThemeMode.system,
                  isSelected: themeProvider.themeMode == ThemeMode.system,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Live Dynamic Preview Mini Card
          _buildDynamicPreviewCard(isDark, borderColor),
        ],
      ),
    );
  }

  Widget _buildThemeSegmentOption({
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeTextColor = isDark ? AppColors.lovableGreen : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected && !isDark ? AppColors.lightHighlightGradient : null,
            color: isSelected
                ? (isDark ? AppColors.lovableGreen.withValues(alpha: 0.18) : null)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: isSelected && isDark
                ? Border.all(
                    color: AppColors.lovableGreen.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  icon,
                  key: ValueKey<bool>(isSelected),
                  size: 17,
                  color: isSelected ? activeTextColor : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeTextColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicPreviewCard(bool isDark, Color borderColor) {
    final previewBg = isDark ? const Color(0xFF090D16) : Colors.white;
    final previewCard = isDark ? const Color(0xFF111927) : Colors.white;
    final previewText = isDark ? Colors.white : const Color(0xFF0F172A);
    final previewSubtext = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.remove_red_eye_outlined,
                size: 14,
                color: isDark ? AppColors.lovableTeal : AppColors.lightTeal,
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE PREVIEW (${isDark ? 'DARK MODE' : 'LIGHT MODE'})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.lovableTeal : AppColors.lightTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: previewCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.lovableGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.lovableGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kochi → Munnar Corridor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: previewText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '12% Low Weather Risk · Dry Asphalt',
                        style: TextStyle(
                          fontSize: 11,
                          color: previewSubtext,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lovableGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Safe',
                    style: TextStyle(
                      color: AppColors.lovableGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeDescription(ThemeMode mode, bool isDark) {
    switch (mode) {
      case ThemeMode.system:
        return 'Following device system (${isDark ? 'Dark' : 'Light'} active)';
      case ThemeMode.dark:
        return 'Deep navy palette with emerald accents';
      case ThemeMode.light:
        return 'Soft clean slate palette with teal accents';
    }
  }

  Widget _buildNotificationsCard({
    required ThemeProvider themeProvider,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow> shadows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Weather Hazard Alerts',
            subtitle: 'Real-time rainfall & cloudburst updates along route',
            value: themeProvider.weatherAlerts,
            onChanged: (v) => themeProvider.setWeatherAlerts(v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          Divider(height: 1, color: borderColor),
          _buildSwitchTile(
            icon: Icons.warning_amber_rounded,
            title: 'Severe Landslide Alerts',
            subtitle: 'Immediate warnings for KSDMA high-susceptibility zones',
            value: themeProvider.severeAlerts,
            onChanged: (v) => themeProvider.setSevereAlerts(v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          Divider(height: 1, color: borderColor),
          _buildSwitchTile(
            icon: Icons.alarm_outlined,
            title: 'Journey Departure Reminders',
            subtitle: 'Alerts when your optimal safety departure window opens',
            value: themeProvider.journeyReminders,
            onChanged: (v) => themeProvider.setJourneyReminders(v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required ThemeProvider themeProvider,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow> shadows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.my_location_rounded,
            title: 'Use Current GPS Position',
            subtitle: 'Automatically center journey planning around you',
            value: themeProvider.useCurrentLocation,
            onChanged: (v) => themeProvider.setUseCurrentLocation(v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  color: AppColors.lovableTeal,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Permission',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _permissionStatus,
                        style: AppTypography.bodySmall.copyWith(
                          color: _permissionStatus.contains('Granted')
                              ? AppColors.lovableGreen
                              : AppColors.riskCritical,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Check / Request Permission',
                  icon: _isCheckingPermission
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.lovableTeal,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _permissionStatus.contains('Granted')
                      ? _checkPermission
                      : _requestPermission,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard({
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow> shadows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.info_outline_rounded,
            title: 'Application Version',
            value: 'v1.0.0+1 (SIH 2026)',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, color: borderColor),
          _buildInfoTile(
            icon: Icons.groups_rounded,
            title: 'Development Team',
            value: 'Team SIH 2026',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, color: borderColor),
          _buildNavTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Offline GPS processing & data minimization pledge',
            onTap: _showPrivacyPolicy,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, color: borderColor),
          _buildNavTile(
            icon: Icons.gavel_rounded,
            title: 'Terms & Conditions',
            subtitle: 'Safety guidance disclaimer & licensing information',
            onTap: _showTermsAndConditions,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard({
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow> shadows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Column(
        children: [
          _buildNavTile(
            icon: Icons.rate_review_outlined,
            title: 'Send Feedback',
            subtitle: 'Share your thoughts with the developers',
            onTap: _showFeedbackDialog,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(height: 1, color: borderColor),
          _buildNavTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help improve hazard detection reliability',
            onTap: _showReportBugDialog,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lovableTeal, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.lovableGreen,
            activeTrackColor: AppColors.lovableGreen.withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF94A3B8),
            inactiveTrackColor: const Color(0xFF334155),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lovableTeal, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.lovableTeal, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceFor(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Privacy Policy',
          style: TextStyle(color: AppColors.textPrimaryFor(ctx)),
        ),
        content: SingleChildScrollView(
          child: Text(
            'JourneyGuard AI is engineered with privacy as a foundational principle:\n\n'
            '1. Location Privacy: GPS coordinates are processed on-device and mapped directly to Open-Meteo and OSRM open routing services without identifying user profiles.\n\n'
            '2. Incident Reporting: Crowdsourced disaster markers are tagged anonymously with coordinate timestamps only.\n\n'
            '3. Offline First: Critical KSDMA hazard mappings operate entirely on-device without continuous tracking.\n\n'
            'SIH 2026 - JourneyGuard AI Team.',
            style: TextStyle(
              color: AppColors.textSecondaryFor(ctx),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.lovableTeal)),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceFor(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Terms & Conditions',
          style: TextStyle(color: AppColors.textPrimaryFor(ctx)),
        ),
        content: SingleChildScrollView(
          child: Text(
            'JourneyGuard AI provides predictive hazard navigation assistance based on meteorological forecast models and Kerala State Disaster Management Authority (KSDMA) historical susceptibility data.\n\n'
            'Disclaimer: While JourneyGuard AI uses state-of-the-art predictive algorithms, weather and geotechnical conditions in ghat sectors can change rapidly. Drivers must always obey local police advisories and official red alerts.\n\n'
            'SIH 2026 Edition.',
            style: TextStyle(
              color: AppColors.textSecondaryFor(ctx),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Agree', style: TextStyle(color: AppColors.lovableTeal)),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    int rating = 5;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceFor(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Send Feedback',
            style: TextStyle(color: AppColors.textPrimaryFor(ctx)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How is your experience with JourneyGuard AI?',
                style: TextStyle(color: AppColors.textSecondaryFor(ctx), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.riskModerate,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => rating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimaryFor(ctx), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'What features would you love to see next?',
                  fillColor: AppColors.surfaceElevatedFor(ctx),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lovableGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you! Your feedback helps keep Kerala routes safer.'),
                    backgroundColor: AppColors.lovableGreen,
                  ),
                );
              },
              child: const Text('Submit', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportBugDialog() {
    final controller = TextEditingController();
    String selectedCategory = 'Weather Forecast Mismatch';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceFor(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Report a Bug',
            style: TextStyle(color: AppColors.textPrimaryFor(ctx)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help us diagnose route calculation or UI anomalies:',
                style: TextStyle(color: AppColors.textSecondaryFor(ctx), fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: AppColors.surfaceFor(ctx),
                style: TextStyle(color: AppColors.textPrimaryFor(ctx), fontSize: 13),
                decoration: InputDecoration(
                  fillColor: AppColors.surfaceElevatedFor(ctx),
                ),
                items: [
                  'Weather Forecast Mismatch',
                  'Routing / OSRM Offline Issue',
                  'Theme / UI Glitch',
                  'Location Accuracy Error',
                  'Other',
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimaryFor(ctx), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  fillColor: AppColors.surfaceElevatedFor(ctx),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.riskModerate,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bug report logged. Diagnostics attached!'),
                    backgroundColor: AppColors.lovableTeal,
                  ),
                );
              },
              child: const Text('Send Report', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
