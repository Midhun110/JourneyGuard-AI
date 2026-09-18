import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/route_model.dart';
import '../../models/saved_route_model.dart';
import '../../services/risk_engine.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/gradient_button.dart';
import '../departure_time/departure_time_screen.dart';

class RouteComparisonScreen extends StatefulWidget {
  final List<RouteModel> routes;
  final DateTime departureTime;
  final String fromName;
  final String toName;
  final LatLng fromLocation;
  final LatLng toLocation;

  const RouteComparisonScreen({
    super.key,
    required this.routes,
    required this.departureTime,
    required this.fromName,
    required this.toName,
    required this.fromLocation,
    required this.toLocation,
  });

  @override
  State<RouteComparisonScreen> createState() => _RouteComparisonScreenState();
}

class _RouteComparisonScreenState extends State<RouteComparisonScreen> {
  final _riskEngine = RiskEngine();
  RouteComparisonResult? _comparisonResult;
  List<RouteComparison> _comparisons = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Module C: Interactive Ranking Weights
  double _riskWeight = AppConstants.defaultRiskWeight; // Default: 0.70 (Safety-first)
  double _timeWeight = AppConstants.defaultTimeWeight; // Default: 0.30
  bool _useConservativeMax = false;
  bool _showAdvancedWeights = false;

  @override
  void initState() {
    super.initState();
    _loadComparisons();
  }

  Future<void> _loadComparisons() async {
    try {
      final result = await _riskEngine.compareRoutesDetailed(
        routes: widget.routes,
        departureTime: widget.departureTime,
        riskWeight: _riskWeight,
        timeWeight: _timeWeight,
        useConservativeMax: _useConservativeMax,
      ).timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _comparisonResult = result;
          _comparisons = result.comparisons;
          _isLoading = false;
          _selectedIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        final fallback = await _riskEngine.compareRoutesDetailed(
          routes: const [],
          departureTime: widget.departureTime,
          riskWeight: _riskWeight,
          timeWeight: _timeWeight,
          useConservativeMax: _useConservativeMax,
        );
        setState(() {
          _comparisonResult = fallback;
          _comparisons = fallback.comparisons;
          _isLoading = false;
          _selectedIndex = 0;
        });
      }
    }
  }

  /// Instant local re-ranking without refetching network weather
  void _recalculateRankings() {
    if (_comparisons.isEmpty) return;

    final routes = _comparisons.map((c) => c.route).toList();
    final normDurations = _riskEngine.normalizeRouteDurations(routes);

    final raw = <RouteComparison>[];
    for (int i = 0; i < _comparisons.length; i++) {
      final comp = _comparisons[i];
      final activeRisk =
          _useConservativeMax ? comp.maxRisk : comp.weightedAvgRisk;
      final normDuration = normDurations[i];
      final combinedScore = _riskEngine.calculateCombinedRouteScore(
        normalizedRisk: activeRisk,
        normalizedDuration: normDuration,
        riskWeight: _riskWeight,
        timeWeight: _timeWeight,
      );

      raw.add(comp.copyWith(
        riskScore: activeRisk,
        normalizedDuration: normDuration,
        combinedScore: combinedScore,
      ));
    }

    // Identify Safest & Fastest-Acceptable
    final minRisk =
        raw.map((c) => c.riskScore).reduce((a, b) => a < b ? a : b);
    final safest = raw.firstWhere((c) => c.riskScore == minRisk);

    final acceptable = raw
        .where((c) => c.riskScore <= AppConstants.acceptableRiskThreshold)
        .toList();
    RouteComparison? fastestAcceptable;
    if (acceptable.isNotEmpty) {
      fastestAcceptable = acceptable.reduce(
        (a, b) => a.route.durationSeconds < b.route.durationSeconds ? a : b,
      );
    }

    // Postponement Advisory
    final allHigh = raw.every(
        (c) => c.riskScore > AppConstants.acceptableRiskThreshold);
    final allCritical = raw.every(
        (c) => c.maxRisk >= AppConstants.highRiskThreshold);
    final isPostponementAdvised = allHigh || allCritical;

    // Sort by combined score (lower is superior)
    final sorted = List<RouteComparison>.from(raw)
      ..sort((a, b) => a.combinedScore.compareTo(b.combinedScore));

    final updated = <RouteComparison>[];
    for (int r = 1; r <= sorted.length; r++) {
      final comp = sorted[r - 1];
      final isSafest = comp.route == safest.route;
      final isFastestAcceptable =
          fastestAcceptable != null && comp.route == fastestAcceptable.route;
      final isRecommended = r == 1;

      String label;
      String tag;
      if (isSafest && isFastestAcceptable) {
        label = 'Safest & Fastest';
        tag = 'Optimal';
      } else if (isSafest) {
        label = 'Safest';
        tag = 'Safest';
      } else if (isFastestAcceptable) {
        label = 'Fastest Acceptable';
        tag = 'Fastest Safe';
      } else if (isRecommended) {
        label = 'Recommended';
        tag = 'Top Ranked';
      } else {
        label = 'Alternative $r';
        tag = 'Alternative';
      }

      if (comp.riskScore > AppConstants.highRiskThreshold) {
        label = '$label (Critical)';
      } else if (comp.riskScore > AppConstants.acceptableRiskThreshold) {
        label = '$label (High Risk)';
      }

      updated.add(comp.copyWith(
        rank: r,
        label: label,
        isSafest: isSafest,
        isFastestAcceptable: isFastestAcceptable,
        isRecommended: isRecommended,
        recommendationTag: tag,
      ));
    }

    setState(() {
      _comparisons = updated;
      _comparisonResult = RouteComparisonResult(
        comparisons: updated,
        riskWeight: _riskWeight,
        timeWeight: _timeWeight,
        useConservativeMax: _useConservativeMax,
        isPostponementAdvised: isPostponementAdvised,
        postponementReason: isPostponementAdvised
            ? 'All available routes exceed safe risk limits (High/Critical hazard). '
                'Severe weather or unstable road corridors detected. '
                'Strongly advise postponing journey or selecting an alternative departure window.'
            : null,
      );
      if (_selectedIndex >= updated.length) _selectedIndex = 0;
    });
  }

  void _applyPreset(String preset) {
    switch (preset) {
      case 'safety':
        _riskWeight = 0.70;
        _timeWeight = 0.30;
        break;
      case 'balanced':
        _riskWeight = 0.50;
        _timeWeight = 0.50;
        break;
      case 'time':
        _riskWeight = 0.30;
        _timeWeight = 0.70;
        break;
    }
    _recalculateRankings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Route Comparison',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textPrimaryFor(context),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimaryFor(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Departure Times',
            icon: const Icon(Icons.schedule_rounded,
                color: AppColors.accentCyan),
            onPressed: _openDepartureTimes,
          ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.accentIndigo),
          ),
          const SizedBox(height: 20),
          Text('Comparing Routes...', style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Analyzing hazard corridors & calculating multi-factor scores',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_comparisons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route_rounded,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text('No alternatives found', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text('Only one route is available for this journey.',
                style: AppTypography.bodyMedium),
          ],
        ),
      );
    }

    final isPostponement = _comparisonResult?.isPostponementAdvised ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route header
          _buildRouteHeader(),
          const SizedBox(height: 16),

          // Postponement Advisory Alert (Module C - 3)
          if (isPostponement) ...[
            _buildPostponementAdvisoryBanner(),
            const SizedBox(height: 20),
          ],

          // Interactive Ranking Weights Controls (Module C - 2)
          _buildWeightControls(),
          const SizedBox(height: 24),

          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ranked Corridors', style: AppTypography.headlineMedium),
              Text(
                '${_comparisons.length} Options',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.accentCyan),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route Cards List
          ...List.generate(_comparisons.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RouteCard(
                comparison: _comparisons[i],
                isSelected: _selectedIndex == i,
                riskWeight: _riskWeight,
                timeWeight: _timeWeight,
                departureTime: widget.departureTime,
                onTap: () => setState(() => _selectedIndex = i),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 120))
                  .slideX(begin: 0.15),
            );
          }),

          const SizedBox(height: 20),

          // Comparison Table
          _buildComparisonTable(),

          const SizedBox(height: 24),

          // Action Buttons
          GradientButton(
            label:
                'Use ${_comparisons.isNotEmpty ? _comparisons[_selectedIndex].recommendationTag : "Selected"} Route',
            icon: Icons.navigation_rounded,
            onPressed: () {
              Navigator.pop(
                  context, _comparisons[_selectedIndex].route);
            },
          ),
          const SizedBox(height: 12),

          ListenableBuilder(
            listenable: NotificationService.instance,
            builder: (context, _) {
              final notifService = NotificationService.instance;
              final isMonitored = notifService.isRouteMonitored(
                widget.fromName,
                widget.toName,
              );

              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isMonitored ? AppColors.lovableGreen : Colors.white,
                    side: BorderSide(
                      color: isMonitored
                          ? AppColors.lovableGreen
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(
                    isMonitored
                        ? Icons.notifications_active_rounded
                        : Icons.notification_add_outlined,
                    size: 18,
                    color: isMonitored ? AppColors.lovableGreen : Colors.white70,
                  ),
                  label: Text(
                    isMonitored
                        ? 'Pre-Departure Push Monitoring Active'
                        : 'Monitor Selected Corridor Before Departure',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () async {
                    if (_comparisons.isEmpty) return;
                    final selected = _comparisons[_selectedIndex];
                    final saved = SavedRouteModel(
                      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
                      name: '${widget.fromName} → ${widget.toName}',
                      fromName: widget.fromName,
                      toName: widget.toName,
                      fromLatitude: widget.fromLocation.latitude,
                      fromLongitude: widget.fromLocation.longitude,
                      toLatitude: widget.toLocation.latitude,
                      toLongitude: widget.toLocation.longitude,
                      departureTime: widget.departureTime,
                      initialRiskScore: selected.riskScore,
                      isMonitored: true,
                      savedAt: DateTime.now(),
                      summary: selected.route.summary,
                    );
                    await notifService.saveRoute(saved);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Route saved! Push notifications enabled for risk spikes & nearby hazards.',
                          ),
                          backgroundColor: AppColors.lovableTealDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton.icon(
              onPressed: _openDepartureTimes,
              icon: const Icon(Icons.schedule_rounded,
                  color: AppColors.accentIndigo, size: 18),
              label: Text(
                'Explore Smart Departure Times',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.accentIndigo),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRouteHeader() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  color: AppColors.riskLow, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fromName,
                  style: AppTypography.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.riskCritical, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.toName,
                  style: AppTypography.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostponementAdvisoryBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskCritical.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.riskCritical.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.riskCritical.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: AppColors.riskCritical,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSTPONEMENT ADVISORY',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.riskCritical,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'All corridors exceed safe risk limits',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Heavy precipitation and hazardous road vulnerabilities are active across all routes. '
            'Non-essential travel is strongly discouraged at this time.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.riskCritical,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _openDepartureTimes,
              icon: const Icon(Icons.schedule_rounded, size: 16),
              label: const Text(
                'Find Safer Departure Window',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms);
  }

  Widget _buildWeightControls() {
    final isSafetyPreset = (_riskWeight - 0.70).abs() < 0.01 &&
        (_timeWeight - 0.30).abs() < 0.01;
    final isBalancedPreset = (_riskWeight - 0.50).abs() < 0.01 &&
        (_timeWeight - 0.50).abs() < 0.01;
    final isTimePreset = (_riskWeight - 0.30).abs() < 0.01 &&
        (_timeWeight - 0.70).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      color: AppColors.accentIndigo, size: 18),
                  const SizedBox(width: 8),
                  Text('Ranking Preference',
                      style: AppTypography.headlineSmall),
                ],
              ),
              GestureDetector(
                onTap: () => setState(
                    () => _showAdvancedWeights = !_showAdvancedWeights),
                child: Row(
                  children: [
                    Text(
                      _showAdvancedWeights ? 'Simple' : 'Adjust',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.accentCyan),
                    ),
                    Icon(
                      _showAdvancedWeights
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.accentCyan,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preset Buttons
          Row(
            children: [
              Expanded(
                child: _PresetChip(
                  label: 'Safety-First\n(70 / 30)',
                  isActive: isSafetyPreset,
                  onTap: () => _applyPreset('safety'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: 'Balanced\n(50 / 50)',
                  isActive: isBalancedPreset,
                  onTap: () => _applyPreset('balanced'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: 'Time-First\n(30 / 70)',
                  isActive: isTimePreset,
                  onTap: () => _applyPreset('time'),
                ),
              ),
            ],
          ),

          // Advanced Sliders & Toggles
          if (_showAdvancedWeights) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Safety Weight: ${(_riskWeight * 100).toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall),
                Text('Time Weight: ${(_timeWeight * 100).toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.accentCyan)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.riskLow,
                inactiveTrackColor: AppColors.accentCyan,
                thumbColor: Colors.white,
                overlayColor: AppColors.accentIndigo.withOpacity(0.2),
              ),
              child: Slider(
                value: _riskWeight,
                min: 0.1,
                max: 0.9,
                divisions: 8,
                onChanged: (val) {
                  _riskWeight = val;
                  _timeWeight = 1.0 - val;
                  _recalculateRankings();
                },
              ),
            ),

            // Conservative mode toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Conservative Mode',
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Ranks by peak hazardous segment instead of route average',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textMuted, fontSize: 11),
              ),
              value: _useConservativeMax,
              activeColor: AppColors.riskCritical,
              onChanged: (val) {
                _useConservativeMax = val;
                _recalculateRankings();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    if (_comparisons.length < 2) return const SizedBox.shrink();

    final displayed = _comparisons.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Side-by-Side Analysis',
              style: AppTypography.headlineSmall),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.6),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(1.6),
            },
            children: [
              _tableRow(
                ['Metric', ...displayed.map((c) => '#${c.rank} ${c.recommendationTag}')],
                isHeader: true,
              ),
              _tableRow([
                'Combined Score',
                ...displayed.map((c) => c.combinedScore.toStringAsFixed(1)),
              ]),
              _tableRow([
                'Active Risk',
                ...displayed.map((c) => '${c.riskScore.toStringAsFixed(0)}% (${c.riskClassification})'),
              ]),
              _tableRow([
                'Peak Segment',
                ...displayed.map((c) => '${c.maxRisk.toStringAsFixed(0)}%'),
              ]),
              _tableRow([
                'Duration',
                ...displayed.map((c) => c.route.formattedDuration),
              ]),
              _tableRow([
                'Distance',
                ...displayed.map((c) => c.route.formattedDistance),
              ]),
              _tableRow([
                'Rain Prob.',
                ...displayed.map((c) => '${c.rainProbability.toStringAsFixed(0)}%'),
              ]),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: isHeader
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)))
          : null,
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Text(
            cell,
            style: isHeader
                ? AppTypography.labelSmall
                    .copyWith(color: AppColors.textMuted, fontSize: 11)
                : AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
          ),
        );
      }).toList(),
    );
  }

  void _openDepartureTimes() {
    final selectedRoute = _comparisons.isNotEmpty
        ? _comparisons[_selectedIndex].route
        : widget.routes.first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepartureTimeScreen(
          location: widget.fromLocation,
          date: widget.departureTime,
          fromName: widget.fromName,
          toName: widget.toName,
          route: selectedRoute,
        ),
      ),
    );
  }
}

// ─── Route Card ────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final RouteComparison comparison;
  final bool isSelected;
  final double riskWeight;
  final double timeWeight;
  final DateTime departureTime;
  final VoidCallback onTap;

  const _RouteCard({
    required this.comparison,
    required this.isSelected,
    required this.riskWeight,
    required this.timeWeight,
    required this.departureTime,
    required this.onTap,
  });

  Color get _tagColor {
    if (comparison.isSafest && comparison.isFastestAcceptable) {
      return AppColors.riskLow;
    }
    if (comparison.isSafest) return AppColors.riskLow;
    if (comparison.isFastestAcceptable) return AppColors.accentCyan;
    if (comparison.isRecommended) return AppColors.accentIndigo;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = AppColors.riskColor(comparison.riskScore);
    final isDark = AppColors.isDark(context);
    final isSafestOrTop = comparison.isSafest || comparison.rank == 1;
    final isEstimated = comparison.isEstimated || comparison.route.isEstimated;
    final eta = departureTime
        .add(Duration(seconds: comparison.route.durationSeconds.round()));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? _tagColor.withValues(alpha: 0.14)
                  : const Color(0xFFF0FDF4))
              : (isDark ? AppColors.surfaceFor(context) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? _tagColor : const Color(0xFF10B981))
                : (isDark ? AppColors.borderFor(context) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? (isDark
                  ? AppColors.cardShadowFor(context)
                  : [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ])
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Rank badge + AI Recommended Badge + ~estimated + Risk badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _tagColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${comparison.rank}',
                          style: TextStyle(
                            color: _tagColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        comparison.label,
                        style: AppTypography.headlineSmall.copyWith(
                          color: _tagColor,
                          fontSize: 14.5,
                        ),
                      ),
                      if (isSafestOrTop)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF0D9488)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 10.5),
                              SizedBox(width: 3.5),
                              Text(
                                'AI Recommended',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isEstimated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFFCBD5E1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insights_rounded,
                                size: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '~estimated',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RiskBadge(score: comparison.riskScore),
              ],
            ),
            const SizedBox(height: 12),

            // Combined Score Formula Display (Module C - 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceElevatedFor(context)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderFor(context)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined,
                      size: 14, color: AppColors.textMutedFor(context)),
                  const SizedBox(width: 6),
                  Text(
                    'Score: ${comparison.combinedScore.toStringAsFixed(1)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimaryFor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Risk ${(riskWeight * 100).toStringAsFixed(0)}% + Time ${(timeWeight * 100).toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textMutedFor(context), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Metrics row: Distance, ETA, Rainfall
            Row(
              children: [
                _MetricChip(
                  icon: Icons.straighten_rounded,
                  value: comparison.route.formattedDistance,
                  color: AppColors.textSecondaryFor(context),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: Icons.flag_rounded,
                  value: 'ETA ${DateFormat('h:mm a').format(eta)}',
                  color: AppColors.lovableGreen,
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: Icons.water_drop_rounded,
                  value:
                      '${comparison.cumulativeRainfall.toStringAsFixed(1)} mm rain',
                  color: AppColors.accentCyan,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Peak Hazard indicator
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 13,
                  color: AppColors.riskColor(comparison.maxRisk),
                ),
                const SizedBox(width: 4),
                Text(
                  'Avg: ${comparison.weightedAvgRisk.toStringAsFixed(0)}% • Peak hazard: ${comparison.maxRisk.toStringAsFixed(0)}%',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Risk bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: comparison.riskScore / 100,
                backgroundColor: AppColors.surfaceElevatedFor(context),
                valueColor: AlwaysStoppedAnimation(riskColor),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentIndigo.withValues(alpha: 0.2)
              : AppColors.surfaceElevatedFor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.accentIndigo : AppColors.borderFor(context),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppColors.accentIndigo : AppColors.textSecondaryFor(context),
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MetricChip(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(value, style: AppTypography.bodySmall.copyWith(color: color)),
      ],
    );
  }
}
