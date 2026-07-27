import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../friends/presentation/friends_provider.dart';

class PhysioDashboardScreen extends ConsumerWidget {
  const PhysioDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);

    return ResponsiveLayout(
      title: localizations.translate('role_physiotherapist') + ' ' + localizations.translate('dashboard'),
      currentRoute: '/dashboard/physio',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            _buildHeaderBanner(context, localizations),
            const SizedBox(height: 24),

            // Today's list of sessions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Physiotherapy Sessions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friends.length > 3 ? 3 : friends.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final double screenWidth = MediaQuery.of(context).size.width;
                        final bool isMobile = screenWidth < 600;

                        if (isMobile) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: InkWell(
                              onTap: () => context.push('/therapy/physiotherapy/${friend.id}'),
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
                                            Text('Status: Active • Assigned Workshop: ${localizations.translate(friend.assignedWorkshopId)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        minimumSize: const Size(double.infinity, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      onPressed: () {
                                        context.push('/therapy/physiotherapy/${friend.id}');
                                      },
                                      child: const Text('Record Session', style: TextStyle(fontSize: 12)),
                                    ),
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
                          subtitle: Text('Status: Active • Assigned Workshop: ${localizations.translate(friend.assignedWorkshopId)}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              minimumSize: const Size(120, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              context.push('/therapy/physiotherapy/${friend.id}');
                            },
                            child: const Text('Record Session', style: TextStyle(fontSize: 12)),
                          ),
                          onTap: () => context.push('/therapy/physiotherapy/${friend.id}'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Friends directory for Physiotherapy
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Friends - Physical Assessment List',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friends.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(friend.photoUrl),
                          ),
                          title: Text(friend.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Mobility: Stable • ROM: Normal • Strength: 4/5'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.push('/therapy/physiotherapy/${friend.id}'),
                        );
                      },
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

  Widget _buildHeaderBanner(BuildContext context, AppLocalizations localizations) {
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
            children: const [
              Icon(Icons.accessibility_new, color: Colors.white, size: 36),
              SizedBox(width: 12),
              Text(
                'Physiotherapy Management Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Record ROM assessments, create custom muscle-strength exercises, plan rehabilitation tasks, and track individual progress over time.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
