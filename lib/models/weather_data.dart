class WeatherData {
  final double rainfallIntensity;  // mm/h
  final double rainProbability;    // 0-100 %
  final double cumulativeRainfall; // mm over period
  final double temperature;        // Celsius
  final double windSpeed;          // km/h
  final String weatherCode;        // WMO code
  final DateTime fetchedAt;

  const WeatherData({
    required this.rainfallIntensity,
    required this.rainProbability,
    required this.cumulativeRainfall,
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.fetchedAt,
  });

  String get weatherDescription {
    final code = int.tryParse(weatherCode) ?? 0;
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 49) return 'Foggy';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rain';
    if (code <= 79) return 'Snow';
    if (code <= 82) return 'Rain showers';
    if (code <= 86) return 'Snow showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  bool get isRaining => rainfallIntensity > 0.1;

  factory WeatherData.fromOpenMeteo({
    required Map<String, dynamic> hourly,
    required int hourIndex,
  }) {
    List<dynamic> getList(String key) =>
        (hourly[key] as List?) ?? [];

    final rainfallList = getList('precipitation');
    final probList = getList('precipitation_probability');
    final tempList = getList('temperature_2m');
    final windList = getList('wind_speed_10m');
    final codeList = getList('weather_code');

    double safeDouble(List<dynamic> list, int idx) {
      if (idx >= list.length || list[idx] == null) return 0.0;
      return (list[idx] as num).toDouble();
    }

    final rainfall = safeDouble(rainfallList, hourIndex);

    // Module B - 3.2: Cumulative antecedent rainfall (preceding 6-24 hours)
    // Captures ground/soil saturation for landslide and flood triggering
    final precedingLookback = 24;
    final startIdx = (hourIndex - precedingLookback + 1).clamp(0, rainfallList.length);
    double cumulative = 0;
    for (int i = startIdx; i <= hourIndex && i < rainfallList.length; i++) {
      cumulative += safeDouble(rainfallList, i);
    }

    return WeatherData(
      rainfallIntensity: rainfall,
      rainProbability: safeDouble(probList, hourIndex),
      cumulativeRainfall: cumulative,
      temperature: safeDouble(tempList, hourIndex),
      windSpeed: safeDouble(windList, hourIndex),
      weatherCode: (codeList.isNotEmpty && hourIndex < codeList.length)
          ? codeList[hourIndex]?.toString() ?? '0'
          : '0',
      fetchedAt: DateTime.now(),
    );
  }

  factory WeatherData.empty() => WeatherData(
        rainfallIntensity: 0,
        rainProbability: 0,
        cumulativeRainfall: 0,
        temperature: 25,
        windSpeed: 10,
        weatherCode: '0',
        fetchedAt: DateTime.now(),
      );
}

class DepartureTimeWeather {
  final int hour;
  final String label;
  final WeatherData weather;
  final double riskScore;
  final double maxRisk;
  final double weightedAvgRisk;
  final double riskReductionVsBaseline;
  final bool isSafestSlot;
  final DateTime? departureTime;

  const DepartureTimeWeather({
    required this.hour,
    required this.label,
    required this.weather,
    required this.riskScore,
    this.maxRisk = 0.0,
    this.weightedAvgRisk = 0.0,
    this.riskReductionVsBaseline = 0.0,
    this.isSafestSlot = false,
    this.departureTime,
  });

  bool get isSafest => isSafestSlot || riskScore < 30;
}
