import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';
import '../models/route_model.dart';

class RoutingService {
  static const _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'JourneyGuardAI/1.0',
  };

  /// Fetch routes from OSRM for given origin and destination.
  /// Returns up to [alternatives] routes.
  Future<List<RouteModel>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    int alternatives = AppConstants.osrmMaxAlternatives,
  }) async {
    final coordStr =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url =
        '${AppConstants.osrmBaseUrl}/$coordStr?alternatives=$alternatives&geometries=geojson&overview=full&steps=false';

    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('OSRM API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code != 'Ok') {
        throw Exception('OSRM routing failed: $code');
      }

      final routes = (data['routes'] as List)
          .map((r) => RouteModel.fromOsrm(r as Map<String, dynamic>))
          .toList();

      return routes;
    } catch (e) {
      rethrow;
    }
  }

  /// Geocode a place name using Nominatim
  Future<LatLng?> geocodePlace(String placeName) async {
    final encoded = Uri.encodeComponent(placeName);
    final url =
        '${AppConstants.nominatimBaseUrl}/search?q=$encoded&format=json&limit=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ..._headers,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final results = json.decode(response.body) as List;
      if (results.isEmpty) return null;

      final first = results[0] as Map<String, dynamic>;
      return LatLng(
        double.parse(first['lat'] as String),
        double.parse(first['lon'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode coordinates to get a place name
  Future<String?> reverseGeocode(LatLng position) async {
    final url =
        '${AppConstants.nominatimBaseUrl}/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ..._headers,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Search for place suggestions (autocomplete)
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.length < 3) return [];

    final encoded = Uri.encodeComponent(query);
    final url =
        '${AppConstants.nominatimBaseUrl}/search?q=$encoded&format=json&limit=5&addressdetails=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ..._headers,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final results = json.decode(response.body) as List;
      return results.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
