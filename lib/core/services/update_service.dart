import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/theme.dart';

class AppRelease {
  final String id;
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String? releaseNotes;
  final bool isMandatory;
  final DateTime createdAt;

  AppRelease({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    this.releaseNotes,
    this.isMandatory = false,
    required this.createdAt,
  });

  factory AppRelease.fromMap(Map<String, dynamic> map) {
    return AppRelease(
      id: map['id']?.toString() ?? '',
      versionName: map['version_name']?.toString() ?? '1.0.0',
      versionCode: (map['version_code'] is int)
          ? map['version_code'] as int
          : int.tryParse(map['version_code']?.toString() ?? '1') ?? 1,
      downloadUrl: map['download_url']?.toString() ?? '',
      releaseNotes: map['release_notes']?.toString(),
      isMandatory: map['is_mandatory'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version_name': versionName,
      'version_code': versionCode,
      'download_url': downloadUrl,
      'release_notes': releaseNotes,
      'is_mandatory': isMandatory,
    };
  }
}

class UpdateService {
  static bool _hasCheckedThisSession = false;

  /// Fetches the newest release recorded in Supabase
  static Future<AppRelease?> fetchLatestRelease() async {
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('app_releases')
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return AppRelease.fromMap(data);
    } catch (e) {
      debugPrint('UpdateService.fetchLatestRelease error: $e');
      return null;
    }
  }

  /// Fetches all past releases (for Admin Release Manager)
  static Future<List<AppRelease>> fetchAllReleases() async {
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('app_releases')
          .select()
          .order('version_code', ascending: false);

      return (data as List).map((row) => AppRelease.fromMap(row as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('UpdateService.fetchAllReleases error: $e');
      return [];
    }
  }

  /// Publishes a new release
  static Future<bool> publishRelease({
    required String versionName,
    required int versionCode,
    required String downloadUrl,
    required String releaseNotes,
    required bool isMandatory,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('app_releases').insert({
        'version_name': versionName.trim(),
        'version_code': versionCode,
        'download_url': downloadUrl.trim(),
        'release_notes': releaseNotes.trim(),
        'is_mandatory': isMandatory,
      });
      return true;
    } catch (e) {
      debugPrint('UpdateService.publishRelease error: $e');
      return false;
    }
  }

  /// Auto-check on launch (runs at most once per session)
  static void checkOnLaunch(BuildContext context) {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    // Slight delay so the initial route finishes rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!context.mounted) return;
        checkForUpdates(context, isManualCheck: false);
      });
    });
  }

  /// Check for updates (either automatic on startup or manual click from Settings/Drawer)
  static Future<void> checkForUpdates(BuildContext context, {bool isManualCheck = false}) async {
    if (isManualCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 14),
              Text('Checking for new app updates...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final latest = await fetchLatestRelease();
    if (!context.mounted) return;

    if (latest == null) {
      if (isManualCheck) {
        _showUpToDateDialog(context);
      }
      return;
    }

    final isUpdateAvailable = latest.versionCode > AppConfig.appBuildNumber;

    if (isUpdateAvailable) {
      showUpdateDialog(context, latest);
    } else if (isManualCheck) {
      _showUpToDateDialog(context);
    }
  }

  /// Shows the dialog when the app is already up to date
  static void _showUpToDateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('App Is Up To Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are currently running version ${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber}).'),
            const SizedBox(height: 8),
            const Text('No new updates are available right now.', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Shows the update modal dialog
  static void showUpdateDialog(BuildContext context, AppRelease release) {
    showDialog(
      context: context,
      barrierDismissible: !release.isMandatory,
      builder: (ctx) {
        return PopScope(
          canPop: !release.isMandatory,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top icon & Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Update Available!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roshni RAMS v${release.versionName}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Version Compare Chips
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Installed: v${AppConfig.appVersion} (#${AppConfig.appBuildNumber})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                        Text(
                          'Latest: v${release.versionName} (#${release.versionCode})',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Release notes
                  if (release.releaseNotes != null && release.releaseNotes!.isNotEmpty) ...[
                    const Text(
                      'What\'s New in this update:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          release.releaseNotes!,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (release.isMandatory)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This update is required to continue using the application.',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Actions
                  Row(
                    children: [
                      if (!release.isMandatory)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Later'),
                          ),
                        ),
                      if (!release.isMandatory) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final uri = Uri.tryParse(release.downloadUrl);
                            if (uri != null) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
