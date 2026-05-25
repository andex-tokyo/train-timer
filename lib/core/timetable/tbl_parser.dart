import 'timetable.dart';

class TblParseResult {
  const TblParseResult({required this.timetable, required this.warnings});

  final Timetable timetable;
  final List<String> warnings;
}

class TblParser {
  TblParseResult parse(String source) {
    final kinds = <String, TrainKind>{};
    final destinations = <String, Destination>{};
    final entries = <TimetableEntry>[];
    final warnings = <String>[];
    var activeDays = <ServiceDay>{};

    final lines = source.split(RegExp(r'\r?\n'));
    for (var index = 0; index < lines.length; index++) {
      final lineNo = index + 1;
      final raw = lines[index];
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final dayMatches = RegExp(r'\[([A-Z]+)\]').allMatches(line).toList();
      if (dayMatches.isNotEmpty) {
        activeDays = dayMatches
            .map((match) => _parseDay(match.group(1)!))
            .whereType<ServiceDay>()
            .toSet();
        if (activeDays.isEmpty) {
          warnings.add('Line $lineNo: unknown day block "$line"');
        }
        continue;
      }

      final definition = RegExp(r'^([^:]):(.+)$').firstMatch(line);
      if (definition != null && !RegExp(r'^\d+:').hasMatch(line)) {
        final code = definition.group(1)!;
        final parts = definition.group(2)!.split(';');
        if (parts.length == 3 && parts.last.startsWith('#')) {
          kinds[code] = TrainKind(
            code: code,
            name: parts[0],
            shortName: parts[1],
            colorHex: parts[2],
          );
        } else if (parts.length >= 2) {
          destinations[code] = Destination(
            code: code,
            name: parts[0],
            shortName: parts[1],
          );
        } else {
          // Single-value definitions are used by some TBL generators for
          // platform notes such as "A:2番線発車". The current app does not
          // display them, but they are valid metadata and should not block
          // timetable parsing.
        }
        continue;
      }

      final hourMatch = RegExp(r'^(\d{1,2}):\s*(.*)$').firstMatch(line);
      if (hourMatch == null) {
        warnings.add('Line $lineNo: ignored "$line"');
        continue;
      }
      if (activeDays.isEmpty) {
        warnings.add('Line $lineNo: time row without day block');
        continue;
      }

      final hour = int.tryParse(hourMatch.group(1)!);
      if (hour == null || hour < 0 || hour > 47) {
        warnings.add('Line $lineNo: invalid hour "$line"');
        continue;
      }

      final tokens = hourMatch
          .group(2)!
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty);
      for (final token in tokens) {
        final tokenMatch = RegExp(r'^(.)(.)(.*?)(\d{2})$').firstMatch(token);
        if (tokenMatch == null) {
          warnings.add('Line $lineNo: invalid train token "$token"');
          continue;
        }
        final minute = int.tryParse(tokenMatch.group(4)!);
        if (minute == null || minute > 59) {
          warnings.add('Line $lineNo: invalid minute "$token"');
          continue;
        }
        for (final day in activeDays) {
          entries.add(
            TimetableEntry(
              serviceDay: day,
              hour: hour,
              minute: minute,
              kindCode: tokenMatch.group(1)!,
              destinationCode: tokenMatch.group(2)!,
            ),
          );
        }
      }
    }

    entries.sort((a, b) {
      final day = a.serviceDay.index.compareTo(b.serviceDay.index);
      if (day != 0) return day;
      final hour = a.hour.compareTo(b.hour);
      if (hour != 0) return hour;
      return a.minute.compareTo(b.minute);
    });

    return TblParseResult(
      timetable: Timetable(
        kinds: kinds,
        destinations: destinations,
        entries: entries,
      ),
      warnings: warnings,
    );
  }

  ServiceDay? _parseDay(String value) {
    return switch (value) {
      'MON' || 'TUE' || 'WED' || 'THU' || 'FRI' => ServiceDay.weekday,
      'SAT' => ServiceDay.saturday,
      'SUN' => ServiceDay.sunday,
      'HOL' => ServiceDay.holiday,
      _ => null,
    };
  }
}
