import 'package:latlong2/latlong.dart';

class RouteModel {
  final List<LatLng> coordinates;
  final double distanceMeters;
  final double durationSeconds;
  final String summary;

  const RouteModel({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.summary,
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
    );
  }
}

class RouteComparison {
  final RouteModel route;
  final double riskScore;
  final double rainProbability;
  final String label; // 'Safest', 'Fastest', 'Balanced'

  const RouteComparison({
    required this.route,
    required this.riskScore,
    required this.rainProbability,
    required this.label,
  });
}
