import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/storage/hive_storage.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final workshopId = user?.workshopId ?? 'bakery';

    final friends = ref.watch(friendsProvider);
    // Filter friends assigned to this staff's workshop
    final assignedFriends = friends.where((f) => f.assignedWorkshopId == workshopId).toList();
    final activeCount = assignedFriends.where((f) => f.status == 'active').length;

    int evaluatedCount = 0;
    try {
      final box = HiveStorage.getBox(HiveStorage.activitiesBoxName);
      for (final friend in assignedFriends) {
        if (box.containsKey('record_${workshopId}_${friend.id}')) {
          evaluatedCount++;
        }
      }
    } catch (_) {}

    return ResponsiveLayout(
      title: '${localizations.translate(workshopId)} ${localizations.translate('dashboard')}',
      currentRoute: '/dashboard/staff',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop Header Card
            _buildWorkshopHeaderCard(context, localizations, user?.fullName ?? '', workshopId),
            const SizedBox(height: 24),

            // Statistics row
            LayoutBuilder(
              builder: (context, constraints) {
                final card1 = _buildCountCard(
                  context,
                  title: 'Assigned Friends',
                  value: '${assignedFriends.length}',
                  icon: Icons.people,
                  color: AppTheme.primaryColor,
                );
                final card2 = _buildCountCard(
                  context,
                  title: 'Active Today',
                  value: '$activeCount/${assignedFriends.length}',
                  icon: Icons.check_box_outlined,
                  color: AppTheme.successColor,
                );
                final card3 = _buildCountCard(
                  context,
                  title: 'Evaluated',
                  value: '$evaluatedCount/${assignedFriends.length}',
                  icon: Icons.star_outline,
                  color: AppTheme.accentColor,
                );

                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 12),
                          Expanded(child: card2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      card3,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: card1),
                    const SizedBox(width: 16),
                    Expanded(child: card2),
                    const SizedBox(width: 16),
                    Expanded(child: card3),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Assigned Friends List and Tasks
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Friends for ${localizations.translate(workshopId)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    assignedFriends.isEmpty
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No friends assigned to this workshop.'),
                          ))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: assignedFriends.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final friend = assignedFriends[index];
                              final double screenWidth = MediaQuery.of(context).size.width;
                              final bool isMobile = screenWidth < 600;

                              if (isMobile) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: InkWell(
                                    onTap: () => context.push('/friends/${friend.id}'),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundImage: NetworkImage(friend.photoUrl),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(friend.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  Text('Reg: ${friend.registrationNumber} • Age: ${friend.age}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right, size: 20),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              icon: const Icon(Icons.star_border, color: AppTheme.accentColor, size: 18),
                                              label: const Text('Record Skills', style: TextStyle(fontSize: 12, color: AppTheme.accentColor)),
                                              onPressed: () => context.push('/workshops/$workshopId'),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              icon: const Icon(Icons.note_alt_outlined, color: AppTheme.primaryColor, size: 18),
                                              label: const Text('Record Daily', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                                              onPressed: () => context.push('/workshops/$workshopId'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(friend.photoUrl),
                                ),
                                title: Text(friend.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Reg: ${friend.registrationNumber} • Age: ${friend.age}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.star_border, color: AppTheme.accentColor),
                                      tooltip: 'Record Skills',
                                      onPressed: () {
                                        context.push('/workshops/$workshopId');
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.note_alt_outlined, color: AppTheme.primaryColor),
                                      tooltip: 'Record Daily Activity',
                                      onPressed: () {
                                        context.push('/workshops/$workshopId');
                                      },
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () => context.push('/friends/${friend.id}'),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Tools Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workshop Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => context.push('/attendance'),
                          icon: const Icon(Icons.checklist),
                          label: const Text('Mark Today\'s Attendance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            minimumSize: const Size(200, 50),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/workshops/$workshopId'),
                          icon: const Icon(Icons.assessment),
                          label: const Text('Record Activity & Skill Progress'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(220, 50),
                            side: const BorderSide(color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopHeaderCard(
    BuildContext context, 
    AppLocalizations localizations,
    String staffName,
    String workshopId,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${localizations.translate(workshopId)} Workshop Portal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assigned Staff: $staffName • Track daily activities, vocational skills, behavioral records, and goals for assigned special adults.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
