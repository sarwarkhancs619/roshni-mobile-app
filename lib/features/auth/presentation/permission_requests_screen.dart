import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../models/permission_request.dart';
import 'permissions_provider.dart';

class PermissionRequestsScreen extends ConsumerWidget {
  const PermissionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(permissionsProvider);
    final pendingRequests = requests.where((r) => r.status == 'pending').toList();
    final activeRequests = requests.where((r) => r.status == 'approved' && !r.isExpired).toList();
    final historyRequests = requests.where((r) => r.status == 'rejected' || (r.status == 'approved' && r.isExpired)).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Access Permissions Manager'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.blueOrangeGradient,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Pending Requests'),
              Tab(text: 'Active Permissions'),
              Tab(text: 'History / Expired'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsList(context, ref, pendingRequests, isPending: true),
            _buildRequestsList(context, ref, activeRequests, isActive: true),
            _buildRequestsList(context, ref, historyRequests, isHistory: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    WidgetRef ref,
    List<PermissionRequest> list, {
    bool isPending = false,
    bool isActive = false,
    bool isHistory = false,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.verified_user_outlined : (isPending ? Icons.rule_folder_outlined : Icons.history_toggle_off),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? 'No active permissions.'
                  : (isPending ? 'No pending requests.' : 'No permission history.'),
              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final req = list[index];
        final isClinical = req.module == 'clinical';
        final displayModule = isClinical ? 'Clinical & IEP' : 'Bio Data / Demographics';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      req.requesterName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    _buildStatusChip(req),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Student: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    Text(req.studentName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Requested: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    Text(displayModule, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                if (isActive && req.expiresAt != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Expires: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text(
                        _formatTimeRemaining(req.expiresAt!),
                        style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                if (isHistory && req.expiresAt != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.event_busy, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Expired At: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text(
                        '${req.expiresAt!.day}/${req.expiresAt!.month} ${req.expiresAt!.hour}:${req.expiresAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                        onPressed: () => ref.read(permissionsProvider.notifier).rejectPermission(req.id),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                        onPressed: () => _showGrantDurationDialog(context, ref, req),
                        icon: const Icon(Icons.check),
                        label: const Text('Grant Access'),
                      ),
                    ],
                  ),
                ] else if (isActive) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      onPressed: () => ref.read(permissionsProvider.notifier).rejectPermission(req.id),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Revoke Access Now'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(PermissionRequest req) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    String label = req.status;

    if (req.status == 'pending') {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      label = 'Pending';
    } else if (req.status == 'approved') {
      if (req.isExpired) {
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'Expired';
      } else {
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        label = 'Active';
      }
    } else if (req.status == 'rejected') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
      label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  void _showGrantDurationDialog(BuildContext context, WidgetRef ref, PermissionRequest req) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Access Duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How long should ${req.requesterName} have access to ${req.studentName}\'s data?'),
              const SizedBox(height: 20),
              _buildDurationOption(context, ref, req.id, '1 Hour', const Duration(hours: 1)),
              _buildDurationOption(context, ref, req.id, '4 Hours', const Duration(hours: 4)),
              _buildDurationOption(context, ref, req.id, '1 Day (24 Hours)', const Duration(days: 1)),
              _buildDurationOption(context, ref, req.id, '3 Days', const Duration(days: 3)),
              _buildDurationOption(context, ref, req.id, '1 Week', const Duration(days: 7)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDurationOption(
    BuildContext context,
    WidgetRef ref,
    String reqId,
    String label,
    Duration duration,
  ) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        ref.read(permissionsProvider.notifier).approvePermission(reqId, duration);
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access granted for $label.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      },
    );
  }

  String _formatTimeRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h remaining';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    return '${diff.inMinutes}m remaining';
  }
}
