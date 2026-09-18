class AppConstants {
  AppConstants._();

  // OSRM Routing API
  static const String osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const int osrmMaxAlternatives = 3;

  // Open-Meteo Weather API
  static const String openMeteoBaseUrl = 'https://api.open-meteo.com/v1/forecast';

  // Nominatim Geocoding
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // Module B Risk Formula Weights
  static const double weightRainfallIntensity = 0.40;
  static const double weightRainProbability = 0.15;
  static const double weightCumulativeRainfall = 0.20;
  static const double weightRoadVulnerability = 0.15;
  static const double weightHistoricalIncidents = 0.10;

  // Module C Route Comparison Ranking Weights
  static const double defaultRiskWeight = 0.70; // Safety-first default
  static const double defaultTimeWeight = 0.30;

  // Departure Time Options (8 AM, 12 PM, 4 PM)
  static const List<int> departureHours = [8, 12, 16];
  static const List<String> departureLabels = [
    '8 AM',
    '12 PM',
    '4 PM',
  ];

  // Route Segment Distance (meters)
  static const double segmentLengthMeters = 5000; // 5km segments

  // Risk Thresholds
  static const double lowRiskThreshold = 25.0;
  static const double moderateRiskThreshold = 50.0;
  static const double highRiskThreshold = 75.0;
  static const double acceptableRiskThreshold = 50.0; // Routes <= 50 are acceptable for travel
}
