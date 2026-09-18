import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:journey_guard_ai/models/incident_report.dart';
import 'package:journey_guard_ai/models/route_model.dart';
import 'package:journey_guard_ai/models/weather_data.dart';
import 'package:journey_guard_ai/services/incident_service.dart';
import 'package:journey_guard_ai/services/risk_engine.dart';
import 'package:journey_guard_ai/screens/route_comparison/route_comparison_screen.dart';
import 'package:journey_guard_ai/screens/departure_time/departure_time_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fallback Data Visibility - Models & isEstimated flag', () {
    test('RouteModel defaults isEstimated to false', () {
      const route = RouteModel(
        coordinates: [LatLng(9.9816, 76.2999), LatLng(10.1520, 76.3922)],
        distanceMeters: 24800,
        durationSeconds: 2460,
        summary: 'NH 66 Primary Corridor',
      );
      expect(route.isEstimated, isFalse);

      final estimatedRoute = route.copyWith(isEstimated: true);
      expect(estimatedRoute.isEstimated, isTrue);
    });

    test('RouteComparison defaults isEstimated to false and preserves through copyWith', () {
      const route = RouteModel(
        coordinates: [LatLng(9.9816, 76.2999), LatLng(10.1520, 76.3922)],
        distanceMeters: 24800,
        durationSeconds: 2460,
        summary: 'NH 66 Primary Corridor',
      );
      const comp = RouteComparison(
        route: route,
        riskScore: 25.0,
        rainProbability: 20.0,
        label: 'Primary',
        combinedScore: 25.0,
      );
      expect(comp.isEstimated, isFalse);

      final estimatedComp = comp.copyWith(isEstimated: true);
      expect(estimatedComp.isEstimated, isTrue);

      final copiedAgain = estimatedComp.copyWith(label: 'Updated Label');
      expect(copiedAgain.isEstimated, isTrue);
    });

    test('DepartureTimeWeather defaults isEstimated to false', () {
      final weather = WeatherData(
        rainfallIntensity: 0.0,
        rainProbability: 10.0,
        cumulativeRainfall: 0.0,
        temperature: 28.0,
        windSpeed: 10.0,
        weatherCode: '0',
        fetchedAt: DateTime.now(),
      );
      final dtw = DepartureTimeWeather(
        hour: 8,
        label: '8:00 AM',
        weather: weather,
        riskScore: 15.0,
        maxRisk: 20.0,
        weightedAvgRisk: 15.0,
      );
      expect(dtw.isEstimated, isFalse);

      final estimatedDtw = DepartureTimeWeather(
        hour: 8,
        label: '8:00 AM',
        weather: weather,
        riskScore: 15.0,
        maxRisk: 20.0,
        weightedAvgRisk: 15.0,
        isEstimated: true,
      );
      expect(estimatedDtw.isEstimated, isTrue);
    });
  });

  group('Risk Engine Fallback Generation & isEstimated propagation', () {
    test('Fallback comparisons in compareRoutesDetailed set isEstimated: true', () async {
      final engine = RiskEngine();
      // Calling compareRoutesDetailed with empty routes will trigger routing service fallback or mock
      final result = await engine.compareRoutesDetailed(
        routes: [],
        departureTime: DateTime(2026, 9, 20, 10, 0),
      );

      expect(result.comparisons.isNotEmpty, isTrue);
      // Fallback routes and synthesized alternatives must have isEstimated == true
      final hasEstimated = result.comparisons.any((c) => c.isEstimated || c.route.isEstimated);
      expect(hasEstimated, isTrue);
    });

    test('Departure times evaluation fallback sets isEstimated: true on mock failure', () async {
      final engine = RiskEngine();
      const emptyRoute = RouteModel(
        coordinates: [],
        distanceMeters: 0,
        durationSeconds: 0,
        summary: 'Empty Test Corridor',
        isEstimated: true,
      );

      final depTimes = await engine.evaluateRouteAcrossDepartureTimes(
        route: emptyRoute,
        date: DateTime(2026, 9, 20),
        hours: [8, 12, 16],
      );

      expect(depTimes.length, equals(3));
      for (final slot in depTimes) {
        expect(slot.isEstimated, isTrue);
      }
    });
  });

  group('Incident Recency Decay & Seeded Timestamps', () {
    test('Seeded historical incidents have absolute past dates (2024-2025) and zero active count', () {
      final incidentService = IncidentService();
      // At current runtime (2026), all seeded incidents are older than 30 days (> 720 hours)
      final match = incidentService.queryIncidentsNear(
        location: const LatLng(10.0480, 77.0780), // Munnar Gap Road
        radiusKm: 15.0,
        referenceTime: DateTime(2026, 9, 19, 12, 0),
      );

      expect(match.totalCount, greaterThan(0));
      // None of the historical pre-seeded incidents should be counted as active/recent (< 7 days)
      expect(match.activeRecentCount, equals(0));
    });

    test('Fresh incident reported now receives active recent count and full 1.0 weight', () {
      final incidentService = IncidentService();
      final now = DateTime(2026, 9, 19, 12, 0);

      final beforeMatch = incidentService.queryIncidentsNear(
        location: const LatLng(10.0480, 77.0780),
        radiusKm: 15.0,
        referenceTime: now,
      );

      // Report a fresh ongoing landslide
      incidentService.addReport(
        IncidentReport(
          latitude: 10.0480,
          longitude: 77.0780,
          incidentType: 'Landslide',
          description: 'Fresh active rockfall just happened',
          reportedAt: now,
          locationName: 'NH 85 Munnar Gap Road',
        ),
      );

      final afterMatch = incidentService.queryIncidentsNear(
        location: const LatLng(10.0480, 77.0780),
        radiusKm: 15.0,
        referenceTime: now,
      );

      expect(afterMatch.totalCount, equals(beforeMatch.totalCount + 1));
      expect(afterMatch.activeRecentCount, equals(1));
      expect(afterMatch.score, greaterThan(beforeMatch.score));
    });
  });

  group('UI Visibility of ~estimated Badge', () {
    testWidgets('RouteComparisonScreen displays ~estimated badge for synthetic fallback routes', (tester) async {
      const syntheticRoute = RouteModel(
        coordinates: [LatLng(9.9816, 76.2999), LatLng(10.1520, 76.3922)],
        distanceMeters: 24800,
        durationSeconds: 2460,
        summary: 'NH 66 Bypass',
        isEstimated: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouteComparisonScreen(
            routes: const [syntheticRoute],
            departureTime: DateTime(2026, 9, 20, 10, 0),
            fromName: 'Kochi',
            toName: 'Aluva',
            fromLocation: const LatLng(9.9816, 76.2999),
            toLocation: const LatLng(10.1520, 76.3922),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('~estimated'), findsWidgets);
    });

    testWidgets('DepartureTimeScreen displays ~estimated badge when fallback slot is used', (tester) async {
      const estimatedRoute = RouteModel(
        coordinates: [],
        distanceMeters: 0,
        durationSeconds: 0,
        summary: 'Fallback Route',
        isEstimated: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DepartureTimeScreen(
            location: const LatLng(9.9816, 76.2999),
            date: DateTime(2026, 9, 20),
            fromName: 'Kochi',
            toName: 'Aluva',
            route: estimatedRoute,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('~estimated'), findsWidgets);
    });
  });
}
