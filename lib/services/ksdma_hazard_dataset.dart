import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class HazardZone {
  final String id;
  final String name;
  final String routeStretch;
  final double vulnerabilityScore; // 0-100
  final String hazardType; // 'Landslide', 'Flood', 'Debris Flow', 'Rockfall'
  final String ksdmaClassification;
  final LatLng center;
  final double radiusKm;
  final String description;

  const HazardZone({
    required this.id,
    required this.name,
    required this.routeStretch,
    required this.vulnerabilityScore,
    required this.hazardType,
    required this.ksdmaClassification,
    required this.center,
    required this.radiusKm,
    required this.description,
  });
}

class HazardMatch {
  final double score; // 0-100
  final String hazardName;
  final String hazardType;
  final String ksdmaDetails;
  final double? distanceKm;

  const HazardMatch({
    required this.score,
    required this.hazardName,
    required this.hazardType,
    required this.ksdmaDetails,
    this.distanceKm,
  });

  static const HazardMatch baselineLow = HazardMatch(
    score: 25.0,
    hazardName: 'Standard Terrain',
    hazardType: 'Low Hazard',
    ksdmaDetails: 'KSDMA Low Susceptibility Zone',
  );
}

/// Module B - 3.3: Road Vulnerability Dataset
/// Built from public Kerala State Disaster Management Authority (KSDMA) hazard maps,
/// mapping road segments and vulnerable corridors to a vulnerability score (0-100).
class KsdmaHazardDataset {
  KsdmaHazardDataset._();
  static final KsdmaHazardDataset instance = KsdmaHazardDataset._();

  /// Curated KSDMA high-hazard corridors across Kerala
  static const List<HazardZone> knownCorridors = [
    HazardZone(
      id: 'MUNNAR_GAP_ROAD',
      name: 'NH 85 Munnar Gap Road & Devikulam Ghat',
      routeStretch: 'Kochi-Dhanushkodi NH 85 (Adimali - Munnar - Devikulam)',
      vulnerabilityScore: 92.0,
      hazardType: 'Landslide / Rockfall',
      ksdmaClassification: 'KSDMA High Landslide Hazard Zone (High Susceptibility)',
      center: LatLng(10.0512, 77.0820),
      radiusKm: 18.0,
      description: 'Steep rock cutting, intense runoff accumulation, and historical monsoon slope failures.',
    ),
    HazardZone(
      id: 'NERIAMANGALAM_ADIMALI',
      name: 'NH 85 Neriamangalam Forest Pass',
      routeStretch: 'Neriamangalam - Cheeyappara - Adimali',
      vulnerabilityScore: 84.0,
      hazardType: 'Landslide / Tree Fall',
      ksdmaClassification: 'KSDMA Moderate-High Landslide Susceptibility',
      center: LatLng(10.0381, 76.8835),
      radiusKm: 15.0,
      description: 'Ghat corridor with Cheeyappara & Valara seasonal waterfall runoff and slope instability.',
    ),
    HazardZone(
      id: 'THAMARASSERY_CHURAM',
      name: 'NH 766 Thamarassery Churam',
      routeStretch: 'Adivaram - Lakkidi - Vythiri (Wayanad Ghats)',
      vulnerabilityScore: 95.0,
      hazardType: 'Landslide / Debris Flow',
      ksdmaClassification: 'KSDMA Critical Landslide Hazard Zone',
      center: LatLng(11.4925, 76.0123),
      radiusKm: 14.0,
      description: 'Nine acute hairpin bends on unstable Western Ghat escarpment prone to mudslides.',
    ),
    HazardZone(
      id: 'WAYANAD_MEPPADI',
      name: 'Meppadi - Chooralmala - Mundakkai Belt',
      routeStretch: 'Meppadi - Chooralmala Route',
      vulnerabilityScore: 98.0,
      hazardType: 'Debris Flow / Torrential Wash',
      ksdmaClassification: 'KSDMA Very High Debris Flow Susceptibility',
      center: LatLng(11.5350, 76.1550),
      radiusKm: 12.0,
      description: 'High-energy stream catchment prone to catastrophic mudslides and riverbank breaches.',
    ),
    HazardZone(
      id: 'ALAPPUZHA_KUTTANAD',
      name: 'Alappuzha - Changanassery (AC Road) & Kuttanad',
      routeStretch: 'AC Road / Upper Kuttanad Polders',
      vulnerabilityScore: 88.0,
      hazardType: 'Chronic Flood Submersion',
      ksdmaClassification: 'KSDMA Chronic Flood Hazard Zone (Below Sea Level)',
      center: LatLng(9.4930, 76.4320),
      radiusKm: 16.0,
      description: 'Perennial flood zone vulnerable to Pamba, Manimala, and Achankovil river inundation.',
    ),
    HazardZone(
      id: 'KOTTAYAM_VAGAMON',
      name: 'Pala - Erattupetta - Vagamon Route',
      routeStretch: 'SH 14 / Teekoy - Vagamon Ghat Section',
      vulnerabilityScore: 82.0,
      hazardType: 'Flash Flood / Landslide',
      ksdmaClassification: 'KSDMA High Landslide Hazard Zone',
      center: LatLng(9.6840, 76.8520),
      radiusKm: 14.0,
      description: 'Meenachil river headwaters with recurrent cloudburst washouts and road cave-ins.',
    ),
    HazardZone(
      id: 'RANNI_PAMBA',
      name: 'Pathanamthitta Ranni - Pamba River Corridor',
      routeStretch: 'Ranni - Vadasserikkara - Sabarimala Highway',
      vulnerabilityScore: 80.0,
      hazardType: 'Severe Flash Flood',
      ksdmaClassification: 'KSDMA High Flood Susceptibility Zone',
      center: LatLng(9.3812, 76.7845),
      radiusKm: 15.0,
      description: 'Deep river gorge prone to sudden discharge surges from Kakki & Anathode dams.',
    ),
    HazardZone(
      id: 'CHALAKUDY_ATHIRAPPILLY',
      name: 'Chalakudy - Athirappilly - Valparai Corridor',
      routeStretch: 'SH 21 Chalakudy - Vettilappara - Athirappilly',
      vulnerabilityScore: 78.0,
      hazardType: 'River Overflow / Rockfall',
      ksdmaClassification: 'KSDMA Moderate-High Flood & Rockfall Zone',
      center: LatLng(10.3120, 76.4530),
      radiusKm: 15.0,
      description: 'Chalakudy river overflow corridor impacted by Sholayar and Poringalkuthu dam overflows.',
    ),
    HazardZone(
      id: 'IDUKKI_CHERUTHONI',
      name: 'Idukki Arch Dam - Cheruthoni - Kattappana Pass',
      routeStretch: 'Thodupuzha - Idukki - Kattappana State Highway',
      vulnerabilityScore: 86.0,
      hazardType: 'Steep Landslide / Spill Hazard',
      ksdmaClassification: 'KSDMA High Susceptibility Highland Zone',
      center: LatLng(9.8510, 76.9740),
      radiusKm: 16.0,
      description: 'Periyaru gorge highland road with slope collapse risk during reservoir high alerts.',
    ),
  ];

  /// Find matching KSDMA hazard zone or evaluate baseline regional vulnerability (0-100)
  HazardMatch getRoadVulnerability(double lat, double lng) {
    HazardZone? nearestZone;
    double minDistance = double.infinity;

    for (final zone in knownCorridors) {
      final distance = _calculateDistanceKm(lat, lng, zone.center.latitude, zone.center.longitude);
      if (distance <= zone.radiusKm && distance < minDistance) {
        minDistance = distance;
        nearestZone = zone;
      }
    }

    if (nearestZone != null) {
      // Proximity falloff: highest vulnerability near the core, tapering slightly to 80% at boundary
      final proximityFactor = 1.0 - (0.2 * (minDistance / nearestZone.radiusKm));
      final score = (nearestZone.vulnerabilityScore * proximityFactor).clamp(0.0, 100.0);

      return HazardMatch(
        score: score,
        hazardName: nearestZone.name,
        hazardType: nearestZone.hazardType,
        ksdmaDetails: '${nearestZone.ksdmaClassification} (${nearestZone.routeStretch})',
        distanceKm: minDistance,
      );
    }

    // Regional baseline estimation based on Kerala Geomorphology:
    // Highland (Western Ghats > 76.5° E): High slope vulnerability (65)
    // Midland rolling hills (76.2° E - 76.5° E): Moderate (42)
    // Coastal plain (< 76.2° E): Baseline flood risk (30)
    if (lng > 76.60) {
      return const HazardMatch(
        score: 65.0,
        hazardName: 'Western Ghats Highland Zone',
        hazardType: 'Highland Slope Vulnerability',
        ksdmaDetails: 'KSDMA Moderate-High Mountain Hazard Baseline',
      );
    } else if (lng > 76.25) {
      return const HazardMatch(
        score: 42.0,
        hazardName: 'Kerala Midland Corridor',
        hazardType: 'Rolling Terrain Drainage',
        ksdmaDetails: 'KSDMA Standard Midland Risk Baseline',
      );
    } else {
      return const HazardMatch(
        score: 30.0,
        hazardName: 'Kerala Coastal / Lowland Plain',
        hazardType: 'Lowland Drainage',
        ksdmaDetails: 'KSDMA Low-to-Moderate Coastal Drainage Baseline',
      );
    }
  }

  /// Haversine distance in kilometers
  static double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
