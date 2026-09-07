class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final String? workshopId;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.workshopId,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? '',
      workshopId: json['workshopId'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role,
      'workshopId': workshopId,
      'isActive': isActive,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? role,
    String? workshopId,
    bool? isActive,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      workshopId: workshopId ?? this.workshopId,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Strips any legacy "(Admin)" or "(Principal)" suffix if already embedded in fullName
  String get cleanFullName {
    final cleaned = fullName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    return cleaned.isNotEmpty ? cleaned : fullName;
  }

  /// User-friendly label for the role
  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'principal':
        return 'Principal';
      case 'workshop_staff':
        return 'Workshop Staff';
      case 'house_staff':
        return 'House Staff';
      case 'physiotherapist':
        return 'Physiotherapist';
      case 'speech_therapist':
        return 'Speech Therapist';
      case 'medical_officer':
        return 'Medical Officer';
      default:
        return role.isNotEmpty
            ? '${role[0].toUpperCase()}${role.substring(1).replaceAll('_', ' ')}'
            : 'Staff';
    }
  }

  /// Formatted name with role in braces: e.g. "Sarwar Khan (Principal)" or "Sarwar Khan (Admin)"
  String get displayNameWithRole {
    final clean = cleanFullName;
    return '$clean ($roleDisplayName)';
  }
}
