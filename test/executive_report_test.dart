import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:roshni_rams/features/friends/models/friend.dart';
import 'package:roshni_rams/features/friends/models/beneficiary_document.dart';
import 'package:roshni_rams/features/reports/domain/executive_report_builder.dart';

void main() {
  group('ExecutiveReportBuilder Unit Tests', () {
    final mockFriends = [
      Friend(
        id: 'f1',
        registrationNumber: 'RAMS-2026-0001',
        fullName: 'Zainab Fatima',
        photoUrl: '',
        dateOfBirth: DateTime(2002, 5, 10),
        gender: 'female',
        bloodGroup: 'A+',
        admissionDate: DateTime(2022, 1, 1),
        assignedWorkshopId: 'bakery',
        assignedHouseId: 'sunbal_house',
        status: 'active',
        guardianName: 'Fatima Sr.',
        guardianRelation: 'Mother',
        guardianPhone: '+92 300 1111111',
        guardianEmail: '',
        guardianAddress: 'Lahore',
        emergencyName: 'Ali',
        emergencyRelation: 'Brother',
        emergencyPhone: '+92 300 2222222',
        medicalNotesSummary: 'Mild cognitive challenges, excellent in baking.',
      ),
      Friend(
        id: 'f2',
        registrationNumber: 'RAMS-2026-0002',
        fullName: 'Ali Raza',
        photoUrl: '',
        dateOfBirth: DateTime(1999, 8, 20),
        gender: 'male',
        bloodGroup: 'B+',
        admissionDate: DateTime(2021, 6, 15),
        assignedWorkshopId: 'woodwork',
        assignedHouseId: 'roshni_house',
        status: 'active',
        guardianName: 'Raza Sr.',
        guardianRelation: 'Father',
        guardianPhone: '+92 300 3333333',
        guardianEmail: '',
        guardianAddress: 'Lahore',
        emergencyName: 'Hamza',
        emergencyRelation: 'Brother',
        emergencyPhone: '+92 300 4444444',
        medicalNotesSummary: 'Carpentry precision.',
      ),
      Friend(
        id: 'f3',
        registrationNumber: 'RAMS-2026-0003',
        fullName: 'Usman Tariq',
        photoUrl: '',
        dateOfBirth: DateTime(2001, 11, 5),
        gender: 'male',
        bloodGroup: 'O+',
        admissionDate: DateTime(2023, 2, 1),
        assignedWorkshopId: 'farming',
        assignedHouseId: 'sunbal_house',
        status: 'active',
        guardianName: 'Tariq',
        guardianRelation: 'Father',
        guardianPhone: '+92 300 5555555',
        guardianEmail: '',
        guardianAddress: 'Lahore',
        emergencyName: 'Tariq',
        emergencyRelation: 'Father',
        emergencyPhone: '+92 300 5555555',
        medicalNotesSummary: 'Great with organic gardening.',
      ),
    ];

    final mockDocs = [
      BeneficiaryDocument(
        id: 'doc1',
        friendId: 'f1',
        documentType: 'admission_form',
        title: 'Initial Admission Form',
        fileUrl: 'https://example.com/admission.pdf',
        fileName: 'admission.pdf',
        fileType: 'pdf',
        uploadedAt: DateTime(2022, 1, 1),
        uploadedBy: 'Tariq Alvi (Principal)',
      ),
    ];

    test('getWorkshopSkills returns correct skills for all workshops', () {
      final bakerySkills = ExecutiveReportBuilder.getWorkshopSkills('bakery');
      expect(bakerySkills, contains('Mixing'));
      expect(bakerySkills, contains('Baking'));

      final woodworkSkills = ExecutiveReportBuilder.getWorkshopSkills('woodwork');
      expect(woodworkSkills, contains('Sanding'));
      expect(woodworkSkills, contains('Cutting'));

      final sportsSkills = ExecutiveReportBuilder.getWorkshopSkills('sports');
      expect(sportsSkills, contains('Physical Fitness'));
    });

    test('getWorkshopData aggregates headcount and metrics correctly', () {
      final data = ExecutiveReportBuilder.getWorkshopData('bakery', mockFriends);
      expect(data.id, 'bakery');
      expect(data.name, 'Bakery Workshop');
      expect(data.enrolledBeneficiaries.length, 1);
      expect(data.enrolledBeneficiaries.first.fullName, 'Zainab Fatima');
      expect(data.capacity, 15);
      expect(data.averageParticipation, greaterThanOrEqualTo(0.0));
      expect(data.averageAttendanceRate, greaterThanOrEqualTo(0.0));
    });

    test('getAllWorkshopsData compiles all 6 vocational workshops', () {
      final allWs = ExecutiveReportBuilder.getAllWorkshopsData(mockFriends);
      expect(allWs.length, 6);
      final ids = allWs.map((w) => w.id).toList();
      expect(ids, containsAll(['bakery', 'woodwork', 'farming', 'textile', 'artwork', 'sports']));
    });

    test('generatePdf produces valid non-empty PDF bytes for all 4 scopes', () async {
      // 1. Single Beneficiary
      final pdfSingle = await ExecutiveReportBuilder.generatePdf(
        scope: ReportScope.singleBeneficiary,
        allFriends: mockFriends,
        allDocs: mockDocs,
        selectedFriend: mockFriends.first,
        principalName: 'Tariq Alvi (Principal)',
      );
      expect(pdfSingle.isNotEmpty, true);
      expect(pdfSingle.length, greaterThan(100));

      // 2. One Workshop
      final pdfOneWs = await ExecutiveReportBuilder.generatePdf(
        scope: ReportScope.oneWorkshop,
        allFriends: mockFriends,
        allDocs: mockDocs,
        selectedWorkshopId: 'bakery',
        principalName: 'Tariq Alvi (Principal)',
      );
      expect(pdfOneWs.isNotEmpty, true);

      // 3. All Workshops
      final pdfAllWs = await ExecutiveReportBuilder.generatePdf(
        scope: ReportScope.allWorkshops,
        allFriends: mockFriends,
        allDocs: mockDocs,
        principalName: 'Tariq Alvi (Principal)',
      );
      expect(pdfAllWs.isNotEmpty, true);

      // 4. All Beneficiaries
      final pdfAllFriends = await ExecutiveReportBuilder.generatePdf(
        scope: ReportScope.allBeneficiaries,
        allFriends: mockFriends,
        allDocs: mockDocs,
        principalName: 'Tariq Alvi (Principal)',
      );
      expect(pdfAllFriends.isNotEmpty, true);
    });

    test('generateCsv produces valid readable CSV strings for all 4 scopes', () {
      // Single Beneficiary
      final csvSingle = ExecutiveReportBuilder.generateCsv(
        scope: ReportScope.singleBeneficiary,
        allFriends: mockFriends,
        allDocs: mockDocs,
        selectedFriend: mockFriends.first,
      );
      final singleStr = utf8.decode(csvSingle);
      expect(singleStr, contains('Zainab Fatima'));
      expect(singleStr, contains('RAMS-2026-0001'));

      // One Workshop
      final csvOneWs = ExecutiveReportBuilder.generateCsv(
        scope: ReportScope.oneWorkshop,
        allFriends: mockFriends,
        allDocs: mockDocs,
        selectedWorkshopId: 'bakery',
      );
      final oneWsStr = utf8.decode(csvOneWs);
      expect(oneWsStr, contains('Bakery Workshop'));

      // All Workshops
      final csvAllWs = ExecutiveReportBuilder.generateCsv(
        scope: ReportScope.allWorkshops,
        allFriends: mockFriends,
        allDocs: mockDocs,
      );
      final allWsStr = utf8.decode(csvAllWs);
      expect(allWsStr, contains('ALL WORKSHOPS COMPARATIVE AUDIT'));

      // All Beneficiaries
      final csvAllFriends = ExecutiveReportBuilder.generateCsv(
        scope: ReportScope.allBeneficiaries,
        allFriends: mockFriends,
        allDocs: mockDocs,
      );
      final allFriendsStr = utf8.decode(csvAllFriends);
      expect(allFriendsStr, contains('MASTER BENEFICIARY ROSTER'));
      expect(allFriendsStr, contains('Usman Tariq'));
    });
  });
}
