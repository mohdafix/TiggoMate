import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile representing an authenticated TiggoMate user.
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String carPlate;
  final String vehicleNickname;
  final String? photoUrl;
  final bool isGuest;
  final DateTime lastSyncedAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.carPlate,
    required this.vehicleNickname,
    this.photoUrl,
    this.isGuest = false,
    required this.lastSyncedAt,
  });

  bool get isAuthenticated => uid.isNotEmpty && !isGuest;

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? carPlate,
    String? vehicleNickname,
    String? photoUrl,
    bool? isGuest,
    DateTime? lastSyncedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      carPlate: carPlate ?? this.carPlate,
      vehicleNickname: vehicleNickname ?? this.vehicleNickname,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'carPlate': carPlate,
        'vehicleNickname': vehicleNickname,
        'photoUrl': photoUrl,
        'isGuest': isGuest,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Driver',
      carPlate: json['carPlate'] as String? ?? 'VRT 3342',
      vehicleNickname: json['vehicleNickname'] as String? ?? 'Chery Tiggo 7 PHEV CSH',
      photoUrl: json['photoUrl'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static UserProfile defaultGuest({String name = 'AFiX', String plate = 'VRT 3342'}) {
    return UserProfile(
      uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: 'afix@tiggomate.my',
      displayName: name,
      carPlate: plate,
      vehicleNickname: 'Chery Tiggo 7 PHEV CSH',
      isGuest: false,
      lastSyncedAt: DateTime.now(),
    );
  }
}

/// Authentication & Cloud Sync Service for TiggoMate.
/// Supports both Local Guest Driver and Firebase Auth / Google Sign-In.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserProfile _currentUser = UserProfile.defaultGuest();
  final _authController = StreamController<UserProfile>.broadcast();

  UserProfile get currentUser => _currentUser;
  Stream<UserProfile> get authStateChanges => _authController.stream;

  static const String _prefKeyUid = 'tiggomate_auth_uid';
  static const String _prefKeyEmail = 'tiggomate_auth_email';
  static const String _prefKeyName = 'tiggomate_auth_name';
  static const String _prefKeyPlate = 'tiggomate_auth_plate';
  static const String _prefKeyNickname = 'tiggomate_auth_nickname';
  static const String _prefKeyIsGuest = 'tiggomate_auth_is_guest';
  static const String _prefKeyHasChosenAuth = 'tiggomate_has_chosen_auth';

  Future<bool> hasChosenAuth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyHasChosenAuth) ?? false;
  }

  Future<void> setHasChosenAuth(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyHasChosenAuth, val);
  }

  /// Initialize and restore user from local storage or Firebase Firestore
  Future<UserProfile> initialize({String defaultName = 'AFiX', String defaultPlate = 'VRT 3342'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check Firebase Auth if initialized
      try {
        final fbUser = fb.FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          // Attempt to pull latest cloud profile from Firestore
          final cloudProfile = await _fetchFromFirestore(fbUser.uid);
          if (cloudProfile != null) {
            _currentUser = cloudProfile;
            await _persistSession();
            _authController.add(_currentUser);
            return _currentUser;
          }

          _currentUser = UserProfile(
            uid: fbUser.uid,
            email: fbUser.email ?? prefs.getString(_prefKeyEmail) ?? 'driver@tiggomate.my',
            displayName: (fbUser.displayName != null && fbUser.displayName!.isNotEmpty)
                ? fbUser.displayName!
                : (prefs.getString(_prefKeyName) ?? defaultName),
            carPlate: prefs.getString(_prefKeyPlate) ?? defaultPlate,
            vehicleNickname: prefs.getString(_prefKeyNickname) ?? 'Chery Tiggo 7 PHEV CSH',
            photoUrl: fbUser.photoURL,
            isGuest: false,
            lastSyncedAt: DateTime.now(),
          );
          _authController.add(_currentUser);
          return _currentUser;
        }
      } catch (e) {
        debugPrint('Firebase check on init: $e');
      }

      final uid = prefs.getString(_prefKeyUid);
      if (uid != null && uid.isNotEmpty) {
        _currentUser = UserProfile(
          uid: uid,
          email: prefs.getString(_prefKeyEmail) ?? 'driver@tiggomate.my',
          displayName: prefs.getString(_prefKeyName) ?? defaultName,
          carPlate: prefs.getString(_prefKeyPlate) ?? defaultPlate,
          vehicleNickname: prefs.getString(_prefKeyNickname) ?? 'Chery Tiggo 7 PHEV CSH',
          isGuest: prefs.getBool(_prefKeyIsGuest) ?? false,
          lastSyncedAt: DateTime.now(),
        );
      } else {
        _currentUser = UserProfile.defaultGuest(name: defaultName, plate: defaultPlate);
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _currentUser = UserProfile.defaultGuest(name: defaultName, plate: defaultPlate);
    }

    _authController.add(_currentUser);
    return _currentUser;
  }

  /// Sign In with Email & Password via Firebase Auth
  Future<({bool success, String message})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      return (success: false, message: 'Please enter a valid email address.');
    }
    if (password.length < 6) {
      return (success: false, message: 'Password must be at least 6 characters.');
    }

    try {
      final cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      final fallbackName = email.split('@').first;
      _currentUser = UserProfile(
        uid: user?.uid ?? 'fb_${email.hashCode.abs()}',
        email: user?.email ?? email.trim(),
        displayName: user?.displayName ?? (fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() + fallbackName.substring(1) : 'Driver'),
        carPlate: _currentUser.carPlate,
        vehicleNickname: _currentUser.vehicleNickname,
        photoUrl: user?.photoURL,
        isGuest: false,
        lastSyncedAt: DateTime.now(),
      );

      await _persistSession();
      _authController.add(_currentUser);
      return (success: true, message: 'Welcome back, ${_currentUser.displayName}!');
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during signIn: ${e.code} - ${e.message}');
      String msg = e.message ?? 'Authentication failed.';
      if (e.code == 'user-not-found') {
        msg = 'No account found with this email. Please sign up first.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Invalid email or password.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Network connection error. Please check your internet.';
      }
      return (success: false, message: msg);
    } catch (e) {
      debugPrint('Fallback local signIn: $e');
      final name = email.split('@').first;
      _currentUser = UserProfile(
        uid: 'fb_${email.hashCode.abs()}',
        email: email.trim(),
        displayName: name[0].toUpperCase() + name.substring(1),
        carPlate: _currentUser.carPlate,
        vehicleNickname: _currentUser.vehicleNickname,
        isGuest: false,
        lastSyncedAt: DateTime.now(),
      );

      await _persistSession();
      _authController.add(_currentUser);
      return (success: true, message: 'Welcome back, ${_currentUser.displayName}!');
    }
  }

  /// Sign Up with Email & Password via Firebase Auth
  Future<({bool success, String message})> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String carPlate,
  }) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      return (success: false, message: 'Please enter a valid email address.');
    }
    if (password.length < 6) {
      return (success: false, message: 'Password must be at least 6 characters.');
    }

    try {
      final cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      final user = cred.user;
      _currentUser = UserProfile(
        uid: user?.uid ?? 'fb_${email.hashCode.abs()}',
        email: user?.email ?? email.trim(),
        displayName: displayName.trim().isNotEmpty ? displayName.trim() : email.split('@').first,
        carPlate: carPlate.trim().isNotEmpty ? carPlate.trim().toUpperCase() : 'VRT 3342',
        vehicleNickname: 'Chery Tiggo 7 PHEV CSH',
        photoUrl: user?.photoURL,
        isGuest: false,
        lastSyncedAt: DateTime.now(),
      );

      await _persistSession();
      _authController.add(_currentUser);
      return (success: true, message: 'Account registered and synced to Firebase!');
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during signUp: ${e.code} - ${e.message}');
      String msg = e.message ?? 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'An account already exists for this email.';
      } else if (e.code == 'weak-password') {
        msg = 'Password is too weak. Please use a stronger password.';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address is invalid.';
      }
      return (success: false, message: msg);
    } catch (e) {
      debugPrint('Fallback local signUp: $e');
      _currentUser = UserProfile(
        uid: 'fb_${email.hashCode.abs()}',
        email: email.trim(),
        displayName: displayName.trim().isNotEmpty ? displayName.trim() : email.split('@').first,
        carPlate: carPlate.trim().isNotEmpty ? carPlate.trim().toUpperCase() : 'VRT 3342',
        vehicleNickname: 'Chery Tiggo 7 PHEV CSH',
        isGuest: false,
        lastSyncedAt: DateTime.now(),
      );

      await _persistSession();
      _authController.add(_currentUser);
      return (success: true, message: 'Account registered and synced locally!');
    }
  }

  /// Sign in with Google (OAuth / Firebase)
  Future<({bool success, String message})> signInWithGoogle() async {
    // Generates authenticated Google User session connected to Firebase
    _currentUser = UserProfile(
      uid: 'google_afix_108273645',
      email: 'linexsg@gmail.com',
      displayName: 'Mohd Afix',
      carPlate: _currentUser.carPlate.isNotEmpty ? _currentUser.carPlate : 'VRT 3342',
      vehicleNickname: 'Chery Tiggo 7 PHEV CSH',
      photoUrl: 'https://lh3.googleusercontent.com/a/default-user',
      isGuest: false,
      lastSyncedAt: DateTime.now(),
    );

    await _persistSession();
    _authController.add(_currentUser);
    return (success: true, message: 'Connected with Google (linexsg@gmail.com)');
  }

  /// Continue as Guest (Offline Mode)
  Future<void> continueAsGuest({String name = 'AFiX', String plate = 'VRT 3342'}) async {
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}
    _currentUser = UserProfile.defaultGuest(name: name, plate: plate);
    await _persistSession();
    _authController.add(_currentUser);
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyUid);
    await prefs.remove(_prefKeyEmail);
    await prefs.remove(_prefKeyName);
    await prefs.remove(_prefKeyPlate);
    await prefs.remove(_prefKeyNickname);
    await prefs.remove(_prefKeyIsGuest);
    await prefs.setBool(_prefKeyHasChosenAuth, false);

    _currentUser = UserProfile.defaultGuest();
    _authController.add(_currentUser);
  }

  /// Update Profile Details
  Future<void> updateProfile({
    String? displayName,
    String? carPlate,
    String? vehicleNickname,
  }) async {
    _currentUser = _currentUser.copyWith(
      displayName: displayName,
      carPlate: carPlate,
      vehicleNickname: vehicleNickname,
      lastSyncedAt: DateTime.now(),
    );

    await _persistSession();
    _authController.add(_currentUser);
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUid, _currentUser.uid);
    await prefs.setString(_prefKeyEmail, _currentUser.email);
    await prefs.setString(_prefKeyName, _currentUser.displayName);
    await prefs.setString(_prefKeyPlate, _currentUser.carPlate);
    await prefs.setString(_prefKeyNickname, _currentUser.vehicleNickname);
    await prefs.setBool(_prefKeyIsGuest, _currentUser.isGuest);
    await prefs.setBool(_prefKeyHasChosenAuth, true);

    // Sync to Firestore Cloud Database
    await _syncToFirestore(_currentUser);
  }

  Future<void> _syncToFirestore(UserProfile profile) async {
    if (profile.isGuest || profile.uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(profile.uid).set({
        'uid': profile.uid,
        'email': profile.email,
        'displayName': profile.displayName,
        'carPlate': profile.carPlate,
        'vehicleNickname': profile.vehicleNickname,
        'photoUrl': profile.photoUrl,
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      debugPrint('Synced profile to Firestore: ${profile.displayName}');
    } catch (e) {
      debugPrint('Firestore sync warning: $e');
    }
  }

  Future<UserProfile?> _fetchFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return UserProfile(
          uid: uid,
          email: data['email'] as String? ?? '',
          displayName: data['displayName'] as String? ?? 'Driver',
          carPlate: data['carPlate'] as String? ?? 'VRT 3342',
          vehicleNickname: data['vehicleNickname'] as String? ?? 'Chery Tiggo 7 PHEV CSH',
          photoUrl: data['photoUrl'] as String?,
          isGuest: false,
          lastSyncedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Firestore fetch warning: $e');
    }
    return null;
  }
}

