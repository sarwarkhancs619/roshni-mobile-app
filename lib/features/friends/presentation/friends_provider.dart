import 'package:flutter/foundation.dart';
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
    };
  }

  Friend _fromDbMap(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      fullName: json['full_name'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      dateOfBirth: json['date_of_birth'] != null ? DateTime.parse(json['date_of_birth']) : DateTime.now(),
      gender: json['gender'] ?? 'male',
      bloodGroup: json['blood_group'] ?? 'A+',
      cnicOrBForm: json['cnic_or_bform'],
      admissionDate: json['admission_date'] != null ? DateTime.parse(json['admission_date']) : DateTime.now(),
      assignedWorkshopId: json['assigned_workshop_id'] ?? 'bakery',
      assignedHouseId: json['assigned_house_id'] ?? 'amin_house',
      status: json['status'] ?? 'active',
      guardianName: json['guardian_name'] ?? '',
      guardianRelation: json['guardian_relation'] ?? '',
      guardianPhone: json['guardian_phone'] ?? '',
      guardianEmail: json['guardian_email'] ?? '',
      guardianAddress: json['guardian_address'] ?? '',
      emergencyName: json['emergency_name'] ?? '',
      emergencyRelation: json['emergency_relation'] ?? '',
      emergencyPhone: json['emergency_phone'] ?? '',
      medicalNotesSummary: json['medical_notes_summary'] ?? '',
    );
  }

  Future<void> _loadFriends() async {
    final box = HiveStorage.getBox(HiveStorage.friendsBoxName);
    
    // Load local friends first so UI renders immediately
    final localFriends = box.values
        .map((item) => Friend.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    state = localFriends;
    
    // Attempt Supabase Fetch & Sync
    if (_isSupabaseConfigured) {
      try {
        final List<dynamic> data = await _client.from('friends').select();
        final remoteFriends = data.map((json) => _fromDbMap(json)).toList();
        
        final Map<String, Friend> merged = {};
        for (var f in remoteFriends) {
          merged[f.id] = f;
        }
        for (var f in localFriends) {
          if (!merged.containsKey(f.id)) {
            merged[f.id] = f;
            // Async upload local friend to Supabase so it's not lost
            _client.from('friends').insert(_toDbMap(f)).catchError((e) {
              debugPrint('Failed to auto-sync local friend ${f.fullName}: $e');
            });
          }
        }

        final finalFriends = merged.values.toList();
        state = finalFriends;
        
        // Update Hive cache
        await box.clear();
        for (var f in finalFriends) {
          await box.put(f.id, f.toJson());
        }
        debugPrint('Friends loaded and synced with Supabase.');
        return;
      } catch (e) {
        debugPrint('Supabase fetch failed, falling back to Hive cache: $e');
      }
    }

    if (box.isEmpty) {
      // Seed initial dummy data for development
      final initialFriends = [
        Friend(
          id: '00000000-0000-0000-0000-000000000001',
          registrationNumber: 'RAMS-2026-0001',
          fullName: 'Zainab Fatima',
          photoUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
          dateOfBirth: DateTime(2004, 3, 14),
          gender: 'female',
          bloodGroup: 'O+',
          cnicOrBForm: '35201-1234567-8',
          admissionDate: DateTime(2023, 1, 10),
          assignedWorkshopId: 'bakery',
          assignedHouseId: 'amin_house',
          status: 'active',
          guardianName: 'Imran Fatima',
          guardianRelation: 'Father',
          guardianPhone: '0300-1234567',
          guardianEmail: 'imran@example.com',
          guardianAddress: 'Model Town, Lahore',
          emergencyName: 'Imran Fatima',
          emergencyRelation: 'Father',
          emergencyPhone: '0300-1234567',
          medicalNotesSummary: 'Mild developmental delay. Requires supervision during baking mixing processes. No allergies.',
        ),
        Friend(
          id: '00000000-0000-0000-0000-000000000002',
          registrationNumber: 'RAMS-2026-0002',
          fullName: 'Ali Raza',
          photoUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
          dateOfBirth: DateTime(2001, 8, 22),
          gender: 'male',
          bloodGroup: 'B+',
          cnicOrBForm: '35202-8765432-1',
          admissionDate: DateTime(2022, 6, 15),
          assignedWorkshopId: 'woodwork',
          assignedHouseId: 'roshni_house',
          status: 'active',
          guardianName: 'Muhammad Raza',
          guardianRelation: 'Father',
          guardianPhone: '0321-7654321',
          guardianEmail: 'raza@example.com',
          guardianAddress: 'Johar Town, Lahore',
          emergencyName: 'Khadija Bibi',
          emergencyRelation: 'Mother',
          emergencyPhone: '0322-1122334',
          medicalNotesSummary: 'Down Syndrome. Highly active, loves woodwork. Prefers assembling and carving tasks. Monitor hydration.',
        ),
        Friend(
          id: '00000000-0000-0000-0000-000000000003',
          registrationNumber: 'RAMS-2026-0003',
          fullName: 'Usman Tariq',
          photoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
          dateOfBirth: DateTime(1998, 11, 5),
          gender: 'male',
          bloodGroup: 'A-',
          cnicOrBForm: '35201-9988776-5',
          admissionDate: DateTime(2021, 9, 1),
          assignedWorkshopId: 'farming',
          assignedHouseId: 'amin_house',
          status: 'active',
          guardianName: 'Tariq Mahmood',
          guardianRelation: 'Father',
          guardianPhone: '0333-4455667',
          guardianEmail: 'tariq@example.com',
          guardianAddress: 'Gulberg, Lahore',
          emergencyName: 'Tariq Mahmood',
          emergencyRelation: 'Father',
          emergencyPhone: '0333-4455667',
          medicalNotesSummary: 'Autism spectrum. Sensitive to loud noises. Enjoys farming/composting activities.',
        ),
        Friend(
          id: '00000000-0000-0000-0000-000000000004',
          registrationNumber: 'RAMS-2026-0004',
          fullName: 'Ayesha Bibi',
          photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
          dateOfBirth: DateTime(2002, 5, 30),
          gender: 'female',
          bloodGroup: 'AB+',
          cnicOrBForm: '35201-5544332-9',
          admissionDate: DateTime(2024, 2, 20),
          assignedWorkshopId: 'textile',
          assignedHouseId: 'roshni_house',
          status: 'active',
          guardianName: 'Zubaida Bibi',
          guardianRelation: 'Mother',
          guardianPhone: '0312-9988776',
          guardianEmail: 'zubaida@example.com',
          guardianAddress: 'Faisal Town, Lahore',
          emergencyName: 'Sajid Ali',
          emergencyRelation: 'Brother',
          emergencyPhone: '0315-6677889',
          medicalNotesSummary: 'Speech impairment, mild cognitive delay. Excellent focus in stitching and thread cutting.',
        ),
        Friend(
          id: '00000000-0000-0000-0000-000000000005',
          registrationNumber: 'RAMS-2026-0005',
          fullName: 'Bilal Mustafa',
          photoUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
          dateOfBirth: DateTime(2005, 1, 19),
          gender: 'male',
          bloodGroup: 'O-',
          cnicOrBForm: '35203-1122334-5',
          admissionDate: DateTime(2025, 4, 1),
          assignedWorkshopId: 'artwork',
          assignedHouseId: 'roshni_house',
          status: 'active',
          guardianName: 'Mustafa Qureshi',
          guardianRelation: 'Father',
          guardianPhone: '0300-8889990',
          guardianEmail: 'mustafa@example.com',
          guardianAddress: 'DHA Phase 5, Lahore',
          emergencyName: 'Mustafa Qureshi',
          emergencyRelation: 'Father',
          emergencyPhone: '0300-8889990',
          medicalNotesSummary: 'ADHD and cognitive challenge. Highly creative in painting. Requires calming environments.',
        ),
      ];

      for (var f in initialFriends) {
        box.put(f.id, f.toJson());
      }
      state = initialFriends;
    } else {
      state = box.values
          .map((item) => Friend.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  }

  Future<void> addFriend(Friend friend) async {
    final box = HiveStorage.getBox(HiveStorage.friendsBoxName);
    await box.put(friend.id, friend.toJson());
    state = [...state, friend];

    if (_isSupabaseConfigured) {
      try {
        await _client.from('friends').insert(_toDbMap(friend));
        debugPrint('Friend added to Supabase.');
      } catch (e) {
        debugPrint('Supabase add failed (saved locally only): $e');
      }
    }
  }

  Future<void> updateFriend(Friend friend) async {
    final box = HiveStorage.getBox(HiveStorage.friendsBoxName);
    await box.put(friend.id, friend.toJson());
    state = [
      for (var f in state)
        if (f.id == friend.id) friend else f
    ];

    if (_isSupabaseConfigured) {
      try {
        await _client.from('friends').update(_toDbMap(friend)).eq('id', friend.id);
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
