import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/update_service.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';

class ReleaseManagementScreen extends StatefulWidget {
  const ReleaseManagementScreen({super.key});

  @override
  State<ReleaseManagementScreen> createState() => _ReleaseManagementScreenState();
}

class _ReleaseManagementScreenState extends State<ReleaseManagementScreen> {
  List<AppRelease> _releases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    setState(() => _isLoading = true);
    final data = await UpdateService.fetchAllReleases();
    if (mounted) {
      setState(() {
        _releases = data;
        _isLoading = false;
      });
    }
  }

  void _openPublishDialog() {
    final versionNameCtrl = TextEditingController(text: '1.0.${_releases.length + 1}');
    final highestCode = _releases.isEmpty ? AppConfig.appBuildNumber : _releases.map((r) => r.versionCode).reduce((a, b) => a > b ? a : b);
    final versionCodeCtrl = TextEditingController(text: '${highestCode + 1}');
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isMandatory = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Publish App Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Notify all phones to update in-place', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: versionNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Version Name (e.g. 1.0.1)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: versionCodeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Build # (e.g. 2)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Direct APK Download URL',
                          hintText: 'https://.../app-release.apk or Drive/GitHub link',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: notesCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Release Notes (What\'s New)',
                          hintText: '• Fixed UI overflow on mobile\n• Updated medical vitals tracking\n• Performance enhancements',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mandatory Update', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Forces users to update before they can use the app', style: TextStyle(fontSize: 12)),
                        value: isMandatory,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (v) => setDialogState(() => isMandatory = v),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.publish, size: 18),
                            label: const Text('Publish Update'),
                            onPressed: () async {
                              final name = versionNameCtrl.text.trim();
                              final code = int.tryParse(versionCodeCtrl.text.trim()) ?? 1;
                              final url = urlCtrl.text.trim();
                              final notes = notesCtrl.text.trim();

                              if (name.isEmpty || url.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill Version Name and Download URL')),
                                );
                                return;
                              }

                              Navigator.of(ctx).pop();
                              final ok = await UpdateService.publishRelease(
                                versionName: name,
                                versionCode: code,
                                downloadUrl: url,
                                releaseNotes: notes,
                                isMandatory: isMandatory,
                              );

                              if (!mounted) return;

                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Release v$name published! All users will now receive the update prompt.'),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                                _loadReleases();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to publish release. Check connection.')),
                                );
                              }
                            },
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      title: 'App Releases & In-App Updates',
      currentRoute: '/admin/releases',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Publish Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _openPublishDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReleases,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status & Quick Guide Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.phonelink_setup, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('In-App Update Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                'Current Running App: v${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber})',
                                style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Check Now'),
                          onPressed: () => UpdateService.checkForUpdates(context, isManualCheck: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'How it works: Whenever you build a new APK, publish the new version here. When users open the app on their phones, they will see a notification pop up asking them to update. They tap "Update Now", the APK downloads, and Android updates the app in-place without needing to uninstall!',
                              style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Releases History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Published Releases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_releases.length} releases', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_releases.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No releases published yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text('Tap "Publish Update" above to notify users about new APK builds.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ..._releases.map((release) {
                final isCurrent = release.versionCode == AppConfig.appBuildNumber;
                final isNewer = release.versionCode > AppConfig.appBuildNumber;
                final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(release.createdAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isNewer ? AppTheme.primaryColor : Colors.transparent,
                      width: isNewer ? 1.5 : 0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isNewer
                                    ? AppTheme.primaryColor
                                    : (isCurrent ? Colors.green.shade700 : Colors.grey.shade600),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${release.versionName} (#${release.versionCode})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (release.isMandatory)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('MANDATORY', style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('CURRENT RUNNING', style: TextStyle(color: Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            const Spacer(),
                            Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        if (release.releaseNotes != null && release.releaseNotes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            release.releaseNotes!,
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                release.downloadUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: const Text('Test Link', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final uri = Uri.tryParse(release.downloadUrl);
                                if (uri != null) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.preview, size: 18),
                              tooltip: 'Preview Update Dialog',
                              onPressed: () => UpdateService.showUpdateDialog(context, release),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
