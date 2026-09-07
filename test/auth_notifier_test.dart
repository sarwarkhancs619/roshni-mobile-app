import 'package:flutter_test/flutter_test.dart';
import 'package:roshni_rams/features/auth/presentation/auth_providers.dart';

void main() {
  group('AuthNotifier Unit Tests', () {
    late AuthNotifier authNotifier;

    setUp(() {
      authNotifier = AuthNotifier();
    });

    test('Initial AuthState is empty and not loading', () {
      final initialState = authNotifier.state;
      expect(initialState.user, isNull);
      expect(initialState.isLoading, isFalse);
      expect(initialState.errorMessage, isNull);
    });

    test('Successful login with admin credentials updates role and loading status', () async {
      final success = await authNotifier.login('sarwarkhancs619@gmail.com', 'password123');
      
      expect(success, isTrue);
      expect(authNotifier.state.user, isNotNull);
      expect(authNotifier.state.user?.role, 'admin');
      expect(authNotifier.state.user?.fullName, 'Sarwar Khan (Admin)');
      expect(authNotifier.state.errorMessage, isNull);
    });

    test('Unregistered demo email fails without mock credentials', () async {
      final success = await authNotifier.login('bakery@roshni.org', 'password123');
      
      expect(success, isFalse);
      expect(authNotifier.state.user, isNull);
      expect(authNotifier.state.errorMessage, isNotNull);
    });

    test('Unsuccessful login updates AuthState with correct warning message', () async {
      final success = await authNotifier.login('wrong@roshni.org', 'wrongpass');
      
      expect(success, isFalse);
      expect(authNotifier.state.user, isNull);
      expect(authNotifier.state.errorMessage, contains('Invalid email or password'));
    });

    test('Logout clears user session and resets state', () async {
      // Login first
      await authNotifier.login('admin@roshni.org', 'password123');
      expect(authNotifier.state.user, isNotNull);

      // Perform logout
      authNotifier.logout();
      expect(authNotifier.state.user, isNull);
      expect(authNotifier.state.errorMessage, isNull);
    });
  });
}
