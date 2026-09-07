import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend.dart';
import '../../../core/storage/hive_storage.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/supabase_db_service.dart';

class FriendsNotifier extends StateNotifier<List<Friend>> {
  FriendsNotifier() : super([]) {
    _loadFriends();
  }

  SupabaseClient get _client => Supabase.instance.client;

  bool get _isSupabaseConfigured => SupabaseDbService.isConfigured;

  Map<String, dynamic> _toDbMap(Friend friend) {
    return {
      'id': friend.id,
      'registration_number': friend.registrationNumber,
      'full_name': friend.fullName,
      'photo_url': friend.photoUrl,
      'date_of_birth': friend.dateOfBirth.toIso8601String().split('T')[0],
      'gender': friend.gender == 'other' ? 'other' : friend.gender,
      'blood_group': friend.bloodGroup,
      'cnic_or_bform': friend.cnicOrBForm,
      'admission_date': friend.admissionDate.toIso8601String().split('T')[0],
      'assigned_workshop_id': friend.assignedWorkshopId, 
      'assigned_house_id': friend.assignedHouseId,
      'status': friend.status,
      'guardian_name': friend.guardianName,
      'guardian_relation': friend.guardianRelation,
      'guardian_phone': friend.guardianPhone,
      'guardian_email': friend.guardianEmail,
      'guardian_address': friend.guardianAddress,
      'emergency_name': friend.emergencyName,
      'emergency_relation': friend.emergencyRelation,
      'emergency_phone': friend.emergencyPhone,
      'medical_notes_summary': friend.medicalNotesSummary,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Friend _fromDbMap(Map<String, dynamic> json) {
    return Friend(
      id: json['id']?.toString() ?? '',
      registrationNumber: json['registration_number']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString() ?? '',
      dateOfBirth: json['date_of_birth'] != null ? (DateTime.tryParse(json['date_of_birth'].toString()) ?? DateTime.now()) : DateTime.now(),
      gender: json['gender']?.toString() ?? 'male',
      bloodGroup: json['blood_group']?.toString() ?? 'A+',
      cnicOrBForm: json['cnic_or_bform']?.toString(),
      admissionDate: json['admission_date'] != null ? (DateTime.tryParse(json['admission_date'].toString()) ?? DateTime.now()) : DateTime.now(),
      assignedWorkshopId: json['assigned_workshop_id']?.toString() ?? 'bakery',
      assignedHouseId: json['assigned_house_id']?.toString() ?? 'amin_house',
      status: json['status']?.toString() ?? 'active',
      guardianName: json['guardian_name']?.toString() ?? '',
      guardianRelation: json['guardian_relation']?.toString() ?? '',
      guardianPhone: json['guardian_phone']?.toString() ?? '',
      guardianEmail: json['guardian_email']?.toString() ?? '',
      guardianAddress: json['guardian_address']?.toString() ?? '',
      emergencyName: json['emergency_name']?.toString() ?? '',
      emergencyRelation: json['emergency_relation']?.toString() ?? '',
      emergencyPhone: json['emergency_phone']?.toString() ?? '',
      medicalNotesSummary: json['medical_notes_summary']?.toString() ?? '',
    );
  }

  static const Set<String> _fakeFriendIds = {
    'friend_ali_khan',
    'friend_fatima_noor',
    'friend_usman_tariq',
    'friend_zainab_bibi',
    'friend_bilal_ahmed',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000005',
  };

  static bool _isFakeFriend(Friend f) {
    final name = f.fullName.trim().toLowerCase();
    return name == 'ali khan' ||
        name == 'fatima noor' ||
        name == 'usman tariq' ||
        name == 'zainab bibi' ||
        name == 'bilal ahmed' ||
        name == 'zainab fatima' ||
        name == 'ali raza' ||
        name == 'ayesha bibi' ||
        name == 'bilal mustafa';
  }

  static List<Friend> getDefaultFriends() {
    return [];
  }

  Future<void> seedDefaultFriends() async {
    // No-op to avoid seeding fake friends
  }

  Future<void> _loadFriends() async {
    try {
      final box = HiveStorage.getBox(HiveStorage.friendsBoxName);

      // Purge any fake friends from local Hive storage immediately
      for (final fakeId in _fakeFriendIds) {
        if (box.containsKey(fakeId)) {
          await box.delete(fakeId);
        }
      }

      // Load local friends from cache (excluding any fake ones)
      final localFriends = box.values
          .map((item) => Friend.fromJson(Map<String, dynamic>.from(item)))
          .where((f) => !_fakeFriendIds.contains(f.id) && !_isFakeFriend(f))
          .toList();

      state = localFriends;
      
      // Attempt Supabase Fetch - Supabase is the single source of truth!
      if (_isSupabaseConfigured) {
        try {
          final List<dynamic> data = await _client
              .from('friends')
              .select()
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 7));

          final remoteFriends = data
              .map((json) => _fromDbMap(Map<String, dynamic>.from(json)))
              .where((f) => !_fakeFriendIds.contains(f.id) && !_isFakeFriend(f))
              .toList();

          // Clear local box and write only remote friends so deleted records never resurrect
          await box.clear();
          for (var f in remoteFriends) {
            await box.put(f.id, f.toJson());
          }

          state = remoteFriends;
          debugPrint('Friends loaded from Supabase: ${remoteFriends.length} friends.');
          return;
        } catch (e) {
          debugPrint('Supabase fetch note: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  Future<void> addFriend(Friend friend) async {
    try {
      final box = HiveStorage.getBox(HiveStorage.friendsBoxName);
      await box.put(friend.id, friend.toJson());
    } catch (_) {}
    state = [...state, friend];

    if (_isSupabaseConfigured) {
      try {
        await _client
            .from('friends')
            .upsert(_toDbMap(friend))
            .timeout(const Duration(seconds: 5));
        debugPrint('Friend added/upserted to Supabase.');
      } catch (e) {
        debugPrint('Supabase add failed (saved locally only): $e');
      }
    }
  }

  Future<void> updateFriend(Friend friend) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final box = HiveStorage.getBox(HiveStorage.friendsBoxName);
    await box.put(friend.id, friend.toJson());
    state = [
      for (var f in state)
        if (f.id == friend.id) friend else f
    ];

    if (_isSupabaseConfigured) {
      try {
        await _client
            .from('friends')
            .upsert(_toDbMap(friend))
            .timeout(const Duration(seconds: 5));
        debugPrint('Friend updated in Supabase.');
      } catch (e) {
        debugPrint('Supabase update failed (saved locally only): $e');
      }
    }
  }

  Future<void> deleteFriend(String id) async {
    final box = HiveStorage.getBox(HiveStorage.friendsBoxName);
    await box.delete(id);
    state = state.where((f) => f.id != id).toList();

    if (_isSupabaseConfigured) {
      try {
        await _client.from('friends').delete().eq('id', id);
        debugPrint('Friend deleted from Supabase.');
      } catch (e) {
        debugPrint('Supabase delete failed (deleted locally only): $e');
      }
    }
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, List<Friend>>((ref) {
  return FriendsNotifier();
});

final visibleFriendsProvider = Provider<List<Friend>>((ref) {
  final friends = ref.watch(friendsProvider);
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user != null) {
    if (user.role == 'workshop_staff') {
      return friends.where((f) => f.assignedWorkshopId == user.workshopId).toList();
    } else if (user.role == 'house_staff') {
      return friends.where((f) => f.assignedHouseId == user.workshopId).toList();
    }
  }
  return friends;
});
