import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LovableWeatherTab extends StatefulWidget {
  const LovableWeatherTab({super.key});

  @override
  State<LovableWeatherTab> createState() => _LovableWeatherTabState();
}

class _LovableWeatherTabState extends State<LovableWeatherTab> {
  int _selectedTimelineIndex = 1;

  final List<Map<String, dynamic>> _hourlyForecast = [
    {
      'time': '06:00',
      'temp': '25°',
      'icon': Icons.wb_twilight_rounded,
      'rain': '8%',
      'roadRisk': 'Optimal',
      'riskColor': AppColors.lovableGreen,
    },
    {
      'time': '09:00',
      'temp': '28°',
      'icon': Icons.grain_rounded,
      'rain': '32%',
      'roadRisk': 'Wet Asphalt',
      'riskColor': AppColors.lovableGreen,
    },
    {
      'time': '12:00',
      'temp': '31°',
      'icon': Icons.thunderstorm_outlined,
      'rain': '68%',
      'roadRisk': 'Waterlogging',
      'riskColor': AppColors.riskModerate,
    },
    {
      'time': '15:00',
      'temp': '29°',
      'icon': Icons.water_drop_outlined,
      'rain': '45%',
      'roadRisk': 'Caution',
      'riskColor': AppColors.riskModerate,
    },
    {
      'time': '18:00',
      'temp': '27°',
      'icon': Icons.cloud_outlined,
      'rain': '14%',
      'roadRisk': 'Dry Road',
      'riskColor': AppColors.lovableGreen,
    },
    {
      'time': '21:00',
      'temp': '25°',
      'icon': Icons.nights_stay_outlined,
      'rain': '10%',
      'roadRisk': 'Clear',
      'riskColor': AppColors.lovableGreen,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Live Radar Status Hero Card
              _buildRadarHeroCard(),
              const SizedBox(height: 20),

              // 4-Metric Grid
              _buildMetricsGrid(),
              const SizedBox(height: 24),

              // 24-Hour Forecast Timeline
              _buildForecastSection(),
              const SizedBox(height: 24),

              // Severe Weather Advisories
              _buildAdvisoriesCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WEATHER AI INTELLIGENCE',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Live radar & road climate',
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Predictive atmospheric modeling for hyper-local highway corridors.',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildRadarHeroCard() {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.radarHeroGradientFor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF144D55) : Colors.transparent,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.lovableGreen : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? AppColors.lovableGreen : Colors.white,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DOPPLER RADAR SYNC ACTIVE',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF5EEAD4)
                          : Colors.white.withValues(alpha: 0.95),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF10464E)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF5EEAD4) : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '28°C',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              SizedBox(width: 14),
              Text(
                'Scattered Showers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Precipitation rate 2.4 mm/h · Cloud ceiling 1,200 m',
            style: TextStyle(
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0B292F)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF19464E)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aquaplaning Risk Index',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Low (0.18)',
                  style: TextStyle(
                    color: isDark ? AppColors.lovableGreen : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HIGHWAY CLIMATE METRICS',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.water_drop_outlined,
                title: 'Rain Probability',
                value: '32%',
                subtitle: 'Peak at 12:15 PM',
                accentColor: AppColors.lovableTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.air_rounded,
                title: 'Wind & Gusts',
                value: '12 km/h',
                subtitle: 'Gusts up to 18 km/h',
                accentColor: AppColors.accentIndigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.speed_rounded,
                title: 'Surface Friction',
                value: '0.82 µ',
                subtitle: 'Optimal road grip',
                accentColor: AppColors.lovableGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.visibility_outlined,
                title: 'Visibility Index',
                value: '8.0 km',
                subtitle: 'Clear sightlines',
                accentColor: const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondaryFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textMutedFor(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection() {
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HOURLY ROAD RISK TIMELINE',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _hourlyForecast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final item = _hourlyForecast[i];
              final isSelected = _selectedTimelineIndex == i;
              final riskColor = item['riskColor'] as Color;

              return GestureDetector(
                onTap: () => setState(() => _selectedTimelineIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? (isDark ? null : AppColors.lightHighlightGradient)
                        : null,
                    color: isSelected
                        ? (isDark ? const Color(0xFF152238) : null)
                        : AppColors.surfaceFor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? AppColors.lovableGreen : Colors.transparent)
                          : AppColors.borderFor(context),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected && !isDark
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : AppColors.cardShadowFor(context),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['time'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondaryFor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        item['icon'] as IconData,
                        size: 24,
                        color: isSelected
                            ? (isDark ? AppColors.lovableTeal : Colors.white)
                            : AppColors.lovableTeal,
                      ),
                      Text(
                        item['temp'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected && !isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : riskColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['rain'] as String,
                          style: TextStyle(
                            color: isSelected && !isDark ? Colors.white : riskColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisoriesCard() {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1811) : AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF422E10)
              : AppColors.riskModerate.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.riskModerate.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.riskModerate,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waterlogging Advisory · NH 66',
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expect intermittent water accumulation near Edappally flyover between 11:00 AM – 2:00 PM due to sudden monsoon cloudburst.',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
