import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/route_model.dart';
import '../../models/weather_data.dart';
import '../../services/risk_engine.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class DepartureTimeScreen extends StatefulWidget {
  final LatLng location;
  final DateTime date;
  final String fromName;
  final String toName;
  final RouteModel? route;

  const DepartureTimeScreen({
    super.key,
    required this.location,
    required this.date,
    required this.fromName,
    required this.toName,
    this.route,
  });

  @override
  State<DepartureTimeScreen> createState() => _DepartureTimeScreenState();
}

class _DepartureTimeScreenState extends State<DepartureTimeScreen> {
  final _riskEngine = RiskEngine();
  List<DepartureTimeWeather> _timeslots = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      List<DepartureTimeWeather> results;
      if (widget.route != null) {
        // Module C: Run full Module A -> B segment-level pipeline across shifted departure timestamps
        results = await _riskEngine
            .evaluateRouteAcrossDepartureTimes(
              route: widget.route!,
              date: widget.date,
            )
            .timeout(const Duration(seconds: 4));
      } else {
        // Fallback: Point query
        results = await _riskEngine
            .getDepartureTimeRecommendations(
              location: widget.location,
              date: widget.date,
            )
            .timeout(const Duration(seconds: 4));
      }

      if (results.isEmpty) throw Exception('Empty departure times');

      if (mounted) {
        _applyResults(results);
      }
    } catch (e) {
      if (mounted) {
        final fallback = await _riskEngine.evaluateRouteAcrossDepartureTimes(
          route: widget.route ??
              RouteModel(
                coordinates: [widget.location],
                distanceMeters: 25000,
                durationSeconds: 2400,
                summary: 'Corridor',
              ),
          date: widget.date,
        );
        _applyResults(fallback);
      }
    }
  }

  void _applyResults(List<DepartureTimeWeather> results) {
    setState(() {
      _timeslots = results;
      _isLoading = false;
      int safestIdx = 0;
      double minRisk = double.infinity;
      for (int i = 0; i < results.length; i++) {
        if (results[i].riskScore < minRisk) {
          minRisk = results[i].riskScore;
          safestIdx = i;
        }
      }
      _selectedIndex = safestIdx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Best Departure Time',
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
          Text('Evaluating Route Across Times',
              style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(
            widget.route != null
                ? 'Re-running segment hazard pipeline for shifted windows...'
                : 'Fetching hourly forecasts for departure windows...',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final selected =
        _timeslots.isNotEmpty ? _timeslots[_selectedIndex] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRouteHeader(),
          const SizedBox(height: 24),

          // Recommendation banner
          if (selected != null) _buildRecommendationBanner(selected),
          const SizedBox(height: 24),

          // Time slots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Analyzed Departure Windows',
                  style: AppTypography.headlineMedium),
              if (widget.route != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Full Route Pipeline',
                    style: TextStyle(
                      color: AppColors.accentIndigo,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._timeslots.asMap().entries.map((entry) {
            final i = entry.key;
            final slot = entry.value;
            final isSelected = i == _selectedIndex;
            final isSafest = _timeslots.isNotEmpty &&
                slot.riskScore ==
                    _timeslots
                        .map((t) => t.riskScore)
                        .reduce((a, b) => a < b ? a : b);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TimeSlotCard(
                slot: slot,
                isSelected: isSelected,
                isSafest: isSafest,
                onTap: () => setState(() => _selectedIndex = i),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 80))
                  .slideX(begin: 0.15),
            );
          }),

          const SizedBox(height: 24),

          // Risk chart
          _buildRiskBarChart(),

          const SizedBox(height: 24),

          GradientButton(
            label: selected != null
                ? 'Select ${selected.label} Departure'
                : 'Confirm Selection',
            icon: Icons.schedule_rounded,
            onPressed: () {
              Navigator.pop(context, selected?.departureTime);
            },
          ),

          const SizedBox(height: 32),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMMM d, y').format(widget.date),
                style: AppTypography.headlineSmall,
              ),
              if (widget.route != null)
                Text(
                  '${widget.route!.formattedDistance} • ${widget.route!.formattedDuration}',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.accentCyan),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  color: AppColors.riskLow, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_truncate(widget.fromName, 35),
                    style: AppTypography.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.riskCritical, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_truncate(widget.toName, 35),
                    style: AppTypography.bodySmall),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildRecommendationBanner(DepartureTimeWeather slot) {
    final riskColor = AppColors.riskColor(slot.riskScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withOpacity(0.18), riskColor.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.recommend_rounded, color: riskColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Optimal Window: ${slot.label}',
                      style:
                          AppTypography.headlineSmall.copyWith(color: riskColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Risk: ${slot.riskScore.toStringAsFixed(0)}% (${AppColors.riskLabel(slot.riskScore)})'
                  '${slot.maxRisk > 0 ? " • Peak: ${slot.maxRisk.toStringAsFixed(0)}%" : ""}',
                  style: AppTypography.bodyMedium,
                ),
                if (slot.riskReductionVsBaseline > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '📉 ${slot.riskReductionVsBaseline.toStringAsFixed(0)}% lower risk than earliest departure',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.riskLow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Rain: ${slot.weather.rainProbability.toStringAsFixed(0)}% probability • '
                  '${slot.weather.cumulativeRainfall.toStringAsFixed(1)}mm rainfall',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _buildRiskBarChart() {
    if (_timeslots.isEmpty) return const SizedBox.shrink();

    final maxRisk =
        _timeslots.map((t) => t.riskScore).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Corridor Risk by Time',
                  style: AppTypography.headlineSmall),
              Text('Lower is safer',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _timeslots.asMap().entries.map((entry) {
              final i = entry.key;
              final slot = entry.value;
              final color = AppColors.riskColor(slot.riskScore);
              final height = maxRisk > 0
                  ? (slot.riskScore / maxRisk * 100).clamp(12.0, 100.0)
                  : 12.0;

              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: Column(
                  children: [
                    Text(
                      '${slot.riskScore.toStringAsFixed(0)}%',
                      style: AppTypography.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 28,
                      height: height,
                      decoration: BoxDecoration(
                        color: _selectedIndex == i
                            ? color
                            : color.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: _selectedIndex == i
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      slot.label,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10,
                        fontWeight: _selectedIndex == i
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

// ─── Time Slot Card ────────────────────────────────────────────────────────

class _TimeSlotCard extends StatelessWidget {
  final DepartureTimeWeather slot;
  final bool isSelected;
  final bool isSafest;
  final VoidCallback onTap;

  const _TimeSlotCard({
    required this.slot,
    required this.isSelected,
    required this.isSafest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = AppColors.riskColor(slot.riskScore);
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSafest && !isDark
              ? const Color(0xFFF0FDF4)
              : (isSelected
                  ? riskColor.withValues(alpha: isDark ? 0.14 : 0.09)
                  : AppColors.surfaceFor(context)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSafest
                ? const Color(0xFF10B981)
                : (isSelected ? riskColor : AppColors.borderFor(context)),
            width: isSelected || isSafest ? 1.8 : 1,
          ),
          boxShadow: isSelected || isSafest ? AppColors.cardShadowFor(context) : null,
        ),
        child: Row(
          children: [
            // Time badge
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? riskColor.withValues(alpha: 0.2)
                    : (isSafest && !isDark
                        ? const Color(0xFFDCFCE7)
                        : AppColors.surfaceElevatedFor(context)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    isSafest ? Icons.star_rounded : Icons.schedule_rounded,
                    color: isSafest ? const Color(0xFF0D9488) : riskColor,
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.label,
                    style: AppTypography.labelLarge.copyWith(
                      color: isSafest ? const Color(0xFF0F766E) : riskColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Metrics
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${AppColors.riskLabel(slot.riskScore)} Risk (${slot.riskScore.toStringAsFixed(0)}%)',
                        style: AppTypography.headlineSmall.copyWith(
                          color: riskColor,
                          fontSize: 14,
                        ),
                      ),
                      if (isSafest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF0D9488)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  color: Colors.white, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                'SAFEST TIME',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (slot.maxRisk > 0)
                        _Mini(
                          icon: Icons.trending_up_rounded,
                          label: 'Peak ${slot.maxRisk.toStringAsFixed(0)}%',
                          iconColor: AppColors.riskColor(slot.maxRisk),
                        ),
                      _Mini(
                        icon: Icons.water_drop_rounded,
                        label:
                            '${slot.weather.rainProbability.toStringAsFixed(0)}% rain',
                        iconColor: AppColors.accentCyan,
                      ),
                      _Mini(
                        icon: Icons.grain_rounded,
                        label:
                            '${slot.weather.rainfallIntensity.toStringAsFixed(1)} mm/h',
                        iconColor: const Color(0xFF0D9488),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Progress circle
            SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (slot.riskScore / 100).clamp(0.0, 1.0),
                    backgroundColor: AppColors.surfaceElevatedFor(context),
                    valueColor: AlwaysStoppedAnimation(riskColor),
                    strokeWidth: 3.5,
                  ),
                  Text(
                    slot.riskScore.toStringAsFixed(0),
                    style: AppTypography.labelSmall.copyWith(
                      color: riskColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _Mini({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor ?? AppColors.textMuted, size: 12),
        const SizedBox(width: 3),
        Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11)),
      ],
    );
  }
}
