class RelationshipWorkspace {
  final String id;
  final String? partnerAId;
  final String? partnerBId;
  final String? partnerAEmail;
  final String? partnerBEmail;
  final String status;
  final String? pairingCode;
  final String? recoveryLookupKey;
  final String? recoveryCodeHash;
  final bool isPremium;
  final DateTime? startDate;
  final int? startTimeHour;
  final int? startTimeMinute;
  final String? storyTitle;
  final DateTime? createdAt;

  RelationshipWorkspace({
    required this.id,
    this.partnerAId,
    this.partnerBId,
    this.partnerAEmail,
    this.partnerBEmail,
    required this.status,
    this.pairingCode,
    this.recoveryLookupKey,
    this.recoveryCodeHash,
    this.isPremium = false,
    this.startDate,
    this.startTimeHour,
    this.startTimeMinute,
    this.storyTitle,
    this.createdAt,
  });

  factory RelationshipWorkspace.fromMap(Map<String, dynamic> map) {
    return RelationshipWorkspace(
      id: map['id'] as String,
      partnerAId: map['partner_a_id'] as String?,
      partnerBId: map['partner_b_id'] as String?,
      partnerAEmail: map['partner_a_email'] as String?,
      partnerBEmail: map['partner_b_email'] as String?,
      status: map['status'] as String? ?? 'waiting',
      pairingCode: map['pairing_code'] as String?,
      recoveryLookupKey: map['recovery_lookup_key'] as String?,
      recoveryCodeHash: map['recovery_code_hash'] as String?,
      isPremium: map['is_premium'] as bool? ?? false,
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date'] as String) : null,
      startTimeHour: map['start_time_hour'] as int?,
      startTimeMinute: map['start_time_minute'] as int?,
      storyTitle: map['story_title'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'partner_a_id': partnerAId,
      'partner_b_id': partnerBId,
      'partner_a_email': partnerAEmail,
      'partner_b_email': partnerBEmail,
      'status': status,
      'pairing_code': pairingCode,
      'recovery_lookup_key': recoveryLookupKey,
      'recovery_code_hash': recoveryCodeHash,
      'is_premium': isPremium,
      'start_date': startDate?.toIso8601String(),
      'start_time_hour': startTimeHour,
      'start_time_minute': startTimeMinute,
      'story_title': storyTitle,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  RelationshipWorkspace copyWith({
    String? id,
    String? partnerAId,
    String? partnerBId,
    String? partnerAEmail,
    String? partnerBEmail,
    String? status,
    String? pairingCode,
    String? recoveryLookupKey,
    String? recoveryCodeHash,
    bool? isPremium,
    DateTime? startDate,
    int? startTimeHour,
    int? startTimeMinute,
    String? storyTitle,
    DateTime? createdAt,
  }) {
    return RelationshipWorkspace(
      id: id ?? this.id,
      partnerAId: partnerAId ?? this.partnerAId,
      partnerBId: partnerBId ?? this.partnerBId,
      partnerAEmail: partnerAEmail ?? this.partnerAEmail,
      partnerBEmail: partnerBEmail ?? this.partnerBEmail,
      status: status ?? this.status,
      pairingCode: pairingCode ?? this.pairingCode,
      recoveryLookupKey: recoveryLookupKey ?? this.recoveryLookupKey,
      recoveryCodeHash: recoveryCodeHash ?? this.recoveryCodeHash,
      isPremium: isPremium ?? this.isPremium,
      startDate: startDate ?? this.startDate,
      startTimeHour: startTimeHour ?? this.startTimeHour,
      startTimeMinute: startTimeMinute ?? this.startTimeMinute,
      storyTitle: storyTitle ?? this.storyTitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
