import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:journey_guard_ai/services/risk_engine.dart';
import 'package:journey_guard_ai/services/ksdma_hazard_dataset.dart';
import 'package:journey_guard_ai/services/incident_service.dart';
import 'package:journey_guard_ai/models/incident_report.dart';
import 'package:journey_guard_ai/models/risk_segment.dart';
import 'package:journey_guard_ai/models/weather_data.dart';

void main() {
  late RiskEngine engine;

  setUp(() {
    engine = RiskEngine();
  });

  group('Module B - 3.4: Weighted Risk Score Formula', () {
    test('calculateRiskScore with all minimum values returns 0', () {
      final score = engine.calculateRiskScore(
        rainfallIntensity: 0.0,
        rainProbability: 0.0,
        cumulativeRainfall: 0.0,
        roadVulnerability: 0.0,
        historicalIncidents: 0.0,
      );
      expect(score, closeTo(0.0, 0.001));
    });

    test('calculateRiskScore with all maximum values returns 100', () {
      final score = engine.calculateRiskScore(
        rainfallIntensity: 100.0,
        rainProbability: 100.0,
        cumulativeRainfall: 100.0,
        roadVulnerability: 100.0,
        historicalIncidents: 100.0,
      );
      expect(score, closeTo(100.0, 0.001));
    });

    test('calculateRiskScore adheres precisely to 40-15-20-15-10 weights', () {
      // 50 * 0.40 = 20.0
      // 60 * 0.15 = 9.0
      // 40 * 0.20 = 8.0
      // 80 * 0.15 = 12.0
      // 30 * 0.10 = 3.0
      // Total expected = 20 + 9 + 8 + 12 + 3 = 52.0
      final score = engine.calculateRiskScore(
        rainfallIntensity: 50.0,
        rainProbability: 60.0,
        cumulativeRainfall: 40.0,
        roadVulnerability: 80.0,
        historicalIncidents: 30.0,
      );
      expect(score, closeTo(52.0, 0.001));
    });
  });

  group('Module B - 3.5: Risk Classification Thresholds', () {
    test('riskLevel classifies <= 25 as Low', () {
      expect(engine.riskLevel(0.0), 'Low');
      expect(engine.riskLevel(15.0), 'Low');
      expect(engine.riskLevel(25.0), 'Low');
      expect(RiskSegment.classifyRiskLevel(25.0), 'Low');
    });

    test('riskLevel classifies 25.1 to 50.0 as Moderate', () {
      expect(engine.riskLevel(25.1), 'Moderate');
      expect(engine.riskLevel(35.0), 'Moderate');
      expect(engine.riskLevel(50.0), 'Moderate');
      expect(RiskSegment.classifyRiskLevel(50.0), 'Moderate');
    });

    test('riskLevel classifies 50.1 to 75.0 as High', () {
      expect(engine.riskLevel(50.1), 'High');
      expect(engine.riskLevel(65.0), 'High');
      expect(engine.riskLevel(75.0), 'High');
      expect(RiskSegment.classifyRiskLevel(75.0), 'High');
    });

    test('riskLevel classifies > 75.0 as Critical', () {
      expect(engine.riskLevel(75.1), 'Critical');
      expect(engine.riskLevel(90.0), 'Critical');
      expect(engine.riskLevel(100.0), 'Critical');
      expect(RiskSegment.classifyRiskLevel(100.0), 'Critical');
    });
  });

  group('Module B - Normalization Functions & Reasoning', () {
    test('normalizeRainfallIntensity caps at 50mm/h = 100', () {
      expect(engine.normalizeRainfallIntensity(0.0), 0.0);
      expect(engine.normalizeRainfallIntensity(25.0), closeTo(50.0, 0.001));
      expect(engine.normalizeRainfallIntensity(50.0), closeTo(100.0, 0.001));
      expect(engine.normalizeRainfallIntensity(75.0), 100.0); // capped
    });

    test('normalizeCumulativeRainfall caps at 100mm = 100', () {
      expect(engine.normalizeCumulativeRainfall(0.0), 0.0);
      expect(engine.normalizeCumulativeRainfall(50.0), closeTo(50.0, 0.001));
      expect(engine.normalizeCumulativeRainfall(100.0), closeTo(100.0, 0.001));
      expect(engine.normalizeCumulativeRainfall(140.0), 100.0); // capped
    });

    test('normalizeHistoricalIncidents caps at 5 weighted incidents = 100', () {
      expect(engine.normalizeHistoricalIncidents(0.0), 0.0);
      expect(engine.normalizeHistoricalIncidents(2.5), closeTo(50.0, 0.001));
      expect(engine.normalizeHistoricalIncidents(5.0), closeTo(100.0, 0.001));
      expect(engine.normalizeHistoricalIncidents(10.0), 100.0); // capped
    });
  });

  group('Module B - 3.2: Antecedent Cumulative Rainfall Calculation', () {
    test('WeatherData.fromOpenMeteo sums preceding 24 hours precipitation', () {
      // 48 hours of simulated precipitation
      final hourlyRain = List<double>.generate(48, (i) => 2.0); // 2mm each hour
      final hourlyData = {
        'precipitation': hourlyRain,
        'precipitation_probability': List<int>.generate(48, (i) => 50),
        'temperature_2m': List<double>.generate(48, (i) => 25.0),
        'wind_speed_10m': List<double>.generate(48, (i) => 10.0),
        'weather_code': List<int>.generate(48, (i) => 61),
      };

      // Hour index 30: preceding 24 hours is indices 7 to 30 = 24 hours * 2mm = 48mm
      final weather = WeatherData.fromOpenMeteo(
        hourly: hourlyData,
        hourIndex: 30,
      );

      expect(weather.rainfallIntensity, 2.0);
      expect(weather.cumulativeRainfall, closeTo(48.0, 0.001));
    });
  });

  group('Module B - 3.3: KSDMA Kerala Road Vulnerability Dataset', () {
    test('Matches Munnar Gap Road (NH 85) high vulnerability zone', () {
      final dataset = KsdmaHazardDataset.instance;
      // Coordinate near Munnar Gap Road (10.0512, 77.0820)
      final match = dataset.getRoadVulnerability(10.0512, 77.0820);

      expect(match.hazardName, contains('Munnar Gap Road'));
      expect(match.score, greaterThanOrEqualTo(85.0));
      expect(match.hazardType, contains('Landslide'));
    });

    test('Matches Thamarassery Churam (NH 766) critical hazard zone', () {
      final dataset = KsdmaHazardDataset.instance;
      // Coordinate near Thamarassery Churam (11.4925, 76.0123)
      final match = dataset.getRoadVulnerability(11.4925, 76.0123);

      expect(match.hazardName, contains('Thamarassery Churam'));
      expect(match.score, greaterThanOrEqualTo(90.0));
    });

    test('Matches Kuttanad AC Road below-sea-level flood zone', () {
      final dataset = KsdmaHazardDataset.instance;
      final match = dataset.getRoadVulnerability(9.4930, 76.4320);

      expect(match.hazardName, contains('Kuttanad'));
      expect(match.score, greaterThanOrEqualTo(80.0));
    });

    test('Falls back to regional geomorphic baseline outside specific hotspots', () {
      final dataset = KsdmaHazardDataset.instance;
      // Kochi coastal coordinate (9.9312, 76.2673)
      final match = dataset.getRoadVulnerability(9.9312, 76.2673);
      expect(match.score, closeTo(42.0, 5.0));
    });
  });

  group('Module B - 3.3 & Module D: Incident Reporting & Recency Weighting', () {
    test('Pre-seeded incidents are available and queryable within radius', () {
      final service = IncidentService.instance;
      final match = service.queryIncidentsNear(
        location: const LatLng(10.0480, 77.0780), // Munnar
        radiusKm: 15.0,
      );

      expect(match.totalCount, greaterThan(0));
      expect(match.score, greaterThan(0.0));
      expect(match.nearbyIncidents.first.locationName, contains('Munnar'));
    });

    test('Adding new incident dynamically increases risk score for nearby segments', () {
      final service = IncidentService.instance;
      const testLoc = LatLng(10.5276, 76.2144); // Thrissur test coordinate

      final before = service.queryIncidentsNear(location: testLoc, radiusKm: 10.0);

      service.addReport(IncidentReport(
        latitude: testLoc.latitude,
        longitude: testLoc.longitude,
        incidentType: 'Landslide',
        description: 'New mudslide reported live by commuter.',
        reportedAt: DateTime.now(),
        locationName: 'Thrissur Highway Test',
      ));

      final after = service.queryIncidentsNear(location: testLoc, radiusKm: 10.0);
      expect(after.totalCount, equals(before.totalCount + 1));
      expect(after.score, greaterThan(before.score));
    });
  });
}
