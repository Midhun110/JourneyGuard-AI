import 'package:latlong2/latlong.dart';

/// Represents an autocomplete place suggestion from OpenStreetMap / Nominatim
class PlaceSuggestion {
  final String name;
  final String districtState;
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;

  const PlaceSuggestion({
    required this.name,
    required this.districtState,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type = 'place',
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// Parse from Nominatim OpenStreetMap JSON response
  factory PlaceSuggestion.fromNominatim(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String? ?? '';
    final address = json['address'] as Map<String, dynamic>? ?? {};

    // Determine clean primary name
    String name = (json['name'] as String? ?? '').trim();
    if (name.isEmpty) {
      // Pick first segment of display_name
      final segments = displayName.split(',');
      name = segments.isNotEmpty ? segments.first.trim() : 'Unknown Place';
    }

    // Determine clean district/state subtitle
    final List<String> regionParts = [];
    final locality = address['suburb'] ?? address['city'] ?? address['town'] ?? address['village'];
    final district = address['state_district'] ?? address['county'] ?? address['district'];
    final state = address['state'];
    final country = address['country'];

    if (locality != null && locality.toString().trim() != name) {
      regionParts.add(locality.toString().trim());
    }
    if (district != null) {
      regionParts.add(district.toString().trim());
    }
    if (state != null) {
      regionParts.add(state.toString().trim());
    } else if (country != null) {
      regionParts.add(country.toString().trim());
    }

    String districtState = regionParts.join(', ');
    if (districtState.isEmpty) {
      // Fallback: use remaining segments of display_name
      final segments = displayName.split(',');
      if (segments.length > 1) {
        districtState = segments.skip(1).take(2).map((s) => s.trim()).join(', ');
      } else {
        districtState = displayName;
      }
    }

    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;
    final type = json['type'] as String? ?? json['addresstype'] as String? ?? 'place';

    return PlaceSuggestion(
      name: name,
      districtState: districtState,
      displayName: displayName,
      latitude: lat,
      longitude: lon,
      type: type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'district_state': districtState,
      'display_name': displayName,
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'type': type,
    };
  }

  @override
  String toString() => '$name ($districtState) [$latitude, $longitude]';
}
