class NotificationPreferences {
  final String userId;
  final bool chatEnabled;
  final bool bucketListEnabled;
  final bool loveMeterEnabled;
  final bool dailyPromptEnabled;
  final bool doodleNotesEnabled;
  final bool timelineEnabled;
  final bool timeCapsuleEnabled;
  final bool calendarEnabled;
  final bool loveNotesEnabled;
  final bool vaultEnabled;
  final bool giftsEnabled;
  final bool relationshipEnabled;
  final bool memoriesEnabled;
  final bool muteAll;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool badgeCountEnabled;
  final String timezone;

  NotificationPreferences({
    required this.userId,
    this.chatEnabled = true,
    this.bucketListEnabled = true,
    this.loveMeterEnabled = true,
    this.dailyPromptEnabled = true,
    this.doodleNotesEnabled = true,
    this.timelineEnabled = true,
    this.timeCapsuleEnabled = true,
    this.calendarEnabled = true,
    this.loveNotesEnabled = true,
    this.vaultEnabled = true,
    this.giftsEnabled = true,
    this.relationshipEnabled = true,
    this.memoriesEnabled = true,
    this.muteAll = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.badgeCountEnabled = true,
    this.timezone = 'UTC',
  });

  NotificationPreferences copyWith({
    String? userId,
    bool? chatEnabled,
    bool? bucketListEnabled,
    bool? loveMeterEnabled,
    bool? dailyPromptEnabled,
    bool? doodleNotesEnabled,
    bool? timelineEnabled,
    bool? timeCapsuleEnabled,
    bool? calendarEnabled,
    bool? loveNotesEnabled,
    bool? vaultEnabled,
    bool? giftsEnabled,
    bool? relationshipEnabled,
    bool? memoriesEnabled,
    bool? muteAll,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? badgeCountEnabled,
    String? timezone,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      bucketListEnabled: bucketListEnabled ?? this.bucketListEnabled,
      loveMeterEnabled: loveMeterEnabled ?? this.loveMeterEnabled,
      dailyPromptEnabled: dailyPromptEnabled ?? this.dailyPromptEnabled,
      doodleNotesEnabled: doodleNotesEnabled ?? this.doodleNotesEnabled,
      timelineEnabled: timelineEnabled ?? this.timelineEnabled,
      timeCapsuleEnabled: timeCapsuleEnabled ?? this.timeCapsuleEnabled,
      calendarEnabled: calendarEnabled ?? this.calendarEnabled,
      loveNotesEnabled: loveNotesEnabled ?? this.loveNotesEnabled,
      vaultEnabled: vaultEnabled ?? this.vaultEnabled,
      giftsEnabled: giftsEnabled ?? this.giftsEnabled,
      relationshipEnabled: relationshipEnabled ?? this.relationshipEnabled,
      memoriesEnabled: memoriesEnabled ?? this.memoriesEnabled,
      muteAll: muteAll ?? this.muteAll,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      badgeCountEnabled: badgeCountEnabled ?? this.badgeCountEnabled,
      timezone: timezone ?? this.timezone,
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String? ?? '',
      chatEnabled: json['chat_enabled'] as bool? ?? true,
      bucketListEnabled: json['bucket_list_enabled'] as bool? ?? true,
      loveMeterEnabled: json['love_meter_enabled'] as bool? ?? true,
      dailyPromptEnabled: json['daily_prompt_enabled'] as bool? ?? true,
      doodleNotesEnabled: json['doodle_notes_enabled'] as bool? ?? true,
      timelineEnabled: json['timeline_enabled'] as bool? ?? true,
      timeCapsuleEnabled: json['time_capsule_enabled'] as bool? ?? true,
      calendarEnabled: json['calendar_enabled'] as bool? ?? true,
      loveNotesEnabled: json['love_notes_enabled'] as bool? ?? true,
      vaultEnabled: json['vault_enabled'] as bool? ?? true,
      giftsEnabled: json['gifts_enabled'] as bool? ?? true,
      relationshipEnabled: json['relationship_enabled'] as bool? ?? true,
      memoriesEnabled: json['memories_enabled'] as bool? ?? true,
      muteAll: json['mute_all'] as bool? ?? false,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String? ?? '22:00',
      quietHoursEnd: json['quiet_hours_end'] as String? ?? '07:00',
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      vibrationEnabled: json['vibration_enabled'] as bool? ?? true,
      badgeCountEnabled: json['badge_count_enabled'] as bool? ?? true,
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'chat_enabled': chatEnabled,
      'bucket_list_enabled': bucketListEnabled,
      'love_meter_enabled': loveMeterEnabled,
      'daily_prompt_enabled': dailyPromptEnabled,
      'doodle_notes_enabled': doodleNotesEnabled,
      'timeline_enabled': timelineEnabled,
      'time_capsule_enabled': timeCapsuleEnabled,
      'calendar_enabled': calendarEnabled,
      'love_notes_enabled': loveNotesEnabled,
      'vault_enabled': vaultEnabled,
      'gifts_enabled': giftsEnabled,
      'relationship_enabled': relationshipEnabled,
      'memories_enabled': memoriesEnabled,
      'mute_all': muteAll,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'sound_enabled': soundEnabled,
      'vibration_enabled': vibrationEnabled,
      'badge_count_enabled': badgeCountEnabled,
      'timezone': timezone,
    };
  }
}
