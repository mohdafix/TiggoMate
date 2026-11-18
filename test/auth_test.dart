import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService & UserProfile Unit Tests', () {
    test('Default guest initialization provides default profile', () async {
      final auth = AuthService();
      final user = await auth.initialize(defaultName: 'AFiX', defaultPlate: 'VRT 3342');

      expect(user.displayName, equals('AFiX'));
      expect(user.carPlate, equals('VRT 3342'));
      expect(user.vehicleNickname, contains('Chery Tiggo 7'));
    });

    test('Sign in with Google fails gracefully without a real Firebase/Google session', () async {
      // No Firebase App and no real Google account are available in this
      // unit test sandbox, so signInWithGoogle must report failure rather
      // than fabricate a fake authenticated user (that fake-success path
      // was the bug: it let anyone "sign in" as a fixed hard-coded
      // account without ever touching Firebase or Google).
      final auth = AuthService();
      await auth.initialize();
      final before = auth.currentUser;

      final res = await auth.signInWithGoogle();
      expect(res.success, isFalse);
      // Session must be unchanged on failure.
      expect(auth.currentUser.uid, equals(before.uid));
    });

    test('Sign Up with Email reports failure rather than a fake local account', () async {
      // Without a reachable Firebase backend, signUpWithEmail must not
      // silently create a local-only account: that uid would never match
      // what's in Firestore, and every subsequent sync would be rejected.
      final auth = AuthService();
      await auth.initialize();
      final before = auth.currentUser;

      final res = await auth.signUpWithEmail(
        email: 'afix@example.com',
        password: 'securePassword123',
        displayName: 'Afix Driver',
        carPlate: 'vrt 3342',
      );

      expect(res.success, isFalse);
      expect(auth.currentUser.uid, equals(before.uid));
    });

    test('Sign In rejects invalid email or short password', () async {
      final auth = AuthService();
      await auth.initialize();

      final res1 = await auth.signInWithEmail(email: 'notanemail', password: '123');
      expect(res1.success, isFalse);

      final res2 = await auth.signInWithEmail(email: 'valid@email.com', password: '123');
      expect(res2.success, isFalse);
    });

    test('Sign out clears user session back to default guest', () async {
      final auth = AuthService();
      await auth.initialize();
      await auth.continueAsGuest(name: 'Test Driver', plate: 'ABC 1234');
      expect(auth.currentUser.displayName, equals('Test Driver'));

      await auth.signOut();
      expect(auth.currentUser.isGuest, isTrue);
      expect(auth.currentUser.email, isEmpty);
    });
  });
}
