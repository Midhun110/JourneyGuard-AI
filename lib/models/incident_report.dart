import 'dart:math' as math;
import '../core/constants/supabase_constants.dart';

class IncidentReport {
  final String? id;
  final String? reporterId;
  final String? imagePath; // Local file path
  final String? photoUrl; // Remote Supabase storage URL
  final double? latitude;
  final double? longitude;
  final String incidentType;
  final String description;
  final DateTime reportedAt;
  final String? locationName;
  final double? distanceMeters;

  const IncidentReport({
    this.id,
    this.reporterId,
    this.imagePath,
    this.photoUrl,
    this.latitude,
    this.longitude,
    required this.incidentType,
    required this.description,
    required this.reportedAt,
    this.locationName,
    this.distanceMeters,
  });

  /// Formats location as WKT (Well-Known Text) for PostGIS GEOGRAPHY(POINT, 4326)
  String? get wktLocation {
    if (latitude == null || longitude == null) return null;
    return 'POINT($longitude $latitude)';
  }

  /// Map for Supabase PostgreSQL + PostGIS insert
  Map<String, dynamic> toSupabaseInsertMap() {
    return {
      if (reporterId != null) 'reporter_id': reporterId,
      if (wktLocation != null) 'location': wktLocation,
      'incident_type': _normalizeType(incidentType),
      'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
      'created_at': reportedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (reporterId != null) 'reporter_id': reporterId,
        'incident_type': incidentType,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'image_path': imagePath,
        if (photoUrl != null) 'photo_url': photoUrl,
        'reported_at': reportedAt.toIso8601String(),
        'location_name': locationName,
        if (distanceMeters != null) 'distance_meters': distanceMeters,
      };

  /// Factory to parse from PostGIS RPC `get_incidents_near` or table query
  factory IncidentReport.fromSupabase(Map<String, dynamic> data) {
    double? lat;
    double? lng;

    // 1. Check direct latitude/longitude (from RPC)
    if (data['latitude'] != null && data['longitude'] != null) {
      lat = (data['latitude'] as num).toDouble();
      lng = (data['longitude'] as num).toDouble();
    }
    // 2. Check PostGIS GeoJSON format
    else if (data['location'] is Map<String, dynamic>) {
      final loc = data['location'] as Map<String, dynamic>;
      final coords = loc['coordinates'] as List?;
      if (coords != null && coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }
    // 3. Check PostGIS WKT string: "POINT(lng lat)"
    else if (data['location'] is String) {
      final wkt = data['location'] as String;
      final match = RegExp(r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)', caseSensitive: false)
          .firstMatch(wkt);
      if (match != null) {
        lng = double.tryParse(match.group(1)!);
        lat = double.tryParse(match.group(2)!);
      }
    }

    final createdAt = data['created_at'] != null
        ? DateTime.tryParse(data['created_at'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    final dist = data['distance_meters'] != null
        ? (data['distance_meters'] as num).toDouble()
        : null;

    final typeRaw = data['incident_type']?.toString() ?? 'other';

    return IncidentReport(
      id: data['id']?.toString(),
      reporterId: data['reporter_id']?.toString(),
      latitude: lat,
      longitude: lng,
      incidentType: _formatType(typeRaw),
      description: data['description']?.toString() ?? '',
      photoUrl: data['photo_url']?.toString(),
      reportedAt: createdAt,
      distanceMeters: dist,
      locationName: lat != null && lng != null
          ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
          : null,
    );
  }

  IncidentReport copyWith({
    String? id,
    String? reporterId,
    String? imagePath,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? incidentType,
    String? description,
    DateTime? reportedAt,
    String? locationName,
    double? distanceMeters,
  }) {
    return IncidentReport(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      imagePath: imagePath ?? this.imagePath,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      incidentType: incidentType ?? this.incidentType,
      description: description ?? this.description,
      reportedAt: reportedAt ?? this.reportedAt,
      locationName: locationName ?? this.locationName,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  static String _normalizeType(String type) {
    switch (type.toLowerCase()) {
      case 'flood':
      case 'flash flood':
        return SupabaseConstants.typeFlood;
      case 'landslide':
      case 'landslide / rockfall':
        return SupabaseConstants.typeLandslide;
      case 'tree fall':
      case 'fallen tree':
      case 'fallen_tree':
        return SupabaseConstants.typeFallenTree;
      case 'road damage':
      case 'road washout / crack':
      case 'road_damage':
        return SupabaseConstants.typeRoadDamage;
      case 'waterlogging':
      case 'severe waterlogging':
        return SupabaseConstants.typeWaterlogging;
      default:
        return SupabaseConstants.typeOther;
    }
  }

  static String _formatType(String raw) {
    return SupabaseConstants.getDisplayName(raw);
  }

  static const List<String> incidentTypes = [
    'Flash Flood',
    'Landslide / Rockfall',
    'Fallen Tree',
    'Road Washout / Crack',
    'Severe Waterlogging',
    'Hazard / Obstruction',
  ];
}
