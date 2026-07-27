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
}
