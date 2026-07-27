import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../friends/presentation/friends_provider.dart';

class MedicalDashboardScreen extends ConsumerWidget {
  const MedicalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider);

    return ResponsiveLayout(
      title: localizations.translate('role_medical_officer') + ' ' + localizations.translate('dashboard'),
      currentRoute: '/dashboard/medical',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medical Header Banner
            _buildHeaderBanner(context, localizations),
            const SizedBox(height: 24),

            // Appointments & Daily Checks list
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Medical Appointments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friends.length > 2 ? 2 : friends.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final double screenWidth = MediaQuery.of(context).size.width;
                        final bool isMobile = screenWidth < 600;

                        if (isMobile) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: InkWell(
                              onTap: () => context.push('/medical/${friend.id}'),
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
                                            Text('Diagnosis: Cognitive Delay • Blood: ${friend.bloodGroup}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                                        context.push('/medical/${friend.id}');
                                      },
                                      child: const Text('Add Checkup', style: TextStyle(fontSize: 12)),
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
                          subtitle: Text('Diagnosis: Cognitive Delay • Blood: ${friend.bloodGroup}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              minimumSize: const Size(120, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              context.push('/medical/${friend.id}');
                            },
                            child: const Text('Add Checkup', style: TextStyle(fontSize: 12)),
                          ),
                          onTap: () => context.push('/medical/${friend.id}'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Friends health directory
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friends Health Records Directory',
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
                          subtitle: Text('Last Vitals: BP 120/80, Temp 98.6°F, HR 72 bpm'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.push('/medical/${friend.id}'),
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
              Icon(Icons.medical_services, color: Colors.white, size: 36),
              SizedBox(width: 12),
              Text(
                'Medical & Clinical Portal',
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
            'Strictly authorized clinical access. Track diagnosis, prescribe medications, manage vital charts, record vaccinations, and keep emergency contacts up to date.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
