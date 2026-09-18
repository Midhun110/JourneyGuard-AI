import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journey_guard_ai/models/notification_model.dart';
import 'package:journey_guard_ai/models/saved_route_model.dart';
import 'package:journey_guard_ai/models/incident_report.dart';
import 'package:journey_guard_ai/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Module G — NotificationModel & Serialization', () {
    test('NotificationModel serializes and deserializes cleanly', () {
      final notif = NotificationModel(
        id: 'test_1',
        title: '⚠️ Test Critical Alert',
        body: 'Precipitation exceeded 50mm/h',
        timestamp: DateTime.parse('2026-09-18T12:00:00.000Z'),
        type: NotificationType.riskEscalation,
        isRead: false,
        routeData: {
          'fromName': 'Kochi City Center',
          'toName': 'Kochi Airport',
          'oldRisk': 20.0,
          'newRisk': 85.0,
        },
      );

      final json = notif.toJson();
      final restored = NotificationModel.fromJson(json);

      expect(restored.id, equals('test_1'));
      expect(restored.title, equals('⚠️ Test Critical Alert'));
      expect(restored.type, equals(NotificationType.riskEscalation));
      expect(restored.isRead, isFalse);
      expect(restored.routeData?['newRisk'], equals(85.0));
      expect(restored.typeLabel, equals('RISK ESCALATION'));
    });
  });

  group('Module G — SavedRouteModel', () {
    test('SavedRouteModel serializes and holds coordinates', () {
      final route = SavedRouteModel(
        id: 'route_123',
        name: 'Airport Corridor',
        fromName: 'Kochi City Center',
        toName: 'Kochi Airport',
        fromLatitude: 9.9816,
        fromLongitude: 76.2999,
        toLatitude: 10.1520,
        toLongitude: 76.3922,
        departureTime: DateTime.parse('2026-09-18T15:00:00.000Z'),
        initialRiskScore: 24.0,
        isMonitored: true,
        savedAt: DateTime.parse('2026-09-18T10:00:00.000Z'),
        summary: 'via NH 66',
      );

      final json = route.toJson();
      final restored = SavedRouteModel.fromJson(json);

      expect(restored.fromLocation.latitude, equals(9.9816));
      expect(restored.toLocation.latitude, equals(10.1520));
      expect(restored.initialRiskScore, equals(24.0));
      expect(restored.isMonitored, isTrue);
    });
  });

  group('Module G — NotificationService Simulation & Corridors', () {
    test('simulateRiskEscalation creates notification and updates unread count', () async {
      final service = NotificationService.instance;
      final initialCount = service.notifications.length;

      final notif = await service.simulateRiskEscalation(newRisk: 88.0);

      expect(service.notifications.length, equals(initialCount + 1));
      expect(notif.type, equals(NotificationType.riskEscalation));
      expect(notif.title, contains('CRITICAL'));
      expect(service.unreadCount, greaterThan(0));
    });

    test('simulateIncidentAlert generates hazard push alert', () async {
      final service = NotificationService.instance;
      final initialCount = service.notifications.length;

      final notif = await service.simulateIncidentAlert(
        incidentType: 'Landslide',
        description: 'Road blocked near Aluva bypass',
      );

      expect(service.notifications.length, equals(initialCount + 1));
      expect(notif.type, equals(NotificationType.incidentAlert));
      expect(notif.body, contains('Landslide'));
    });

    test('Saving and monitoring route correctly reports status', () async {
      final service = NotificationService.instance;

      final testRoute = SavedRouteModel(
        id: 'test_monitored_route',
        name: 'Munnar Express',
        fromName: 'Aluva',
        toName: 'Munnar',
        fromLatitude: 10.1076,
        fromLongitude: 76.3516,
        toLatitude: 10.0889,
        toLongitude: 77.0595,
        departureTime: DateTime.now().add(const Duration(hours: 3)),
        initialRiskScore: 35.0,
        isMonitored: true,
        savedAt: DateTime.now(),
      );

      await service.saveRoute(testRoute);
      expect(service.isRouteMonitored('Aluva', 'Munnar'), isTrue);

      await service.toggleRouteMonitoring(testRoute.id, false);
      expect(service.isRouteMonitored('Aluva', 'Munnar'), isFalse);
    });

    test('checkIncidentAgainstSavedRoutes triggers push when hazard is near corridor', () async {
      final service = NotificationService.instance;
      final initialCount = service.notifications.length;

      // Save a monitored route through Kochi
      final testRoute = SavedRouteModel(
        id: 'kochi_route',
        name: 'Kochi to Airport',
        fromName: 'Kochi City',
        toName: 'Nedumbassery Airport',
        fromLatitude: 9.9816,
        fromLongitude: 76.2999,
        toLatitude: 10.1520,
        toLongitude: 76.3922,
        departureTime: DateTime.now().add(const Duration(hours: 1)),
        initialRiskScore: 20.0,
        isMonitored: true,
        savedAt: DateTime.now(),
      );
      await service.saveRoute(testRoute);

      // Report an incident within 1km of the route corridor
      final incident = IncidentReport(
        incidentType: 'Waterlogging',
        description: 'Water buildup near Edappally toll',
        reportedAt: DateTime.now(),
        latitude: 10.0250,
        longitude: 76.3080,
      );

      await service.checkIncidentAgainstSavedRoutes(incident);

      expect(service.notifications.length, equals(initialCount + 1));
      final latest = service.notifications.first;
      expect(latest.type, equals(NotificationType.incidentAlert));
      expect(latest.title, contains('Incident Near Saved Corridor'));
    });
  });
}
