import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum NotificationType {
  riskEscalation,
  incidentAlert,
  system,
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final Map<String, dynamic>? routeData;
  final Map<String, dynamic>? incidentData;
  final Map<String, dynamic>? payload;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.routeData,
    this.incidentData,
    this.payload,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    Map<String, dynamic>? routeData,
    Map<String, dynamic>? incidentData,
    Map<String, dynamic>? payload,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      routeData: routeData ?? this.routeData,
      incidentData: incidentData ?? this.incidentData,
      payload: payload ?? this.payload,
    );
  }

  Color get accentColor {
    switch (type) {
      case NotificationType.riskEscalation:
        return AppColors.riskCritical;
      case NotificationType.incidentAlert:
        return AppColors.riskModerate;
      case NotificationType.system:
        return AppColors.lovableGreen;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.riskEscalation:
        return Icons.warning_amber_rounded;
      case NotificationType.incidentAlert:
        return Icons.report_problem_rounded;
      case NotificationType.system:
        return Icons.notifications_active_rounded;
    }
  }

  String get typeLabel {
    switch (type) {
      case NotificationType.riskEscalation:
        return 'RISK ESCALATION';
      case NotificationType.incidentAlert:
        return 'HAZARD REPORT';
      case NotificationType.system:
        return 'SYSTEM ADVISORY';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'isRead': isRead,
      if (routeData != null) 'routeData': routeData,
      if (incidentData != null) 'incidentData': incidentData,
      if (payload != null) 'payload': payload,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      isRead: json['isRead'] as bool? ?? false,
      routeData: json['routeData'] as Map<String, dynamic>?,
      incidentData: json['incidentData'] as Map<String, dynamic>?,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
}
