class BeneficiaryDocument {
  final String id;
  final String friendId;
  final String documentType; // 'admission_form', 'profile_form', 'undertaking', 'picture', 'other'
  final String title;
  final String fileUrl;
  final String fileName;
  final String fileType; // 'pdf', 'image'
  final DateTime uploadedAt;
  final String uploadedBy;

  BeneficiaryDocument({
    required this.id,
    required this.friendId,
    required this.documentType,
    required this.title,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  factory BeneficiaryDocument.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) {
        return DateTime.tryParse(val.toString()) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BeneficiaryDocument(
      id: json['id']?.toString() ?? '',
      friendId: (json['friendId'] ?? json['friend_id'] ?? '')?.toString() ?? '',
      documentType: (json['documentType'] ?? json['document_type'] ?? 'other')?.toString() ?? 'other',
      title: json['title']?.toString() ?? '',
      fileUrl: (json['fileUrl'] ?? json['file_url'] ?? '')?.toString() ?? '',
      fileName: (json['fileName'] ?? json['file_name'] ?? '')?.toString() ?? '',
      fileType: (json['fileType'] ?? json['file_type'] ?? 'pdf')?.toString() ?? 'pdf',
      uploadedAt: parseDate(json['uploadedAt'] ?? json['created_at']),
      uploadedBy: (json['uploadedBy'] ?? json['uploaded_by'] ?? '')?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friendId': friendId,
      'documentType': documentType,
      'title': title,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'uploadedAt': uploadedAt.toIso8601String(),
      'uploadedBy': uploadedBy,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'friend_id': friendId,
      'document_type': documentType,
      'title': title,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_type': fileType,
      'uploaded_by': uploadedBy,
      'created_at': uploadedAt.toIso8601String(),
    };
  }
}
