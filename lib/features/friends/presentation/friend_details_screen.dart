import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../auth/presentation/auth_providers.dart';
import 'friends_provider.dart';
import '../models/friend.dart';

class FriendDetailsScreen extends ConsumerWidget {
  final String friendId;
  const FriendDetailsScreen({super.key, required this.friendId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(visibleFriendsProvider);
    final authState = ref.watch(authProvider);
    final isPrincipal = authState.user?.role == 'principal';

    // Find the friend safely
    final friendIndex = friends.indexWhere((f) => f.id == friendId);
    if (friendIndex == -1) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Access Denied: You do not have permission to view this friend\'s details.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final friend = friends[friendIndex];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(friend.fullName),
          actions: [
            if (isPrincipal) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Profile',
                onPressed: () {
                  context.push('/friends/${friend.id}/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Profile',
                onPressed: () => _confirmDelete(context, ref, friend.id, friend.fullName),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Back to Dashboard',
              onPressed: () {
                final role = ref.read(authProvider).user?.role;
                context.go(_getDashboardRoute(role));
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(24),
              color: AppTheme.primaryColor.withOpacity(0.08),
              child: Row(
                children: [
                  Hero(
                    tag: 'avatar_${friend.id}',
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(friend.photoUrl),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Reg No: ${friend.registrationNumber}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                localizations.translate(friend.assignedWorkshopId),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                friend.status.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.successColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.person), text: 'Demographics'),
                Tab(icon: Icon(Icons.medical_services), text: 'Clinical & Services'),
                Tab(icon: Icon(Icons.family_restroom), text: 'Guardian & Contact'),
              ],
            ),

            // Tab contents
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Demographics
                  _buildDemographicsTab(context, friend, localizations),
                  // Tab 2: Clinical Modules and actions
                  _buildClinicalTab(context, friend, localizations),
                  // Tab 3: Guardian & Contacts
                  _buildGuardianTab(context, friend, localizations),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemographicsTab(BuildContext context, Friend friend, AppLocalizations localizations) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoRow('Full Name', friend.fullName),
        _buildInfoRow('Age', '${friend.age} years old'),
        _buildInfoRow('Gender', friend.gender.toUpperCase()),
        _buildInfoRow('Blood Group', friend.bloodGroup),
        _buildInfoRow('CNIC / B-Form', friend.cnicOrBForm ?? 'N/A'),
        _buildInfoRow('Admission Date', '${friend.admissionDate.day}/${friend.admissionDate.month}/${friend.admissionDate.year}'),
        _buildInfoRow('Assigned Workshop', localizations.translate(friend.assignedWorkshopId)),
        _buildInfoRow('Medical Briefing Note', friend.medicalNotesSummary),
      ],
    );
  }

  Widget _buildClinicalTab(BuildContext context, Friend friend, AppLocalizations localizations) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Active Rehabilitation Modules',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        
        _buildClinicalActionTile(
          context,
          title: 'Individual Education Plan (IEP)',
          subtitle: 'Active goals and progress tracker',
          icon: Icons.assignment_outlined,
          color: Colors.blue.shade700,
          route: '/iep/${friend.id}',
        ),
        _buildClinicalActionTile(
          context,
          title: 'Physiotherapy Profile',
          subtitle: 'Range of Motion, Exercises, Muscle assessment',
          icon: Icons.accessibility_new,
          color: Colors.green.shade700,
          route: '/therapy/physiotherapy/${friend.id}',
        ),
        _buildClinicalActionTile(
          context,
          title: 'Speech Therapy Profile',
          subtitle: 'Speech goals and language progression log',
          icon: Icons.record_voice_over,
          color: Colors.amber.shade800,
          route: '/therapy/speech/${friend.id}',
        ),
        _buildClinicalActionTile(
          context,
          title: 'Medical Health Record',
          subtitle: 'Vitals history, clinical checks and prescriptions',
          icon: Icons.medical_services_outlined,
          color: Colors.red.shade700,
          route: '/medical/${friend.id}',
        ),
      ],
    );
  }

  Widget _buildGuardianTab(BuildContext context, Friend friend, AppLocalizations localizations) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Primary Guardian Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _buildInfoRow('Name', friend.guardianName),
        _buildInfoRow('Relation', friend.guardianRelation),
        _buildInfoRow('Phone', friend.guardianPhone),
        _buildInfoRow('Email', friend.guardianEmail),
        _buildInfoRow('Address', friend.guardianAddress),
        
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Emergency Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _buildInfoRow('Contact Person', friend.emergencyName),
        _buildInfoRow('Relation', friend.emergencyRelation),
        _buildInfoRow('Emergency Phone', friend.emergencyPhone),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildClinicalActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          context.push(route);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to permanently delete $name\'s records from RAMS? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: () {
              ref.read(friendsProvider.notifier).deleteFriend(id);
              Navigator.pop(context); // Close dialog
              context.go('/friends'); // Go back to directory
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getDashboardRoute(String? role) {
    switch (role) {
      case 'admin':
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
