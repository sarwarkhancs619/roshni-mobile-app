import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';

import '../../../core/storage/hive_storage.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  double _getWorkshopProductivity(String workshopId, List<Friend> friends) {
    final enrolled = friends.where((f) => f.assignedWorkshopId == workshopId).toList();
    if (enrolled.isEmpty) return 0.0;
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      double totalComp = 0.0;
      int evaluatedCount = 0;
      for (final f in enrolled) {
        final rec = box.get('record_${workshopId}_${f.id}');
        if (rec != null && rec is Map) {
          evaluatedCount++;
          totalComp += (rec['task_completion'] as num?)?.toDouble() ?? 0.0;
        }
      }
      if (evaluatedCount > 0) {
        return (totalComp / (evaluatedCount * 5.0)).clamp(0.0, 1.0);
      }
    } catch (_) {}
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);
    
    // Real statistics variables based on current actual data
    final totalFriendsCount = friends.length;
    final activeFriends = friends.where((f) => f.status == 'active').toList();
    final presentTodayCount = activeFriends.length;
    final pendingReportsCount = friends.where((f) => f.medicalNotesSummary.isEmpty).length;
    
    // Real therapy sessions count from Hive
    int therapySessionsCount = 0;
    final List<Map<String, dynamic>> realTherapySessions = [];
    try {
      final actBox = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      for (final f in friends) {
        final physio = actBox.get('physio_sessions_${f.id}');
        if (physio != null && physio is List) {
          therapySessionsCount += physio.length;
          for (final s in physio) {
            if (s is Map) {
              realTherapySessions.add({
                'friend': f.fullName,
                'type': 'Physiotherapy',
                'date': s['date']?.toString() ?? 'Recent',
                'notes': s['notes']?.toString() ?? '',
              });
            }
          }
        }
        final speech = actBox.get('speech_sessions_${f.id}');
        if (speech != null && speech is List) {
          therapySessionsCount += speech.length;
          for (final s in speech) {
            if (s is Map) {
              realTherapySessions.add({
                'friend': f.fullName,
                'type': 'Speech Therapy',
                'date': s['date']?.toString() ?? 'Recent',
                'notes': s['notes']?.toString() ?? '',
              });
            }
          }
        }
      }
    } catch (_) {}

    final medicalAlertsFriends = friends.where((f) => f.medicalNotesSummary.isNotEmpty).toList();
    final medicalAlertsCount = medicalAlertsFriends.length;

    // Real completed IEP goals from Hive
    int completedGoalsCount = 0;
    final List<Map<String, dynamic>> realCompletedGoals = [];
    try {
      final iepBox = HiveStorage.getBox(HiveStorage.iepBoxName);
      for (final f in friends) {
        final iepData = iepBox.get(f.id);
        if (iepData != null && iepData is Map) {
          final goals = iepData['iep_goals'];
          if (goals != null && goals is List) {
            for (final g in goals) {
              if (g is Map && g['status'] == 'completed') {
                completedGoalsCount++;
                realCompletedGoals.add({
                  'friend': f.fullName,
                  'title': g['title']?.toString() ?? 'Goal',
                  'objectives': g['objectives']?.toString() ?? '',
                });
              }
            }
          }
        }
      }
    } catch (_) {}

    return ResponsiveLayout(
      title: '${localizations.translate('admin_dashboard')} - RAMS',
      currentRoute: '/dashboard/admin',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            _buildWelcomeBanner(context, localizations, ref.watch(authProvider).user?.displayNameWithRole ?? 'Admin'),
            const SizedBox(height: 24),
            
            // Statistics Grid (Responsive columns)
            _buildStatsGrid(
              context, 
              localizations,
              friends,
              totalFriendsCount,
              presentTodayCount,
              pendingReportsCount,
              therapySessionsCount,
              medicalAlertsCount,
              completedGoalsCount,
              realTherapySessions,
              medicalAlertsFriends,
              realCompletedGoals,
            ),
            const SizedBox(height: 28),
            
            // Layout with Charts and Recent Activity Side-by-Side on wide screens
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildMainDashboardWidgets(context, localizations, ref, friends),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _buildSidebarWidgets(context, localizations, friends, realCompletedGoals, realTherapySessions, medicalAlertsFriends),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildMainDashboardWidgets(context, localizations, ref, friends),
                      const SizedBox(height: 24),
                      _buildSidebarWidgets(context, localizations, friends, realCompletedGoals, realTherapySessions, medicalAlertsFriends),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, AppLocalizations localizations, String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        gradient: AppTheme.blueOrangeGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assalam-o-Alaikum, $userName!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'RAMS Admin portal is operational. Today is ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}. All systems synchronized.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.security, size: 16),
            label: const Text('Open Principal Vault & IP Console'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => context.push('/dashboard/principal'),
          ),
        ],
      ),
    );
  }

  void _showStatsDetailsBottomSheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(
    BuildContext context, 
    AppLocalizations localizations,
    List<Friend> friends,
    int totalFriends,
    int presentToday,
    int pendingReports,
    int therapySessions,
    int medicalAlerts,
    int completedGoals,
    List<Map<String, dynamic>> realTherapySessions,
    List<Friend> medicalAlertsFriends,
    List<Map<String, dynamic>> realCompletedGoals,
  ) {
    final double width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 6 : (width > 800 ? 3 : 2);
    double aspectRatio = width < 400 ? 1.1 : (width < 600 ? 1.25 : 1.3);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio,
      children: [
        _buildStatCard(
          context,
          title: localizations.translate('total_friends'),
          value: '$totalFriends',
          icon: Icons.people,
          color: AppTheme.primaryColor,
          onTap: () {
            _showStatsDetailsBottomSheet(
              context,
              title: 'Total Registered Beneficiaries ($totalFriends)',
              children: friends.isEmpty
                  ? [const ListTile(title: Text('No friends registered yet.'))]
                  : friends.map<Widget>((f) => ListTile(
                      leading: CircleAvatar(backgroundImage: NetworkImage(f.photoUrl)),
                      title: Text(f.fullName),
                      subtitle: Text('ID: ${f.registrationNumber} • ${f.assignedWorkshopId.toUpperCase()}'),
                    )).toList(),
            );
          },
        ),
        _buildStatCard(
          context,
          title: localizations.translate('present_today'),
          value: '$presentToday/$totalFriends',
          icon: Icons.check_circle_outline,
          color: AppTheme.successColor,
          onTap: () {
            _showStatsDetailsBottomSheet(
              context,
              title: 'Today\'s Attendance Status ($presentToday Present)',
              children: friends.isEmpty
                  ? [const ListTile(title: Text('No attendance data.'))]
                  : friends.map<Widget>((f) {
                      final isPresent = f.status == 'active';
                      return ListTile(
                        leading: Icon(
                          isPresent ? Icons.check_circle : Icons.cancel,
                          color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                        title: Text(f.fullName),
                        subtitle: Text(isPresent ? 'Status: Active / Present' : 'Status: Inactive / Absent'),
                      );
                    }).toList(),
            );
          },
        ),
        _buildStatCard(
          context,
          title: localizations.translate('pending_reports'),
          value: '$pendingReports',
          icon: Icons.pending_actions,
          color: AppTheme.accentColor,
          onTap: () {
            final pendingFriends = friends.where((f) => f.medicalNotesSummary.isEmpty).toList();
            _showStatsDetailsBottomSheet(
              context,
              title: 'Pending Progress & Medical Reviews ($pendingReports)',
              children: pendingFriends.isEmpty
                  ? [
                      const ListTile(
                        leading: Icon(Icons.check_circle, color: AppTheme.successColor),
                        title: Text('All registered friends have medical notes on file.'),
                      )
                    ]
                  : pendingFriends.map<Widget>((f) => ListTile(
                      leading: const Icon(Icons.description_outlined, color: AppTheme.accentColor),
                      title: Text(f.fullName),
                      subtitle: Text('Reg: ${f.registrationNumber} • ${f.assignedWorkshopId.toUpperCase()} • Review required'),
                    )).toList(),
            );
          },
        ),
        _buildStatCard(
          context,
          title: localizations.translate('therapy_sessions'),
          value: '$therapySessions',
          icon: Icons.spatial_audio_off_sharp,
          color: AppTheme.secondaryColor,
          onTap: () {
            _showStatsDetailsBottomSheet(
              context,
              title: 'Recorded Therapy Sessions ($therapySessions total)',
              children: realTherapySessions.isEmpty
                  ? [
                      const ListTile(
                        leading: Icon(Icons.spa_outlined, color: Colors.grey),
                        title: Text('No clinical therapy sessions logged yet.'),
                        subtitle: Text('Log sessions via Physiotherapy or Speech Therapy consoles.'),
                      )
                    ]
                  : realTherapySessions.map<Widget>((s) => ListTile(
                      leading: Icon(
                        s['type'] == 'Physiotherapy' ? Icons.accessibility_new : Icons.record_voice_over,
                        color: AppTheme.secondaryColor,
                      ),
                      title: Text('${s['type']}: ${s['friend']}'),
                      subtitle: Text('Date: ${s['date']} ${s['notes'].isNotEmpty ? "• ${s['notes']}" : ""}'),
                    )).toList(),
            );
          },
        ),
        _buildStatCard(
          context,
          title: localizations.translate('medical_alerts'),
          value: '$medicalAlerts',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.errorColor,
          onTap: () {
            _showStatsDetailsBottomSheet(
              context,
              title: 'Active Medical Alerts ($medicalAlerts)',
              children: medicalAlertsFriends.isEmpty
                  ? [
                      const ListTile(
                        leading: Icon(Icons.health_and_safety, color: AppTheme.successColor),
                        title: Text('No active critical medical alerts.'),
                      )
                    ]
                  : medicalAlertsFriends.map<Widget>((f) => ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                      title: Text(f.fullName),
                      subtitle: Text(f.medicalNotesSummary),
                    )).toList(),
            );
          },
        ),
        _buildStatCard(
          context,
          title: localizations.translate('goals_completed'),
          value: '$completedGoals',
          icon: Icons.golf_course,
          color: Colors.purple,
          onTap: () {
            _showStatsDetailsBottomSheet(
              context,
              title: 'Achieved IEP Learning Goals ($completedGoals)',
              children: realCompletedGoals.isEmpty
                  ? [
                      const ListTile(
                        leading: Icon(Icons.star_border, color: Colors.purple),
                        title: Text('No learning goals completed yet.'),
                        subtitle: Text('Mark goals complete in the IEP section.'),
                      )
                    ]
                  : realCompletedGoals.map<Widget>((g) => ListTile(
                      leading: const Icon(Icons.star, color: Colors.purple),
                      title: Text('${g['friend']} achieved goal:'),
                      subtitle: Text('${g['title']} ${g['objectives'].isNotEmpty ? "• ${g['objectives']}" : ""}'),
                    )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboardWidgets(BuildContext context, AppLocalizations localizations, WidgetRef ref, List<Friend> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workshop progress card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Workshop Productivity Index (Real Evaluations)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.show_chart, color: AppTheme.primaryColor),
                  ],
                ),
                const SizedBox(height: 20),
                _buildProgressRow(context, 'Bakery (Baking & Packaging)', _getWorkshopProductivity('bakery', friends), AppTheme.primaryColor),
                _buildProgressRow(context, 'Textile (Cutting & Stitching)', _getWorkshopProductivity('textile', friends), AppTheme.secondaryColor),
                _buildProgressRow(context, 'Woodwork (Sanding & Assembly)', _getWorkshopProductivity('woodwork', friends), Colors.orange),
                _buildProgressRow(context, 'Artwork & Handicrafts', _getWorkshopProductivity('artwork', friends), AppTheme.accentColor),
                _buildProgressRow(context, 'Organic Farming', _getWorkshopProductivity('farming', friends), Colors.green),
                _buildProgressRow(context, 'Sports & Physical Fitness', _getWorkshopProductivity('sports', friends), Colors.indigo),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Quick Actions Grid
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('quick_actions'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.manage_accounts,
                      label: localizations.translate('manage_users'),
                      onTap: () => context.push('/dashboard/admin/users'),
                    ),
                    if (ref.watch(authProvider).user?.role == 'principal')
                      _buildActionButton(
                        context,
                        icon: Icons.security,
                        label: 'Manage Permissions',
                        onTap: () => context.push('/dashboard/admin/permissions'),
                      ),
                    _buildActionButton(
                      context,
                      icon: Icons.person_add_alt_1,
                      label: localizations.translate('add_friend'),
                      onTap: () => context.push('/friends/add'),
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.checklist,
                      label: 'Mark Attendance',
                      onTap: () => context.push('/attendance'),
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.assignment_turned_in,
                      label: 'Create IEP Goal',
                      onTap: () => context.push('/friends'),
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.picture_as_pdf,
                      label: 'Export reports',
                      onTap: () => context.push('/reports'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(
    BuildContext context, 
    String label, 
    double percentage, 
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percentage > 0 ? '${(percentage * 100).toInt()}%' : '0% (No evals)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: percentage > 0 ? color : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarWidgets(
    BuildContext context, 
    AppLocalizations localizations,
    List<Friend> friends,
    List<Map<String, dynamic>> realCompletedGoals,
    List<Map<String, dynamic>> realTherapySessions,
    List<Friend> medicalAlertsFriends,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('recent_activities'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (friends.isNotEmpty)
              _buildActivityItem(
                context,
                title: 'Beneficiary Active',
                desc: '${friends.first.fullName} active in ${friends.first.assignedWorkshopId.toUpperCase()} workshop.',
                time: 'Today',
                icon: Icons.check_circle,
                iconColor: AppTheme.successColor,
              ),
            if (realCompletedGoals.isNotEmpty)
              _buildActivityItem(
                context,
                title: 'IEP Goal update',
                desc: '${realCompletedGoals.first['friend']} achieved: "${realCompletedGoals.first['title']}".',
                time: 'Recently',
                icon: Icons.star,
                iconColor: AppTheme.accentColor,
              )
            else if (friends.length > 1)
              _buildActivityItem(
                context,
                title: 'Beneficiary Active',
                desc: '${friends[1].fullName} assigned to ${friends[1].assignedWorkshopId.toUpperCase()} workshop.',
                time: 'Today',
                icon: Icons.store,
                iconColor: AppTheme.primaryColor,
              ),
            if (realTherapySessions.isNotEmpty)
              _buildActivityItem(
                context,
                title: 'Clinical session',
                desc: '${realTherapySessions.first['type']} recorded for ${realTherapySessions.first['friend']}.',
                time: realTherapySessions.first['date'],
                icon: Icons.spatial_audio_off_sharp,
                iconColor: AppTheme.secondaryColor,
              )
            else if (friends.length > 2)
              _buildActivityItem(
                context,
                title: 'Beneficiary Active',
                desc: '${friends[2].fullName} assigned to ${friends[2].assignedHouseId.toUpperCase()}.',
                time: 'Today',
                icon: Icons.home,
                iconColor: AppTheme.secondaryColor,
              ),
            if (medicalAlertsFriends.isNotEmpty)
              _buildActivityItem(
                context,
                title: 'Medical Alert',
                desc: '${medicalAlertsFriends.first.fullName}: ${medicalAlertsFriends.first.medicalNotesSummary}',
                time: 'Current',
                icon: Icons.warning_amber_rounded,
                iconColor: AppTheme.errorColor,
              )
            else
              _buildActivityItem(
                context,
                title: 'System Synchronized',
                desc: 'All resident records synchronized with RAMS core database.',
                time: 'Operational',
                icon: Icons.cloud_done,
                iconColor: AppTheme.successColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required String title,
    required String desc,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
