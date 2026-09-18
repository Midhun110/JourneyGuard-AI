import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'weather_data.dart';
import '../core/theme/app_colors.dart';

enum RiskLevel { low, moderate, high, critical }

class RiskSegment {
  final List<LatLng> points;
  final double riskScore;
  final WeatherData weather;
  final double distanceMeters;
  final double durationMinutes;
  final int segmentIndex;

  // Module B factor breakdown (0-100 normalized)
  final double rainfallIntensityNorm;
  final double cumulativeRainfallNorm;
  final double roadVulnerability;
  final double historicalIncidentsScore;
  final String hazardDescription;
  final int recentIncidentsCount;

  const RiskSegment({
    required this.points,
    required this.riskScore,
    required this.weather,
    required this.distanceMeters,
    required this.durationMinutes,
    required this.segmentIndex,
    this.rainfallIntensityNorm = 0.0,
    this.cumulativeRainfallNorm = 0.0,
    this.roadVulnerability = 0.0,
    this.historicalIncidentsScore = 0.0,
    this.hazardDescription = '',
    this.recentIncidentsCount = 0,
  });

  /// Module B - 3.5: Risk classification
  static String classifyRiskLevel(double score) {
    if (score <= 25) return 'Low';
    if (score <= 50) return 'Moderate';
    if (score <= 75) return 'High';
    return 'Critical';
  }

  RiskLevel get riskLevel {
    if (riskScore <= 25) return RiskLevel.low;
    if (riskScore <= 50) return RiskLevel.moderate;
    if (riskScore <= 75) return RiskLevel.high;
    return RiskLevel.critical;
  }

  Color get color {
    switch (riskLevel) {
      case RiskLevel.low:
        return AppColors.riskLow;
      case RiskLevel.moderate:
        return AppColors.riskModerate;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.critical:
        return AppColors.riskCritical;
    }
  }

  String get riskLevelLabel => classifyRiskLevel(riskScore);

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedEta {
    if (durationMinutes >= 60) {
      final h = durationMinutes ~/ 60;
      final m = durationMinutes.round() % 60;
      return '${h}h ${m}m';
    }
    return '${durationMinutes.toStringAsFixed(0)} min';
  }

  LatLng get midpoint {
    if (points.isEmpty) return const LatLng(0, 0);
    final mid = points.length ~/ 2;
    return points[mid];
  }
}
