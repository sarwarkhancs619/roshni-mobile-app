import 'package:flutter_test/flutter_test.dart';
import 'package:roshni_rams/features/friends/models/friend.dart';

void main() {
  group('Friend Model Unit Tests', () {
    test('Age calculation is correct for a given birthday', () {
      final birthday = DateTime(2000, 5, 20);
      final friend = Friend(
        id: 'RAMS-test-001',
        registrationNumber: 'RAMS-test-001',
        fullName: 'Test Friend',
        photoUrl: 'https://example.com/photo.jpg',
        dateOfBirth: birthday,
        gender: 'male',
        bloodGroup: 'A+',
        cnicOrBForm: '12345-1234567-1',
        admissionDate: DateTime.now(),
        assignedWorkshopId: 'bakery',
        assignedHouseId: 'sunbal_house',
        status: 'active',
        guardianName: 'Guardian Name',
        guardianRelation: 'Father',
        guardianPhone: '0300-1234567',
        guardianEmail: 'guardian@example.com',
        guardianAddress: 'Test Address',
        emergencyName: 'Emergency Name',
        emergencyRelation: 'Mother',
        emergencyPhone: '0300-7654321',
        medicalNotesSummary: 'No critical notes',
      );

      // Verify that age is calculated correctly based on current time
      final today = DateTime.now();
      int expectedAge = today.year - birthday.year;
      if (today.month < birthday.month ||
          (today.month == birthday.month && today.day < birthday.day)) {
        expectedAge--;
      }

      expect(friend.age, expectedAge);
    });

    test('Friend JSON serialization/deserialization matches keys', () {
      final original = Friend(
        id: 'RAMS-test-002',
        registrationNumber: 'RAMS-test-002',
        fullName: 'Zainab Qaiser',
        photoUrl: 'https://example.com/z.jpg',
        dateOfBirth: DateTime(2004, 3, 14),
        gender: 'female',
        bloodGroup: 'O+',
        admissionDate: DateTime(2023, 1, 10),
        assignedWorkshopId: 'bakery',
        assignedHouseId: 'sunbal_house',
        status: 'active',
        guardianName: 'Qaiser Mahmood',
        guardianRelation: 'Father',
        guardianPhone: '0300-1234567',
        guardianEmail: 'qaiser@example.com',
        guardianAddress: 'Model Town, Lahore',
        emergencyName: 'Qaiser Mahmood',
        emergencyRelation: 'Father',
        emergencyPhone: '0300-1234567',
        medicalNotesSummary: 'Allergies: None',
      );

      final json = original.toJson();
      final reconstructed = Friend.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.fullName, original.fullName);
      expect(reconstructed.dateOfBirth, original.dateOfBirth);
      expect(reconstructed.assignedWorkshopId, original.assignedWorkshopId);
      expect(reconstructed.guardianName, original.guardianName);
    });
  });
}
