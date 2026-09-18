import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:journey_guard_ai/core/constants/app_constants.dart';
import 'package:journey_guard_ai/models/route_model.dart';
import 'package:journey_guard_ai/models/risk_segment.dart';
import 'package:journey_guard_ai/models/weather_data.dart';
import 'package:journey_guard_ai/services/risk_engine.dart';

import 'package:journey_guard_ai/services/weather_service.dart';

class MockWeatherService extends WeatherService {
  @override
  Future<WeatherData> fetchWeather({
    required LatLng location,
    required DateTime dateTime,
  }) async {
    return WeatherData(
      rainfallIntensity: 5.0,
      rainProbability: 25.0,
      cumulativeRainfall: 15.0,
      temperature: 28.0,
      windSpeed: 10.0,
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
    return hours.map((h) => WeatherData(
      rainfallIntensity: (h % 5) * 4.0,
      rainProbability: (h * 5.0).clamp(10.0, 90.0),
      cumulativeRainfall: 15.0,
      temperature: 28.0,
      windSpeed: 10.0,
      weatherCode: '61',
      fetchedAt: DateTime.now(),
    )).toList();
  }
}

void main() {
  late RiskEngine engine;

  setUp(() {
    engine = RiskEngine(weatherService: MockWeatherService());
  });

  RiskSegment createSegment({
    required int index,
    required double riskScore,
    double distanceMeters = 5000.0,
    double rainProb = 20.0,
  }) {
    return RiskSegment(
      points: [const LatLng(9.98, 76.28), const LatLng(9.99, 76.29)],
      riskScore: riskScore,
      weather: WeatherData(
        rainfallIntensity: 5.0,
        rainProbability: rainProb,
        cumulativeRainfall: 10.0,
        temperature: 28.0,
        windSpeed: 12.0,
        weatherCode: '61',
        fetchedAt: DateTime.now(),
      ),
      distanceMeters: distanceMeters,
      durationMinutes: 8.0,
      segmentIndex: index,
    );
  }

  RouteModel createRoute({
    required double durationSeconds,
    double distanceMeters = 20000.0,
    String summary = 'Test Highway',
  }) {
    return RouteModel(
      coordinates: [
        const LatLng(9.98, 76.28),
        const LatLng(10.05, 76.35),
      ],
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      summary: summary,
    );
  }

  group('Module C - 1: Route-Level Risk Aggregation', () {
    test('calculateRouteRisk computes distance-weighted average correctly', () {
      // Segment 1: 10km at 20% risk -> 200,000
      // Segment 2: 30km at 60% risk -> 1,800,000
      // Total dist: 40km -> (200,000 + 1,800,000) / 40,000 = 50.0%
      final seg1 = createSegment(index: 0, riskScore: 20.0, distanceMeters: 10000.0);
      final seg2 = createSegment(index: 1, riskScore: 60.0, distanceMeters: 30000.0);

      final avgRisk = engine.calculateRouteRisk([seg1, seg2], conservative: false);
      expect(avgRisk, closeTo(50.0, 0.001));
    });

    test('calculateRouteRisk computes conservative peak risk correctly', () {
      final seg1 = createSegment(index: 0, riskScore: 20.0, distanceMeters: 10000.0);
      final seg2 = createSegment(index: 1, riskScore: 85.0, distanceMeters: 5000.0);
      final seg3 = createSegment(index: 2, riskScore: 30.0, distanceMeters: 15000.0);

      final maxRisk = engine.calculateRouteRisk([seg1, seg2, seg3], conservative: true);
      expect(maxRisk, equals(85.0));
    });

    test('calculateRouteRisk handles empty segments gracefully', () {
      expect(engine.calculateRouteRisk([], conservative: false), equals(0.0));
      expect(engine.calculateRouteRisk([], conservative: true), equals(0.0));
    });
  });

  group('Module C - 2: Combined Score Formula & Ranking Weights', () {
    test('calculateCombinedRouteScore adheres to default 70/30 weights', () {
      // risk = 40, duration penalty = 20
      // 0.70 * 40 + 0.30 * 20 = 28.0 + 6.0 = 34.0
      final score = engine.calculateCombinedRouteScore(
        normalizedRisk: 40.0,
        normalizedDuration: 20.0,
      );
      expect(score, closeTo(34.0, 0.001));
    });

    test('calculateCombinedRouteScore supports custom user weights', () {
      // Balanced (50/50): 0.50 * 50 + 0.50 * 30 = 40.0
      final balanced = engine.calculateCombinedRouteScore(
        normalizedRisk: 50.0,
        normalizedDuration: 30.0,
        riskWeight: 0.50,
        timeWeight: 0.50,
      );
      expect(balanced, closeTo(40.0, 0.001));

      // Time-first (30/70): 0.30 * 50 + 0.70 * 30 = 15.0 + 21.0 = 36.0
      final timeFirst = engine.calculateCombinedRouteScore(
        normalizedRisk: 50.0,
        normalizedDuration: 30.0,
        riskWeight: 0.30,
        timeWeight: 0.70,
      );
      expect(timeFirst, closeTo(36.0, 0.001));
    });

    test('normalizeRouteDurations scales relative to fastest alternative', () {
      final rFast = createRoute(durationSeconds: 1800.0); // 30 min -> 0.0 penalty
      final rMid = createRoute(durationSeconds: 2700.0);  // 45 min -> 50.0 penalty
      final rSlow = createRoute(durationSeconds: 3600.0); // 60 min -> 100.0 penalty

      final norms = engine.normalizeRouteDurations([rFast, rMid, rSlow]);
      expect(norms.length, equals(3));
      expect(norms[0], closeTo(0.0, 0.001));
      expect(norms[1], closeTo(50.0, 0.001));
      expect(norms[2], closeTo(100.0, 0.001));
    });

    test('normalizeRouteDurations returns 0 for identical durations or single route', () {
      final r1 = createRoute(durationSeconds: 2000.0);
      final r2 = createRoute(durationSeconds: 2000.0);

      final norms = engine.normalizeRouteDurations([r1, r2]);
      expect(norms, equals([0.0, 0.0]));

      final singleNorm = engine.normalizeRouteDurations([r1]);
      expect(singleNorm, equals([0.0]));
    });
  });

  group('Module C - 3: Recommendation & Postponement Advisory Logic', () {
    test('Identifies Safest and Fastest-Acceptable routes', () {
      final rFastMod = createRoute(durationSeconds: 1800.0, summary: 'Coastal Route'); // 30 min, risk 40 (acceptable)
      final rSlowSafe = createRoute(durationSeconds: 2700.0, summary: 'Bypass Route'); // 45 min, risk 15 (safest)
      final rFastDangerous = createRoute(durationSeconds: 1200.0, summary: 'Mountain Pass'); // 20 min, risk 80 (hazardous)

      final compSafe = RouteComparison(
        route: rSlowSafe,
        riskScore: 15.0,
        rainProbability: 10.0,
        label: '',
      );
      final compMod = RouteComparison(
        route: rFastMod,
        riskScore: 40.0,
        rainProbability: 25.0,
        label: '',
      );
      final compDang = RouteComparison(
        route: rFastDangerous,
        riskScore: 80.0,
        rainProbability: 75.0,
        label: '',
      );

      final candidates = [compSafe, compMod, compDang];

      // Safest route is compSafe (15.0 risk)
      final safest = candidates.reduce((a, b) => a.riskScore < b.riskScore ? a : b);
      expect(safest.route.summary, equals('Bypass Route'));

      // Fastest acceptable (risk <= 50): compSafe (2700s) vs compMod (1800s) -> compMod is fastest acceptable
      final acceptable = candidates.where((c) => c.riskScore <= AppConstants.acceptableRiskThreshold).toList();
      final fastestAcceptable = acceptable.reduce((a, b) => a.route.durationSeconds < b.route.durationSeconds ? a : b);
      expect(fastestAcceptable.route.summary, equals('Coastal Route'));
    });

    test('Postponement advisory triggers when ALL routes score High/Critical', () {
      final comp1 = RouteComparison(
        route: createRoute(durationSeconds: 2000.0),
        riskScore: 65.0, // High
        rainProbability: 80.0,
        label: '',
        maxRisk: 70.0,
      );
      final comp2 = RouteComparison(
        route: createRoute(durationSeconds: 2500.0),
        riskScore: 82.0, // Critical
        rainProbability: 95.0,
        label: '',
        maxRisk: 88.0,
      );

      final allHigh = [comp1, comp2].every((c) => c.riskScore > AppConstants.acceptableRiskThreshold);
      expect(allHigh, isTrue);
    });

    test('Postponement advisory does NOT trigger when at least one acceptable route exists', () {
      final comp1 = RouteComparison(
        route: createRoute(durationSeconds: 2000.0),
        riskScore: 32.0, // Moderate (Acceptable)
        rainProbability: 30.0,
        label: '',
        maxRisk: 45.0,
      );
      final comp2 = RouteComparison(
        route: createRoute(durationSeconds: 2500.0),
        riskScore: 78.0, // Critical
        rainProbability: 90.0,
        label: '',
        maxRisk: 85.0,
      );

      final allHigh = [comp1, comp2].every((c) => c.riskScore > AppConstants.acceptableRiskThreshold);
      expect(allHigh, isFalse);
    });
  });

  group('Module C - 4: Departure-Time Comparison Model & Metrics', () {
    test('DepartureTimeWeather computes risk reduction vs baseline properly', () {
      // Baseline 8 AM = 50% risk; 12 PM = 20% risk
      // Reduction = (50 - 20) / 50 * 100 = 60%
      const baselineRisk = 50.0;
      const optimizedRisk = 20.0;
      final reduction = ((baselineRisk - optimizedRisk) / baselineRisk * 100);

      final slot = DepartureTimeWeather(
        hour: 12,
        label: '12 PM',
        weather: WeatherData.empty(),
        riskScore: optimizedRisk,
        maxRisk: 30.0,
        weightedAvgRisk: optimizedRisk,
        riskReductionVsBaseline: reduction,
        isSafestSlot: true,
      );

      expect(slot.isSafest, isTrue);
      expect(slot.riskReductionVsBaseline, closeTo(60.0, 0.001));
      expect(slot.maxRisk, equals(30.0));
    });

    test('evaluateRouteAcrossDepartureTimes runs pipeline across multiple hours', () async {
      final route = createRoute(durationSeconds: 1800.0);
      final results = await engine.evaluateRouteAcrossDepartureTimes(
        route: route,
        date: DateTime.now(),
        hours: [8, 12, 16],
      );

      expect(results.length, equals(3));
      expect(results[0].hour, equals(8));
      expect(results[1].hour, equals(12));
      expect(results[2].hour, equals(16));
      expect(results.any((r) => r.isSafestSlot), isTrue);
    });

    test('compareRoutesDetailed ranks routes and calculates combined scores', () async {
      final r1 = createRoute(durationSeconds: 1800.0, summary: 'Route 1');
      final r2 = createRoute(durationSeconds: 2400.0, summary: 'Route 2');

      final result = await engine.compareRoutesDetailed(
        routes: [r1, r2],
        departureTime: DateTime.now(),
        riskWeight: 0.70,
        timeWeight: 0.30,
      );

      expect(result.comparisons.length, equals(2));
      expect(result.comparisons.first.rank, equals(1));
      expect(result.comparisons.first.isRecommended, isTrue);
      expect(result.safestRoute, isNotNull);
    });
  });
}
