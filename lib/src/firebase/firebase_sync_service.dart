import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../service/service_appointment_manager.dart';
import '../ui/app_notification.dart';
import '../ui/settings_screen.dart';
import '../ui/trips_logbook_screen.dart';

/// Comprehensive Cloud Synchronization Service for TiggoMate.
/// Handles bi-directional synchronization between local offline storage
/// (SharedPreferences) and Google Cloud Firestore.
class FirebaseSyncService {
  static final FirebaseSyncService instance = FirebaseSyncService._internal();
  FirebaseSyncService._internal();

  /// Check whether Firebase is initialized and active
  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Active User ID for Firestore collection scoping
  String? get currentUserId {
    try {
      final fbUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (fbUid != null && fbUid.isNotEmpty) return fbUid;
    } catch (_) {}

    final authProfile = AuthService().currentUser;
    if (authProfile.isAuthenticated && !authProfile.isGuest) {
      return authProfile.uid;
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>>? _userDoc(String uid) {
    if (!isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance.collection('users').doc(uid);
    } catch (_) {
      return null;
    }
  }

  // =========================================================================
  // 1. SERVICE APPOINTMENT SYNCHRONIZATION
  // =========================================================================

  /// Push a created or updated ServiceAppointment to Firestore
  Future<void> syncAppointment(ServiceAppointment appointment) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      final aptMap = appointment.toJson();
      aptMap['updatedAt'] = FieldValue.serverTimestamp();

      await userRef.collection('appointments').doc(appointment.id).set(
            aptMap,
            SetOptions(merge: true),
          );
      debugPrint('[FirebaseSync] Appointment synced: ${appointment.serviceType} (${appointment.id})');
    } catch (e) {
      debugPrint('[FirebaseSync] Appointment sync error (offline fallback active): $e');
    }
  }

  /// Delete or mark appointment cancelled in Firestore
  Future<void> deleteAppointment(String appointmentId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      await userRef.collection('appointments').doc(appointmentId).update({
        'isCancelled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FirebaseSync] Appointment marked cancelled: $appointmentId');
    } catch (e) {
      debugPrint('[FirebaseSync] Appointment delete error: $e');
    }
  }

  /// Pull all cloud appointments for the current user
  Future<List<ServiceAppointment>> fetchAppointments() async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return [];

      final query = await userRef.collection('appointments').get();
      final List<ServiceAppointment> results = [];
      for (final doc in query.docs) {
        try {
          results.add(ServiceAppointment.fromJson(doc.data()));
        } catch (e) {
          debugPrint('[FirebaseSync] Failed to parse appointment doc ${doc.id}: $e');
        }
      }
      return results;
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch appointments error: $e');
      return [];
    }
  }

  // =========================================================================
  // 2. TRIP LOGBOOK & DRIVING TELEMETRY SYNCHRONIZATION
  // =========================================================================

  /// Push a recorded TripRecord to Firestore
  Future<void> syncTrip(TripRecord trip) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      final tripMap = trip.toJson();
      tripMap['updatedAt'] = FieldValue.serverTimestamp();

      await userRef.collection('trips').doc(trip.id).set(
            tripMap,
            SetOptions(merge: true),
          );
      debugPrint('[FirebaseSync] Trip synced: ${trip.title} (${trip.distanceKm} km)');
    } catch (e) {
      debugPrint('[FirebaseSync] Trip sync error: $e');
    }
  }

  /// Fetch all cloud trips
  Future<List<TripRecord>> fetchTrips() async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return [];

      final query = await userRef.collection('trips').get();
      final List<TripRecord> results = [];
      for (final doc in query.docs) {
        try {
          results.add(TripRecord.fromJson(doc.data()));
        } catch (e) {
          debugPrint('[FirebaseSync] Failed to parse trip doc ${doc.id}: $e');
        }
      }
      return results;
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch trips error: $e');
      return [];
    }
  }

  // =========================================================================
  // 3. ENERGY & EXPENSE RECORDS SYNCHRONIZATION
  // =========================================================================

  /// Push logged expense (Petrol / TNB Home AC / Public DC) to Firestore
  Future<void> syncExpense(ExpenseRecord expense) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      final expMap = expense.toJson();
      expMap['updatedAt'] = FieldValue.serverTimestamp();

      await userRef.collection('expenses').doc(expense.id).set(
            expMap,
            SetOptions(merge: true),
          );
      debugPrint('[FirebaseSync] Expense synced: ${expense.title} (RM ${expense.amountRm})');
    } catch (e) {
      debugPrint('[FirebaseSync] Expense sync error: $e');
    }
  }

  /// Fetch all logged cloud expenses
  Future<List<ExpenseRecord>> fetchExpenses() async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return [];

      final query = await userRef.collection('expenses').get();
      final List<ExpenseRecord> results = [];
      for (final doc in query.docs) {
        try {
          results.add(ExpenseRecord.fromJson(doc.data()));
        } catch (e) {
          debugPrint('[FirebaseSync] Failed to parse expense doc ${doc.id}: $e');
        }
      }
      return results;
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch expenses error: $e');
      return [];
    }
  }

  // =========================================================================
  // 4. VEHICLE SETTINGS & PREFERENCES SYNCHRONIZATION
  // =========================================================================

  /// Sync user vehicle settings to Firestore
  Future<void> syncSettings(AppSettings settings) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      await userRef.collection('settings').doc('vehicle').set({
        'ownerName': settings.ownerName,
        'carPlateNumber': settings.carPlateNumber,
        'vehicleNickname': settings.vehicleNickname,
        'vehicleSkinKey': settings.vehicleSkinKey,
        'tnbTariff': settings.tnbTariff,
        'fuelPrice': settings.fuelPrice,
        'carLinkoStatus': settings.carLinkoStatus,
        'aiModel': settings.aiModel,
        'aiProvider': settings.aiProvider,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FirebaseSync] Vehicle settings synced for ${settings.carPlateNumber}');
    } catch (e) {
      debugPrint('[FirebaseSync] Settings sync error: $e');
    }
  }

  /// Fetch vehicle settings from Firestore
  Future<AppSettings?> fetchSettings() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return null;

      final doc = await userRef.collection('settings').doc('vehicle').get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return AppSettings(
          ownerName: d['ownerName'] as String? ?? 'Chery Owner',
          carPlateNumber: d['carPlateNumber'] as String? ?? 'VAG 7777',
          vehicleNickname: d['vehicleNickname'] as String? ?? 'Chery Tiggo 7 PHEV CSH',
          aiApiKey: '',
          aiModel: d['aiModel'] as String? ?? 'gpt-4o-mini',
          aiHost: 'http://10.0.2.2:8088',
          aiProvider: d['aiProvider'] as String? ?? 'OpenRouter',
          carLinkoStatus: d['carLinkoStatus'] as String? ?? 'Unactivated',
          tnbTariff: (d['tnbTariff'] as num?)?.toDouble() ?? 0.57,
          fuelPrice: (d['fuelPrice'] as num?)?.toDouble() ?? 2.05,
          vehicleSkinKey: d['vehicleSkinKey'] as String? ?? 'khaki_white',
        );
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch settings error: $e');
    }
    return null;
  }

  // =========================================================================
  // 5. VEHICLE ALERTS & NOTIFICATIONS SYNCHRONIZATION
  // =========================================================================

  /// Sync a telematics alert to Firestore
  Future<void> syncAlert(VehicleAlertItem alert) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      final alertMap = alert.toJson();
      alertMap['updatedAt'] = FieldValue.serverTimestamp();

      await userRef.collection('alerts').doc(alert.id).set(
            alertMap,
            SetOptions(merge: true),
          );
      debugPrint('[FirebaseSync] Alert synced: ${alert.title}');
    } catch (e) {
      debugPrint('[FirebaseSync] Alert sync error: $e');
    }
  }

  /// Fetch cloud telematics alerts
  Future<List<VehicleAlertItem>> fetchAlerts() async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return [];

      final query = await userRef.collection('alerts').get();
      final List<VehicleAlertItem> results = [];
      for (final doc in query.docs) {
        try {
          results.add(VehicleAlertItem.fromJson(doc.data()));
        } catch (e) {
          debugPrint('[FirebaseSync] Failed to parse alert doc ${doc.id}: $e');
        }
      }
      return results;
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch alerts error: $e');
      return [];
    }
  }
}
