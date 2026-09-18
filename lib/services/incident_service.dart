import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/incident_report.dart';

class IncidentQueryMatch {
  final double score; // 0-100
  final int totalCount;
  final int activeRecentCount;
  final List<IncidentReport> nearbyIncidents;

  const IncidentQueryMatch({
    required this.score,
    required this.totalCount,
    required this.activeRecentCount,
    required this.nearbyIncidents,
  });

  static const IncidentQueryMatch zero = IncidentQueryMatch(
    score: 0.0,
    totalCount: 0,
    activeRecentCount: 0,
    nearbyIncidents: [],
  );
}

/// Module B - 3.3 & Module D: Incident Reporting & Historical Disaster Service
/// Manages both historical disaster archives and real-time crowdsourced reports.
/// Calculates recency-weighted incident density near route segments.
class IncidentService {
  IncidentService._() {
    _seedHistoricalIncidents();
  }
  static final IncidentService instance = IncidentService._();

  final List<IncidentReport> _reports = [];

  List<IncidentReport> get allReports => List.unmodifiable(_reports);

  /// Add a newly crowdsourced incident report (Module D)
  void addReport(IncidentReport report) {
    _reports.insert(0, report);
  }

  /// Query incidents within [radiusKm] of segment midpoint and compute recency-weighted score (0-100)
  IncidentQueryMatch queryIncidentsNear({
    required LatLng location,
    double radiusKm = 10.0,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();
    double weightedScore = 0.0;
    int totalCount = 0;
    int activeRecentCount = 0;
    final List<IncidentReport> matching = [];

    for (final report in _reports) {
      if (report.latitude == null || report.longitude == null) continue;

      final dist = _calculateDistanceKm(
        location.latitude,
        location.longitude,
        report.latitude!,
        report.longitude!,
      );

      if (dist <= radiusKm) {
        matching.add(report);
        totalCount++;

        final ageInHours = now.difference(report.reportedAt).inHours.abs();
        final double weight;

        if (ageInHours <= 24) {
          weight = 1.0; // Critical active ongoing hazard
          activeRecentCount++;
        } else if (ageInHours <= 24 * 7) {
          weight = 0.7; // Fresh incident (clearing/damaged roadbed)
          activeRecentCount++;
        } else if (ageInHours <= 24 * 30) {
          weight = 0.4; // Recent incident (sub-acute vulnerability)
        } else {
          weight = 0.2; // Historical chronic hazard point
        }

        // Distance attenuation within radius
        final distFactor = 1.0 - (0.3 * (dist / radiusKm));
        weightedScore += weight * distFactor;
      }
    }

    // Normalization: Cap at 5.0 weighted score = 100.0
    // (e.g. 5 active reports or combination of recent/historical reports)
    final normalizedScore = (weightedScore / 5.0 * 100.0).clamp(0.0, 100.0);

    return IncidentQueryMatch(
      score: normalizedScore,
      totalCount: totalCount,
      activeRecentCount: activeRecentCount,
      nearbyIncidents: matching,
    );
  }

  void _seedHistoricalIncidents() {
    final now = DateTime.now();

    _reports.addAll([
      // Munnar Gap Road (NH 85)
      IncidentReport(
        latitude: 10.0480,
        longitude: 77.0780,
        incidentType: 'Landslide',
        description: 'Major rockfall and debris blocked both lanes near Munnar Gap Road.',
        reportedAt: now.subtract(const Duration(hours: 4)),
        locationName: 'NH 85 Munnar Gap Road',
      ),
      IncidentReport(
        latitude: 10.0390,
        longitude: 76.8920,
        incidentType: 'Tree Fall',
        description: 'Uprooted tree obstructing ghat traffic near Cheeyappara waterfalls.',
        reportedAt: now.subtract(const Duration(days: 2)),
        locationName: 'Neriamangalam - Adimali Ghat',
      ),

      // Wayanad Thamarassery Churam & Chooralmala (NH 766)
      IncidentReport(
        latitude: 11.4950,
        longitude: 76.0150,
        incidentType: 'Landslide',
        description: 'Mudslide on 6th hairpin bend causing vehicular blockage.',
        reportedAt: now.subtract(const Duration(hours: 12)),
        locationName: 'Thamarassery Churam Hairpin 6',
      ),
      IncidentReport(
        latitude: 11.5380,
        longitude: 76.1520,
        incidentType: 'Landslide',
        description: 'Severe hillside soil slip and flash flood runoff across bridge.',
        reportedAt: now.subtract(const Duration(days: 14)),
        locationName: 'Chooralmala - Meppadi Route',
      ),

      // Alappuzha Kuttanad / AC Road
      IncidentReport(
        latitude: 9.4950,
        longitude: 76.4380,
        incidentType: 'Waterlogging',
        description: 'Kuttanad polder water level overflowing onto AC road carriageway.',
        reportedAt: now.subtract(const Duration(hours: 18)),
        locationName: 'Alappuzha-Changanassery Road (Nedumudi)',
      ),
      IncidentReport(
        latitude: 9.4890,
        longitude: 76.3890,
        incidentType: 'Flood',
        description: 'Water submerging service lanes near Pallathuruthy bridge.',
        reportedAt: now.subtract(const Duration(days: 3)),
        locationName: 'Pallathuruthy Bridge, AC Road',
      ),

      // Chalakudy / Athirappilly
      IncidentReport(
        latitude: 10.3150,
        longitude: 76.4480,
        incidentType: 'Road Damage',
        description: 'River embankment erosion damaged asphalt shoulder.',
        reportedAt: now.subtract(const Duration(days: 5)),
        locationName: 'Chalakudy-Athirappilly Road',
      ),

      // Idukki Kattappana / Cheruthoni
      IncidentReport(
        latitude: 9.8550,
        longitude: 76.9680,
        incidentType: 'Landslide',
        description: 'Minor earth collapse after continuous evening showers.',
        reportedAt: now.subtract(const Duration(hours: 6)),
        locationName: 'Cheruthoni - Kattappana Road',
      ),
    ]);
  }

  static double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
