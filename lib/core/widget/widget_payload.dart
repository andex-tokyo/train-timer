import 'dart:convert';

import 'package:intl/intl.dart';

import '../../features/profiles/domain/profile.dart';
import '../timetable/timetable.dart';

class WidgetPayload {
  const WidgetPayload({
    required this.station,
    required this.direction,
    required this.countdown,
    required this.departureTime,
    required this.expressMode,
    required this.profileName,
    required this.line,
    required this.isLastDeparture,
    required this.departureEpochMillis,
    required this.departuresJson,
  });

  final String station;
  final String direction;
  final String countdown;
  final String departureTime;
  final bool expressMode;
  final String profileName;
  final String line;
  final bool isLastDeparture;
  final int departureEpochMillis;
  final String departuresJson;

  Map<String, Object> toMap() => {
    'station': station,
    'direction': direction,
    'countdown': countdown,
    'departureTime': departureTime,
    'expressMode': expressMode,
    'profileName': profileName,
    'line': line,
    'isLastDeparture': isLastDeparture,
    'departureEpochMillis': departureEpochMillis,
    'departuresJson': departuresJson,
  };
}

class WidgetPayloadFactory {
  const WidgetPayloadFactory();

  WidgetPayload from({
    required TrainProfile profile,
    required NextDeparture? departure,
    required Timetable timetable,
    required bool expressMode,
  }) {
    if (departure == null) {
      return WidgetPayload(
        station: profile.station,
        direction: profile.direction,
        countdown: '運行終了',
        departureTime: '--:--',
        expressMode: expressMode,
        profileName: profile.name,
        line: profile.line,
        isLastDeparture: false,
        departureEpochMillis: 0,
        departuresJson: '[]',
      );
    }

    final destination = timetable.destinations[departure.entry.destinationCode];
    final isLastDeparture = _isLastDeparture(departure.entry, timetable);
    final upcoming = _upcomingDepartures(
      profile: profile,
      timetable: timetable,
      now: departure.departureAt.subtract(departure.remaining),
    );
    return WidgetPayload(
      station: profile.station,
      direction: destination == null
          ? profile.direction
          : '${destination.name}行',
      countdown: _formatCountdown(departure, timetable, expressMode),
      departureTime: '${DateFormat('HH:mm').format(departure.departureAt)}発',
      expressMode: expressMode,
      profileName: profile.name,
      line: profile.line,
      isLastDeparture: isLastDeparture,
      departureEpochMillis: departure.departureAt.millisecondsSinceEpoch,
      departuresJson: jsonEncode(upcoming),
    );
  }

  String _formatCountdown(
    NextDeparture departure,
    Timetable timetable,
    bool expressMode,
  ) {
    final remaining = departure.remaining;
    if (!expressMode && _isOperationEnded(departure, timetable)) {
      return '運行終了';
    }
    if (remaining.inSeconds <= 300) {
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return 'あと ${remaining.inMinutes}分';
  }

  bool _isOperationEnded(NextDeparture departure, Timetable timetable) {
    if (departure.remaining.inMinutes <= 60) {
      return false;
    }
    final departureMinute = _serviceMinute(departure.entry);
    final sameServiceEntries = timetable.entries.where(
      (entry) => entry.serviceDay == departure.entry.serviceDay,
    );
    if (sameServiceEntries.isEmpty) {
      return false;
    }
    final firstMinute = sameServiceEntries
        .map(_serviceMinute)
        .reduce((a, b) => a < b ? a : b);
    return departureMinute == firstMinute;
  }

  bool _isLastDeparture(TimetableEntry entry, Timetable timetable) {
    final entryMinute = _serviceMinute(entry);
    return !timetable.entries.any(
      (candidate) =>
          candidate.serviceDay == entry.serviceDay &&
          _serviceMinute(candidate) > entryMinute,
    );
  }

  int _serviceMinute(TimetableEntry entry) {
    final hour = entry.hour < 3 ? entry.hour + 24 : entry.hour;
    return hour * 60 + entry.minute;
  }

  List<Map<String, Object>> _upcomingDepartures({
    required TrainProfile profile,
    required Timetable timetable,
    required DateTime now,
  }) {
    final candidates = <({TimetableEntry entry, DateTime departureAt})>[];
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
        final departureAt = serviceDate.add(
          Duration(days: dayOffset, hours: entry.hour, minutes: entry.minute),
        );
        if (departureAt.isAfter(now) || departureAt.isAtSameMomentAs(now)) {
          candidates.add((entry: entry, departureAt: departureAt));
        }
      }
    }
    candidates.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return candidates.take(96).map((candidate) {
      final destination =
          timetable.destinations[candidate.entry.destinationCode];
      return {
        'station': profile.station,
        'direction': destination == null
            ? profile.direction
            : '${destination.name}行',
        'departureTime':
            '${DateFormat('HH:mm').format(candidate.departureAt)}発',
        'departureEpochMillis': candidate.departureAt.millisecondsSinceEpoch,
        'isFirstDeparture': _isFirstDeparture(candidate.entry, timetable),
        'isLastDeparture': _isLastDeparture(candidate.entry, timetable),
      };
    }).toList();
  }

  bool _isFirstDeparture(TimetableEntry entry, Timetable timetable) {
    final entryMinute = _serviceMinute(entry);
    return !timetable.entries.any(
      (candidate) =>
          candidate.serviceDay == entry.serviceDay &&
          _serviceMinute(candidate) < entryMinute,
    );
  }

  ServiceDay _serviceDayFor(DateTime date) {
    return switch (date.weekday) {
      DateTime.saturday => ServiceDay.saturday,
      DateTime.sunday => ServiceDay.sunday,
      _ => ServiceDay.weekday,
    };
  }
}
