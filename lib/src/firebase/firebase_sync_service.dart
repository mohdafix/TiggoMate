import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../carlinko/vehicle_telemetry.dart';
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

  /// Vehicle Scope ID for Firestore backup & cross-reinstall recovery (e.g. 'VRT3342')
  String get vehicleScopeId {
    final plate = AuthService().currentUser.carPlate.replaceAll(' ', '').toUpperCase();
    return plate.isNotEmpty ? plate : 'VRT3342';
  }

  /// Active User ID for Firestore collection scoping
  String? get currentUserId {
    try {
      final fbUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (fbUid != null && fbUid.isNotEmpty) return fbUid;
    } catch (_) {}

    final authProfile = AuthService().currentUser;
    if (authProfile.uid.isNotEmpty) {
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

  DocumentReference<Map<String, dynamic>>? _vehicleDoc(String vScope) {
    if (!isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance.collection('vehicles').doc(vScope);
    } catch (_) {
      return null;
    }
  }

  final Set<String> _claimedVehicleScopes = {};

  /// Claims (or re-confirms) ownership of a `vehicles/{plate}` document for
  /// the current uid. Vehicle documents are keyed by plate number, which
  /// is visible on the car itself, so the Firestore security rules require
  /// an `ownerUid` field matching the writer before any subcollection
  /// write/read under that vehicle is allowed. Calling this before every
  /// write is cheap once cached in-memory per app session, and `set` with
  /// `merge: true` acts as "create if absent, else no-op on a field the
  /// rules already verified matches" so it's safe to call repeatedly.
  Future<bool> _claimVehicleOwnership(String vScope) async {
    if (_claimedVehicleScopes.contains(vScope)) return true;
    final uid = currentUserId;
    if (uid == null) return false;
    final vRef = _vehicleDoc(vScope);
    if (vRef == null) return false;
    try {
      await vRef.set({'ownerUid': uid, 'plate': vScope}, SetOptions(merge: true));
      _claimedVehicleScopes.add(vScope);
      return true;
    } catch (e) {
      debugPrint('[FirebaseSync] Vehicle ownership claim note ($vScope): $e');
      return false;
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

      // `set` with merge instead of `update`: an appointment created while
      // offline (never previously synced) has no Firestore doc yet, and
      // `update` throws `not-found` in that case instead of just marking
      // it cancelled.
      await userRef.collection('appointments').doc(appointmentId).set({
        'isCancelled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    if (!isFirebaseAvailable) return;
    final vScope = vehicleScopeId;
    final uid = currentUserId;

    final tripMap = trip.toJson();
    tripMap['updatedAt'] = FieldValue.serverTimestamp();
    tripMap['vehicleId'] = vScope;

    try {
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        await vRef.collection('trips').doc(trip.id).set(
              tripMap,
              SetOptions(merge: true),
            );
        debugPrint('[FirebaseSync] Trip backed up to vehicle cloud ($vScope): ${trip.title} (${trip.distanceKm} km)');
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Vehicle trip sync note: $e');
    }

    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          await userRef.collection('trips').doc(trip.id).set(
                tripMap,
                SetOptions(merge: true),
              );
        }
      } catch (e) {
        debugPrint('[FirebaseSync] User trip sync note: $e');
      }
    }
  }

  /// Fetch all cloud trips (restores from both vehicle cloud and user profile)
  Future<List<TripRecord>> fetchTrips() async {
    if (!isFirebaseAvailable) return [];
    final vScope = vehicleScopeId;
    final Map<String, TripRecord> results = {};

    try {
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        final query = await vRef.collection('trips').orderBy('timestamp', descending: true).limit(500).get();
        for (final doc in query.docs) {
          try {
            results[doc.id] = TripRecord.fromJson(doc.data());
          } catch (e) {
            debugPrint('[FirebaseSync] Failed to parse vehicle trip ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch vehicle trips note: $e');
    }

    final uid = currentUserId;
    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          final query = await userRef.collection('trips').orderBy('timestamp', descending: true).limit(500).get();
          for (final doc in query.docs) {
            try {
              results[doc.id] = TripRecord.fromJson(doc.data());
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[FirebaseSync] Fetch user trips note: $e');
      }
    }

    debugPrint('[FirebaseSync] Total restored trips from cloud: ${results.length}');
    return results.values.toList();
  }

  // =========================================================================
  // 3. ENERGY & EXPENSE RECORDS SYNCHRONIZATION
  // =========================================================================

  /// Push logged expense (Petrol / TNB Home AC / Public DC) to Firestore
  Future<void> syncExpense(ExpenseRecord expense) async {
    if (!isFirebaseAvailable) return;
    final vScope = vehicleScopeId;
    final uid = currentUserId;

    final expMap = expense.toJson();
    expMap['updatedAt'] = FieldValue.serverTimestamp();
    expMap['vehicleId'] = vScope;

    try {
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        await vRef.collection('expenses').doc(expense.id).set(
              expMap,
              SetOptions(merge: true),
            );
        debugPrint('[FirebaseSync] Expense backed up to vehicle cloud ($vScope): ${expense.title} (RM ${expense.amountRm})');
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Vehicle expense sync note: $e');
    }

    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          await userRef.collection('expenses').doc(expense.id).set(
                expMap,
                SetOptions(merge: true),
              );
        }
      } catch (e) {
        debugPrint('[FirebaseSync] User expense sync note: $e');
      }
    }
  }

  /// Fetch all logged cloud expenses (restores from both vehicle cloud and user profile)
  Future<List<ExpenseRecord>> fetchExpenses() async {
    if (!isFirebaseAvailable) return [];
    final vScope = vehicleScopeId;
    final Map<String, ExpenseRecord> results = {};

    try {
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        final query = await vRef.collection('expenses').limit(1000).get();
        for (final doc in query.docs) {
          try {
            results[doc.id] = ExpenseRecord.fromJson(doc.data());
          } catch (e) {
            debugPrint('[FirebaseSync] Failed to parse vehicle expense doc ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch vehicle expenses note: $e');
    }

    final uid = currentUserId;
    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          final query = await userRef.collection('expenses').limit(1000).get();
          for (final doc in query.docs) {
            try {
              results[doc.id] = ExpenseRecord.fromJson(doc.data());
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[FirebaseSync] Fetch user expenses note: $e');
      }
    }

    return results.values.toList();
  }

  // =========================================================================
  // 4. VEHICLE SETTINGS & PREFERENCES SYNCHRONIZATION
  // =========================================================================

  /// Sync user vehicle settings to Firestore
  Future<void> syncSettings(AppSettings settings) async {
    if (!isFirebaseAvailable) return;
    final vScope = vehicleScopeId;
    final uid = currentUserId;

    final settingsMap = {
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
    };

    try {
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        await vRef.collection('settings').doc('vehicle').set(settingsMap, SetOptions(merge: true));
        debugPrint('[FirebaseSync] Settings backed up to vehicle cloud ($vScope)');
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Vehicle settings sync note: $e');
    }

    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          await userRef.collection('settings').doc('vehicle').set(settingsMap, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[FirebaseSync] User settings sync note: $e');
      }
    }
  }

  /// Fetch vehicle settings from Firestore
  Future<AppSettings?> fetchSettings() async {
    if (!isFirebaseAvailable) return null;
    final vScope = vehicleScopeId;

    try {
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        final doc = await vRef.collection('settings').doc('vehicle').get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          return AppSettings(
            ownerName: d['ownerName'] as String? ?? 'Chery Owner',
            carPlateNumber: d['carPlateNumber'] as String? ?? 'VRT 3342',
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
      }
    } catch (_) {}

    final uid = currentUserId;
    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          final doc = await userRef.collection('settings').doc('vehicle').get();
          if (doc.exists && doc.data() != null) {
            final d = doc.data()!;
            return AppSettings(
              ownerName: d['ownerName'] as String? ?? 'Chery Owner',
              carPlateNumber: d['carPlateNumber'] as String? ?? 'VRT 3342',
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
        }
      } catch (_) {}
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

      final query = await userRef.collection('alerts').limit(200).get();
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

  // =========================================================================
  // 6. LAST KNOWN VEHICLE TELEMETRY SNAPSHOT SYNCHRONIZATION
  // =========================================================================

  /// Push the most recent real (non-simulated) telemetry reading to
  /// Firestore, so the last known car state is backed up / visible from
  /// another device even when this device has no live CarLinko session.
  Future<void> syncTelemetrySnapshot(VehicleTelemetry telemetry) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (telemetry.isSimulated || !telemetry.isBound) return;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return;

      final snapshotMap = telemetry.toJson();
      snapshotMap['syncedAt'] = FieldValue.serverTimestamp();

      await userRef.collection('telemetry').doc('last').set(
            snapshotMap,
            SetOptions(merge: true),
          );
      debugPrint('[FirebaseSync] Telemetry snapshot synced (odometer: ${telemetry.odometerKm} km)');
    } catch (e) {
      debugPrint('[FirebaseSync] Telemetry snapshot sync error: $e');
    }
  }

  /// Fetch the last known telemetry snapshot from Firestore, if any.
  Future<VehicleTelemetry?> fetchLastTelemetrySnapshot() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final userRef = _userDoc(uid);
      if (userRef == null) return null;

      final doc = await userRef.collection('telemetry').doc('last').get();
      if (doc.exists && doc.data() != null) {
        return VehicleTelemetry.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Fetch telemetry snapshot error: $e');
    }
    return null;
  }

  /// Sync dated electricity tariff & fuel price book (vehicles + users dual-write).
  Future<void> syncPriceBook(Map<String, dynamic> priceBookPayload) async {
    if (!isFirebaseAvailable) return;
    final payload = {
      ...priceBookPayload,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      final vScope = vehicleScopeId;
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        await vRef.collection('settings').doc('priceBook').set(payload, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[FirebaseSync] Vehicle priceBook sync note: $e');
    }
    final uid = currentUserId;
    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          await userRef.collection('settings').doc('priceBook').set(payload, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[FirebaseSync] User priceBook sync note: $e');
      }
    }
  }

  /// Fetch dated electricity tariff & fuel price book from Firestore.
  Future<Map<String, dynamic>?> fetchPriceBook() async {
    if (!isFirebaseAvailable) return null;
    try {
      final vScope = vehicleScopeId;
      final vRef = await _claimVehicleOwnership(vScope) ? _vehicleDoc(vScope) : null;
      if (vRef != null) {
        final doc = await vRef.collection('settings').doc('priceBook').get();
        if (doc.exists && doc.data() != null) {
          return doc.data();
        }
      }
    } catch (_) {}
    final uid = currentUserId;
    if (uid != null) {
      try {
        final userRef = _userDoc(uid);
        if (userRef != null) {
          final doc = await userRef.collection('settings').doc('priceBook').get();
          if (doc.exists && doc.data() != null) {
            return doc.data();
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
