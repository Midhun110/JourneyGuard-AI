class IncidentReport {
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final String incidentType;
  final String description;
  final DateTime reportedAt;
  final String? locationName;

  const IncidentReport({
    this.imagePath,
    this.latitude,
    this.longitude,
    required this.incidentType,
    required this.description,
    required this.reportedAt,
    this.locationName,
  });

  Map<String, dynamic> toJson() => {
        'incident_type': incidentType,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'image_path': imagePath,
        'reported_at': reportedAt.toIso8601String(),
        'location_name': locationName,
      };

  static const List<String> incidentTypes = [
    'Flood',
    'Landslide',
    'Accident',
    'Road Damage',
    'Waterlogging',
    'Tree Fall',
    'Bridge Damage',
    'Other',
  ];
}
