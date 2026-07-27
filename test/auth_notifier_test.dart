import 'package:flutter_test/flutter_test.dart';
import 'package:roshni_rams/features/auth/presentation/auth_providers.dart';

void main() {
  group('AuthNotifier Unit Tests', () {
    late AuthNotifier authNotifier;

    setUp(() {
      authNotifier = AuthNotifier();
    });

    test('Initial AuthState is empty and not loading', () {
      final initialState = authNotifier.debugState; // Access the current state of StateNotifier
      expect(initialState.user, isNull);
      expect(initialState.isLoading, isFalse);
      expect(initialState.errorMessage, isNull);
    });

    test('Successful login with admin credentials updates role and loading status', () async {
      final success = await authNotifier.login('admin@roshni.org', 'password123');
      
      expect(success, isTrue);
      expect(authNotifier.debugState.user, isNotNull);
      expect(authNotifier.debugState.user?.role, 'admin');
      expect(authNotifier.debugState.user?.fullName, 'Zahid Khan (Admin)');
      expect(authNotifier.debugState.errorMessage, isNull);
    });

    test('Successful login with staff credentials updates role and workshopId', () async {
      final success = await authNotifier.login('bakery@roshni.org', 'password123');
      
      expect(success, isTrue);
      expect(authNotifier.debugState.user, isNotNull);
      expect(authNotifier.debugState.user?.role, 'workshop_staff');
      expect(authNotifier.debugState.user?.workshopId, 'bakery');
      expect(authNotifier.debugState.errorMessage, isNull);
    });

    test('Unsuccessful login updates AuthState with correct warning message', () async {
      final success = await authNotifier.login('wrong@roshni.org', 'wrongpass');
      
      expect(success, isFalse);
      expect(authNotifier.debugState.user, isNull);
      expect(authNotifier.debugState.errorMessage, contains('Invalid username or password'));
    });

    test('Logout clears user session and resets state', () async {
      // Login first
      await authNotifier.login('admin@roshni.org', 'password123');
      expect(authNotifier.debugState.user, isNotNull);

      // Perform logout
      authNotifier.logout();
      expect(authNotifier.debugState.user, isNull);
      expect(authNotifier.debugState.errorMessage, isNull);
    });
  });
}

// Helper extension to access state in tests without widget refs
extension on AuthNotifier {
  AuthState get debugState => state;
}
