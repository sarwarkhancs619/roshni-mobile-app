import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Import screens (which we will create next)
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/user_management_screen.dart';
import '../../features/auth/presentation/permission_requests_screen.dart';
import '../../features/dashboard/presentation/principal_dashboard.dart';
import '../../features/dashboard/presentation/admin_dashboard.dart';
import '../../features/dashboard/presentation/staff_dashboard.dart';
import '../../features/dashboard/presentation/physio_dashboard.dart';
import '../../features/dashboard/presentation/speech_dashboard.dart';
import '../../features/dashboard/presentation/medical_dashboard.dart';
import '../../features/dashboard/presentation/house_dashboard.dart';
import '../../features/friends/presentation/friend_list_screen.dart';
import '../../features/friends/presentation/friend_details_screen.dart';
import '../../features/friends/presentation/friend_form_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/workshops/presentation/workshop_details_screen.dart';
import '../../features/iep/presentation/iep_details_screen.dart';
import '../../features/therapy/presentation/physio_details_screen.dart';
import '../../features/therapy/presentation/speech_details_screen.dart';
import '../../features/medical/presentation/medical_details_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

import '../../features/auth/presentation/auth_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final isLoggingIn = state.uri.toString() == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        // Redirect to appropriate dashboard based on user role
        final role = authState.user?.role;
        return _getDashboardRouteForRole(role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Dashboards
      GoRoute(
        path: '/dashboard/principal',
        builder: (context, state) => const PrincipalDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin/permissions',
        builder: (context, state) => const PermissionRequestsScreen(),
      ),
      GoRoute(
        path: '/dashboard/staff',
        builder: (context, state) => const StaffDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/physio',
        builder: (context, state) => const PhysioDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/speech',
        builder: (context, state) => const SpeechDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/medical',
        builder: (context, state) => const MedicalDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/house',
        builder: (context, state) => const HouseDashboardScreen(),
      ),

      // Friends Management
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendListScreen(),
      ),
      GoRoute(
        path: '/friends/add',
        builder: (context, state) => const FriendFormScreen(),
      ),
      GoRoute(
        path: '/friends/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FriendDetailsScreen(friendId: id);
        },
      ),
      GoRoute(
        path: '/friends/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FriendFormScreen(friendId: id);
        },
      ),

      // Attendance
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),

      // Workshops
      GoRoute(
        path: '/workshops/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WorkshopDetailsScreen(workshopId: id);
        },
      ),

      // IEP Module
      GoRoute(
        path: '/iep/:friendId',
        builder: (context, state) {
          final friendId = state.pathParameters['friendId']!;
          return IepDetailsScreen(friendId: friendId);
        },
      ),

      // Therapies
      GoRoute(
        path: '/therapy/physiotherapy/:friendId',
        builder: (context, state) {
          final friendId = state.pathParameters['friendId']!;
          return PhysioDetailsScreen(friendId: friendId);
        },
      ),
      GoRoute(
        path: '/therapy/speech/:friendId',
        builder: (context, state) {
          final friendId = state.pathParameters['friendId']!;
          return SpeechDetailsScreen(friendId: friendId);
        },
      ),

      // Medical
      GoRoute(
        path: '/medical/:friendId',
        builder: (context, state) {
          final friendId = state.pathParameters['friendId']!;
          return MedicalDetailsScreen(friendId: friendId);
        },
      ),

      // Reporting & Analytics
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

String _getDashboardRouteForRole(String? role) {
  switch (role) {
    case 'principal':
      return '/dashboard/principal';
    case 'admin':
      return '/dashboard/admin';
    case 'workshop_staff':
      return '/dashboard/staff';
    case 'physiotherapist':
      return '/dashboard/physio';
    case 'speech_therapist':
      return '/dashboard/speech';
    case 'medical_officer':
      return '/dashboard/medical';
    case 'house_staff':
      return '/dashboard/house';
    default:
      return '/login';
  }
}
