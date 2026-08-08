class UserProfile {
  final String id;
  final String? coupleId;
  final String? displayName;
  final String? avatarUrl;
  final String? gender;
  final String? phone;
  final DateTime? birthdate;
  final String? address;
  final String? nationality;
  final String? weight;
  final String? height;
  final String? bloodType;
  final String? eyeColor;
  final String? conditions;
  final DateTime? dateIssued;
  final String? signature;
  final String? currentActivity;
  final bool partnerDeletedNotice;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.coupleId,
    this.displayName,
    this.avatarUrl,
    this.gender,
    this.phone,
    this.birthdate,
    this.address,
    this.nationality,
    this.weight,
    this.height,
    this.bloodType,
    this.eyeColor,
    this.conditions,
    this.dateIssued,
    this.signature,
    this.currentActivity,
    this.partnerDeletedNotice = false,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      coupleId: map['couple_id'] as String?,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      gender: map['gender'] as String?,
      phone: map['phone'] as String?,
      birthdate: map['birthdate'] != null ? DateTime.parse(map['birthdate'] as String) : null,
      address: map['address'] as String?,
      nationality: map['nationality'] as String?,
      weight: map['weight'] as String?,
      height: map['height'] as String?,
      bloodType: map['blood_type'] as String?,
      eyeColor: map['eye_color'] as String?,
      conditions: map['conditions'] as String?,
      dateIssued: map['date_issued'] != null ? DateTime.parse(map['date_issued'] as String) : null,
      signature: map['signature'] as String?,
      currentActivity: map['current_activity'] as String?,
      partnerDeletedNotice: map['partner_deleted_notice'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'couple_id': coupleId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'gender': gender,
      'phone': phone,
      'birthdate': birthdate?.toIso8601String(),
      'address': address,
      'nationality': nationality,
      'weight': weight,
      'height': height,
      'blood_type': bloodType,
      'eye_color': eyeColor,
      'conditions': conditions,
      'date_issued': dateIssued?.toIso8601String(),
      'signature': signature,
      'current_activity': currentActivity,
      'partner_deleted_notice': partnerDeletedNotice,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? coupleId,
    String? displayName,
    String? avatarUrl,
    String? gender,
    String? phone,
    DateTime? birthdate,
    String? address,
    String? nationality,
    String? weight,
    String? height,
    String? bloodType,
    String? eyeColor,
    String? conditions,
    DateTime? dateIssued,
    String? signature,
    String? currentActivity,
    bool? partnerDeletedNotice,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      birthdate: birthdate ?? this.birthdate,
      address: address ?? this.address,
      nationality: nationality ?? this.nationality,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bloodType: bloodType ?? this.bloodType,
      eyeColor: eyeColor ?? this.eyeColor,
      conditions: conditions ?? this.conditions,
      dateIssued: dateIssued ?? this.dateIssued,
      signature: signature ?? this.signature,
      currentActivity: currentActivity ?? this.currentActivity,
      partnerDeletedNotice: partnerDeletedNotice ?? this.partnerDeletedNotice,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
