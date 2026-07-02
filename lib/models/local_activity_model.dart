class LocalActivity {
  final String id;
  final String activityType; // e.g., 'created', 'completed', 'updated', etc.
  final String title;
  final String description;
  final String icon;
  final DateTime timestamp;
  final String? referenceId; // Optional ID pointing to the feature item (e.g. bucket item ID)
  final String? route; // Optional navigation route/deep link
  final bool initiatedByCurrentUser; // Distinguish local action vs partner's actions (if any)

  LocalActivity({
    required this.id,
    required this.activityType,
    required this.title,
    required this.description,
    required this.icon,
    required this.timestamp,
    this.referenceId,
    this.route,
    required this.initiatedByCurrentUser,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_type': activityType,
      'title': title,
      'description': description,
      'icon': icon,
      'timestamp': timestamp.toIso8601String(),
      'reference_id': referenceId,
      'route': route,
      'initiated_by_current_user': initiatedByCurrentUser ? 1 : 0,
    };
  }

  factory LocalActivity.fromMap(Map<String, dynamic> map) {
    return LocalActivity(
      id: map['id'] as String,
      activityType: map['activity_type'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      referenceId: map['reference_id'] as String?,
      route: map['route'] as String?,
      initiatedByCurrentUser: (map['initiated_by_current_user'] as int) == 1,
    );
  }
}
