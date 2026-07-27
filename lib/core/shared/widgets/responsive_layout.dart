import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_drawer.dart';
import '../../../features/auth/presentation/auth_providers.dart';

class ResponsiveLayout extends ConsumerWidget {
  final String title;
  final Widget body;
  final String currentRoute;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveLayout({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    this.actions,
    this.floatingActionButton,
  });

  String _getDashboardRoute(String? role) {
    switch (role) {
      case 'admin':
      case 'principal':
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.of(context).size.width;
    final bool isLargeScreen = width >= 900;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final dashboardRoute = _getDashboardRoute(user?.role);
    final isDashboard = currentRoute == dashboardRoute;

    final List<Widget> finalActions = [
      if (actions != null) ...actions!,
      if (!isDashboard && user != null)
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            context.go(dashboardRoute);
          },
        ),
    ];

    if (isLargeScreen) {
      // Wide desktop / Tablet UI: Permanent side drawer next to content
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: AppDrawer(currentRoute: currentRoute),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  centerTitle: false,
                  actions: finalActions,
                ),
                body: body,
                floatingActionButton: floatingActionButton,
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile / Portrait UI: Appbar with Drawer slide-in
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: finalActions,
        ),
        drawer: AppDrawer(currentRoute: currentRoute),
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }
  }
}
