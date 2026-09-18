import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/weather_data.dart';
import '../../services/risk_engine.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class DepartureTimeScreen extends StatefulWidget {
  final LatLng location;
  final DateTime date;
  final String fromName;
  final String toName;

  const DepartureTimeScreen({
    super.key,
    required this.location,
    required this.date,
    required this.fromName,
    required this.toName,
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
      final results = await _riskEngine.getDepartureTimeRecommendations(
        location: widget.location,
        date: widget.date,
      );
      if (mounted) {
        setState(() {
          _timeslots = results;
          _isLoading = false;
          // Auto-select safest
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Best Departure Time', style: AppTypography.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
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
          Text('Analyzing Departure Times', style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          Text('Fetching 5 time windows...', style: AppTypography.bodyMedium),
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
          Text('All Departure Windows', style: AppTypography.headlineMedium),
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
              ).animate().fadeIn(delay: Duration(milliseconds: i * 100))
                  .slideX(begin: 0.2),
            );
          }),

          const SizedBox(height: 24),

          // Risk chart
          _buildRiskBarChart(),

          const SizedBox(height: 24),

          GradientButton(
            label: selected != null
                ? 'Set Departure: ${selected.label}'
                : 'Confirm Selection',
            icon: Icons.schedule_rounded,
            onPressed: () => Navigator.pop(context),
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
          Text('Journey Date',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMMM d, y').format(widget.date),
            style: AppTypography.headlineSmall,
          ),
          const SizedBox(height: 8),
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
          colors: [riskColor.withOpacity(0.15), riskColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.3)),
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
                Text(
                  'Recommended: ${slot.label}',
                  style: AppTypography.headlineSmall.copyWith(color: riskColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Risk Score: ${slot.riskScore.toStringAsFixed(0)}% • '
                  '${AppColors.riskLabel(slot.riskScore)} Risk',
                  style: AppTypography.bodyMedium,
                ),
                Text(
                  'Rain: ${slot.weather.rainProbability.toStringAsFixed(0)}% probability • '
                  '${slot.weather.cumulativeRainfall.toStringAsFixed(1)}mm expected',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildRiskBarChart() {
    if (_timeslots.isEmpty) return const SizedBox.shrink();

    final maxRisk =
        _timeslots.map((t) => t.riskScore).reduce((a, b) => a > b ? a : b);

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
          Text('Risk by Departure Time', style: AppTypography.headlineSmall),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _timeslots.asMap().entries.map((entry) {
              final i = entry.key;
              final slot = entry.value;
              final color = AppColors.riskColor(slot.riskScore);
              final height = maxRisk > 0
                  ? (slot.riskScore / maxRisk * 100).clamp(10.0, 100.0)
                  : 10.0;

              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: Column(
                  children: [
                    Text(
                      '${slot.riskScore.toStringAsFixed(0)}%',
                      style: AppTypography.labelSmall.copyWith(color: color),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: _selectedIndex == i
                            ? color
                            : color.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: _selectedIndex == i
                            ? Border.all(color: color, width: 2)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(slot.label, style: AppTypography.bodySmall),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? riskColor.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? riskColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Time badge
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? riskColor.withOpacity(0.2)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule_rounded, color: riskColor, size: 16),
                  const SizedBox(height: 4),
                  Text(slot.label,
                      style: AppTypography.labelLarge
                          .copyWith(color: riskColor),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Metrics
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${AppColors.riskLabel(slot.riskScore)} Risk',
                        style: AppTypography.headlineSmall
                            .copyWith(color: riskColor),
                      ),
                      if (isSafest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.riskLow.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'SAFEST',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.riskLow,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Mini(
                          icon: Icons.percent_rounded,
                          label:
                              '${slot.riskScore.toStringAsFixed(0)}% risk'),
                      const SizedBox(width: 12),
                      _Mini(
                          icon: Icons.water_drop_rounded,
                          label:
                              '${slot.weather.rainProbability.toStringAsFixed(0)}% rain'),
                      const SizedBox(width: 12),
                      _Mini(
                          icon: Icons.opacity_rounded,
                          label:
                              '${slot.weather.cumulativeRainfall.toStringAsFixed(1)}mm'),
                    ],
                  ),
                ],
              ),
            ),
            // Progress bar
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: slot.riskScore / 100,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation(riskColor),
                    strokeWidth: 4,
                  ),
                  Text(
                    '${slot.riskScore.toStringAsFixed(0)}',
                    style: AppTypography.labelSmall.copyWith(color: riskColor),
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

  const _Mini({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 12),
        const SizedBox(width: 3),
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }
}
