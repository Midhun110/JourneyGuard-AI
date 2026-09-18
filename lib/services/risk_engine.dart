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

  // ─── Module C: Route-Level Risk Aggregation & Ranking ──────────────────────

  /// Module C: Route-level risk aggregation
  ///
  /// - Distance-weighted average (default):
  ///   sum(segment.riskScore * segment.distanceMeters) / sum(segment.distanceMeters)
  /// - Conservative peak risk (if [conservative] is true):
  ///   max(segment.riskScore)
  double calculateRouteRisk(
    List<RiskSegment> segments, {
    bool conservative = false,
  }) {
    if (segments.isEmpty) return 0.0;
    if (conservative) {
      return segments.map((s) => s.riskScore).reduce((a, b) => a > b ? a : b);
    }

    final totalDist =
        segments.map((s) => s.distanceMeters).fold<double>(0.0, (a, b) => a + b);
    if (totalDist <= 0) {
      return segments.map((s) => s.riskScore).reduce((a, b) => a + b) /
          segments.length;
    }

    final weightedSum = segments.fold<double>(
      0.0,
      (sum, s) => sum + (s.riskScore * s.distanceMeters),
    );
    return (weightedSum / totalDist).clamp(0.0, 100.0);
  }

  /// Module C: Combined score balancing safety and time
  ///
  /// route_score = (risk_weight * normalized_risk) + (time_weight * normalized_duration)
  /// Default: risk_weight = 0.70 (safety-first), time_weight = 0.30
  double calculateCombinedRouteScore({
    required double normalizedRisk,
    required double normalizedDuration,
    double riskWeight = AppConstants.defaultRiskWeight,
    double timeWeight = AppConstants.defaultTimeWeight,
  }) {
    final score = (riskWeight * normalizedRisk.clamp(0.0, 100.0)) +
        (timeWeight * normalizedDuration.clamp(0.0, 100.0));
    return score.clamp(0.0, 100.0);
  }

  /// Normalizes durations across a set of routes to a 0-100 penalty scale.
  /// The fastest route receives 0.0, while the slowest alternative receives 100.0.
  List<double> normalizeRouteDurations(List<RouteModel> routes) {
    if (routes.isEmpty) return [];
    if (routes.length == 1) return [0.0];

    final minDuration =
        routes.map((r) => r.durationSeconds).reduce((a, b) => a < b ? a : b);
    final maxDuration =
        routes.map((r) => r.durationSeconds).reduce((a, b) => a > b ? a : b);
    final span = maxDuration - minDuration;

    return routes.map((r) {
      if (span <= 0) return 0.0;
      return ((r.durationSeconds - minDuration) / span * 100.0)
          .clamp(0.0, 100.0);
    }).toList();
  }

  /// Module C: Compare routes and produce comprehensive ranking, recommendations,
  /// and postponement advisory check.
  Future<RouteComparisonResult> compareRoutesDetailed({
    required List<RouteModel> routes,
    required DateTime departureTime,
    double riskWeight = AppConstants.defaultRiskWeight,
    double timeWeight = AppConstants.defaultTimeWeight,
    bool useConservativeMax = false,
  }) async {
    if (routes.isEmpty) {
      return RouteComparisonResult(
        comparisons: [],
        riskWeight: riskWeight,
        timeWeight: timeWeight,
        useConservativeMax: useConservativeMax,
        isPostponementAdvised: false,
      );
    }

    // Step 1: Analyze each route's segments using Module B pipeline
    final List<List<RiskSegment>> allSegments = [];
    for (final route in routes) {
      final segments = await buildRiskSegments(
        route: route,
        departureTime: departureTime,
      );
      allSegments.add(segments);
    }

    // Step 2: Normalize durations across all alternative routes
    final normDurations = normalizeRouteDurations(routes);

    // Step 3: Compute individual route metrics
    final List<RouteComparison> rawComparisons = [];
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final segments = allSegments[i];

      final weightedAvg = calculateRouteRisk(segments, conservative: false);
      final maxRisk = calculateRouteRisk(segments, conservative: true);
      final activeRisk = useConservativeMax ? maxRisk : weightedAvg;

      final avgRainProb = segments.isEmpty
          ? 0.0
          : segments
                  .map((s) => s.weather.rainProbability)
                  .reduce((a, b) => a + b) /
              segments.length;

      final normDuration = normDurations[i];
      final combinedScore = calculateCombinedRouteScore(
        normalizedRisk: activeRisk,
        normalizedDuration: normDuration,
        riskWeight: riskWeight,
        timeWeight: timeWeight,
      );

      rawComparisons.add(RouteComparison(
        route: route,
        riskScore: activeRisk,
        rainProbability: avgRainProb,
        label: '',
        segments: segments,
        weightedAvgRisk: weightedAvg,
        maxRisk: maxRisk,
        normalizedDuration: normDuration,
        combinedScore: combinedScore,
      ));
    }

    // Step 4: Identify Safest and Fastest-Acceptable routes
    final minRisk =
        rawComparisons.map((c) => c.riskScore).reduce((a, b) => a < b ? a : b);
    final safestRoute = rawComparisons.firstWhere((c) => c.riskScore == minRisk);

    // Fastest-Acceptable = fastest duration among routes with acceptable risk (<= 50.0)
    final acceptableCandidates = rawComparisons.where(
      (c) => c.riskScore <= AppConstants.acceptableRiskThreshold,
    ).toList();
    RouteComparison? fastestAcceptable;
    if (acceptableCandidates.isNotEmpty) {
      fastestAcceptable = acceptableCandidates.reduce(
        (a, b) => a.route.durationSeconds < b.route.durationSeconds ? a : b,
      );
    }

    // Step 5: Postponement Advisory Check
    // Triggered if EVERY route scores High or Critical (> 50.0) OR all routes have critical peak hazard
    final allHighOrCritical = rawComparisons.every(
      (c) => c.riskScore > AppConstants.acceptableRiskThreshold,
    );
    final allHaveCriticalHazards = rawComparisons.every(
      (c) => c.maxRisk >= AppConstants.highRiskThreshold,
    );
    final isPostponementAdvised = allHighOrCritical || allHaveCriticalHazards;
    String? postponementReason;
    if (isPostponementAdvised) {
      postponementReason =
          'All available routes exceed safe risk limits (High/Critical hazard). '
          'Severe weather or unstable road corridors detected. '
          'Strongly advise postponing journey or selecting an alternative departure window.';
    }

    // Step 6: Sort routes by combinedScore ascending (lower penalty = better route)
    final sorted = List<RouteComparison>.from(rawComparisons)
      ..sort((a, b) => a.combinedScore.compareTo(b.combinedScore));

    // Step 7: Assign ranks and informative labels
    final List<RouteComparison> finalComparisons = [];
    for (int rank = 1; rank <= sorted.length; rank++) {
      final comp = sorted[rank - 1];
      final isSafest = comp.route == safestRoute.route;
      final isFastestAcceptable =
          fastestAcceptable != null && comp.route == fastestAcceptable.route;
      final isRecommended = rank == 1;

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
        label = 'Alternative $rank';
        tag = 'Alternative';
      }

      if (comp.riskScore > AppConstants.highRiskThreshold) {
        label = '$label (Critical)';
      } else if (comp.riskScore > AppConstants.acceptableRiskThreshold) {
        label = '$label (High Risk)';
      }

      finalComparisons.add(comp.copyWith(
        rank: rank,
        label: label,
        isSafest: isSafest,
        isFastestAcceptable: isFastestAcceptable,
        isRecommended: isRecommended,
        recommendationTag: tag,
      ));
    }

    return RouteComparisonResult(
      comparisons: finalComparisons,
      riskWeight: riskWeight,
      timeWeight: timeWeight,
      useConservativeMax: useConservativeMax,
      isPostponementAdvised: isPostponementAdvised,
      postponementReason: postponementReason,
    );
  }

  /// Module C: Compare multiple routes and return list of comparisons
  Future<List<RouteComparison>> compareRoutes({
    required List<RouteModel> routes,
    required DateTime departureTime,
    double riskWeight = AppConstants.defaultRiskWeight,
    double timeWeight = AppConstants.defaultTimeWeight,
    bool useConservativeMax = false,
  }) async {
    final result = await compareRoutesDetailed(
      routes: routes,
      departureTime: departureTime,
      riskWeight: riskWeight,
      timeWeight: timeWeight,
      useConservativeMax: useConservativeMax,
    );
    return result.comparisons;
  }

  /// Module C: Smart Departure Time Recommendation
  ///
  /// Re-runs the entire Module A -> B segment-level pipeline across shifted
  /// departure timestamps for the given route.
  Future<List<DepartureTimeWeather>> evaluateRouteAcrossDepartureTimes({
    required RouteModel route,
    required DateTime date,
    List<int>? hours,
  }) async {
    final targetHours = hours ?? AppConstants.departureHours;
    final List<DepartureTimeWeather> results = [];

    for (int i = 0; i < targetHours.length; i++) {
      final hour = targetHours[i];
      final label = i < AppConstants.departureLabels.length
          ? AppConstants.departureLabels[i]
          : '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? "AM" : "PM"}';

      final shiftedDeparture = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        0,
      );

      // Run full Module A -> B pipeline on this route with shifted timestamp
      final segments = await buildRiskSegments(
        route: route,
        departureTime: shiftedDeparture,
      );

      final weightedAvg = calculateRouteRisk(segments, conservative: false);
      final maxRisk = calculateRouteRisk(segments, conservative: true);

      final avgRainProb = segments.isEmpty
          ? 0.0
          : segments
                  .map((s) => s.weather.rainProbability)
                  .reduce((a, b) => a + b) /
              segments.length;
      final avgRainIntensity = segments.isEmpty
          ? 0.0
          : segments
                  .map((s) => s.weather.rainfallIntensity)
                  .reduce((a, b) => a + b) /
              segments.length;
      final totalRainfall = segments.isEmpty
          ? 0.0
          : segments
                  .map((s) => s.weather.cumulativeRainfall)
                  .reduce((a, b) => a + b);

      final representativeWeather = WeatherData(
        rainfallIntensity: avgRainIntensity,
        rainProbability: avgRainProb,
        cumulativeRainfall: totalRainfall,
        temperature:
            segments.isNotEmpty ? segments.first.weather.temperature : 25.0,
        windSpeed: segments.isNotEmpty ? segments.first.weather.windSpeed : 10.0,
        weatherCode:
            segments.isNotEmpty ? segments.first.weather.weatherCode : '0',
        fetchedAt: DateTime.now(),
      );

      results.add(DepartureTimeWeather(
        hour: hour,
        label: label,
        weather: representativeWeather,
        riskScore: weightedAvg,
        maxRisk: maxRisk,
        weightedAvgRisk: weightedAvg,
        departureTime: shiftedDeparture,
      ));
    }

    if (results.isEmpty) return [];

    // Find safest slot (minimum risk score)
    final minRisk =
        results.map((r) => r.riskScore).reduce((a, b) => a < b ? a : b);
    final baselineRisk = results.first.riskScore;

    return results.map((r) {
      final isSafest = r.riskScore == minRisk;
      double reduction = 0.0;
      if (baselineRisk > 0) {
        reduction =
            ((baselineRisk - r.riskScore) / baselineRisk * 100).clamp(-100.0, 100.0);
      }
      return DepartureTimeWeather(
        hour: r.hour,
        label: r.label,
        weather: r.weather,
        riskScore: r.riskScore,
        maxRisk: r.maxRisk,
        weightedAvgRisk: r.weightedAvgRisk,
        riskReductionVsBaseline: reduction,
        isSafestSlot: isSafest,
        departureTime: r.departureTime,
      );
    }).toList();
  }

  /// Calculate risk for multiple departure times considering location vulnerability and weather
  /// (Point fallback when full route model is not supplied)
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
        maxRisk: risk,
        weightedAvgRisk: risk,
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
