class TrainProfile {
  const TrainProfile({
    required this.id,
    required this.name,
    required this.station,
    required this.line,
    required this.direction,
    required this.timetableAsset,
    this.customTimetableText,
    this.showLine = false,
  });

  final String id;
  final String name;
  final String station;
  final String line;
  final String direction;
  final String timetableAsset;
  final String? customTimetableText;
  final bool showLine;

  TrainProfile copyWith({
    String? name,
    String? station,
    String? line,
    String? direction,
    String? timetableAsset,
    Object? customTimetableText = _unset,
    bool? showLine,
  }) {
    return TrainProfile(
      id: id,
      name: name ?? this.name,
      station: station ?? this.station,
      line: line ?? this.line,
      direction: direction ?? this.direction,
      timetableAsset: timetableAsset ?? this.timetableAsset,
      customTimetableText: customTimetableText == _unset
          ? this.customTimetableText
          : customTimetableText as String?,
      showLine: showLine ?? this.showLine,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'station': station,
    'line': line,
    'direction': direction,
    'timetableAsset': timetableAsset,
    'customTimetableText': customTimetableText,
    'showLine': showLine,
  };

  factory TrainProfile.fromJson(Map<String, Object?> json) {
    return TrainProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      station: json['station'] as String,
      line: json['line'] as String,
      direction: json['direction'] as String,
      timetableAsset: json['timetableAsset'] as String,
      customTimetableText: json['customTimetableText'] as String?,
      showLine: json['showLine'] as bool? ?? false,
    );
  }
}

const _unset = Object();

const defaultProfiles = [
  TrainProfile(
    id: 'commute',
    name: '出勤',
    station: '舞浜',
    line: '京葉線',
    direction: '東京方面',
    timetableAsset: 'assets/timetable/sample.tbl',
  ),
  TrainProfile(
    id: 'home',
    name: '帰宅',
    station: '舞浜',
    line: '京葉線',
    direction: '海浜幕張方面',
    timetableAsset: 'assets/timetable/sample.tbl',
  ),
  TrainProfile(
    id: 'holiday',
    name: '休日',
    station: '舞浜',
    line: '京葉線',
    direction: '東京方面',
    timetableAsset: 'assets/timetable/sample.tbl',
  ),
];
