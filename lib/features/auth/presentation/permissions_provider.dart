import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/permission_request.dart';
import '../../../core/storage/hive_storage.dart';
import '../presentation/auth_providers.dart';

class PermissionsNotifier extends StateNotifier<List<PermissionRequest>> {
  PermissionsNotifier() : super([]) {
    _loadPermissions();
  }

  void _loadPermissions() {
    final box = HiveStorage.getBox(HiveStorage.permissionsBoxName);
    final list = box.values
        .map((item) => PermissionRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    state = list;
  }

  Future<void> requestPermission({
    required String requesterId,
    required String requesterName,
    required String studentId,
    required String studentName,
    required String module,
  }) async {
    // Check if there is already a pending or active request to avoid duplicates
    final existing = state.any((req) =>
        req.requesterId == requesterId &&
        req.studentId == studentId &&
        req.module == module &&
        (req.status == 'pending' || req.isApproved));
    if (existing) return;

    final request = PermissionRequest(
      id: const Uuid().v4(),
      requesterId: requesterId,
      requesterName: requesterName,
      studentId: studentId,
      studentName: studentName,
      module: module,
      status: 'pending',
      requestedAt: DateTime.now(),
    );

    final box = HiveStorage.getBox(HiveStorage.permissionsBoxName);
    await box.put(request.id, request.toJson());
    state = [...state, request];
  }

  Future<void> approvePermission(String id, Duration duration) async {
    final box = HiveStorage.getBox(HiveStorage.permissionsBoxName);
    final index = state.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updated = state[index].copyWith(
        status: 'approved',
        approvedAt: DateTime.now(),
        expiresAt: DateTime.now().add(duration),
      );
      await box.put(id, updated.toJson());
      state = [
        for (var r in state)
          if (r.id == id) updated else r
      ];
    }
  }

  Future<void> rejectPermission(String id) async {
    final box = HiveStorage.getBox(HiveStorage.permissionsBoxName);
    final index = state.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updated = state[index].copyWith(
        status: 'rejected',
      );
      await box.put(id, updated.toJson());
      state = [
        for (var r in state)
          if (r.id == id) updated else r
      ];
    }
  }

  bool hasPermission({
    required String requesterId,
    required String studentId,
    required String module,
  }) {
    // Clean up expired items in state (optional, or just filter)
    return state.any((req) =>
        req.requesterId == requesterId &&
        req.studentId == studentId &&
        req.module == module &&
        req.isApproved);
  }
}

final permissionsProvider = StateNotifierProvider<PermissionsNotifier, List<PermissionRequest>>((ref) {
  return PermissionsNotifier();
});

final hasPermissionProvider = Provider.family<bool, PermissionQueryParams>((ref, params) {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  if (user.role == 'principal') return true; // Principal has absolute access

  final permissions = ref.watch(permissionsProvider);

  // Find any approved, non-expired request in the watched list
  return permissions.any((req) =>
      req.requesterId == user.uid &&
      req.studentId == params.studentId &&
      req.module == params.module &&
      req.isApproved);
});

class PermissionQueryParams {
  final String studentId;
  final String module;

  PermissionQueryParams({required this.studentId, required this.module});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionQueryParams &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          module == other.module;

  @override
  int get hashCode => studentId.hashCode ^ module.hashCode;
}
