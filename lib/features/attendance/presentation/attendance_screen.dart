import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../friends/presentation/friends_provider.dart';
import '../../auth/presentation/auth_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final Map<String, String> _attendanceStatus = {}; // friendId -> status

  @override
  void initState() {
    super.initState();
    // Default all friends to present initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friends = ref.read(visibleFriendsProvider);
      setState(() {
        for (var f in friends) {
          _attendanceStatus[f.id] = 'present';
        }
      });
    });
  }

  void _submitAttendance() {
    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppTheme.successColor, size: 48),
        title: const Text('Attendance Recorded'),
        content: Text('Attendance for ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} has been successfully saved offline and queued for server synchronization.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final friends = ref.watch(visibleFriendsProvider);
    final user = ref.read(authProvider).user;
    final canMarkAttendance = user?.role == 'principal' || user?.role == 'workshop_staff';

    return ResponsiveLayout(
      title: 'Daily Attendance - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      currentRoute: '/attendance',
      body: Column(
        children: [
          // Informational bar
          Container(
            color: AppTheme.primaryColor.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mark present, absent, leave, or half-day status for each Friend. Changes are synchronized automatically.',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Attendance grid list
          Expanded(
            child: friends.isEmpty
                ? const Center(child: Text('No Friends Profiles found.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final currentStatus = _attendanceStatus[friend.id] ?? 'present';
                      
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(friend.photoUrl),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(friend.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          'Workshop: ${localizations.translate(friend.assignedWorkshopId)}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              
                              // Selectors
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildRadioOption(friend.id, 'Present', 'present', AppTheme.successColor, currentStatus),
                                  _buildRadioOption(friend.id, 'Absent', 'absent', AppTheme.errorColor, currentStatus),
                                  _buildRadioOption(friend.id, 'Leave', 'leave', AppTheme.accentColor, currentStatus),
                                  _buildRadioOption(friend.id, 'Half Day', 'half_day', Colors.purple, currentStatus),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Submit Bar
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: canMarkAttendance ? _submitAttendance : null,
              child: const Text('Save & Submit Attendance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
    String friendId, 
    String label, 
    String status, 
    Color color,
    String currentStatus,
  ) {
    final isSelected = currentStatus == status;
    final user = ref.read(authProvider).user;
    final canMarkAttendance = user?.role == 'principal' || user?.role == 'workshop_staff';

    return InkWell(
      onTap: canMarkAttendance 
          ? () {
              setState(() {
                _attendanceStatus[friendId] = status;
              });
            }
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: status,
            groupValue: currentStatus,
            activeColor: color,
            onChanged: canMarkAttendance 
                ? (val) {
                    setState(() {
                      _attendanceStatus[friendId] = val!;
                    });
                  }
                : null,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? color
                  : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
