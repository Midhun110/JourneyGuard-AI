import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';
import '../models/route_model.dart';
import '../models/risk_segment.dart';
import '../models/weather_data.dart';
import 'weather_service.dart';
import 'ksdma_hazard_dataset.dart';
import 'incident_service.dart';

/// Module B — Weather Risk Engine (The Core Innovation)
///
/// Implements the multi-factor predictive risk algorithm:
/// Risk = (Rainfall Intensity × 0.40) +
///        (Rain Probability    × 0.15) +
///        (Cumulative Rainfall × 0.20) +
///        (Road Vulnerability  × 0.15) +
///        (Historical Incidents× 0.10)
class RiskEngine {
  final WeatherService _weatherService;
  final KsdmaHazardDataset _ksdmaDataset;
  final IncidentService _incidentService;

  RiskEngine({
    WeatherService? weatherService,
    KsdmaHazardDataset? ksdmaDataset,
    IncidentService? incidentService,
  })  : _weatherService = weatherService ?? WeatherService(),
        _ksdmaDataset = ksdmaDataset ?? KsdmaHazardDataset.instance,
        _incidentService = incidentService ?? IncidentService.instance;

  // ─── Module B - 3.4: Core Weighted Risk Formula ────────────────────────────

  /// Module B - 3.4: Apply the weighted formula from the problem statement:
  ///
  /// - [rainfallIntensity]: Normalized 0-100 (capped at 50mm/h)
  /// - [rainProbability]: 0-100 %
  /// - [cumulativeRainfall]: Normalized 0-100 (preceding 24h, capped at 100mm)
  /// - [roadVulnerability]: 0-100 from KSDMA hazard mapping table
  /// - [historicalIncidents]: Normalized 0-100 (recency-weighted incident density)
  double calculateRiskScore({
    required double rainfallIntensity, // normalized 0-100
    required double rainProbability,   // 0-100
    required double cumulativeRainfall,// normalized 0-100
    required double roadVulnerability, // 0-100
    required double historicalIncidents, // 0-100
  }) {
    final score = (rainfallIntensity * AppConstants.weightRainfallIntensity) +
        (rainProbability * AppConstants.weightRainProbability) +
        (cumulativeRainfall * AppConstants.weightCumulativeRainfall) +
        (roadVulnerability * AppConstants.weightRoadVulnerability) +
        (historicalIncidents * AppConstants.weightHistoricalIncidents);

    return score.clamp(0.0, 100.0);
  }

  // ─── Module B - 3.5: Risk Classification ───────────────────────────────────

  /// Module B - 3.5: Classify risk score into category levels:
  /// - Score <= 25: Low
  /// - Score <= 50: Moderate
  /// - Score <= 75: High
  /// - Score > 75: Critical
  String riskLevel(double score) {
    if (score <= 25) return 'Low';
    if (score <= 50) return 'Moderate';
    if (score <= 75) return 'High';
    return 'Critical';
  }

  // ─── Normalization Functions & Engineering Rationale ───────────────────────

  /// Normalizes rainfall intensity (mm/h) to a 0-100 scale.
  ///
  /// **Threshold Rationale:**
  /// IMD (India Meteorological Department) classifies rainfall > 50 mm/h as
  /// intense torrential downpour / cloudburst intensity. Above this threshold,
  /// rapid flash runoff, hydroplaning, and road washouts reach peak hazard.
  /// We cap at 50 mm/h = 100 and scale linearly below that.
  double normalizeRainfallIntensity(double mmPerHour) {
    if (mmPerHour <= 0) return 0.0;
    return (mmPerHour / 50.0 * 100.0).clamp(0.0, 100.0);
  }

  /// Normalizes rain probability (0-100%).
  double normalizeRainProbability(double probability) {
    return probability.clamp(0.0, 100.0);
  }

  /// Normalizes cumulative rainfall over preceding 6-24 hours to a 0-100 scale.
  ///
  /// **Threshold Rationale:**
  /// Hydrological & geotechnical research across Kerala (KSDMA & Geological
  /// Survey of India) identifies antecedent 24-hour rainfall of 100 mm as the
  /// critical saturation threshold where pore water pressure destabilizes
  /// steep Western Ghats slopes and triggers landslides or river overflow.
  /// We cap at 100 mm = 100 and scale linearly below that.
  double normalizeCumulativeRainfall(double cumulativeMm) {
    if (cumulativeMm <= 0) return 0.0;
    return (cumulativeMm / 100.0 * 100.0).clamp(0.0, 100.0);
  }

  /// Normalizes road vulnerability (0-100).
  double normalizeRoadVulnerability(double score) {
    return score.clamp(0.0, 100.0);
  }

  /// Normalizes recency-weighted historical/reported incidents (0-100).
  ///
  /// **Threshold Rationale:**
  /// A cluster of 5 recent/active incident reports within a 10 km corridor
  /// represents an active disaster zone (100). Scaled linearly below 5.
  double normalizeHistoricalIncidents(double weightedCount) {
    if (weightedCount <= 0) return 0.0;
    return (weightedCount / 5.0 * 100.0).clamp(0.0, 100.0);
  }

  // ─── Route & Segment Risk Analysis ─────────────────────────────────────────

  /// Build risk segments from a route and weather/hazard data.
  /// Attaches calculated score, classification, and factor breakdown to each segment.
  Future<List<RiskSegment>> buildRiskSegments({
    required RouteModel route,
    required DateTime departureTime,
  }) async {
    if (route.coordinates.isEmpty) return [];

    final segments = _splitRouteIntoSegments(route);
    final List<RiskSegment> riskSegments = [];

    for (int i = 0; i < segments.length; i++) {
      final segPoints = segments[i];
      if (segPoints.isEmpty) continue;

      final midpoint = segPoints[segPoints.length ~/ 2];

      // Estimated time to reach this segment based on route duration
      final segmentDurationMinutes =
          (route.durationSeconds / 60) * (i / segments.length);
      final eta = departureTime
          .add(Duration(minutes: segmentDurationMinutes.round()));

      // 3.1 & 3.2: Fetch weather for this segment midpoint and ETA (includes preceding 24h)
      final weather = await _weatherService.fetchWeather(
        location: midpoint,
        dateTime: eta,
      );

      // 3.3: Query KSDMA road vulnerability dataset for segment midpoint
      final hazardMatch = _ksdmaDataset.getRoadVulnerability(
        midpoint.latitude,
        midpoint.longitude,
      );

      // 3.3: Query Module D recency-weighted incident reports near segment
      final incidentMatch = _incidentService.queryIncidentsNear(
        location: midpoint,
        radiusKm: 10.0,
        referenceTime: eta,
      );

      // 3.4: Normalize all inputs to 0-100
      final rainIntensityNorm = normalizeRainfallIntensity(weather.rainfallIntensity);
      final rainProbNorm = normalizeRainProbability(weather.rainProbability);
      final cumRainfallNorm = normalizeCumulativeRainfall(weather.cumulativeRainfall);
      final roadVulnNorm = normalizeRoadVulnerability(hazardMatch.score);
      final incidentsNorm = incidentMatch.score;

      // Calculate composite risk score
      final riskScore = calculateRiskScore(
        rainfallIntensity: rainIntensityNorm,
        rainProbability: rainProbNorm,
        cumulativeRainfall: cumRainfallNorm,
        roadVulnerability: roadVulnNorm,
        historicalIncidents: incidentsNorm,
      );

      final segDistance = route.distanceMeters / segments.length;
      final segDuration = route.durationSeconds / 60 / segments.length;

      // 3.5: Classify and attach to segment object
      riskSegments.add(RiskSegment(
        points: segPoints,
        riskScore: riskScore,
        weather: weather,
        distanceMeters: segDistance,
        durationMinutes: segDuration,
        segmentIndex: i,
        rainfallIntensityNorm: rainIntensityNorm,
        cumulativeRainfallNorm: cumRainfallNorm,
        roadVulnerability: roadVulnNorm,
        historicalIncidentsScore: incidentsNorm,
        hazardDescription: hazardMatch.hazardName,
        recentIncidentsCount: incidentMatch.totalCount,
      ));
    }

    return riskSegments;
  }

  /// Compare multiple routes and add risk metadata
  Future<List<RouteComparison>> compareRoutes({
    required List<RouteModel> routes,
    required DateTime departureTime,
  }) async {
    if (routes.isEmpty) return [];

    final List<RouteComparison> comparisons = [];

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final segments = await buildRiskSegments(
        route: route,
        departureTime: departureTime,
      );

      final overallRisk = segments.isEmpty
          ? 0.0
          : segments.map((s) => s.riskScore).reduce((a, b) => a + b) /
              segments.length;

      final avgRainProb = segments.isEmpty
          ? 0.0
          : segments
                  .map((s) => s.weather.rainProbability)
                  .reduce((a, b) => a + b) /
              segments.length;

      comparisons.add(RouteComparison(
        route: route,
        riskScore: overallRisk,
        rainProbability: avgRainProb,
        label: '',
      ));
    }

    // Sort by risk to assign labels
    comparisons.sort((a, b) => a.riskScore.compareTo(b.riskScore));

    // Assign labels
    final List<RouteComparison> labeled = [];
    for (int i = 0; i < comparisons.length; i++) {
      String label;
      if (i == 0) {
        label = 'Safest';
      } else {
        final fastest = comparisons.reduce(
            (a, b) => a.route.durationSeconds < b.route.durationSeconds ? a : b);
        label = comparisons[i] == fastest ? 'Fastest' : 'Balanced';
      }

      labeled.add(RouteComparison(
        route: comparisons[i].route,
        riskScore: comparisons[i].riskScore,
        rainProbability: comparisons[i].rainProbability,
        label: label,
      ));
    }

    return labeled;
  }

  /// Calculate risk for multiple departure times considering location vulnerability and weather
  Future<List<DepartureTimeWeather>> getDepartureTimeRecommendations({
    required LatLng location,
    required DateTime date,
  }) async {
    final weatherList = await _weatherService.fetchDepartureTimeWeather(
      location: location,
      date: date,
      hours: AppConstants.departureHours,
    );

    final hazardMatch = _ksdmaDataset.getRoadVulnerability(
      location.latitude,
      location.longitude,
    );
    final incidentMatch = _incidentService.queryIncidentsNear(
      location: location,
      referenceTime: date,
    );

    final List<DepartureTimeWeather> results = [];

    for (int i = 0; i < AppConstants.departureHours.length; i++) {
      final weather = weatherList[i];
      final risk = calculateRiskScore(
        rainfallIntensity: normalizeRainfallIntensity(weather.rainfallIntensity),
        rainProbability: normalizeRainProbability(weather.rainProbability),
        cumulativeRainfall: normalizeCumulativeRainfall(weather.cumulativeRainfall),
        roadVulnerability: hazardMatch.score,
        historicalIncidents: incidentMatch.score,
      );

      results.add(DepartureTimeWeather(
        hour: AppConstants.departureHours[i],
        label: AppConstants.departureLabels[i],
        weather: weather,
        riskScore: risk,
      ));
    }

    return results;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  List<List<LatLng>> _splitRouteIntoSegments(RouteModel route) {
    final coords = route.coordinates;
    if (coords.isEmpty) return [];

    // Each segment is ~5km based on constant
    final targetSegments =
        (route.distanceMeters / AppConstants.segmentLengthMeters).ceil();
    final count = targetSegments.clamp(1, 10);

    final segmentSize = (coords.length / count).ceil();
    final List<List<LatLng>> segments = [];

    for (int i = 0; i < count; i++) {
      final start = i * segmentSize;
      final end = ((i + 1) * segmentSize).clamp(0, coords.length);
      if (start >= coords.length) break;
      segments.add(coords.sublist(start, end));
    }

    return segments;
  }
}
