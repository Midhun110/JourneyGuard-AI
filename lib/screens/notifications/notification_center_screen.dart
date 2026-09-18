import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../models/saved_route_model.dart';
import '../../services/notification_service.dart';
import '../../services/routing_service.dart';
import '../route_risk/route_risk_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Risk, 2: Hazards
  bool _isSimulating = false;

  Future<void> _handleNotificationTap(
      BuildContext context, NotificationModel notif) async {
    NotificationService.instance.markAsRead(notif.id);

    if (notif.routeData != null) {
      final routeData = notif.routeData!;
      final fromName = routeData['fromName'] as String? ?? 'Origin';
      final toName = routeData['toName'] as String? ?? 'Destination';
      final fromLat = routeData['fromLat'] as num?;
      final fromLng = routeData['fromLng'] as num?;
      final toLat = routeData['toLat'] as num?;
      final toLng = routeData['toLng'] as num?;

      if (fromLat != null && fromLng != null && toLat != null && toLng != null) {
        final origin = LatLng(fromLat.toDouble(), fromLng.toDouble());
        final destination = LatLng(toLat.toDouble(), toLng.toDouble());

        _showLoadingSnackbar('Fetching live route risk map...');

        try {
          final routing = RoutingService();
          final routes = await routing.fetchRoutes(
            origin: origin,
            destination: destination,
          );

          if (!mounted) return;
          if (routes.isNotEmpty) {
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (_) => RouteRiskScreen(
                  routes: routes,
                  fromName: fromName,
                  toName: toName,
                  departureTime: DateTime.now().add(const Duration(hours: 1)),
                  fromLocation: origin,
                  toLocation: destination,
                ),
              ),
            );
            return;
          }
        } catch (_) {}
      }
    }
  }

  void _showLoadingSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(msg),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.lovableTealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runRiskEscalationDemo() async {
    setState(() => _isSimulating = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await NotificationService.instance.simulateRiskEscalation();
    if (mounted) setState(() => _isSimulating = false);
  }

  Future<void> _runIncidentAlertDemo() async {
    setState(() => _isSimulating = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await NotificationService.instance.simulateIncidentAlert();
    if (mounted) setState(() => _isSimulating = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final notifService = NotificationService.instance;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final allNotifs = notifService.notifications;
        final filteredNotifs = allNotifs.where((n) {
          if (_selectedFilterIndex == 1) {
            return n.type == NotificationType.riskEscalation;
          }
          if (_selectedFilterIndex == 2) {
            return n.type == NotificationType.incidentAlert;
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'Alerts & Push Notifications',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (allNotifs.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Mark all as read',
                  icon: const Icon(Icons.done_all_rounded, size: 20),
                  onPressed: () => notifService.markAllAsRead(),
                ),
                IconButton(
                  tooltip: 'Clear all',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  onPressed: () => _confirmClearAll(context, notifService),
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              children: [
                // SIH 2026 Demo Simulation Controls
                _buildSimulationCard(isDark),
                const SizedBox(height: 18),

                // Monitored Routes Section
                _buildMonitoredRoutesCard(notifService, isDark),
                const SizedBox(height: 20),

                // Filter Tabs
                _buildFilterChips(notifService, isDark),
                const SizedBox(height: 16),

                // Notification List
                if (filteredNotifs.isEmpty)
                  _buildEmptyState(isDark)
                else
                  ...filteredNotifs.map(
                    (notif) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildNotificationItem(notif, isDark),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimulationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131E31) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.lovableTeal.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lovableTeal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.lovableTeal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MODULE G · HACKATHON DEMO TRIGGERS',
                      style: TextStyle(
                        color: AppColors.lovableTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Simulate server-side FCM push delivery before departure',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSimulating ? null : _runRiskEscalationDemo,
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: const Text(
                    'Risk Escalation',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.riskCritical.withValues(alpha: 0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSimulating ? null : _runIncidentAlertDemo,
                  icon: const Icon(Icons.report_problem_rounded, size: 16),
                  label: const Text(
                    'Hazard Report',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.riskModerate.withValues(alpha: 0.95),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoredRoutesCard(
      NotificationService notifService, bool isDark) {
    final savedRoutes = notifService.savedRoutes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    color: AppColors.lovableGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monitored Travel Corridors',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lovableGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.lovableGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Live Tracking',
                      style: TextStyle(
                        color: AppColors.lovableGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (savedRoutes.isEmpty)
            Text(
              'No routes saved yet. Tap "Monitor Route" from any route risk analysis to receive pre-departure push alerts.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
              ),
            )
          else
            ...savedRoutes.map((route) => _buildMonitoredRouteRow(
                  route,
                  notifService,
                  isDark,
                )),
        ],
      ),
    );
  }

  Widget _buildMonitoredRouteRow(
    SavedRouteModel route,
    NotificationService notifService,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: route.isMonitored
              ? AppColors.lovableGreen.withValues(alpha: 0.3)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alt_route_rounded,
            color: route.isMonitored
                ? AppColors.lovableGreen
                : (isDark ? Colors.white38 : Colors.black38),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${route.fromName} → ${route.toName}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Departure: ${DateFormat('h:mm a, MMM d').format(route.departureTime)} · Init: ${route.initialRiskScore.toStringAsFixed(0)}% risk',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: route.isMonitored,
            activeColor: AppColors.lovableGreen,
            onChanged: (val) {
              notifService.toggleRouteMonitoring(route.id, val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(NotificationService notifService, bool isDark) {
    final labels = ['All', 'Risk Escalations', 'Hazards'];

    return Row(
      children: List.generate(labels.length, (index) {
        final isSelected = _selectedFilterIndex == index;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(labels[index]),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedFilterIndex = index),
            selectedColor: AppColors.lovableGreen.withValues(alpha: 0.25),
            labelStyle: TextStyle(
              color: isSelected
                  ? (isDark ? AppColors.lovableGreen : const Color(0xFF004D40))
                  : (isDark ? Colors.white60 : Colors.black54),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppColors.lovableGreen
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
            backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
          ),
        );
      }),
    );
  }

  Widget _buildNotificationItem(NotificationModel notif, bool isDark) {
    final timeStr = DateFormat('h:mm a · dd MMM').format(notif.timestamp);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        NotificationService.instance.deleteNotification(notif.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.riskCritical.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _handleNotificationTap(context, notif),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111927) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0))
                  : notif.accentColor.withValues(alpha: 0.6),
              width: notif.isRead ? 1.0 : 1.5,
            ),
            boxShadow: [
              if (!notif.isRead)
                BoxShadow(
                  color: notif.accentColor.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tag row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: notif.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(notif.icon, color: notif.accentColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: notif.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notif.typeLabel,
                      style: TextStyle(
                        color: notif.accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                  if (!notif.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: notif.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                notif.title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              // Body
              Text(
                notif.body,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              if (notif.routeData != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      size: 14,
                      color: AppColors.lovableTeal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to inspect affected corridor & alternatives',
                      style: TextStyle(
                        color: AppColors.lovableTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.lovableTeal,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Alerts In This Category',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All monitored corridors are currently within normal safety parameters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text(
          'This will remove all alerts from your notification center history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.riskCritical,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              service.clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
