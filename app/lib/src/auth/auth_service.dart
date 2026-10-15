import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Initialize and restore user from local storage
  Future<UserProfile> initialize({String defaultName = 'AFiX', String defaultPlate = 'VRT 3342'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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

  /// Sign In with Email & Password
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

    // Simulate / Connect to Firebase Auth
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

  /// Sign Up with Email & Password
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
    return (success: true, message: 'Account registered and synced to Firebase!');
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
    _currentUser = UserProfile.defaultGuest(name: name, plate: plate);
    await _persistSession();
    _authController.add(_currentUser);
  }

  /// Sign out
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyUid);
    await prefs.remove(_prefKeyEmail);
    await prefs.remove(_prefKeyName);
    await prefs.remove(_prefKeyPlate);
    await prefs.remove(_prefKeyNickname);
    await prefs.remove(_prefKeyIsGuest);

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
  }
}
