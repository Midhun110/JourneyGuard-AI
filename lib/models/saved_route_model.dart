import 'package:latlong2/latlong.dart';

class SavedRouteModel {
  final String id;
  final String name;
  final String fromName;
  final String toName;
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;
  final DateTime departureTime;
  final double initialRiskScore;
  final bool isMonitored;
  final DateTime savedAt;
  final String summary;

  const SavedRouteModel({
    required this.id,
    required this.name,
    required this.fromName,
    required this.toName,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
    required this.departureTime,
    required this.initialRiskScore,
    this.isMonitored = true,
    required this.savedAt,
    this.summary = '',
  });

  LatLng get fromLocation => LatLng(fromLatitude, fromLongitude);
  LatLng get toLocation => LatLng(toLatitude, toLongitude);

  SavedRouteModel copyWith({
    String? id,
    String? name,
    String? fromName,
    String? toName,
    double? fromLatitude,
    double? fromLongitude,
    double? toLatitude,
    double? toLongitude,
    DateTime? departureTime,
    double? initialRiskScore,
    bool? isMonitored,
    DateTime? savedAt,
    String? summary,
  }) {
    return SavedRouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fromName: fromName ?? this.fromName,
      toName: toName ?? this.toName,
      fromLatitude: fromLatitude ?? this.fromLatitude,
      fromLongitude: fromLongitude ?? this.fromLongitude,
      toLatitude: toLatitude ?? this.toLatitude,
      toLongitude: toLongitude ?? this.toLongitude,
      departureTime: departureTime ?? this.departureTime,
      initialRiskScore: initialRiskScore ?? this.initialRiskScore,
      isMonitored: isMonitored ?? this.isMonitored,
      savedAt: savedAt ?? this.savedAt,
      summary: summary ?? this.summary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fromName': fromName,
      'toName': toName,
      'fromLatitude': fromLatitude,
      'fromLongitude': fromLongitude,
      'toLatitude': toLatitude,
      'toLongitude': toLongitude,
      'departureTime': departureTime.toIso8601String(),
      'initialRiskScore': initialRiskScore,
      'isMonitored': isMonitored,
      'savedAt': savedAt.toIso8601String(),
      'summary': summary,
    };
  }

  factory SavedRouteModel.fromJson(Map<String, dynamic> json) {
    return SavedRouteModel(
      id: json['id'] as String,
      name: json['name'] as String,
      fromName: json['fromName'] as String,
      toName: json['toName'] as String,
      fromLatitude: (json['fromLatitude'] as num).toDouble(),
      fromLongitude: (json['fromLongitude'] as num).toDouble(),
      toLatitude: (json['toLatitude'] as num).toDouble(),
      toLongitude: (json['toLongitude'] as num).toDouble(),
      departureTime: DateTime.parse(json['departureTime'] as String),
      initialRiskScore: (json['initialRiskScore'] as num).toDouble(),
      isMonitored: json['isMonitored'] as bool? ?? true,
      savedAt: DateTime.parse(json['savedAt'] as String),
      summary: json['summary'] as String? ?? '',
    );
  }
}
