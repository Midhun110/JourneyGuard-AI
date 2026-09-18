import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/saved_route_model.dart';
import '../models/incident_report.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal() {
    _init();
  }

  factory NotificationService() => instance;

  static const String _prefsNotificationsKey = 'journeyguard_notifications_v1';
  static const String _prefsSavedRoutesKey = 'journeyguard_saved_routes_v1';

  final List<NotificationModel> _notifications = [];
  final List<SavedRouteModel> _savedRoutes = [];
  bool _isInitialized = false;

  final StreamController<NotificationModel> _headsUpStreamController =
      StreamController<NotificationModel>.broadcast();

  Stream<NotificationModel> get headsUpStream => _headsUpStreamController.stream;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  List<SavedRouteModel> get savedRoutes => List.unmodifiable(_savedRoutes);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Saved Routes
      final routesJson = prefs.getStringList(_prefsSavedRoutesKey);
      if (routesJson != null && routesJson.isNotEmpty) {
        _savedRoutes.clear();
        for (final item in routesJson) {
          try {
            _savedRoutes.add(SavedRouteModel.fromJson(
                jsonDecode(item) as Map<String, dynamic>));
          } catch (_) {}
        }
      } else {
        // Seed default monitored route for Kochi demonstration
        _savedRoutes.add(
          SavedRouteModel(
            id: 'seed_route_1',
            name: 'Airport Commute',
            fromName: 'Kochi City Center',
            toName: 'Kochi International Airport',
            fromLatitude: 9.9816,
            fromLongitude: 76.2999,
            toLatitude: 10.1520,
            toLongitude: 76.3922,
            departureTime: DateTime.now().add(const Duration(hours: 2)),
            initialRiskScore: 24.0,
            isMonitored: true,
            savedAt: DateTime.now().subtract(const Duration(hours: 1)),
            summary: 'via NH 66 Corridor',
          ),
        );
      }

      // Load Notifications
      final notifsJson = prefs.getStringList(_prefsNotificationsKey);
      if (notifsJson != null && notifsJson.isNotEmpty) {
        _notifications.clear();
        for (final item in notifsJson) {
          try {
            _notifications.add(NotificationModel.fromJson(
                jsonDecode(item) as Map<String, dynamic>));
          } catch (_) {}
        }
      } else {
        // Seed initial welcoming notification
        _notifications.add(
          NotificationModel(
            id: 'welcome_notif_0',
            title: 'Pre-Departure Route Monitoring Active',
            body:
                'JourneyGuard AI is actively tracking weather risk and crowdsourced hazards for your saved routes.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
            type: NotificationType.system,
            isRead: false,
          ),
        );
      }
    } catch (_) {
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _persistNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList(_prefsNotificationsKey, list);
    } catch (_) {}
  }

  Future<void> _persistSavedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _savedRoutes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_prefsSavedRoutesKey, list);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification Management
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> postNotification(NotificationModel notification,
      {bool showHeadsUp = true}) async {
    _notifications.insert(0, notification);
    notifyListeners();
    if (showHeadsUp) {
      _headsUpStreamController.add(notification);
    }
    await _persistNotifications();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
      _persistNotifications();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persistNotifications();
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _persistNotifications();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
    _persistNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Saved / Monitored Routes
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveRoute(SavedRouteModel route) async {
    final existingIndex = _savedRoutes.indexWhere(
      (r) =>
          (r.fromName == route.fromName && r.toName == route.toName) ||
          r.id == route.id,
    );

    if (existingIndex >= 0) {
      _savedRoutes[existingIndex] = route;
    } else {
      _savedRoutes.insert(0, route);
    }
    notifyListeners();
    await _persistSavedRoutes();
  }

  bool isRouteMonitored(String fromName, String toName) {
    return _savedRoutes.any((r) =>
        r.fromName.toLowerCase().trim() == fromName.toLowerCase().trim() &&
        r.toName.toLowerCase().trim() == toName.toLowerCase().trim() &&
        r.isMonitored);
  }

  Future<void> toggleRouteMonitoring(String routeId, bool isMonitored) async {
    final idx = _savedRoutes.indexWhere((r) => r.id == routeId);
    if (idx >= 0) {
      _savedRoutes[idx] = _savedRoutes[idx].copyWith(isMonitored: isMonitored);
      notifyListeners();
      await _persistSavedRoutes();
    }
  }

  Future<void> removeSavedRoute(String routeId) async {
    _savedRoutes.removeWhere((r) => r.id == routeId);
    notifyListeners();
    await _persistSavedRoutes();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Module G Triggers & Simulations (Hackathon Demo)
  // ─────────────────────────────────────────────────────────────────────────

  /// Trigger 1: A previously "safe" route's risk crosses into High/Critical
  Future<NotificationModel> simulateRiskEscalation({
    SavedRouteModel? targetRoute,
    double newRisk = 82.0,
  }) async {
    final route = targetRoute ??
        (_savedRoutes.isNotEmpty
            ? _savedRoutes.first
            : SavedRouteModel(
                id: 'demo_route',
                name: 'Kochi Airport Corridor',
                fromName: 'Kochi City Center',
                toName: 'Kochi International Airport',
                fromLatitude: 9.9816,
                fromLongitude: 76.2999,
                toLatitude: 10.1520,
                toLongitude: 76.3922,
                departureTime: DateTime.now().add(const Duration(hours: 1)),
                initialRiskScore: 22.0,
                savedAt: DateTime.now(),
              ));

    final oldRisk = route.initialRiskScore;
    final id = 'risk_esc_${DateTime.now().millisecondsSinceEpoch}';

    final notif = NotificationModel(
      id: id,
      title: 'CRITICAL: Route Risk Escalation',
      body:
          '${route.fromName} → ${route.toName} risk escalated from ${oldRisk.toStringAsFixed(0)}% to ${newRisk.toStringAsFixed(0)}% (Critical). Severe convective downpour detected.',
      timestamp: DateTime.now(),
      type: NotificationType.riskEscalation,
      isRead: false,
      routeData: {
        'routeId': route.id,
        'fromName': route.fromName,
        'toName': route.toName,
        'fromLat': route.fromLatitude,
        'fromLng': route.fromLongitude,
        'toLat': route.toLatitude,
        'toLng': route.toLongitude,
        'oldRisk': oldRisk,
        'newRisk': newRisk,
        'departureTime': route.departureTime.toIso8601String(),
      },
      payload: {
        'fcm_message_id': 'fcm_${DateTime.now().millisecondsSinceEpoch}',
        'channel_id': 'journeyguard_critical_alerts',
        'priority': 'high',
        'action': 'OPEN_ROUTE_COMPARISON',
      },
    );

    await postNotification(notif, showHeadsUp: true);
    return notif;
  }

  /// Trigger 2: A new incident is reported near a route the user has saved
  Future<NotificationModel> simulateIncidentAlert({
    SavedRouteModel? targetRoute,
    String incidentType = 'Landslide',
    String description =
        'Debris flow and fallen utility pole blocking Northbound lane on NH 66 bypass.',
  }) async {
    final route = targetRoute ??
        (_savedRoutes.isNotEmpty
            ? _savedRoutes.first
            : SavedRouteModel(
                id: 'demo_route',
                name: 'Kochi Airport Corridor',
                fromName: 'Kochi City Center',
                toName: 'Kochi International Airport',
                fromLatitude: 9.9816,
                fromLongitude: 76.2999,
                toLatitude: 10.1520,
                toLongitude: 76.3922,
                departureTime: DateTime.now().add(const Duration(hours: 1)),
                initialRiskScore: 24.0,
                savedAt: DateTime.now(),
              ));

    final id = 'incident_alert_${DateTime.now().millisecondsSinceEpoch}';

    final notif = NotificationModel(
      id: id,
      title: 'Hazard Alert on Saved Route',
      body:
          '$incidentType reported 650m from your saved corridor (${route.fromName} → ${route.toName}). Avoid lane or reroute.',
      timestamp: DateTime.now(),
      type: NotificationType.incidentAlert,
      isRead: false,
      incidentData: {
        'incidentType': incidentType,
        'description': description,
        'distanceMeters': 650.0,
        'latitude': (route.fromLatitude + route.toLatitude) / 2,
        'longitude': (route.fromLongitude + route.toLongitude) / 2,
      },
      routeData: {
        'fromName': route.fromName,
        'toName': route.toName,
        'fromLat': route.fromLatitude,
        'fromLng': route.fromLongitude,
        'toLat': route.toLatitude,
        'toLng': route.toLongitude,
      },
      payload: {
        'fcm_message_id': 'fcm_${DateTime.now().millisecondsSinceEpoch}',
        'channel_id': 'journeyguard_incident_channel',
        'priority': 'high',
        'action': 'OPEN_INCIDENT_MAP',
      },
    );

    await postNotification(notif, showHeadsUp: true);
    return notif;
  }

  /// Real-time proximity check when a citizen or official posts a report
  Future<void> checkIncidentAgainstSavedRoutes(IncidentReport incident) async {
    if (incident.latitude == null || incident.longitude == null) return;

    for (final route in _savedRoutes) {
      if (!route.isMonitored) continue;

      double minDistanceKm = double.infinity;
      // Sample 10 interpolated points along the corridor segment for accurate distance
      for (int step = 0; step <= 10; step++) {
        final t = step / 10.0;
        final lat =
            route.fromLatitude + t * (route.toLatitude - route.fromLatitude);
        final lon =
            route.fromLongitude + t * (route.toLongitude - route.fromLongitude);
        final d = _calculateDistanceKm(
            incident.latitude!, incident.longitude!, lat, lon);
        if (d < minDistanceKm) {
          minDistanceKm = d;
        }
      }

      // If incident is within 3.5 km of the corridor
      if (minDistanceKm <= 3.5) {
        final distStr = minDistanceKm < 1.0
            ? '${(minDistanceKm * 1000).round()}m'
            : '${minDistanceKm.toStringAsFixed(1)}km';

        final notif = NotificationModel(
          id: 'incident_near_${DateTime.now().millisecondsSinceEpoch}',
          title: '🚨 Incident Near Saved Corridor',
          body:
              'New ${incident.incidentType} reported $distStr from ${route.fromName} → ${route.toName}. "${incident.description}"',
          timestamp: DateTime.now(),
          type: NotificationType.incidentAlert,
          isRead: false,
          incidentData: {
            'incidentType': incident.incidentType,
            'description': incident.description,
            'distanceMeters': minDistanceKm * 1000,
            'latitude': incident.latitude,
            'longitude': incident.longitude,
          },
          routeData: {
            'fromName': route.fromName,
            'toName': route.toName,
            'fromLat': route.fromLatitude,
            'fromLng': route.fromLongitude,
            'toLat': route.toLatitude,
            'toLng': route.toLongitude,
          },
        );

        await postNotification(notif, showHeadsUp: true);
        break; // Alert once per incident
      }
    }
  }

  double _calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R * asin...
  }

  @override
  void dispose() {
    _headsUpStreamController.close();
    super.dispose();
  }
}
