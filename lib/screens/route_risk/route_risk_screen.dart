import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/route_model.dart';
import '../../models/risk_segment.dart';
import '../../services/risk_engine.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/risk_badge.dart';
import '../route_comparison/route_comparison_screen.dart';
import '../departure_time/departure_time_screen.dart';

class RouteRiskScreen extends StatefulWidget {
  final List<RouteModel> routes;
  final String fromName;
  final String toName;
  final DateTime departureTime;
  final LatLng fromLocation;
  final LatLng toLocation;

  const RouteRiskScreen({
    super.key,
    required this.routes,
    required this.fromName,
    required this.toName,
    required this.departureTime,
    required this.fromLocation,
    required this.toLocation,
  });

  @override
  State<RouteRiskScreen> createState() => _RouteRiskScreenState();
}

class _RouteRiskScreenState extends State<RouteRiskScreen>
    with TickerProviderStateMixin {
  final _riskEngine = RiskEngine();
  final _mapController = MapController();

  List<RiskSegment> _segments = [];
  bool _isLoading = true;
  String? _errorMsg;
  int _selectedSegmentIndex = -1;
  late AnimationController _bottomSheetController;
  late RouteModel _activeRoute;
  late DateTime _activeDepartureTime;

  @override
  void initState() {
    super.initState();
    _activeRoute = widget.routes.first;
    _activeDepartureTime = widget.departureTime;
    _bottomSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadRiskData();
  }

  @override
  void dispose() {
    _bottomSheetController.dispose();
    super.dispose();
  }

  Future<void> _loadRiskData() async {
    try {
      final segments = await _riskEngine.buildRiskSegments(
        route: _activeRoute,
        departureTime: _activeDepartureTime,
      );

      if (mounted) {
        setState(() {
          _segments = segments;
          _isLoading = false;
        });
        _bottomSheetController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Failed to analyze risk: $e';
        });
      }
    }
  }

  double get _overallRisk {
    if (_segments.isEmpty) return 0;
    return _riskEngine.calculateRouteRisk(_segments, conservative: false);
  }

  double get _totalRainfall {
    if (_segments.isEmpty) return 0;
    return _segments
        .map((s) => s.weather.cumulativeRainfall)
        .reduce((a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    final route = _activeRoute;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map
          _buildMap(route),

          // Top overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  _buildRouteInfoChip(route),
                ],
              ),
            ),
          ),

          // Error banner
          if (_errorMsg != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.riskCritical.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Bottom sheet
          if (!_isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomSheet(route),
            ),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildMap(RouteModel route) {
    final bounds = _getMapBounds();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: 11,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.journeyguard.journey_guard_ai',
        ),
        // Draw risk segments as colored polylines
        if (_segments.isNotEmpty)
          PolylineLayer(
            polylines: _segments.map((seg) {
              return Polyline(
                points: seg.points,
                color: seg.color.withOpacity(
                    seg.segmentIndex == _selectedSegmentIndex ? 1.0 : 0.8),
                strokeWidth:
                    seg.segmentIndex == _selectedSegmentIndex ? 7 : 5,
              );
            }).toList(),
          )
        else
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.coordinates,
                color: AppColors.accentIndigo,
                strokeWidth: 4,
              ),
            ],
          ),
        // Markers
        MarkerLayer(
          markers: [
            Marker(
              point: widget.fromLocation,
              width: 40,
              height: 40,
              child: _MapMarker(
                  color: AppColors.riskLow, icon: Icons.trip_origin_rounded),
            ),
            Marker(
              point: widget.toLocation,
              width: 40,
              height: 40,
              child: _MapMarker(
                  color: AppColors.riskCritical,
                  icon: Icons.location_on_rounded),
            ),
            // Segment tap markers
            ..._segments.map((seg) => Marker(
                  point: seg.midpoint,
                  width: 32,
                  height: 32,
                  child: GestureDetector(
                    onTap: () {
                      setState(
                          () => _selectedSegmentIndex = seg.segmentIndex);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: seg.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          seg.riskScore.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ],
    );
  }

  LatLngBounds _getMapBounds() {
    final allPoints = [widget.fromLocation, widget.toLocation];
    if (_segments.isNotEmpty) {
      for (final seg in _segments) {
        allPoints.addAll(seg.points);
      }
    } else {
      allPoints.addAll(_activeRoute.coordinates);
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  Widget _buildTopBar() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _truncate(widget.fromName, 25),
                  style: AppTypography.labelSmall,
                ),
                Text(
                  '→  ${_truncate(widget.toName, 25)}',
                  style: AppTypography.labelLarge,
                ),
              ],
            ),
          ),
          if (!_isLoading && _segments.isNotEmpty)
            RiskBadge(score: _overallRisk),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3);
  }

  Widget _buildRouteInfoChip(RouteModel route) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _InfoChip(
          icon: Icons.straighten_rounded,
          label: route.formattedDistance,
        ),
        const SizedBox(width: 8),
        _InfoChip(
          icon: Icons.schedule_rounded,
          label: route.formattedDuration,
        ),
        const SizedBox(width: 8),
        _InfoChip(
          icon: Icons.calendar_today_rounded,
          label: DateFormat('h:mm a').format(_activeDepartureTime),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildBottomSheet(RouteModel route) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _bottomSheetController, curve: Curves.easeOutCubic)),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Risk score + stats row
                  Row(
                    children: [
                      RiskBadge(score: _overallRisk, large: true),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            _StatRow(
                              label: 'Rainfall',
                              value:
                                  '${_totalRainfall.toStringAsFixed(1)} mm',
                              icon: Icons.water_drop_outlined,
                            ),
                            const SizedBox(height: 8),
                            _StatRow(
                              label: 'Segments',
                              value: '${_segments.length} zones',
                              icon: Icons.route_rounded,
                            ),
                            const SizedBox(height: 8),
                            _StatRow(
                              label: 'Distance',
                              value: route.formattedDistance,
                              icon: Icons.straighten_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),

                  // Risk legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _LegendItem(color: AppColors.riskLow, label: 'Low'),
                      _LegendItem(
                          color: AppColors.riskModerate, label: 'Moderate'),
                      _LegendItem(color: AppColors.riskHigh, label: 'High'),
                      _LegendItem(
                          color: AppColors.riskCritical, label: 'Critical'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Segments list
                  if (_segments.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _segments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final seg = _segments[i];
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedSegmentIndex =
                                    _selectedSegmentIndex == i ? -1 : i),
                            child: _SegmentCard(
                              segment: seg,
                              isSelected: _selectedSegmentIndex == i,
                            ),
                          );
                        },
                      ),
                    ),

                  // Module B selected segment factor breakdown
                  if (_selectedSegmentIndex >= 0 &&
                      _selectedSegmentIndex < _segments.length) ...[
                    const SizedBox(height: 12),
                    _buildSelectedSegmentBreakdown(
                        _segments[_selectedSegmentIndex]),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: 'Compare Routes',
                          icon: Icons.compare_arrows_rounded,
                          onTap: () async {
                            final selectedRoute =
                                await Navigator.push<RouteModel>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RouteComparisonScreen(
                                  routes: widget.routes,
                                  departureTime: _activeDepartureTime,
                                  fromName: widget.fromName,
                                  toName: widget.toName,
                                  fromLocation: widget.fromLocation,
                                  toLocation: widget.toLocation,
                                ),
                              ),
                            );
                            if (selectedRoute != null && mounted) {
                              setState(() {
                                _activeRoute = selectedRoute;
                                _isLoading = true;
                              });
                              _loadRiskData();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OutlineButton(
                          label: 'Best Time',
                          icon: Icons.schedule_rounded,
                          onTap: () async {
                            final selectedTime =
                                await Navigator.push<DateTime>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DepartureTimeScreen(
                                  location: widget.fromLocation,
                                  date: _activeDepartureTime,
                                  fromName: widget.fromName,
                                  toName: widget.toName,
                                  route: _activeRoute,
                                ),
                              ),
                            );
                            if (selectedTime != null && mounted) {
                              setState(() {
                                _activeDepartureTime = selectedTime;
                                _isLoading = true;
                              });
                              _loadRiskData();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: AppColors.background.withOpacity(0.8),
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.accentIndigo),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text('Analyzing Route Risk',
                  style: AppTypography.headlineSmall),
              const SizedBox(height: 8),
              Text('Fetching weather & calculating risk scores...',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSegmentBreakdown(RiskSegment seg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: seg.color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Segment ${seg.segmentIndex + 1} — ${seg.riskLevelLabel} Risk (${seg.riskScore.toStringAsFixed(1)}%)',
                style: AppTypography.labelLarge.copyWith(color: seg.color),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _selectedSegmentIndex = -1),
                child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
          if (seg.hazardDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.riskModerate),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    seg.hazardDescription,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.riskModerate),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // 5-Factor telemetry grid
          Row(
            children: [
              Expanded(
                child: _FactorMiniCard(
                  label: 'Rainfall (40%)',
                  value: '${seg.weather.rainfallIntensity.toStringAsFixed(1)} mm/h',
                  score: '${seg.rainfallIntensityNorm.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FactorMiniCard(
                  label: 'Rain Prob (15%)',
                  value: '${seg.weather.rainProbability.toStringAsFixed(0)}%',
                  score: '${seg.weather.rainProbability.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FactorMiniCard(
                  label: '24h Antecedent (20%)',
                  value: '${seg.weather.cumulativeRainfall.toStringAsFixed(1)} mm',
                  score: '${seg.cumulativeRainfallNorm.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _FactorMiniCard(
                  label: 'KSDMA Hazard (15%)',
                  value: '${seg.roadVulnerability.toStringAsFixed(0)}/100',
                  score: '${seg.roadVulnerability.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FactorMiniCard(
                  label: 'Incidents (10%)',
                  value: '${seg.recentIncidentsCount} nearby',
                  score: '${seg.historicalIncidentsScore.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentIndigo, size: 14),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.bodySmall),
        const Spacer(),
        Text(value,
            style: AppTypography.labelLarge
                .copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final RiskSegment segment;
  final bool isSelected;

  const _SegmentCard({required this.segment, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? segment.color.withOpacity(0.2)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? segment.color : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: segment.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text('Seg ${segment.segmentIndex + 1}',
                  style: AppTypography.labelSmall),
            ],
          ),
          const Spacer(),
          Text(
            '${segment.riskScore.toStringAsFixed(0)}%',
            style: AppTypography.headlineSmall.copyWith(color: segment.color),
          ),
          Text(segment.riskLevelLabel, style: AppTypography.bodySmall),
          Text(
            '${segment.weather.cumulativeRainfall.toStringAsFixed(1)}mm rain',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accentIndigo, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.accentIndigo)),
          ],
        ),
      ),
    );
  }
}

class _FactorMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final String score;

  const _FactorMiniCard({
    required this.label,
    required this.value,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.labelSmall.copyWith(
                  fontSize: 10, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value,
              style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          Text(score,
              style: AppTypography.labelSmall.copyWith(
                  fontSize: 10, color: AppColors.accentIndigo)),
        ],
      ),
    );
  }
}
