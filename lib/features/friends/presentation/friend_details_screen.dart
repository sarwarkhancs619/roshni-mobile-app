import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/utils/image_utils.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/permissions_provider.dart';
import '../../auth/models/permission_request.dart';
import 'friends_provider.dart';
import '../models/friend.dart';
import 'widgets/friend_photo_picker_sheet.dart';

class FriendDetailsScreen extends ConsumerStatefulWidget {
  final String friendId;
  const FriendDetailsScreen({super.key, required this.friendId});

  @override
  ConsumerState<FriendDetailsScreen> createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends ConsumerState<FriendDetailsScreen> {
  String? _overridePhotoUrl;

  Future<void> _updatePhoto(Friend friend, String newUrl) async {
    setState(() {
      _overridePhotoUrl = newUrl;
    });
    final updatedFriend = friend.copyWith(photoUrl: newUrl);
    await ref.read(friendsProvider.notifier).updateFriend(updatedFriend);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(visibleFriendsProvider);
    final authState = ref.watch(authProvider);
    final isPrincipal = authState.user?.role == 'principal' || authState.user?.role == 'admin';
    
    final hasBioPermission = ref.watch(hasPermissionProvider(PermissionQueryParams(studentId: widget.friendId, module: 'bio_data')));
    final hasClinicalPermission = ref.watch(hasPermissionProvider(PermissionQueryParams(studentId: widget.friendId, module: 'clinical')));

    // Find the friend safely
    final friendIndex = friends.indexWhere((f) => f.id == widget.friendId);
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
    final activePhotoUrl = _overridePhotoUrl ?? friend.photoUrl;

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
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: isPrincipal
                              ? () {
                                  showFriendPhotoPickerSheet(
                                    context: context,
                                    currentPhotoUrl: activePhotoUrl,
                                    onPhotoSelected: (newUrl) => _updatePhoto(friend, newUrl),
                                  );
                                }
                              : null,
                          child: CircleAvatar(
                            key: ValueKey('avatar_${widget.friendId}_$activePhotoUrl'),
                            radius: 48,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                            backgroundImage: getAppImageProvider(activePhotoUrl),
                            onBackgroundImageError: (_, __) {},
                            child: getAppImageProvider(activePhotoUrl) == null
                                ? const Icon(Icons.person, size: 48, color: Colors.grey)
                                : null,
                          ),
                        ),
                        if (isPrincipal)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              elevation: 2,
                              shape: const CircleBorder(),
                              color: AppTheme.primaryColor,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  showFriendPhotoPickerSheet(
                                    context: context,
                                    currentPhotoUrl: activePhotoUrl,
                                    onPhotoSelected: (newUrl) => _updatePhoto(friend, newUrl),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(7.0),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                localizations.translate(friend.assignedWorkshopId),
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF60A5FA)
                                      : AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
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
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              indicatorColor: Theme.of(context).colorScheme.primary,
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
                  hasBioPermission
                      ? _buildDemographicsTab(context, friend, localizations)
                      : RestrictedAccessWidget(friendId: friend.id, friendName: friend.fullName, module: 'bio_data'),
                  // Tab 2: Clinical Modules and actions
                  hasClinicalPermission
                      ? _buildClinicalTab(context, friend, localizations)
                      : RestrictedAccessWidget(friendId: friend.id, friendName: friend.fullName, module: 'clinical'),
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

class RestrictedAccessWidget extends ConsumerWidget {
  final String friendId;
  final String friendName;
  final String module; // 'bio_data' or 'clinical'

  const RestrictedAccessWidget({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.module,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final requests = ref.watch(permissionsProvider);

    // Find if there is a request for this module and friend
    final req = requests.firstWhere(
      (r) => r.requesterId == user?.uid && r.studentId == friendId && r.module == module,
      orElse: () => PermissionRequest(
        id: '',
        requesterId: '',
        requesterName: '',
        studentId: '',
        studentName: '',
        module: '',
        status: '',
        requestedAt: DateTime.now(),
      ),
    );

    String statusText = '';
    bool canRequest = true;

    if (req.id.isNotEmpty) {
      if (req.status == 'pending') {
        statusText = 'Access Request Pending Approval';
        canRequest = false;
      } else if (req.status == 'rejected') {
        statusText = 'Access Request Rejected';
      } else if (req.isExpired) {
        statusText = 'Access Expired';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.errorColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'This information is only visible to the Principal. You must request permission to view $friendName\'s ${module == 'bio_data' ? 'Bio Data' : 'clinical records & IEP'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: req.status == 'pending'
                          ? Colors.amber.shade100
                          : (req.status == 'rejected' ? Colors.red.shade100 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: req.status == 'pending'
                            ? Colors.amber.shade900
                            : (req.status == 'rejected' ? Colors.red.shade900 : Colors.grey.shade800),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: canRequest
                      ? () {
                          if (user != null) {
                            ref.read(permissionsProvider.notifier).requestPermission(
                              requesterId: user.uid,
                              requesterName: user.fullName,
                              studentId: friendId,
                              studentName: friendName,
                              module: module,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Access request submitted to Principal.'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(req.id.isNotEmpty && req.status == 'pending' ? 'Request Pending' : 'Request Access'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

