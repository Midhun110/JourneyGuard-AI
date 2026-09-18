import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/routing_service.dart';
import '../core/theme/app_colors.dart';
import '../screens/route_risk/route_risk_screen.dart';
import '../screens/notifications/notification_center_screen.dart';

class HeadsUpNotificationOverlay extends StatefulWidget {
  final Widget child;

  const HeadsUpNotificationOverlay({super.key, required this.child});

  @override
  State<HeadsUpNotificationOverlay> createState() =>
      _HeadsUpNotificationOverlayState();
}

class _HeadsUpNotificationOverlayState
    extends State<HeadsUpNotificationOverlay> {
  StreamSubscription<NotificationModel>? _sub;
  NotificationModel? _activeNotification;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _sub = NotificationService.instance.headsUpStream.listen((notif) {
      if (mounted) {
        _showNotification(notif);
      }
    });
  }

  void _showNotification(NotificationModel notif) {
    _dismissTimer?.cancel();
    setState(() {
      _activeNotification = notif;
    });

    _dismissTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    setState(() {
      _activeNotification = null;
    });
  }

  Future<void> _handleTap(BuildContext context, NotificationModel notif) async {
    _dismiss();
    NotificationService.instance.markAsRead(notif.id);

    // If notification has route coordinates, attempt to navigate directly to RouteRiskScreen
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

        try {
          final routing = RoutingService();
          final routes = await routing.fetchRoutes(
            origin: origin,
            destination: destination,
          );

          if (routes.isNotEmpty && context.mounted) {
            Navigator.push(
              context,
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

    // Default fallback: open Notification Center
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const NotificationCenterScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_activeNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta != null &&
                        details.primaryDelta! < -5) {
                      _dismiss();
                    }
                  },
                  onTap: () => _handleTap(context, _activeNotification!),
                  child: Material(
                    color: Colors.transparent,
                    child: _buildBannerCard(_activeNotification!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerCard(NotificationModel notif) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notif.accentColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: notif.accentColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Brand badge + Type + Dismiss icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: notif.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notif.icon,
                  color: notif.accentColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'JOURNEYGUARD AI',
                      style: TextStyle(
                        color: notif.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white38 : Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Just now',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: _dismiss,
              ),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Action Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: notif.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notif.typeLabel,
                  style: TextStyle(
                    color: notif.accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Row(
                children: [
                  Text(
                    'Tap to inspect route',
                    style: TextStyle(
                      color: AppColors.lovableTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: AppColors.lovableTeal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -0.8, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 250.ms);
  }
}
