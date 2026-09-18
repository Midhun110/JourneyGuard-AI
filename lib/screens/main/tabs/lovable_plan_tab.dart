import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/routing_service.dart';
import '../../route_risk/route_risk_screen.dart';

class LovablePlanTab extends StatefulWidget {
  const LovablePlanTab({super.key});

  @override
  State<LovablePlanTab> createState() => _LovablePlanTabState();
}

class _LovablePlanTabState extends State<LovablePlanTab> {
  int _selectedRouteIndex = 0;
  int _selectedHourIndex = 0;
  bool _isLoadingMap = false;

  final List<Map<String, dynamic>> _routesData = [
    {
      'title': 'NH 66 · Edappally',
      'tag': 'Safest',
      'tagType': 'safe',
      'distance': '24.8 km',
      'duration': '41 min',
      'riskScore': 12,
      'rainChance': '18%',
      'roadCondition': 'Optimal dry asphalt, smooth traffic flow',
      'color': AppColors.lovableGreen,
    },
    {
      'title': 'Seaport–Airport Rd',
      'tag': 'Fastest',
      'tagType': 'fast',
      'distance': '21.2 km',
      'duration': '36 min',
      'riskScore': 34,
      'rainChance': '28%',
      'roadCondition': 'Moderate water buildup near Kakkanad junction',
      'color': AppColors.riskModerate,
    },
    {
      'title': 'Infopark Expressway',
      'tag': 'Caution',
      'tagType': 'caution',
      'distance': '27.1 km',
      'duration': '44 min',
      'riskScore': 58,
      'rainChance': '64%',
      'roadCondition': 'Waterlogging reported, high aquaplaning probability',
      'color': AppColors.riskCritical,
    },
  ];

  final List<Map<String, dynamic>> _hourlySlots = [
    {'time': '06:00', 'risk': '8%', 'status': 'Ideal', 'isSafest': true},
    {'time': '07:00', 'risk': '19%', 'status': 'Good', 'isSafest': false},
    {'time': '08:00', 'risk': '42%', 'status': 'Congested', 'isSafest': false},
    {'time': '09:00', 'risk': '35%', 'status': 'Moderate', 'isSafest': false},
    {'time': '10:00', 'risk': '22%', 'status': 'Clear', 'isSafest': false},
  ];

  Future<void> _navigateToRiskMap() async {
    setState(() => _isLoadingMap = true);
    try {
      final routing = RoutingService();
      const from = LatLng(9.9816, 76.2999);
      const to = LatLng(10.1520, 76.3922);
      final routes = await routing.fetchRoutes(origin: from, destination: to);

      if (!mounted) return;
      if (routes.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteRiskScreen(
              routes: routes,
              fromName: 'Kochi City Center',
              toName: 'Kochi International Airport',
              departureTime: DateTime.now().add(const Duration(hours: 1)),
              fromLocation: from,
              toLocation: to,
            ),
          ),
        );
      }
    } catch (_) {
      // Fallback message
    } finally {
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

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

              // AI Departure Recommendation Card
              _buildAiRecommendationCard(),
              const SizedBox(height: 22),

              // Hourly Departure Timeline
              _buildHourlyTimeline(),
              const SizedBox(height: 24),

              // Section Label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ANALYZED ROUTES',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${_routesData.length} available',
                    style: const TextStyle(
                      color: AppColors.lovableTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Route Cards List
              ...List.generate(_routesData.length, (index) {
                return _buildRouteCard(index);
              }),
              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(),
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
          'ROUTE COMPARISON',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Compare routes',
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Three corridors analyzed for weather risk, road grip, and travel time.',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildAiRecommendationCard() {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.recommendationGradientFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF233554) : Colors.transparent,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.accentIndigo.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.accentIndigo.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: isDark ? AppColors.accentViolet : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI RECOMMENDATION',
                      style: TextStyle(
                        color: isDark ? AppColors.accentViolet : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.lovableGreen.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '8% Rain Risk',
                  style: TextStyle(
                    color: isDark ? AppColors.lovableGreen : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Leave at 6:00 AM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Light traffic and an 8% chance of rain make this your safest departure window. Saves ~14 min in commute.',
            style: TextStyle(
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyTimeline() {
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DEPARTURE TIME SLOTS',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _hourlySlots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final slot = _hourlySlots[i];
              final isSelected = _selectedHourIndex == i;
              final isSafest = slot['isSafest'] as bool;

              return GestureDetector(
                onTap: () => setState(() => _selectedHourIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? (isDark ? null : AppColors.lightHighlightGradient)
                        : null,
                    color: isSelected
                        ? (isDark ? const Color(0xFF16253B) : null)
                        : AppColors.surfaceFor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? AppColors.lovableGreen : Colors.transparent)
                          : (isSafest
                              ? AppColors.lovableGreen.withValues(alpha: 0.5)
                              : AppColors.borderFor(context)),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected && !isDark
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : AppColors.cardShadowFor(context),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot['time'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slot['risk'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isSafest
                                  ? AppColors.lovableGreen
                                  : AppColors.textSecondaryFor(context)),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        slot['status'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : (isSafest
                                  ? AppColors.lovableGreen
                                  : AppColors.textMutedFor(context)),
                          fontSize: 10,
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

  Widget _buildRouteCard(int index) {
    final isDark = AppColors.isDark(context);
    final route = _routesData[index];
    final isSelected = _selectedRouteIndex == index;
    final color = route['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedRouteIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.lovableTeal : AppColors.borderFor(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: AppColors.lovableTeal.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppColors.cardShadowFor(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title + Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected
                          ? AppColors.lovableTeal
                          : AppColors.textMutedFor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      route['title'] as String,
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                _buildTag(route['tag'] as String, route['tagType'] as String),
              ],
            ),
            const SizedBox(height: 14),

            // Metrics row: Distance, Duration, Rain
            Row(
              children: [
                _buildMetric(Icons.straighten, route['distance'] as String),
                const SizedBox(width: 18),
                _buildMetric(Icons.timer_outlined, route['duration'] as String),
                const SizedBox(width: 18),
                _buildMetric(Icons.water_drop_outlined, route['rainChance'] as String),
              ],
            ),
            const SizedBox(height: 12),

            // Risk Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Risk Level',
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${route['riskScore']}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (route['riskScore'] as int) / 100.0,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Road Condition Note
            Text(
              route['roadCondition'] as String,
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String tag, String type) {
    Color bg;
    Color text;
    IconData icon;

    if (type == 'safe') {
      bg = AppColors.lovableGreen.withValues(alpha: 0.15);
      text = AppColors.lovableGreen;
      icon = Icons.verified_user_outlined;
    } else if (type == 'fast') {
      bg = AppColors.riskModerate.withValues(alpha: 0.15);
      text = AppColors.riskModerate;
      icon = Icons.bolt_rounded;
    } else {
      bg = AppColors.riskCritical.withValues(alpha: 0.15);
      text = AppColors.riskCritical;
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 4),
          Text(
            tag,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMutedFor(context)),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isDark = AppColors.isDark(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.lovableGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.lovableGreen.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoadingMap ? null : _navigateToRiskMap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoadingMap
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Start Safe Navigation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _isLoadingMap ? null : _navigateToRiskMap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: isDark ? Colors.transparent : Colors.white,
            side: BorderSide(
              color: isDark ? const Color(0xFF2E3D56) : AppColors.borderFor(context),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, color: AppColors.lovableTeal, size: 18),
              SizedBox(width: 8),
              Text(
                'Open Full Risk Heatmap',
                style: TextStyle(
                  color: AppColors.lovableTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
