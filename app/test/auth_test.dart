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

    test('Sign in with Google establishes authenticated session', () async {
      final auth = AuthService();
      await auth.initialize();

      final res = await auth.signInWithGoogle();
      expect(res.success, isTrue);
      expect(auth.currentUser.email, equals('linexsg@gmail.com'));
      expect(auth.currentUser.displayName, equals('Mohd Afix'));
      expect(auth.currentUser.isAuthenticated, isTrue);
    });

    test('Sign Up with Email creates user account', () async {
      final auth = AuthService();
      await auth.initialize();

      final res = await auth.signUpWithEmail(
        email: 'afix@example.com',
        password: 'securePassword123',
        displayName: 'Afix Driver',
        carPlate: 'vrt 3342',
      );

      expect(res.success, isTrue);
      expect(auth.currentUser.email, equals('afix@example.com'));
      expect(auth.currentUser.displayName, equals('Afix Driver'));
      expect(auth.currentUser.carPlate, equals('VRT 3342'));
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
      await auth.signInWithGoogle();
      expect(auth.currentUser.isAuthenticated, isTrue);

      await auth.signOut();
      expect(auth.currentUser.email, equals('afix@tiggomate.my'));
    });
  });
}
