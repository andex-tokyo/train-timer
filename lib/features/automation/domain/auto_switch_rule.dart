class AutoSwitchRule {
  const AutoSwitchRule({
    required this.id,
    required this.name,
    required this.profileId,
    required this.weekdays,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String profileId;
  final Set<int> weekdays;
  final int startMinuteOfDay;
  final int endMinuteOfDay;
  final bool enabled;

  AutoSwitchRule copyWith({
    String? name,
    String? profileId,
    Set<int>? weekdays,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    bool? enabled,
  }) {
    return AutoSwitchRule(
      id: id,
      name: name ?? this.name,
      profileId: profileId ?? this.profileId,
      weekdays: weekdays ?? this.weekdays,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      enabled: enabled ?? this.enabled,
    );
  }

  bool matches(DateTime now) {
    if (!enabled || !weekdays.contains(now.weekday)) {
      return false;
    }
    final minute = now.hour * 60 + now.minute;
    if (startMinuteOfDay <= endMinuteOfDay) {
      return minute >= startMinuteOfDay && minute < endMinuteOfDay;
    }
    return minute >= startMinuteOfDay || minute < endMinuteOfDay;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'profileId': profileId,
    'weekdays': weekdays.toList(),
    'startMinuteOfDay': startMinuteOfDay,
    'endMinuteOfDay': endMinuteOfDay,
    'enabled': enabled,
  };

  factory AutoSwitchRule.fromJson(Map<String, Object?> json) {
    return AutoSwitchRule(
      id: json['id'] as String,
      name: json['name'] as String,
      profileId: json['profileId'] as String,
      weekdays: (json['weekdays'] as List<dynamic>).cast<int>().toSet(),
      startMinuteOfDay: json['startMinuteOfDay'] as int,
      endMinuteOfDay: json['endMinuteOfDay'] as int,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

const defaultAutoSwitchRules = [
  AutoSwitchRule(
    id: 'weekday-morning',
    name: '平日 朝',
    profileId: 'commute',
    weekdays: {1, 2, 3, 4, 5},
    startMinuteOfDay: 5 * 60,
    endMinuteOfDay: 10 * 60,
  ),
  AutoSwitchRule(
    id: 'weekday-evening',
    name: '平日 夜',
    profileId: 'home',
    weekdays: {1, 2, 3, 4, 5},
    startMinuteOfDay: 17 * 60,
    endMinuteOfDay: 23 * 60,
  ),
  AutoSwitchRule(
    id: 'weekend',
    name: '土日',
    profileId: 'holiday',
    weekdays: {6, 7},
    startMinuteOfDay: 0,
    endMinuteOfDay: 24 * 60,
  ),
];
