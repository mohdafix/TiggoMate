import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/app_notification.dart';
import '../firebase/firebase_sync_service.dart';

/// Represents a scheduled Chery authorised service appointment with date and reminder.
class ServiceAppointment {
  final String id;
  final String centreId;
  final String centreName;
  final String centreAddress;
  final String centrePhone;
  final String serviceType;
  final DateTime appointmentDate;
  final String timeSlot;
  final String reminderPreference; // '1_day_before', '2_hours_before', 'morning_of', 'none'
  final String notes;
  final DateTime createdAt;
  final bool isCancelled;

  const ServiceAppointment({
    required this.id,
    required this.centreId,
    required this.centreName,
    required this.centreAddress,
    required this.centrePhone,
    required this.serviceType,
    required this.appointmentDate,
    required this.timeSlot,
    this.reminderPreference = '1_day_before',
    this.notes = '',
    required this.createdAt,
    this.isCancelled = false,
  });

  ServiceAppointment copyWith({
    String? id,
    String? centreId,
    String? centreName,
    String? centreAddress,
    String? centrePhone,
    String? serviceType,
    DateTime? appointmentDate,
    String? timeSlot,
    String? reminderPreference,
    String? notes,
    DateTime? createdAt,
    bool? isCancelled,
  }) {
    return ServiceAppointment(
      id: id ?? this.id,
      centreId: centreId ?? this.centreId,
      centreName: centreName ?? this.centreName,
      centreAddress: centreAddress ?? this.centreAddress,
      centrePhone: centrePhone ?? this.centrePhone,
      serviceType: serviceType ?? this.serviceType,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      timeSlot: timeSlot ?? this.timeSlot,
      reminderPreference: reminderPreference ?? this.reminderPreference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  String get formattedReminder {
    switch (reminderPreference) {
      case '2_hours_before':
        return '2 hours before';
      case 'morning_of':
        return 'Morning of service (8:00 AM)';
      case 'none':
        return 'No reminder';
      case '1_day_before':
      default:
        return '1 day before';
    }
  }

  String get formattedDate {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = days[appointmentDate.weekday - 1];
    final monthName = months[appointmentDate.month - 1];
    return '$dayName, ${appointmentDate.day} $monthName ${appointmentDate.year}';
  }

  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);
    return target.difference(today).inDays;
  }

  String get calendarUrl {
    final title = Uri.encodeComponent('Chery Service: $serviceType');
    final details = Uri.encodeComponent(
      'Service Appointment at $centreName.\nAddress: $centreAddress\nPhone: $centrePhone\nNotes: $notes\nChery Tiggo 7 PHEV.',
    );
    final location = Uri.encodeComponent('$centreName, $centreAddress');

    // Parse timeSlot e.g. "09:30 AM"
    int hour = 9;
    int minute = 0;
    try {
      final parts = timeSlot.split(' ');
      final hm = parts[0].split(':');
      hour = int.parse(hm[0]);
      minute = int.parse(hm[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      }
    } catch (_) {}

    final start = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      hour,
      minute,
    ).toUtc();
    final end = start.add(const Duration(hours: 2));

    String formatUtc(DateTime dt) {
      return '${dt.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
    }

    final dates = '${formatUtc(start)}/${formatUtc(end)}';
    return 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$dates&details=$details&location=$location';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'centreId': centreId,
        'centreName': centreName,
        'centreAddress': centreAddress,
        'centrePhone': centrePhone,
        'serviceType': serviceType,
        'appointmentDate': appointmentDate.toIso8601String(),
        'timeSlot': timeSlot,
        'reminderPreference': reminderPreference,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'isCancelled': isCancelled,
      };

  factory ServiceAppointment.fromJson(Map<String, dynamic> json) {
    return ServiceAppointment(
      id: json['id'] as String? ?? UniqueKey().toString(),
      centreId: json['centreId'] as String? ?? '',
      centreName: json['centreName'] as String? ?? 'Chery Service Centre',
      centreAddress: json['centreAddress'] as String? ?? '',
      centrePhone: json['centrePhone'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? 'General Inspection',
      appointmentDate: DateTime.tryParse(json['appointmentDate'] as String? ?? '') ?? DateTime.now(),
      timeSlot: json['timeSlot'] as String? ?? '09:30 AM',
      reminderPreference: json['reminderPreference'] as String? ?? '1_day_before',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isCancelled: json['isCancelled'] as bool? ?? false,
    );
  }
}

/// Offline-first Persistent Manager for Chery Service Appointments
class ServiceAppointmentManager extends ChangeNotifier {
  static final ServiceAppointmentManager instance = ServiceAppointmentManager._internal();
  ServiceAppointmentManager._internal();

  static const String _kStorageKey = 'tm_service_appointments_v1';
  List<ServiceAppointment> _appointments = [];
  bool _isLoaded = false;

  List<ServiceAppointment> get appointments => List.unmodifiable(_appointments);

  /// Returns next upcoming confirmed appointment, or null if none
  ServiceAppointment? get upcomingAppointment {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = _appointments.where((a) {
      if (a.isCancelled) return false;
      final target = DateTime(a.appointmentDate.year, a.appointmentDate.month, a.appointmentDate.day);
      return !target.isBefore(today);
    }).toList();

    if (active.isEmpty) return null;
    active.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    return active.first;
  }

  /// Initialize and load saved appointments
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _appointments = decoded.map((e) => ServiceAppointment.fromJson(e as Map<String, dynamic>)).toList();
      }
      _isLoaded = true;
      notifyListeners();
      unawaited(_syncFromCloud());
    } catch (_) {
      _isLoaded = true;
    }
  }

  /// Synchronize with Google Cloud Firestore
  Future<void> _syncFromCloud() async {
    try {
      final cloudApts = await FirebaseSyncService.instance.fetchAppointments();
      if (cloudApts.isNotEmpty) {
        final Map<String, ServiceAppointment> map = {
          for (final a in _appointments) a.id: a,
        };
        for (final ca in cloudApts) {
          map[ca.id] = ca;
        }
        _appointments = map.values.toList();
        _appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _persist();
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Save new appointment, store offline, and add vehicle alert notification
  Future<void> setAppointment(ServiceAppointment appointment) async {
    await load();
    _appointments.removeWhere((a) => a.id == appointment.id);
    _appointments.insert(0, appointment);
    await _persist();
    unawaited(FirebaseSyncService.instance.syncAppointment(appointment));

    // Register vehicle alert event
    VehicleAlertsManager.instance.addAlert(
      VehicleAlertItem(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Service Appointment Confirmed',
        message: '${appointment.serviceType} at ${appointment.centreName} on ${appointment.formattedDate} (${appointment.timeSlot}). Reminder: ${appointment.formattedReminder}.',
        timestamp: DateTime.now(),
        type: NotificationType.success,
        icon: Icons.calendar_month_rounded,
      ),
    );

    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Cancel an appointment
  Future<void> cancelAppointment(String id) async {
    await load();
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _appointments[idx];
      _appointments[idx] = old.copyWith(isCancelled: true);
      await _persist();
      unawaited(FirebaseSyncService.instance.deleteAppointment(id));

      VehicleAlertsManager.instance.addAlert(
        VehicleAlertItem(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Service Appointment Cancelled',
          message: 'Your appointment for ${old.serviceType} at ${old.centreName} was cancelled.',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
          icon: Icons.event_busy_rounded,
        ),
      );

      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }

  /// Reschedule an appointment
  Future<void> rescheduleAppointment({
    required String id,
    required DateTime newDate,
    required String newTimeSlot,
    String? newReminder,
  }) async {
    await load();
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _appointments[idx];
      _appointments[idx] = old.copyWith(
        appointmentDate: newDate,
        timeSlot: newTimeSlot,
        reminderPreference: newReminder ?? old.reminderPreference,
        isCancelled: false,
      );
      await _persist();
      unawaited(FirebaseSyncService.instance.syncAppointment(_appointments[idx]));

      VehicleAlertsManager.instance.addAlert(
        VehicleAlertItem(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Service Appointment Rescheduled',
          message: '${old.serviceType} rescheduled to ${_appointments[idx].formattedDate} at $newTimeSlot.',
          timestamp: DateTime.now(),
          type: NotificationType.info,
          icon: Icons.event_repeat_rounded,
        ),
      );

      HapticFeedback.mediumImpact();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_appointments.map((a) => a.toJson()).toList());
      await prefs.setString(_kStorageKey, encoded);
    } catch (_) {}
  }

  /// Helper to launch external device calendar
  Future<bool> launchDeviceCalendar(ServiceAppointment appointment) async {
    final uri = Uri.parse(appointment.calendarUrl);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
