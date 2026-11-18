import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  static UserProfile defaultGuest({String name = 'Driver', String plate = 'VRT 3342'}) {
    return UserProfile(
      uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      displayName: name,
      carPlate: plate,
      vehicleNickname: 'Chery Tiggo 7 PHEV CSH',
      isGuest: true,
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
  Future<UserProfile> initialize({String defaultName = 'Driver', String defaultPlate = 'VRT 3342'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check Firebase Auth if initialized, or auto-sign in anonymously
      try {
        var fbUser = fb.FirebaseAuth.instance.currentUser;
        if (fbUser == null) {
          try {
            final cred = await fb.FirebaseAuth.instance.signInAnonymously();
            fbUser = cred.user;
            debugPrint('[AuthService] Signed in anonymously with Firebase: ${fbUser?.uid}');
          } catch (anonErr) {
            debugPrint('[AuthService] Anonymous auth note: $anonErr');
          }
        }
        if (fbUser != null) {
          // Attempt to pull latest cloud profile from Firestore
          final cloudProfile = await _fetchFromFirestore(fbUser.uid);
          if (cloudProfile != null) {
            _currentUser = cloudProfile;
            await _persistSession();
            _authController.add(_currentUser);
            return _currentUser;
          }

          // An anonymous Firebase user with no cloud profile yet is still
          // a "guest" from the app's point of view (they haven't linked a
          // real email/Google account), even though Firebase gave them a uid.
          _currentUser = UserProfile(
            uid: fbUser.uid,
            email: fbUser.email ?? prefs.getString(_prefKeyEmail) ?? '',
            displayName: (fbUser.displayName != null && fbUser.displayName!.isNotEmpty)
                ? fbUser.displayName!
                : (prefs.getString(_prefKeyName) ?? defaultName),
            carPlate: prefs.getString(_prefKeyPlate) ?? defaultPlate,
            vehicleNickname: prefs.getString(_prefKeyNickname) ?? 'Chery Tiggo 7 PHEV CSH',
            photoUrl: fbUser.photoURL,
            isGuest: fbUser.isAnonymous,
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
          email: prefs.getString(_prefKeyEmail) ?? '',
          displayName: prefs.getString(_prefKeyName) ?? defaultName,
          carPlate: prefs.getString(_prefKeyPlate) ?? defaultPlate,
          vehicleNickname: prefs.getString(_prefKeyNickname) ?? 'Chery Tiggo 7 PHEV CSH',
          isGuest: prefs.getBool(_prefKeyIsGuest) ?? true,
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
      // Do NOT fabricate a local-only session here: without a real
      // Firebase user, the uid won't match what's in Firestore and every
      // subsequent sync will be silently rejected by the security rules.
      debugPrint('[AuthService] signIn failed (no Firebase user): $e');
      return (success: false, message: 'Sign in failed. Please check your connection and try again.');
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
      // Do NOT fabricate a local-only account here: without a real
      // Firebase user, Firestore writes for this uid will be rejected by
      // the security rules and the user will believe they registered
      // when nothing was actually saved to the cloud.
      debugPrint('[AuthService] signUp failed (no Firebase user created): $e');
      return (success: false, message: 'Registration failed. Please check your connection and try again.');
    }
  }

  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }

  /// Sign in with Google (OAuth) and exchange the ID token for a real
  /// Firebase Auth session. If the current session is an anonymous
  /// Firebase user, the Google credential is linked to it so existing
  /// trips/appointments/settings are kept instead of starting a new uid.
  Future<({bool success, String message})> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return (success: false, message: 'Google Sign-In is not supported on this platform.');
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        return (
          success: false,
          message: 'Google Sign-In did not return an ID token. Check that Google sign-in is enabled for this app in the Firebase console.'
        );
      }

      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final existingUser = fb.FirebaseAuth.instance.currentUser;

      fb.UserCredential userCred;
      if (existingUser != null && existingUser.isAnonymous) {
        try {
          userCred = await existingUser.linkWithCredential(credential);
        } on fb.FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
            // This Google account is already tied to a different Firebase
            // user; sign into that one instead of the anonymous session.
            userCred = await fb.FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        userCred = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user == null) {
        return (success: false, message: 'Google Sign-In failed: no user returned.');
      }

      final cloudProfile = await _fetchFromFirestore(user.uid);
      _currentUser = cloudProfile ??
          UserProfile(
            uid: user.uid,
            email: user.email ?? googleUser.email,
            displayName: user.displayName ?? googleUser.displayName ?? 'Driver',
            carPlate: _currentUser.carPlate.isNotEmpty ? _currentUser.carPlate : 'VRT 3342',
            vehicleNickname: _currentUser.vehicleNickname,
            photoUrl: user.photoURL ?? googleUser.photoUrl,
            isGuest: false,
            lastSyncedAt: DateTime.now(),
          );

      await _persistSession();
      _authController.add(_currentUser);
      return (success: true, message: 'Connected with Google (${_currentUser.email})');
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException during Google sign-in: ${e.code} - ${e.message}');
      return (success: false, message: e.message ?? 'Google Sign-In failed.');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return (success: false, message: 'Google Sign-In cancelled.');
      }
      debugPrint('[AuthService] GoogleSignInException: ${e.code} - ${e.description}');
      return (success: false, message: 'Google Sign-In failed: ${e.description ?? e.code}');
    } catch (e) {
      debugPrint('[AuthService] Google sign-in error: $e');
      return (success: false, message: 'Google Sign-In failed: $e');
    }
  }

  Future<void> _signOutGoogleIfSignedIn() async {
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  /// Continue as Guest (Offline Mode). Keeps an anonymous Firebase session
  /// going (rather than fully signing out) so trips/appointments entered as
  /// a guest still back up to Firestore and aren't lost if the user later
  /// upgrades to a real account via linkWithCredential.
  Future<void> continueAsGuest({String name = 'Driver', String plate = 'VRT 3342'}) async {
    await _signOutGoogleIfSignedIn();
    try {
      if (fb.FirebaseAuth.instance.currentUser == null) {
        await fb.FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('[AuthService] Anonymous sign-in on guest mode note: $e');
    }
    _currentUser = UserProfile.defaultGuest(name: name, plate: plate);
    await _persistSession();
    _authController.add(_currentUser);
  }

  /// Sign out of the current Google/email account and drop back to a
  /// fresh anonymous guest session (local profile is cleared, but a new
  /// anonymous Firebase user is established immediately so background
  /// sync keeps working instead of going dark until the next app launch).
  Future<void> signOut() async {
    await _signOutGoogleIfSignedIn();
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
    try {
      await fb.FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('[AuthService] Anonymous sign-in after signOut note: $e');
    }
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

