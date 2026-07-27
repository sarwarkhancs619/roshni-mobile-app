import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../friends/models/friend.dart';
import '../../auth/presentation/auth_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);
    
    // Quick statistics variables
    final totalFriendsCount = friends.length;
    const presentTodayCount = 4; // Mock
    const pendingReportsCount = 3; // Mock
    const therapySessionsCount = 5; // Mock
    const medicalAlertsCount = 1; // Mock
    const completedGoalsCount = 18; // Mock

    return ResponsiveLayout(
      title: localizations.translate('admin_dashboard') + ' - RAMS',
      currentRoute: '/dashboard/admin',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            _buildWelcomeBanner(context, localizations, ref.watch(authProvider).user?.fullName ?? 'Admin'),
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
                        child: _buildMainDashboardWidgets(context, localizations),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _buildSidebarWidgets(context, localizations),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildMainDashboardWidgets(context, localizations),
                      const SizedBox(height: 24),
                      _buildSidebarWidgets(context, localizations),
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
              title: 'Total Registered Friends',
              children: friends.map<Widget>((f) => ListTile(
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
              title: 'Today\'s Attendance Details',
              children: friends.take(4).map<Widget>((f) => ListTile(
                leading: const Icon(Icons.check_circle, color: AppTheme.successColor),
                title: Text(f.fullName),
                subtitle: const Text('Status: Present Today'),
              )).toList() + <Widget>[
                ListTile(
                  leading: const Icon(Icons.cancel, color: AppTheme.errorColor),
                  title: Text(friends.isNotEmpty ? friends.last.fullName : 'No resident'),
                  subtitle: const Text('Status: Absent Today'),
                )
              ],
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
            _showStatsDetailsBottomSheet(
              context,
              title: 'Pending Progress Reports',
              children: [
                const ListTile(
                  leading: Icon(Icons.description_outlined, color: AppTheme.accentColor),
                  title: Text('Weekly IEP Progress Report'),
                  subtitle: Text('Required for Bakery workshop residents'),
                ),
                const ListTile(
                  leading: Icon(Icons.medical_services_outlined, color: AppTheme.accentColor),
                  title: Text('Monthly Medical Update'),
                  subtitle: Text('Pending for Ali Raza'),
                ),
                const ListTile(
                  leading: Icon(Icons.accessibility_new, color: AppTheme.accentColor),
                  title: Text('Physiotherapy Session Log'),
                  subtitle: Text('Required for Ayesha Bibi'),
                ),
              ],
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
              title: 'Today\'s Therapy Schedule',
              children: [
                const ListTile(
                  leading: Icon(Icons.spatial_audio_off_sharp, color: AppTheme.secondaryColor),
                  title: Text('Speech Therapy: Bilal Mustafa'),
                  subtitle: Text('Time: 11:30 AM - Room B'),
                ),
                const ListTile(
                  leading: Icon(Icons.accessibility_new, color: AppTheme.secondaryColor),
                  title: Text('Physiotherapy: Zainab Fatima'),
                  subtitle: Text('Time: 02:00 PM - Gym Hall'),
                ),
                const ListTile(
                  leading: Icon(Icons.spatial_audio_off_sharp, color: AppTheme.secondaryColor),
                  title: Text('Speech Therapy: Usman Tariq'),
                  subtitle: Text('Time: 03:00 PM - Room B'),
                ),
              ],
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
              title: 'Active Medical Alerts',
              children: [
                ListTile(
                  leading: const Icon(Icons.warning, color: AppTheme.errorColor),
                  title: Text(friends.length > 2 ? '${friends[2].fullName}: Medication Adjust' : 'Medication Adjust'),
                  subtitle: const Text('Dr. Usman Ahmed: Monitor blood pressure twice daily after dosage adjustment.'),
                ),
              ],
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
              title: 'IEP Goals Completed Recently',
              children: [
                const ListTile(
                  leading: Icon(Icons.star, color: Colors.purple),
                  title: Text('Zainab Fatima achieved goal:'),
                  subtitle: Text('Mixing ingredients independently (Bakery)'),
                ),
                const ListTile(
                  leading: Icon(Icons.star, color: Colors.purple),
                  title: Text('Ali Raza achieved goal:'),
                  subtitle: Text('Sanding wooden blocks without supervision (Woodwork)'),
                ),
                const ListTile(
                  leading: Icon(Icons.star, color: Colors.purple),
                  title: Text('Ayesha Bibi achieved goal:'),
                  subtitle: Text('Identifying colored threads (Textile)'),
                ),
              ],
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

  Widget _buildMainDashboardWidgets(BuildContext context, AppLocalizations localizations) {
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
                    Text(
                      'Workshop Productivity Index',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Icon(Icons.show_chart, color: AppTheme.primaryColor),
                  ],
                ),
                const SizedBox(height: 20),
                _buildProgressRow(context, 'Bakery (Baking & Packaging)', 0.85, AppTheme.primaryColor),
                _buildProgressRow(context, 'Textile (Cutting & Stitching)', 0.72, AppTheme.secondaryColor),
                _buildProgressRow(context, 'Woodwork (Sanding & Assembly)', 0.90, Colors.orange),
                _buildProgressRow(context, 'Artwork & Handicrafts', 0.65, AppTheme.accentColor),
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
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${(percentage * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
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
          color: AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
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

  Widget _buildSidebarWidgets(BuildContext context, AppLocalizations localizations) {
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
            _buildActivityItem(
              context,
              title: 'Attendance marked',
              desc: 'Ali Raza marked present in Woodwork workshop.',
              time: '10 mins ago',
              icon: Icons.check_circle,
              iconColor: AppTheme.successColor,
            ),
            _buildActivityItem(
              context,
              title: 'IEP Goal update',
              desc: 'Zainab Fatima achieved goal: "Mixing ingredients independently".',
              time: '1 hour ago',
              icon: Icons.star,
              iconColor: AppTheme.accentColor,
            ),
            _buildActivityItem(
              context,
              title: 'Speech assessment',
              desc: 'Speech Therapist Amina added initial review for Bilal Mustafa.',
              time: '2 hours ago',
              icon: Icons.spatial_audio_off_sharp,
              iconColor: AppTheme.secondaryColor,
            ),
            _buildActivityItem(
              context,
              title: 'Medical Alert',
              desc: 'Dr. Usman prescribed medication adjust for Usman Tariq.',
              time: 'Yesterday',
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.errorColor,
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
              color: iconColor.withOpacity(0.1),
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
