import 'timetable.dart';

class NextDepartureCalculator {
  const NextDepartureCalculator();

  NextDeparture? findNext(Timetable timetable, DateTime now) {
    return findUpcoming(timetable, now, limit: 1).firstOrNull;
  }

  List<NextDeparture> findUpcoming(
    Timetable timetable,
    DateTime now, {
    int limit = 2,
  }) {
    final candidates = <NextDeparture>[];
    for (var offset = -1; offset <= 2; offset++) {
      final serviceDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));
      final day = _serviceDayFor(serviceDate);
      for (final entry in timetable.entries.where(
        (entry) => entry.serviceDay == day,
      )) {
        final dayOffset = entry.hour < 3 ? 1 : 0;
        final departure = serviceDate.add(
          Duration(days: dayOffset, hours: entry.hour, minutes: entry.minute),
        );
        if (departure.isAfter(now) || departure.isAtSameMomentAs(now)) {
          candidates.add(
            NextDeparture(
              entry: entry,
              departureAt: departure,
              remaining: departure.difference(now),
            ),
          );
        }
      }
    }
    candidates.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return candidates.take(limit).toList();
  }

  ServiceDay _serviceDayFor(DateTime date) {
    return switch (date.weekday) {
      DateTime.saturday => ServiceDay.saturday,
      DateTime.sunday => ServiceDay.sunday,
      _ => ServiceDay.weekday,
    };
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
