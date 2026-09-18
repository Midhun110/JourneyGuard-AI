import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:journey_guard_ai/core/theme/app_colors.dart';
import 'package:journey_guard_ai/models/route_model.dart';
import 'package:journey_guard_ai/services/routing_service.dart';
import 'package:journey_guard_ai/services/risk_engine.dart';
import 'package:journey_guard_ai/services/weather_service.dart';
import 'package:journey_guard_ai/models/weather_data.dart';

class FastMockWeatherService extends WeatherService {
  @override
  Future<WeatherData> fetchWeather({
    required LatLng location,
    required DateTime dateTime,
  }) async {
    return WeatherData(
      rainfallIntensity: 3.5,
      rainProbability: 20.0,
      cumulativeRainfall: 8.0,
      temperature: 28.0,
      windSpeed: 11.0,
      weatherCode: '61',
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<List<WeatherData>> fetchDepartureTimeWeather({
    required LatLng location,
    required DateTime date,
    required List<int> hours,
  }) async {
    return hours.map((h) {
      final isSafest = h == 16; // 4 PM safest in this mock
      return WeatherData(
        rainfallIntensity: isSafest ? 0.0 : 12.0,
        rainProbability: isSafest ? 5.0 : 80.0,
        cumulativeRainfall: isSafest ? 1.0 : 30.0,
        temperature: 29.0,
        windSpeed: 10.0,
        weatherCode: isSafest ? '0' : '65',
        fetchedAt: DateTime.now(),
      );
    }).toList();
  }
}

void main() {
  group('Route Risk Analysis & OSM Light Map Tests', () {
    late RiskEngine riskEngine;
    late RoutingService routingService;

    setUp(() {
      riskEngine = RiskEngine(weatherService: FastMockWeatherService());
      routingService = RoutingService();
    });

    test('Color-coded risk thresholds match requirements', () {
      expect(AppColors.riskColor(15.0), AppColors.riskLow); // Green (<= 25)
      expect(AppColors.riskColor(25.0), AppColors.riskLow);
      expect(AppColors.riskColor(40.0), AppColors.riskModerate); // Yellow (<= 50)
      expect(AppColors.riskColor(50.0), AppColors.riskModerate);
      expect(AppColors.riskColor(65.0), AppColors.riskHigh); // Orange (<= 75)
      expect(AppColors.riskColor(75.0), AppColors.riskHigh);
      expect(AppColors.riskColor(85.0), AppColors.riskCritical); // Red (> 75)
    });

    test('RoutingService guarantees 2–3 distinct route options', () async {
      final routes = await routingService.fetchRoutes(
        origin: const LatLng(9.9816, 76.2999),
        destination: const LatLng(10.1520, 76.3922),
      );

      expect(routes.length, inInclusiveRange(2, 3));
      for (final r in routes) {
        expect(r.coordinates.isNotEmpty, isTrue);
        expect(r.distanceMeters, greaterThan(0));
        expect(r.durationSeconds, greaterThan(0));
        expect(r.summary.isNotEmpty, isTrue);
      }
    });

    test('RiskEngine.compareRoutesDetailed displays 2–3 route options without hanging', () async {
      final testRoutes = [
        const RouteModel(
          coordinates: [LatLng(9.98, 76.28), LatLng(10.15, 76.39)],
          distanceMeters: 25000,
          durationSeconds: 2400,
          summary: 'Main Highway',
        ),
      ];

      final result = await riskEngine.compareRoutesDetailed(
        routes: testRoutes,
        departureTime: DateTime.now(),
      );

      expect(result.comparisons.length, inInclusiveRange(2, 3));
      for (final comp in result.comparisons) {
        expect(comp.combinedScore, greaterThan(0));
        expect(comp.riskScore, inInclusiveRange(0.0, 100.0));
        expect(comp.recommendationTag.isNotEmpty, isTrue);
      }
    });

    test('RiskEngine.evaluateRouteAcrossDepartureTimes yields 8 AM, 12 PM, 4 PM with safest slot', () async {
      final route = const RouteModel(
        coordinates: [
          LatLng(9.9816, 76.2999),
          LatLng(10.0500, 76.3400),
          LatLng(10.1520, 76.3922),
        ],
        distanceMeters: 25000,
        durationSeconds: 2400,
        summary: 'NH 66 Corridor',
      );

      final results = await riskEngine.evaluateRouteAcrossDepartureTimes(
        route: route,
        date: DateTime.now(),
      );

      expect(results.length, equals(3));
      expect(results.map((r) => r.hour).toList(), equals([8, 12, 16]));

      // Verify at least one slot is designated safest
      final safestSlots = results.where((r) => r.isSafestSlot).toList();
      expect(safestSlots.isNotEmpty, isTrue);
    });

    test('Segments correctly split route and calculate rainfall metrics', () async {
      final route = const RouteModel(
        coordinates: [
          LatLng(9.9816, 76.2999),
          LatLng(10.0200, 76.3200),
          LatLng(10.0600, 76.3400),
          LatLng(10.1000, 76.3600),
          LatLng(10.1520, 76.3922),
        ],
        distanceMeters: 25000,
        durationSeconds: 2400,
        summary: 'NH 66 Corridor',
      );

      final segments = await riskEngine.buildRiskSegments(
        route: route,
        departureTime: DateTime.now(),
      );

      expect(segments.isNotEmpty, isTrue);
      for (final seg in segments) {
        expect(seg.points.isNotEmpty, isTrue);
        expect(seg.riskScore, inInclusiveRange(0.0, 100.0));
        expect(seg.weather.rainfallIntensity, greaterThanOrEqualTo(0));
        expect(seg.color, isNotNull);
      }
    });
  });
}
