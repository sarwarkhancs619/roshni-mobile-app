import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../auth/presentation/auth_providers.dart';

// Riverpod theme provider for dark/light state
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggleTheme(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);

    return ResponsiveLayout(
      title: localizations.translate('settings'),
      currentRoute: '/settings',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Account Summary Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      authState.user?.fullName.characters.first.toUpperCase() ?? 'U',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.fullName ?? 'User Name',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations.translate('role_${authState.user?.role ?? "workshop_staff"}'),
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.user?.email ?? 'email@example.com',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Settings section
          const Text('System Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          
          // Language setting
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppTheme.primaryColor),
              title: Text(localizations.translate('language')),
              subtitle: Text(locale.languageCode == 'en' ? 'English' : 'اردو (Urdu)'),
              trailing: Switch(
                value: locale.languageCode == 'ur',
                activeColor: AppTheme.primaryColor,
                onChanged: (val) {
                  ref.read(localeProvider.notifier).toggleLanguage();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dark Theme setting
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_medium, color: AppTheme.primaryColor),
              title: Text(localizations.translate('theme')),
              subtitle: Text(themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode'),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) {
                  ref.read(themeModeProvider.notifier).toggleTheme(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Information Section
          const Text('About Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  title: Text('Application Version'),
                  trailing: Text('1.0.0 (Build 1)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.security, color: AppTheme.primaryColor),
                  title: Text('Data Encryption Status'),
                  trailing: Text('Active (HTTPS/AES-256)', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_sync, color: AppTheme.primaryColor),
                  title: Text('Local Database Sync'),
                  trailing: Text('In-Sync', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
