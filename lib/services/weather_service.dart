import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';
import '../models/weather_data.dart';

class WeatherService {
  static const _weatherVariables = [
    'precipitation',
    'precipitation_probability',
    'temperature_2m',
    'wind_speed_10m',
    'weather_code',
    'relative_humidity_2m',
  ];

  /// Module B - 3.1: Get weather forecast per segment matching prompt signature.
  /// Calls Open-Meteo for the segment's midpoint and ETA.
  /// Also includes 3.2 cumulative rainfall across preceding hours.
  Future<Map<String, dynamic>> getWeatherForSegment(
    double lat,
    double lng,
    DateTime eta,
  ) async {
    final date = DateFormat('yyyy-MM-dd').format(eta);
    // Request past_days=1 to capture antecedent rainfall for ground saturation (3.2)
    final url = Uri.parse(
      '${AppConstants.openMeteoBaseUrl}?latitude=$lat&longitude=$lng'
      '&hourly=precipitation,precipitation_probability,temperature_2m,wind_speed_10m,weather_code'
      '&start_date=${DateFormat('yyyy-MM-dd').format(eta.subtract(const Duration(days: 1)))}'
      '&end_date=$date'
      '&timezone=auto',
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final hourly = data['hourly'] as Map<String, dynamic>;
        final times = (hourly['time'] as List?)?.cast<String>() ?? [];
        final targetHour = 'T${eta.hour.toString().padLeft(2, '0')}:00';
        
        int hourIndex = times.lastIndexWhere((t) => t.contains(targetHour) && t.startsWith(date));
        if (hourIndex < 0) {
          // Fallback: 24h yesterday + eta.hour today
          hourIndex = (24 + eta.hour).clamp(0, (hourly['precipitation'] as List).length - 1);
        }

        final precipitationList = (hourly['precipitation'] as List?) ?? [];
        final probList = (hourly['precipitation_probability'] as List?) ?? [];

        double safeDouble(List<dynamic> list, int idx) {
          if (idx < 0 || idx >= list.length || list[idx] == null) return 0.0;
          return (list[idx] as num).toDouble();
        }

        final precipitation = safeDouble(precipitationList, hourIndex);
        final probability = safeDouble(probList, hourIndex);

        // 3.2: Cumulative rainfall over preceding 24 hours
        double cumulativePrecipitation = 0.0;
        final startIdx = (hourIndex - 24 + 1).clamp(0, precipitationList.length);
        for (int i = startIdx; i <= hourIndex && i < precipitationList.length; i++) {
          cumulativePrecipitation += safeDouble(precipitationList, i);
        }

        return {
          'precipitation': precipitation,
          'probability': probability,
          'cumulativePrecipitation': cumulativePrecipitation,
          'hourIndex': hourIndex,
          'hourly': hourly,
        };
      }
    } catch (_) {
      // Fallback for offline or API timeout
    }

    // Default fallback
    return {
      'precipitation': 0.0,
      'probability': 0.0,
      'cumulativePrecipitation': 0.0,
      'hourIndex': eta.hour,
      'hourly': <String, dynamic>{},
    };
  }

  /// Fetch full hourly weather forecast model for a given location and date.
  /// Captures preceding 24 hours for ground saturation calculation.
  Future<WeatherData> fetchWeather({
    required LatLng location,
    required DateTime dateTime,
  }) async {
    final prevDate = _formatDate(dateTime.subtract(const Duration(days: 1)));
    final curDate = _formatDate(dateTime);

    final url = '${AppConstants.openMeteoBaseUrl}'
        '?latitude=${location.latitude}'
        '&longitude=${location.longitude}'
        '&hourly=${_weatherVariables.join(',')}'
        '&start_date=$prevDate'
        '&end_date=$curDate'
        '&timezone=auto'
        '&wind_speed_unit=kmh';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return WeatherData.empty();
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>;

      // Find target hour on the current date
      final times = (hourly['time'] as List?)?.cast<String>() ?? [];
      final targetHour = 'T${dateTime.hour.toString().padLeft(2, '0')}:00';
      int hourIndex = times.lastIndexWhere((t) => t.contains(targetHour) && t.startsWith(curDate));
      if (hourIndex < 0) {
        // Fallback: 24h yesterday + dateTime.hour
        hourIndex = 24 + dateTime.hour;
      }

      return WeatherData.fromOpenMeteo(
        hourly: hourly,
        hourIndex: hourIndex,
      );
    } catch (_) {
      return WeatherData.empty();
    }
  }

  /// Fetch weather for multiple departure hours on same day
  Future<List<WeatherData>> fetchDepartureTimeWeather({
    required LatLng location,
    required DateTime date,
    required List<int> hours,
  }) async {
    final prevDate = _formatDate(date.subtract(const Duration(days: 1)));
    final curDate = _formatDate(date);

    final url = '${AppConstants.openMeteoBaseUrl}'
        '?latitude=${location.latitude}'
        '&longitude=${location.longitude}'
        '&hourly=${_weatherVariables.join(',')}'
        '&start_date=$prevDate'
        '&end_date=$curDate'
        '&timezone=auto'
        '&wind_speed_unit=kmh';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return hours.map((_) => WeatherData.empty()).toList();
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List?)?.cast<String>() ?? [];

      return hours.map((hour) {
        final targetHour = 'T${hour.toString().padLeft(2, '0')}:00';
        int hourIndex = times.lastIndexWhere((t) => t.contains(targetHour) && t.startsWith(curDate));
        if (hourIndex < 0) hourIndex = 24 + hour;

        return WeatherData.fromOpenMeteo(
          hourly: hourly,
          hourIndex: hourIndex,
        );
      }).toList();
    } catch (_) {
      return hours.map((_) => WeatherData.empty()).toList();
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
