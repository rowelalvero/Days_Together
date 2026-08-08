class RelationshipMetadata {
  final String coupleId;
  final String? certificateNumber;
  final DateTime? issueDate;
  final DateTime? anniversary;
  final String? theme;
  final String? relationshipTitle;

  RelationshipMetadata({
    required this.coupleId,
    this.certificateNumber,
    this.issueDate,
    this.anniversary,
    this.theme,
    this.relationshipTitle,
  });

  factory RelationshipMetadata.fromMap(Map<String, dynamic> map) {
    return RelationshipMetadata(
      coupleId: map['couple_id'] as String,
      certificateNumber: map['certificate_number'] as String?,
      issueDate: map['issue_date'] != null ? DateTime.parse(map['issue_date'] as String) : null,
      anniversary: map['anniversary'] != null ? DateTime.parse(map['anniversary'] as String) : null,
      theme: map['theme'] as String?,
      relationshipTitle: map['relationship_title'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'couple_id': coupleId,
      'certificate_number': certificateNumber,
      'issue_date': issueDate?.toIso8601String(),
      'anniversary': anniversary?.toIso8601String(),
      'theme': theme,
      'relationship_title': relationshipTitle,
    };
  }

  RelationshipMetadata copyWith({
    String? coupleId,
    String? certificateNumber,
    DateTime? issueDate,
    DateTime? anniversary,
    String? theme,
    String? relationshipTitle,
  }) {
    return RelationshipMetadata(
      coupleId: coupleId ?? this.coupleId,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      issueDate: issueDate ?? this.issueDate,
      anniversary: anniversary ?? this.anniversary,
      theme: theme ?? this.theme,
      relationshipTitle: relationshipTitle ?? this.relationshipTitle,
    );
  }
}
