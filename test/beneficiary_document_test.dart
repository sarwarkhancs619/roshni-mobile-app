import 'package:flutter_test/flutter_test.dart';
import 'package:roshni_rams/features/friends/models/beneficiary_document.dart';

void main() {
  group('BeneficiaryDocument Unit Tests', () {
    test('BeneficiaryDocument JSON serialization and deserialization', () {
      final now = DateTime(2026, 9, 3, 12, 0, 0);
      final doc = BeneficiaryDocument(
        id: 'doc-123',
        friendId: 'friend-456',
        documentType: 'admission_form',
        title: 'Admission Form',
        fileUrl: 'https://example.com/admission.pdf',
        fileName: 'admission.pdf',
        fileType: 'pdf',
        uploadedAt: now,
        uploadedBy: 'Tariq Alvi (Principal)',
      );

      final json = doc.toJson();
      expect(json['id'], 'doc-123');
      expect(json['friendId'], 'friend-456');
      expect(json['documentType'], 'admission_form');
      expect(json['title'], 'Admission Form');
      expect(json['fileType'], 'pdf');

      final deserialized = BeneficiaryDocument.fromJson(json);
      expect(deserialized.id, doc.id);
      expect(deserialized.friendId, doc.friendId);
      expect(deserialized.documentType, doc.documentType);
      expect(deserialized.title, doc.title);
      expect(deserialized.fileUrl, doc.fileUrl);
      expect(deserialized.uploadedBy, doc.uploadedBy);
    });

    test('toDbMap produces valid snake_case keys for database', () {
      final doc = BeneficiaryDocument(
        id: 'doc-999',
        friendId: 'friend-777',
        documentType: 'undertaking',
        title: 'Guardian Undertaking Form',
        fileUrl: 'https://example.com/undertaking.pdf',
        fileName: 'undertaking.pdf',
        fileType: 'pdf',
        uploadedAt: DateTime.now(),
        uploadedBy: 'Principal',
      );

      final dbMap = doc.toDbMap();
      expect(dbMap['friend_id'], 'friend-777');
      expect(dbMap['document_type'], 'undertaking');
      expect(dbMap['file_url'], 'https://example.com/undertaking.pdf');
      expect(dbMap['file_name'], 'undertaking.pdf');
      expect(dbMap['uploaded_by'], 'Principal');
      expect(dbMap['created_at'], isNotNull);
    });
  });
}
