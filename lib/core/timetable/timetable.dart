enum ServiceDay { weekday, saturday, sunday, holiday }

class TrainKind {
  const TrainKind({
    required this.code,
    required this.name,
    required this.shortName,
    required this.colorHex,
  });

  final String code;
  final String name;
  final String shortName;
  final String colorHex;
}

class Destination {
  const Destination({
    required this.code,
    required this.name,
    required this.shortName,
  });

  final String code;
  final String name;
  final String shortName;
}

class TimetableEntry {
  const TimetableEntry({
    required this.serviceDay,
    required this.hour,
    required this.minute,
    required this.kindCode,
    required this.destinationCode,
  });

  final ServiceDay serviceDay;
  final int hour;
  final int minute;
  final String kindCode;
  final String destinationCode;
}

class Timetable {
  const Timetable({
    required this.kinds,
    required this.destinations,
    required this.entries,
  });

  final Map<String, TrainKind> kinds;
  final Map<String, Destination> destinations;
  final List<TimetableEntry> entries;
}

class NextDeparture {
  const NextDeparture({
    required this.entry,
    required this.departureAt,
    required this.remaining,
  });

  final TimetableEntry entry;
  final DateTime departureAt;
  final Duration remaining;
}
