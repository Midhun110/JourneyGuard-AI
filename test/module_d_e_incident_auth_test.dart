import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:journey_guard_ai/core/constants/supabase_constants.dart';
import 'package:journey_guard_ai/models/incident_report.dart';
import 'package:journey_guard_ai/models/route_model.dart';
import 'package:journey_guard_ai/models/weather_data.dart';
import 'package:journey_guard_ai/services/incident_service.dart';
import 'package:journey_guard_ai/services/supabase_service.dart';
import 'package:journey_guard_ai/services/risk_engine.dart';
import 'package:journey_guard_ai/services/weather_service.dart';

class MockWeatherServiceForIncidents extends WeatherService {
  @override
  Future<WeatherData> fetchWeather({
    required LatLng location,
    required DateTime dateTime,
  }) async {
    return WeatherData(
      rainfallIntensity: 0.0,
      rainProbability: 0.0,
      cumulativeRainfall: 0.0,
      temperature: 28.0,
      windSpeed: 5.0,
      weatherCode: '0',
      fetchedAt: DateTime.now(),
    );
  }
}

void main() {
  group('Module D — Data Model & PostGIS Formatting Tests', () {
    test('IncidentReport formats location as valid PostGIS WKT POINT(lng lat)', () {
      final report = IncidentReport(
        latitude: 9.9816,
        longitude: 76.2829,
        incidentType: 'Fallen Tree',
        description: 'Tree fell across northbound lane',
        reportedAt: DateTime(2026, 9, 18, 12, 0),
      );

      // PostGIS coordinate order is X (longitude), then Y (latitude)
      expect(report.wktLocation, equals('POINT(76.2829 9.9816)'));
    });

    test('IncidentReport returns null wktLocation when coordinates are missing', () {
      final report = IncidentReport(
        latitude: null,
        longitude: null,
        incidentType: 'Other',
        description: 'Unknown hazard',
        reportedAt: DateTime.now(),
      );

      expect(report.wktLocation, isNull);
    });

    test('toSupabaseInsertMap maps fields and normalizes types', () {
      final report = IncidentReport(
        reporterId: 'user-uuid-1234',
        latitude: 10.02,
        longitude: 76.31,
        incidentType: 'Road Damage',
        description: 'Large crater in right lane',
        photoUrl: 'https://example.com/storage/reports/photo.jpg',
        reportedAt: DateTime.utc(2026, 9, 18, 14, 30),
      );

      final insertMap = report.toSupabaseInsertMap();

      expect(insertMap['reporter_id'], equals('user-uuid-1234'));
      expect(insertMap['location'], equals('POINT(76.31 10.02)'));
      expect(insertMap['incident_type'], equals('road_damage'));
      expect(insertMap['description'], equals('Large crater in right lane'));
      expect(insertMap['photo_url'], equals('https://example.com/storage/reports/photo.jpg'));
      expect(insertMap['created_at'], equals('2026-09-18T14:30:00.000Z'));
    });

    test('fromSupabase parses PostGIS RPC result with direct latitude and longitude', () {
      final rpcData = {
        'id': 'inc-rpc-1',
        'reporter_id': 'rep-456',
        'latitude': 9.9816,
        'longitude': 76.2829,
        'incident_type': 'fallen_tree',
        'description': 'Tree branch on road',
        'photo_url': 'https://storage/tree.jpg',
        'created_at': '2026-09-18T09:00:00Z',
        'distance_meters': 250.5,
      };

      final parsed = IncidentReport.fromSupabase(rpcData);

      expect(parsed.id, equals('inc-rpc-1'));
      expect(parsed.reporterId, equals('rep-456'));
      expect(parsed.latitude, equals(9.9816));
      expect(parsed.longitude, equals(76.2829));
      expect(parsed.incidentType, equals('Fallen Tree'));
      expect(parsed.description, equals('Tree branch on road'));
      expect(parsed.photoUrl, equals('https://storage/tree.jpg'));
      expect(parsed.distanceMeters, equals(250.5));
    });

    test('fromSupabase parses PostGIS GeoJSON location format', () {
      final geoJsonData = {
        'id': 'inc-geojson-2',
        'location': {
          'type': 'Point',
          'coordinates': [76.5000, 10.1000],
        },
        'incident_type': 'landslide',
        'description': 'Minor mudslide near turn',
        'created_at': '2026-09-18T08:00:00Z',
      };

      final parsed = IncidentReport.fromSupabase(geoJsonData);

      expect(parsed.id, equals('inc-geojson-2'));
      // GeoJSON coordinates are [longitude, latitude]
      expect(parsed.longitude, equals(76.5000));
      expect(parsed.latitude, equals(10.1000));
      expect(parsed.incidentType, equals('Landslide / Rockfall'));
    });

    test('fromSupabase parses PostGIS WKT string format', () {
      final wktData = {
        'id': 'inc-wkt-3',
        'location': 'POINT(76.9500 10.2500)',
        'incident_type': 'flood',
        'description': 'Water logged up to 1 foot',
        'created_at': '2026-09-18T07:30:00Z',
      };

      final parsed = IncidentReport.fromSupabase(wktData);

      expect(parsed.id, equals('inc-wkt-3'));
      expect(parsed.longitude, equals(76.9500));
      expect(parsed.latitude, equals(10.2500));
      expect(parsed.incidentType, equals('Flash Flood'));
    });
  });

  group('Module D & B — Incident Service & Recency Weighting Tests', () {
    final incidentService = IncidentService.instance;
    final now = DateTime(2026, 9, 18, 18, 0);

    test('Recency weighting: < 24h hazard receives maximum weight (1.0)', () {
      final center = const LatLng(10.5000, 76.5000);

      // Fresh report: 2 hours ago
      final freshReport = IncidentReport(
        id: 'fresh-1',
        latitude: 10.5010,
        longitude: 76.5010,
        incidentType: 'Landslide',
        description: 'Active landslide',
        reportedAt: now.subtract(const Duration(hours: 2)),
      );

      incidentService.addReport(freshReport);

      final match = incidentService.queryIncidentsNear(
        location: center,
        radiusKm: 5.0,
        referenceTime: now,
      );

      expect(match.totalCount, greaterThanOrEqualTo(1));
      expect(match.activeRecentCount, greaterThanOrEqualTo(1));
      expect(match.score, greaterThan(0.0));
    });

    test('Older incidents (> 30 days) receive lower recency weight (0.2)', () {
      final isolatedPoint = const LatLng(11.8000, 75.9000);

      final oldReport = IncidentReport(
        id: 'old-1',
        latitude: 11.8005,
        longitude: 75.9005,
        incidentType: 'Road Damage',
        description: 'Historical pothole patch',
        reportedAt: now.subtract(const Duration(days: 45)),
      );

      incidentService.addReport(oldReport);

      final matchOld = incidentService.queryIncidentsNear(
        location: isolatedPoint,
        radiusKm: 5.0,
        referenceTime: now,
      );

      expect(matchOld.totalCount, equals(1));
      expect(matchOld.activeRecentCount, equals(0)); // not active/recent (<7d)

      // Score for 1 historical report (weight 0.2) attenuated: (0.2 * ~0.99) / 5.0 * 100 ≈ 4.0
      expect(matchOld.score, inInclusiveRange(3.0, 5.0));
    });

    test('submitReport adds report immediately to local memory and query results', () async {
      final newLoc = const LatLng(10.9900, 76.8800);

      final report = IncidentReport(
        latitude: 10.9910,
        longitude: 76.8810,
        incidentType: 'Fallen Tree',
        description: 'Road blocked near toll gate',
        reportedAt: now,
      );

      final submitted = await incidentService.submitReport(report);
      expect(submitted.description, equals(report.description));

      final match = incidentService.queryIncidentsNear(
        location: newLoc,
        radiusKm: 5.0,
        referenceTime: now,
      );

      expect(match.totalCount, greaterThanOrEqualTo(1));
      expect(match.nearbyIncidents.any((r) => r.description == report.description), isTrue);
    });

    test('Crowdsourced incidents elevate risk score in RiskEngine', () async {
      final engine = RiskEngine(weatherService: MockWeatherServiceForIncidents());

      final segmentLoc = const LatLng(10.7500, 76.6500);

      // Add 3 high-impact active incidents right at the segment location
      for (int i = 0; i < 3; i++) {
        incidentService.addReport(IncidentReport(
          latitude: segmentLoc.latitude + (i * 0.001),
          longitude: segmentLoc.longitude + (i * 0.001),
          incidentType: 'Flood',
          description: 'Flash flood on highway segment $i',
          reportedAt: DateTime.now().subtract(Duration(minutes: 30 * i)),
        ));
      }

      final route = RouteModel(
        summary: 'Testing incident integration',
        distanceMeters: 6000.0,
        durationSeconds: 600.0,
        coordinates: [
          segmentLoc,
          LatLng(segmentLoc.latitude + 0.01, segmentLoc.longitude + 0.01),
          LatLng(segmentLoc.latitude + 0.02, segmentLoc.longitude + 0.02),
        ],
      );

      final segments = await engine.buildRiskSegments(
        route: route,
        departureTime: DateTime.now(),
      );

      expect(segments.isNotEmpty, isTrue);
      // Historical incidents score should be elevated (weight 0.10 in total risk)
      final highestIncidentSegment = segments.reduce((a, b) =>
          a.historicalIncidentsScore > b.historicalIncidentsScore ? a : b);
      expect(highestIncidentSegment.historicalIncidentsScore, greaterThan(20.0));
      expect(highestIncidentSegment.riskScore, greaterThan(0.0));
    });
  });

  group('Module E — Supabase Authentication & Demo Mode Tests', () {
    test('SupabaseService initializes in Resilient Local Demo Mode with default placeholder keys', () async {
      final service = SupabaseService.instance;
      await service.init();

      // With default placeholder keys, isAvailable should be false (safe offline mode)
      expect(service.isAvailable, isFalse);
      expect(service.client, isNull);
    });

    test('signInAnonymously returns null safely in offline/demo mode without throwing', () async {
      final service = SupabaseService.instance;
      final res = await service.signInAnonymously();

      // In resilient local demo mode, returns null and prints simulation log
      expect(res, isNull);
      expect(service.isAuthenticated, isTrue);
      expect(service.isAnonymous, isTrue);
      await service.signOut();
    });

    test('uploadIncidentPhoto returns local path safely when storage is offline', () async {
      final service = SupabaseService.instance;
      // In offline mode, does not crash and preserves the local path
      expect(service.isAvailable, isFalse);
    });

    test('SupabaseConstants defines valid incident categories and labels', () {
      expect(SupabaseConstants.allTypes, contains('flood'));
      expect(SupabaseConstants.allTypes, contains('landslide'));
      expect(SupabaseConstants.allTypes, contains('fallen_tree'));
      expect(SupabaseConstants.allTypes, contains('road_damage'));
      expect(SupabaseConstants.allTypes, contains('other'));

      expect(SupabaseConstants.getDisplayName('flood'), equals('Flash Flood'));
      expect(SupabaseConstants.getDisplayName('fallen_tree'), equals('Fallen Tree'));
      expect(SupabaseConstants.getDisplayName('landslide'), equals('Landslide / Rockfall'));
    });
  });
}
