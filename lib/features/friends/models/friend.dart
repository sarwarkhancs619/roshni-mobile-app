class Friend {
  final String id;
  final String registrationNumber;
  final String fullName;
  final String photoUrl;
  final DateTime dateOfBirth;
  final String gender;
  final String bloodGroup;
  final String? cnicOrBForm;
  final DateTime admissionDate;
  final String assignedWorkshopId;
  final String assignedHouseId;
  final String status;
  final String guardianName;
  final String guardianRelation;
  final String guardianPhone;
  final String guardianEmail;
  final String guardianAddress;
  final String emergencyName;
  final String emergencyRelation;
  final String emergencyPhone;
  final String medicalNotesSummary;

  Friend({
    required this.id,
    required this.registrationNumber,
    required this.fullName,
    required this.photoUrl,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    this.cnicOrBForm,
    required this.admissionDate,
    required this.assignedWorkshopId,
    required this.assignedHouseId,
    required this.status,
    required this.guardianName,
    required this.guardianRelation,
    required this.guardianPhone,
    required this.guardianEmail,
    required this.guardianAddress,
    required this.emergencyName,
    required this.emergencyRelation,
    required this.emergencyPhone,
    required this.medicalNotesSummary,
  });

  int get age {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) {
        return DateTime.tryParse(val.toString()) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Friend(
      id: json['id']?.toString() ?? '',
      registrationNumber: json['registrationNumber']?.toString() ?? json['registration_number']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString() ?? json['photo_url']?.toString() ?? '',
      dateOfBirth: parseDate(json['dateOfBirth'] ?? json['date_of_birth']),
      gender: json['gender']?.toString() ?? 'male',
      bloodGroup: json['bloodGroup']?.toString() ?? json['blood_group']?.toString() ?? 'A+',
      cnicOrBForm: json['cnicOrBForm']?.toString() ?? json['cnic_or_bform']?.toString(),
      admissionDate: parseDate(json['admissionDate'] ?? json['admission_date']),
      assignedWorkshopId: json['assignedWorkshopId']?.toString() ?? json['assigned_workshop_id']?.toString() ?? 'bakery',
      assignedHouseId: json['assignedHouseId']?.toString() ?? json['assigned_house_id']?.toString() ?? 'amin_house',
      status: json['status']?.toString() ?? 'active',
      guardianName: json['guardianName']?.toString() ?? json['guardian_name']?.toString() ?? '',
      guardianRelation: json['guardianRelation']?.toString() ?? json['guardian_relation']?.toString() ?? '',
      guardianPhone: json['guardianPhone']?.toString() ?? json['guardian_phone']?.toString() ?? '',
      guardianEmail: json['guardianEmail']?.toString() ?? json['guardian_email']?.toString() ?? '',
      guardianAddress: json['guardianAddress']?.toString() ?? json['guardian_address']?.toString() ?? '',
      emergencyName: json['emergencyName']?.toString() ?? json['emergency_name']?.toString() ?? '',
      emergencyRelation: json['emergencyRelation']?.toString() ?? json['emergency_relation']?.toString() ?? '',
      emergencyPhone: json['emergencyPhone']?.toString() ?? json['emergency_phone']?.toString() ?? '',
      medicalNotesSummary: json['medicalNotesSummary']?.toString() ?? json['medical_notes_summary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'registrationNumber': registrationNumber,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'bloodGroup': bloodGroup,
      'cnicOrBForm': cnicOrBForm,
      'admissionDate': admissionDate.toIso8601String(),
      'assignedWorkshopId': assignedWorkshopId,
      'assignedHouseId': assignedHouseId,
      'status': status,
      'guardianName': guardianName,
      'guardianRelation': guardianRelation,
      'guardianPhone': guardianPhone,
      'guardianEmail': guardianEmail,
      'guardianAddress': guardianAddress,
      'emergencyName': emergencyName,
      'emergencyRelation': emergencyRelation,
      'emergencyPhone': emergencyPhone,
      'medicalNotesSummary': medicalNotesSummary,
    };
  }

  Friend copyWith({
    String? id,
    String? registrationNumber,
    String? fullName,
    String? photoUrl,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? cnicOrBForm,
    DateTime? admissionDate,
    String? assignedWorkshopId,
    String? assignedHouseId,
    String? status,
    String? guardianName,
    String? guardianRelation,
    String? guardianPhone,
    String? guardianEmail,
    String? guardianAddress,
    String? emergencyName,
    String? emergencyRelation,
    String? emergencyPhone,
    String? medicalNotesSummary,
  }) {
    return Friend(
      id: id ?? this.id,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      cnicOrBForm: cnicOrBForm ?? this.cnicOrBForm,
      admissionDate: admissionDate ?? this.admissionDate,
      assignedWorkshopId: assignedWorkshopId ?? this.assignedWorkshopId,
      assignedHouseId: assignedHouseId ?? this.assignedHouseId,
      status: status ?? this.status,
      guardianName: guardianName ?? this.guardianName,
      guardianRelation: guardianRelation ?? this.guardianRelation,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      guardianEmail: guardianEmail ?? this.guardianEmail,
      guardianAddress: guardianAddress ?? this.guardianAddress,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyRelation: emergencyRelation ?? this.emergencyRelation,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      medicalNotesSummary: medicalNotesSummary ?? this.medicalNotesSummary,
    );
  }
}
