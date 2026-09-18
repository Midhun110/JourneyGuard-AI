import 'package:latlong2/latlong.dart';
import 'risk_segment.dart';

class RouteModel {
  final List<LatLng> coordinates;
  final double distanceMeters;
  final double durationSeconds;
  final String summary;
  final bool isEstimated;

  const RouteModel({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.summary,
    this.isEstimated = false,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();

  String get formattedDistance {
    if (distanceKm >= 1) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      return '${hours}h ${minutes}m';
    }
    return '$durationMinutes min';
  }

  factory RouteModel.fromOsrm(Map<String, dynamic> route) {
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = (geometry['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final legs = route['legs'] as List;
    final summary = legs.isNotEmpty ? (legs[0]['summary'] as String? ?? '') : '';

    return RouteModel(
      coordinates: coordinates,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      summary: summary,
      isEstimated: false,
    );
  }

  RouteModel copyWith({
    List<LatLng>? coordinates,
    double? distanceMeters,
    double? durationSeconds,
    String? summary,
    bool? isEstimated,
  }) {
    return RouteModel(
      coordinates: coordinates ?? this.coordinates,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      summary: summary ?? this.summary,
      isEstimated: isEstimated ?? this.isEstimated,
    );
  }
}

/// Module C: Comprehensive Route Comparison Model
///
/// Balances route-level risk (distance-weighted or conservative peak)
/// with normalized journey duration according to user safety weights.
class RouteComparison {
  final RouteModel route;
  final double riskScore; // Active route-level risk score (0-100)
  final double rainProbability; // 0-100 %
  final String label; // 'Safest', 'Fastest Acceptable', 'Balanced', etc.
  final bool isEstimated;

  // Module C Extended Metrics
  final List<RiskSegment> segments;
  final double weightedAvgRisk;
  final double maxRisk;
  final double normalizedDuration; // 0-100 penalty relative to fastest route
  final double combinedScore; // (risk_weight * norm_risk) + (time_weight * norm_duration)
  final int rank; // 1-based rank
  final bool isSafest;
  final bool isFastestAcceptable;
  final bool isRecommended;
  final String recommendationTag;

  const RouteComparison({
    required this.route,
    required this.riskScore,
    required this.rainProbability,
    required this.label,
    this.isEstimated = false,
    this.segments = const [],
    this.weightedAvgRisk = 0.0,
    this.maxRisk = 0.0,
    this.normalizedDuration = 0.0,
    this.combinedScore = 0.0,
    this.rank = 1,
    this.isSafest = false,
    this.isFastestAcceptable = false,
    this.isRecommended = false,
    this.recommendationTag = '',
  });

  String get riskClassification => RiskSegment.classifyRiskLevel(riskScore);
  String get peakRiskClassification => RiskSegment.classifyRiskLevel(maxRisk);

  double get cumulativeRainfall {
    if (segments.isEmpty) return 0.0;
    return segments.fold(0.0, (acc, s) => acc + s.weather.cumulativeRainfall);
  }

  RouteComparison copyWith({
    RouteModel? route,
    double? riskScore,
    double? rainProbability,
    String? label,
    bool? isEstimated,
    List<RiskSegment>? segments,
    double? weightedAvgRisk,
    double? maxRisk,
    double? normalizedDuration,
    double? combinedScore,
    int? rank,
    bool? isSafest,
    bool? isFastestAcceptable,
    bool? isRecommended,
    String? recommendationTag,
  }) {
    return RouteComparison(
      route: route ?? this.route,
      riskScore: riskScore ?? this.riskScore,
      rainProbability: rainProbability ?? this.rainProbability,
      label: label ?? this.label,
      isEstimated: isEstimated ?? this.isEstimated,
      segments: segments ?? this.segments,
      weightedAvgRisk: weightedAvgRisk ?? this.weightedAvgRisk,
      maxRisk: maxRisk ?? this.maxRisk,
      normalizedDuration: normalizedDuration ?? this.normalizedDuration,
      combinedScore: combinedScore ?? this.combinedScore,
      rank: rank ?? this.rank,
      isSafest: isSafest ?? this.isSafest,
      isFastestAcceptable: isFastestAcceptable ?? this.isFastestAcceptable,
      isRecommended: isRecommended ?? this.isRecommended,
      recommendationTag: recommendationTag ?? this.recommendationTag,
    );
  }
}

/// Container for multi-route evaluation results and active recommendations
class RouteComparisonResult {
  final List<RouteComparison> comparisons;
  final double riskWeight;
  final double timeWeight;
  final bool useConservativeMax;
  final bool isPostponementAdvised;
  final String? postponementReason;

  const RouteComparisonResult({
    required this.comparisons,
    required this.riskWeight,
    required this.timeWeight,
    required this.useConservativeMax,
    required this.isPostponementAdvised,
    this.postponementReason,
  });

  RouteComparison? get safestRoute {
    if (comparisons.isEmpty) return null;
    return comparisons.firstWhere(
      (c) => c.isSafest,
      orElse: () => comparisons.reduce((a, b) => a.riskScore < b.riskScore ? a : b),
    );
  }

  RouteComparison? get fastestAcceptableRoute {
    final matches = comparisons.where((c) => c.isFastestAcceptable);
    return matches.isNotEmpty ? matches.first : null;
  }

  RouteComparison? get recommendedRoute {
    if (comparisons.isEmpty) return null;
    return comparisons.firstWhere(
      (c) => c.isRecommended,
      orElse: () => comparisons.first,
    );
  }
}
