import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/route_model.dart';
import '../../models/risk_segment.dart';
import '../../models/saved_route_model.dart';
import '../../services/risk_engine.dart';
import '../../services/notification_service.dart';
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
  bool _showRadarOverlay = false;

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
      duration: const Duration(milliseconds: 350),
    );
    _loadRiskData();
  }

  @override
  void dispose() {
    _bottomSheetController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRiskData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final segments = await _riskEngine
          .buildRiskSegments(
            route: _activeRoute,
            departureTime: _activeDepartureTime,
          )
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _segments = segments;
          _isLoading = false;
        });
        _bottomSheetController.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToRoute();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Live weather timeout. Loaded corridor hazard baseline.';
        });
        _bottomSheetController.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToRoute();
        });
      }
    }
  }

  void _fitMapToRoute() {
    try {
      final bounds = _getMapBounds();
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 130,
            bottom: 320,
            left: 36,
            right: 36,
          ),
        ),
      );
    } catch (_) {}
  }

  void _zoomIn() {
    try {
      final z = (_mapController.camera.zoom + 1.0).clamp(3.0, 19.0);
      _mapController.move(_mapController.camera.center, z);
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final z = (_mapController.camera.zoom - 1.0).clamp(3.0, 19.0);
      _mapController.move(_mapController.camera.center, z);
    } catch (_) {}
  }

  void _centerOnMyLocation() {
    try {
      _mapController.move(widget.fromLocation, 14.5);
    } catch (_) {}
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

  double get _averageRainfallIntensity {
    if (_segments.isEmpty) return 0;
    return _segments
            .map((s) => s.weather.rainfallIntensity)
            .reduce((a, b) => a + b) /
        _segments.length;
  }

  double get _averageWindSpeed {
    if (_segments.isEmpty) return 12.0;
    return _segments
            .map((s) => s.weather.windSpeed)
            .reduce((a, b) => a + b) /
        _segments.length;
  }

  String get _visibilityLabel {
    final rain = _averageRainfallIntensity;
    if (rain > 10.0) return '2.0 km (Heavy Rain)';
    if (rain > 3.0) return '5.0 km (Moderate Rain)';
    if (rain > 0.5) return '8.0 km (Light Rain)';
    return '10.0 km (Clear)';
  }

  int get _highRiskCount =>
      _segments.where((s) => s.riskScore >= 50.0).length;

  DateTime get _estimatedArrivalTime =>
      _activeDepartureTime.add(Duration(seconds: _activeRoute.durationSeconds.round()));

  @override
  Widget build(BuildContext context) {
    final route = _activeRoute;
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: Stack(
        children: [
          // 1. Google Maps style OpenStreetMap light map with thick route polylines
          _buildMap(route),

          // 2. Weather Radar Active Status Banner (when radar toggle is ON)
          if (_showRadarOverlay)
            Positioned(
              top: 136,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accentCyan),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF06B6D4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Precipitation Radar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),

          // 3. Top Bar and Route Overview Chips
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 6),
                  _buildRouteInfoChip(route),
                ],
              ),
            ),
          ),

          // 4. Floating Navigation Controls (Radar, Recenter, My Location, Zoom +/-)
          Positioned(
            right: 16,
            top: 140,
            child: Column(
              children: [
                // Weather Radar Toggle
                _buildMapFloatingButton(
                  icon: _showRadarOverlay
                      ? Icons.radar_rounded
                      : Icons.water_drop_outlined,
                  activeColor: AppColors.accentCyan,
                  isActive: _showRadarOverlay,
                  tooltip: 'Weather Radar Overlay',
                  onTap: () {
                    setState(() => _showRadarOverlay = !_showRadarOverlay);
                  },
                ),
                const SizedBox(height: 8),

                // Fit Route
                _buildMapFloatingButton(
                  icon: Icons.crop_free_rounded,
                  tooltip: 'Fit Entire Route',
                  onTap: _fitMapToRoute,
                ),
                const SizedBox(height: 8),

                // My Location
                _buildMapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Origin Location',
                  onTap: _centerOnMyLocation,
                ),
                const SizedBox(height: 14),

                // Zoom In
                _buildMapFloatingButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 4),

                // Zoom Out
                _buildMapFloatingButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),

          // 5. Interactive Segment Inspection Card (on tap)
          if (_selectedSegmentIndex >= 0 &&
              _selectedSegmentIndex < _segments.length)
            Positioned(
              left: 16,
              right: 16,
              bottom: 350,
              child: _buildTappedSegmentInspectionCard(
                _segments[_selectedSegmentIndex],
              ),
            ),

          // 6. Error/Fallback Banner
          if (_errorMsg != null)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF78350F).withValues(alpha: 0.9)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Color(0xFF92400E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _errorMsg = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 7. Rounded White Glass-Style Bottom Sheet
          if (!_isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomSheet(route),
            ),

          // 8. Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  /// Clean OpenStreetMap light map with Google Maps aesthetics & dynamic risk polylines
  Widget _buildMap(RouteModel route) {
    final bounds = _getMapBounds();

    // High-risk segments for selective hazard warning markers only
    final highRiskSegments = _segments
        .where((s) => s.riskScore >= 50.0 || s.roadVulnerability >= 60.0)
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: 11.5,
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 130,
            bottom: 320,
            left: 36,
            right: 36,
          ),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // 1. Base OpenStreetMap light road tiles (CartoDB Voyager: clean roads, highways, cities)
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.journeyguard.journey_guard_ai',
          maxZoom: 19,
        ),

        // 2. Optional Weather Radar Overlay (RainViewer precipitation raster tiles)
        if (_showRadarOverlay)
          TileLayer(
            urlTemplate:
                'https://tilecache.rainviewer.com/v2/radar/nowcast_5/256/{z}/{x}/{y}/2/1_1.png',
            userAgentPackageName: 'com.journeyguard.journey_guard_ai',
            tileProvider: NetworkTileProvider(),
            maxZoom: 12,
            minZoom: 4,
          ),

        // 3. Thick Primary Route Polyline with Color-Coded Risk Segments
        // Outer casing/glow polyline
        PolylineLayer(
          polylines: [
            Polyline(
              points: route.coordinates,
              color: Colors.white.withValues(alpha: 0.85),
              strokeWidth: 9.5,
            ),
          ],
        ),

        // Dynamic colored segments
        if (_segments.isNotEmpty)
          PolylineLayer(
            polylines: _segments.map((seg) {
              final isSelected = seg.segmentIndex == _selectedSegmentIndex;
              return Polyline(
                points: seg.points,
                color: isSelected
                    ? seg.color
                    : seg.color.withValues(alpha: 0.95),
                strokeWidth: isSelected ? 8.5 : 7.0,
                borderStrokeWidth: isSelected ? 2.5 : 0.8,
                borderColor: isSelected ? Colors.black87 : Colors.white,
              );
            }).toList(),
          )
        else
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.coordinates,
                color: AppColors.accentIndigo,
                strokeWidth: 7.0,
              ),
            ],
          ),

        // 4. Markers: Animated Start Pin, Animated Destination Pin, and High-Risk Warning Markers ONLY
        MarkerLayer(
          markers: [
            // Start Marker (Animated Green Pin)
            Marker(
              point: widget.fromLocation,
              width: 54,
              height: 58,
              alignment: Alignment.bottomCenter,
              child: const _AnimatedPin(
                color: Color(0xFF16A34A), // Emerald Green
                icon: Icons.trip_origin_rounded,
                label: 'START',
              ),
            ),

            // Destination Marker (Animated Red Pin)
            Marker(
              point: widget.toLocation,
              width: 54,
              height: 58,
              alignment: Alignment.bottomCenter,
              child: const _AnimatedPin(
                color: Color(0xFFDC2626), // Vibrant Red
                icon: Icons.location_on_rounded,
                label: 'DEST',
              ),
            ),

            // Warning Markers ONLY at High-Risk locations
            ...highRiskSegments.map((seg) {
              final isSelected = seg.segmentIndex == _selectedSegmentIndex;
              return Marker(
                point: seg.midpoint,
                width: isSelected ? 42 : 36,
                height: isSelected ? 42 : 36,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSegmentIndex =
                          _selectedSegmentIndex == seg.segmentIndex
                              ? -1
                              : seg.segmentIndex;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: seg.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: isSelected ? 2.8 : 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: seg.color.withValues(alpha: 0.6),
                          blurRadius: isSelected ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: isSelected ? 22 : 18,
                      ),
                    ),
                  ),
                ),
              );
            }),
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

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? activeColor,
    bool isActive = false,
  }) {
    final isDark = AppColors.isDark(context);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? (activeColor ?? AppColors.lovableGreen)
                : AppColors.surfaceFor(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? (activeColor ?? AppColors.lovableGreen)
                  : AppColors.borderFor(context),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 19,
            color: isActive
                ? Colors.white
                : AppColors.textPrimaryFor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedFor(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _truncate(widget.fromName, 22),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: AppColors.lovableGreen,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _truncate(widget.toName, 22),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryFor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isLoading && _segments.isNotEmpty)
            RiskBadge(score: _overallRisk),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.2);
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
          icon: Icons.access_time_filled_rounded,
          label: DateFormat('h:mm a').format(_activeDepartureTime),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 350.ms);
  }

  /// Interactive inspection card shown when tapping a route segment
  Widget _buildTappedSegmentInspectionCard(RiskSegment seg) {
    final isDark = AppColors.isDark(context);

    // Flood probability calculated from precipitation probability and antecedent saturation
    final floodProbability = ((seg.weather.rainProbability * 0.7) +
            (seg.cumulativeRainfallNorm * 0.3))
        .clamp(5.0, 95.0);

    // Landslide risk description
    String landslideRisk;
    Color landslideColor;
    if (seg.roadVulnerability >= 60.0) {
      landslideRisk = 'High Hazard (Unstable Ghat Slope)';
      landslideColor = AppColors.riskCritical;
    } else if (seg.roadVulnerability >= 30.0) {
      landslideRisk = 'Moderate Slope Sensitivity';
      landslideColor = AppColors.riskModerate;
    } else {
      landslideRisk = 'Low Hazard (Stable Ground)';
      landslideColor = AppColors.riskLow;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: seg.color, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: seg.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Segment ${seg.segmentIndex + 1} of ${_segments.length} — ${seg.riskLevelLabel} Risk',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: seg.color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: seg.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${seg.riskScore.toStringAsFixed(1)}% Risk',
                  style: TextStyle(
                    color: seg.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedSegmentIndex = -1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedFor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3-Metric Row: Rainfall, Flood Probability, Landslide Hazard
          Row(
            children: [
              Expanded(
                child: _GreenTealMetricCard(
                  icon: Icons.water_drop_rounded,
                  label: 'Rainfall',
                  value: '${seg.weather.rainfallIntensity.toStringAsFixed(1)} mm/h',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _GreenTealMetricCard(
                  icon: Icons.flood_rounded,
                  label: 'Flood Prob',
                  value: '${floodProbability.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _GreenTealMetricCard(
                  icon: Icons.landscape_rounded,
                  label: 'Landslide',
                  value: seg.roadVulnerability >= 50.0 ? 'High' : (seg.roadVulnerability >= 25.0 ? 'Mod' : 'Low'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Terrain / Slope advisory note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: landslideColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.terrain_rounded, size: 14, color: landslideColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    seg.hazardDescription.isNotEmpty
                        ? '${seg.hazardDescription} ($landslideRisk)'
                        : landslideRisk,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: landslideColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1);
  }

  /// Rounded white glass-style bottom sheet displaying overall risk, rainfall, ETA, distance, visibility, wind, and risk segments
  Widget _buildBottomSheet(RouteModel route) {
    final isDark = AppColors.isDark(context);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _bottomSheetController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF111827).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                children: [
                  // 1. Overall Risk Header + ETA & Distance
                  Row(
                    children: [
                      RiskBadge(score: _overallRisk, large: true),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.flag_rounded,
                                  size: 15,
                                  color: AppColors.lovableGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ETA ${DateFormat('h:mm a').format(_estimatedArrivalTime)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimaryFor(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${route.formattedDistance} • ${route.formattedDuration}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondaryFor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Zone status pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _highRiskCount > 0
                              ? AppColors.riskCritical.withValues(alpha: 0.15)
                              : AppColors.lovableGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _highRiskCount > 0
                                ? AppColors.riskCritical.withValues(alpha: 0.5)
                                : AppColors.lovableGreen.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _highRiskCount > 0
                              ? '$_highRiskCount Hazard Zones'
                              : 'All Clear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _highRiskCount > 0
                                ? AppColors.riskCritical
                                : AppColors.lovableGreen,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Comprehensive Navigation Metrics Grid (Green/Teal cards in Light Mode)
                  Row(
                    children: [
                      Expanded(
                        child: _GreenTealMetricCard(
                          icon: Icons.water_drop_outlined,
                          label: 'Rainfall',
                          value: '${_totalRainfall.toStringAsFixed(1)} mm',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GreenTealMetricCard(
                          icon: Icons.visibility_outlined,
                          label: 'Visibility',
                          value: _visibilityLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GreenTealMetricCard(
                          icon: Icons.air_rounded,
                          label: 'Wind Speed',
                          value: '${_averageWindSpeed.toStringAsFixed(0)} km/h',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GreenTealMetricCard(
                          icon: Icons.alt_route_rounded,
                          label: 'Segments',
                          value: '${_segments.length} corridor zones',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3. Horizontal Segment Zones List
                  if (_segments.isNotEmpty)
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _segments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final seg = _segments[i];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSegmentIndex =
                                    _selectedSegmentIndex == i ? -1 : i;
                              });
                            },
                            child: _SegmentCard(
                              segment: seg,
                              isSelected: _selectedSegmentIndex == i,
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 14),

                  // 4. Action Buttons: Compare Routes & Best Time
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCardButton(
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
                        child: _ActionCardButton(
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
                  const SizedBox(height: 10),

                  // 5. Pre-departure monitoring toggle
                  _buildMonitorTripButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorTripButton() {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (ctx, _) {
        final notifService = NotificationService.instance;
        final isMonitored = notifService.isRouteMonitored(
          widget.fromName,
          widget.toName,
        );

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isMonitored
                  ? AppColors.lovableGreen.withValues(alpha: 0.15)
                  : AppColors.lovableGreen,
              foregroundColor:
                  isMonitored ? AppColors.lovableGreen : Colors.white,
              side: isMonitored
                  ? const BorderSide(color: AppColors.lovableGreen, width: 1.2)
                  : BorderSide.none,
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
            ),
            label: Text(
              isMonitored
                  ? 'Corridor Monitoring Active (Tap to pause)'
                  : 'Monitor Corridor for Pre-Departure Alerts',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            onPressed: () async {
              if (isMonitored) {
                final match = notifService.savedRoutes.firstWhere(
                  (r) =>
                      r.fromName.toLowerCase().trim() ==
                          widget.fromName.toLowerCase().trim() &&
                      r.toName.toLowerCase().trim() ==
                          widget.toName.toLowerCase().trim(),
                );
                await notifService.toggleRouteMonitoring(match.id, false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Pre-departure monitoring paused for this trip.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                final saved = SavedRouteModel(
                  id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
                  name: '${widget.fromName} → ${widget.toName}',
                  fromName: widget.fromName,
                  toName: widget.toName,
                  fromLatitude: widget.fromLocation.latitude,
                  fromLongitude: widget.fromLocation.longitude,
                  toLatitude: widget.toLocation.latitude,
                  toLongitude: widget.toLocation.longitude,
                  departureTime: _activeDepartureTime,
                  initialRiskScore: _overallRisk,
                  isMonitored: true,
                  savedAt: DateTime.now(),
                  summary: _activeRoute.summary,
                );
                await notifService.saveRoute(saved);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Corridor monitored! You will receive push alerts if risk escalates or hazards are reported.',
                      ),
                      backgroundColor: AppColors.lovableTealDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    final isDark = AppColors.isDark(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderFor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.lovableGreen),
                strokeWidth: 3,
              ),
              const SizedBox(height: 18),
              Text(
                'Analyzing Route Risk',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Assessing Open-Meteo & KSDMA risk segments...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedFor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

// ─── Helper Components ────────────────────────────────────────────────────────

/// Animated map pin with repeating pulse ripple ring
class _AnimatedPin extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _AnimatedPin({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final val = _pulseController.value;
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Outer pulsing ripple ring
            Positioned(
              bottom: 4,
              child: Transform.scale(
                scale: 1.0 + (val * 0.7),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: (1.0 - val) * 0.35),
                    border: Border.all(
                      color: widget.color.withValues(alpha: (1.0 - val) * 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            // Pin Body
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.45),
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(widget.icon, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.lovableGreen, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green / Teal styled metric card for light mode elegance & dark mode compatibility
class _GreenTealMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GreenTealMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F262B)
            : const Color(0xFFF0FDF4), // Gentle mint green in light mode
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF134E4A)
              : const Color(0xFFBBF7D0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF115E59).withValues(alpha: 0.5)
                  : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color: isDark ? AppColors.lovableTeal : const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF047857),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF065F46),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final RiskSegment segment;
  final bool isSelected;

  const _SegmentCard({
    required this.segment,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      width: 118,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isSelected
            ? segment.color.withValues(alpha: isDark ? 0.25 : 0.12)
            : AppColors.surfaceElevatedFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? segment.color : AppColors.borderFor(context),
          width: isSelected ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: segment.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Zone ${segment.segmentIndex + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
              const Spacer(),
              Text(
                '${segment.riskScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: segment.color,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            segment.riskLevelLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: segment.color,
            ),
          ),
          Text(
            '${segment.weather.rainfallIntensity.toStringAsFixed(1)} mm/h',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMutedFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCardButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.lovableGreen, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
