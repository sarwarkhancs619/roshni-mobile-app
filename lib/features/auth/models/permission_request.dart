class PermissionRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String studentId;
  final String studentName;
  final String module; // 'iep', 'bio_data', 'clinical_history', 'all'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? expiresAt;

  PermissionRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.studentId,
    required this.studentName,
    required this.module,
    required this.status,
    required this.requestedAt,
    this.approvedAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isApproved => status == 'approved' && !isExpired;

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json['id'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      module: json['module'] ?? '',
      status: json['status'] ?? 'pending',
      requestedAt: json['requestedAt'] != null 
          ? DateTime.parse(json['requestedAt']) 
          : DateTime.now(),
      approvedAt: json['approvedAt'] != null 
          ? DateTime.parse(json['approvedAt']) 
          : null,
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'studentId': studentId,
      'studentName': studentName,
      'module': module,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  PermissionRequest copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? studentId,
    String? studentName,
    String? module,
    String? status,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? expiresAt,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      module: module ?? this.module,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
