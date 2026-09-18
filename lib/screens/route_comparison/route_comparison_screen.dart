import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/route_model.dart';
import '../../services/risk_engine.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/gradient_button.dart';

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
  State<RouteComparisonScreen> createState() =>
      _RouteComparisonScreenState();
}

class _RouteComparisonScreenState extends State<RouteComparisonScreen> {
  final _riskEngine = RiskEngine();
  List<RouteComparison> _comparisons = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadComparisons();
  }

  Future<void> _loadComparisons() async {
    try {
      final comparisons = await _riskEngine.compareRoutes(
        routes: widget.routes,
        departureTime: widget.departureTime,
      );
      if (mounted) {
        setState(() {
          _comparisons = comparisons;
          _isLoading = false;
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
        title: Text('Route Comparison', style: AppTypography.headlineMedium),
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
          Text('Comparing Routes...', style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          Text('Analyzing risk for all alternatives',
              style: AppTypography.bodyMedium),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route header
          _buildRouteHeader(),
          const SizedBox(height: 24),

          // Summary cards
          Text('Route Options', style: AppTypography.headlineMedium),
          const SizedBox(height: 12),
          ...List.generate(_comparisons.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RouteCard(
                comparison: _comparisons[i],
                isSelected: _selectedIndex == i,
                onTap: () => setState(() => _selectedIndex = i),
                index: i,
              ).animate().fadeIn(delay: Duration(milliseconds: i * 150))
                  .slideX(begin: 0.2),
            );
          }),

          const SizedBox(height: 24),

          // Comparison table
          _buildComparisonTable(),

          const SizedBox(height: 24),

          // Select button
          GradientButton(
            label: 'Use ${_comparisons.isNotEmpty ? _comparisons[_selectedIndex].label : "Selected"} Route',
            icon: Icons.navigation_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteHeader() {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.trip_origin_rounded,
              color: AppColors.riskLow, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _truncate(widget.fromName, 30),
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    if (_comparisons.length < 2) return const SizedBox.shrink();

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
          Text('Side-by-Side Comparison', style: AppTypography.headlineSmall),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
            },
            children: [
              _tableRow(['Metric', ..._comparisons.take(2).map((c) => c.label)],
                  isHeader: true),
              _tableRow([
                'Distance',
                ..._comparisons
                    .take(2)
                    .map((c) => c.route.formattedDistance),
              ]),
              _tableRow([
                'Duration',
                ..._comparisons
                    .take(2)
                    .map((c) => c.route.formattedDuration),
              ]),
              _tableRow([
                'Risk Score',
                ..._comparisons
                    .take(2)
                    .map((c) => '${c.riskScore.toStringAsFixed(0)}%'),
              ]),
              _tableRow([
                'Rain Prob.',
                ..._comparisons
                    .take(2)
                    .map((c) => '${c.rainProbability.toStringAsFixed(0)}%'),
              ]),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: isHeader
          ? BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.border)))
          : null,
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            cell,
            style: isHeader
                ? AppTypography.labelSmall
                    .copyWith(color: AppColors.textMuted)
                : AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary),
          ),
        );
      }).toList(),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

// ─── Route Card ────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final RouteComparison comparison;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  const _RouteCard({
    required this.comparison,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  Color get _labelColor {
    switch (comparison.label) {
      case 'Safest':
        return AppColors.riskLow;
      case 'Fastest':
        return AppColors.accentCyan;
      default:
        return AppColors.accentIndigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = AppColors.riskColor(comparison.riskScore);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _labelColor.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _labelColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (comparison.label == 'Safest')
                      const Icon(Icons.verified_rounded,
                          color: AppColors.riskLow, size: 18),
                    if (comparison.label == 'Fastest')
                      const Icon(Icons.bolt_rounded,
                          color: AppColors.accentCyan, size: 18),
                    if (comparison.label == 'Balanced')
                      const Icon(Icons.balance_rounded,
                          color: AppColors.accentIndigo, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      comparison.label,
                      style: AppTypography.headlineSmall
                          .copyWith(color: _labelColor),
                    ),
                  ],
                ),
                RiskBadge(score: comparison.riskScore),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MetricChip(
                  icon: Icons.straighten_rounded,
                  value: comparison.route.formattedDistance,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                _MetricChip(
                  icon: Icons.schedule_rounded,
                  value: comparison.route.formattedDuration,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                _MetricChip(
                  icon: Icons.water_drop_rounded,
                  value:
                      '${comparison.rainProbability.toStringAsFixed(0)}% rain',
                  color: AppColors.accentCyan,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Risk bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: comparison.riskScore / 100,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(riskColor),
                minHeight: 6,
              ),
            ),
          ],
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
