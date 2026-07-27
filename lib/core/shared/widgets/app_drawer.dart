import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../localization/localization.dart';
import '../../theme/theme.dart';
import '../../../features/auth/presentation/auth_providers.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;
  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final isUrdu = locale.languageCode == 'ur';

    return Drawer(
      child: Column(
        children: [
          // Elegant Drawer Header with Profile
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.fullName.characters.first.toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            accountName: Text(
              user?.fullName ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          
          // Drawer navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.dashboard,
                  title: localizations.translate('dashboard'),
                  route: _getDashboardRoute(user?.role),
                  currentRoute: currentRoute,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.people,
                  title: localizations.translate('friends'),
                  route: '/friends',
                  currentRoute: currentRoute,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.calendar_today,
                  title: localizations.translate('attendance'),
                  route: '/attendance',
                  currentRoute: currentRoute,
                ),
                
                // Workshops dropdown header (visible to admin, principal, or workshop staff)
                if (user?.role == 'admin' || user?.role == 'principal' || user?.role == 'workshop_staff') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      localizations.translate('workshops'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (user?.role == 'admin' || user?.role == 'principal' || (user?.role == 'workshop_staff' && user?.workshopId == 'bakery'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.bakery_dining,
                      title: localizations.translate('bakery'),
                      route: '/workshops/bakery',
                      currentRoute: currentRoute,
                    ),
                  if (user?.role == 'admin' || user?.role == 'principal' || (user?.role == 'workshop_staff' && user?.workshopId == 'woodwork'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.handyman,
                      title: localizations.translate('woodwork'),
                      route: '/workshops/woodwork',
                      currentRoute: currentRoute,
                    ),
                  if (user?.role == 'admin' || user?.role == 'principal' || (user?.role == 'workshop_staff' && user?.workshopId == 'farming'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.forest,
                      title: localizations.translate('farming'),
                      route: '/workshops/farming',
                      currentRoute: currentRoute,
                    ),
                  if (user?.role == 'admin' || user?.role == 'principal' || (user?.role == 'workshop_staff' && user?.workshopId == 'textile'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.checkroom,
                      title: localizations.translate('textile'),
                      route: '/workshops/textile',
                      currentRoute: currentRoute,
                    ),
                  if (user?.role == 'admin' || user?.role == 'principal' || (user?.role == 'workshop_staff' && user?.workshopId == 'artwork'))
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.palette,
                      title: localizations.translate('artwork'),
                      route: '/workshops/artwork',
                      currentRoute: currentRoute,
                    ),
                ],

                // Residential Houses (visible to admin, principal, or house_staff)
                if (user?.role == 'admin' || user?.role == 'principal' || user?.role == 'house_staff') ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Residential Houses',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home,
                    title: localizations.translate('house_dashboard'),
                    route: '/dashboard/house',
                    currentRoute: currentRoute,
                  ),
                ],

                const Divider(),
                // Therapies & Medical (visible to admin or specific roles)
                if (user?.role == 'admin' || user?.role == 'principal' || user?.role == 'physiotherapist')
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.accessibility_new,
                    title: localizations.translate('physiotherapy'),
                    route: '/therapy/physiotherapy/all',
                    currentRoute: currentRoute,
                    onTapOverride: () {
                      // Navigate to first friend or custom list
                      context.push('/friends');
                    }
                  ),
                if (user?.role == 'admin' || user?.role == 'principal' || user?.role == 'speech_therapist')
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.record_voice_over,
                    title: localizations.translate('speech_therapy'),
                    route: '/therapy/speech/all',
                    currentRoute: currentRoute,
                    onTapOverride: () {
                      context.push('/friends');
                    }
                  ),
                if (user?.role == 'admin' || user?.role == 'principal' || user?.role == 'medical_officer')
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.medical_services,
                    title: localizations.translate('medical'),
                    route: '/medical/all',
                    currentRoute: currentRoute,
                    onTapOverride: () {
                      context.push('/friends');
                    }
                  ),

                const Divider(),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.analytics,
                  title: localizations.translate('analytics'),
                  route: '/analytics',
                  currentRoute: currentRoute,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.description,
                  title: localizations.translate('reports'),
                  route: '/reports',
                  currentRoute: currentRoute,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings,
                  title: localizations.translate('settings'),
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
              ],
            ),
          ),
          
          // Drawer Footer controls (Language & Logout)
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Language switcher
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.translate('language'),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        side: const BorderSide(color: AppTheme.primaryColor),
                      ),
                      onPressed: () {
                        ref.read(localeProvider.notifier).toggleLanguage();
                      },
                      child: Text(
                        isUrdu ? 'English' : 'اردو',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Logout button
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                  title: Text(
                    localizations.translate('logout'),
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required String currentRoute,
    VoidCallback? onTapOverride,
  }) {
    final isSelected = currentRoute.startsWith(route);
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: onTapOverride ??
          () {
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
              Navigator.pop(context); // Close drawer
            }
            context.go(route);
          },
    );
  }

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
}
