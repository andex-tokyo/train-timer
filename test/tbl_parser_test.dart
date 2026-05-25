import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:train_timer/core/widget/widget_payload.dart';
import 'package:train_timer/core/timetable/next_departure_calculator.dart';
import 'package:train_timer/core/timetable/tbl_parser.dart';
import 'package:train_timer/core/timetable/timetable.dart';
import 'package:train_timer/features/profiles/domain/profile.dart';

void main() {
  const sample = '''
A:快速;快;#4040FF
X:普通;無印;#000000
a:府中本町;府
b:西船橋;西
[MON][TUE][WED][THU][FRI]
# comment
6: Xa18 Xa42 Xb52
23: Xb59
0: Xa10
[SAT][SUN][HOL]
6: Xa32
''';

  test('parses definitions and train entries', () {
    final result = TblParser().parse(sample);

    expect(result.warnings, isEmpty);
    expect(result.timetable.kinds['A']?.shortName, '快');
    expect(result.timetable.destinations['a']?.name, '府中本町');
    expect(result.timetable.entries.length, 8);
  });

  test('parses train tokens with platform markers before minute', () {
    const source = '''
A:2番線発車
B:1番線発車
C:快速;快;#4040FF
X:普通;無印;#000000
a:府中本町;府
b:西船橋;西
[MON][TUE][WED][THU][FRI]
6: XaA22 XaA45 XbA56
7: XaB09 XbB44
''';

    final result = TblParser().parse(source);

    expect(result.warnings, isEmpty);
    expect(result.timetable.entries.length, 5);
    expect(result.timetable.entries.first.kindCode, 'X');
    expect(result.timetable.entries.first.destinationCode, 'a');
    expect(result.timetable.entries.first.minute, 22);
    expect(result.timetable.entries.last.destinationCode, 'b');
    expect(result.timetable.entries.last.minute, 44);
  });

  test('finds next weekday departure across midnight', () {
    final timetable = TblParser().parse(sample).timetable;
    final next = const NextDepartureCalculator().findNext(
      timetable,
      DateTime(2026, 5, 22, 23, 59, 30),
    );

    expect(next?.departureAt, DateTime(2026, 5, 23, 0, 10));
  });

  test('shows operation ended until one hour before first departure', () {
    const profile = TrainProfile(
      id: 'test',
      name: 'test',
      station: '舞浜',
      line: '京葉線',
      direction: '東京方面',
      timetableAsset: 'assets/timetable/sample.tbl',
    );
    const entry = TimetableEntry(
      serviceDay: ServiceDay.weekday,
      hour: 6,
      minute: 18,
      kindCode: 'X',
      destinationCode: 'a',
    );
    final departure = NextDeparture(
      entry: entry,
      departureAt: DateTime(2026, 5, 25, 6, 18),
      remaining: Duration(hours: 3),
    );

    final payload = const WidgetPayloadFactory().from(
      profile: profile,
      departure: departure,
      timetable: Timetable(
        kinds: {},
        destinations: {
          'a': Destination(code: 'a', name: '府中本町', shortName: '府'),
        },
        entries: [entry],
      ),
      expressMode: false,
    );

    expect(payload.countdown, '運行終了');
    expect(payload.direction, '府中本町行');
    expect(payload.departureTime, '06:18発');
  });

  test('marks the final train of the service day', () {
    const profile = TrainProfile(
      id: 'test',
      name: 'test',
      station: '舞浜',
      line: '京葉線',
      direction: '東京方面',
      timetableAsset: 'assets/timetable/sample.tbl',
    );
    const entry = TimetableEntry(
      serviceDay: ServiceDay.weekday,
      hour: 0,
      minute: 10,
      kindCode: 'X',
      destinationCode: 'a',
    );
    final payload = WidgetPayloadFactory().from(
      profile: profile,
      departure: NextDeparture(
        entry: entry,
        departureAt: DateTime(2026, 5, 23, 0, 10),
        remaining: const Duration(minutes: 20),
      ),
      timetable: const Timetable(
        kinds: {},
        destinations: {
          'a': Destination(code: 'a', name: '府中本町', shortName: '府'),
        },
        entries: [
          TimetableEntry(
            serviceDay: ServiceDay.weekday,
            hour: 23,
            minute: 59,
            kindCode: 'X',
            destinationCode: 'a',
          ),
          entry,
        ],
      ),
      expressMode: false,
    );

    expect(payload.isLastDeparture, isTrue);
  });

  test('uses second countdown from five minutes before departure', () {
    const profile = TrainProfile(
      id: 'test',
      name: 'test',
      station: '舞浜',
      line: '京葉線',
      direction: '東京方面',
      timetableAsset: 'assets/timetable/sample.tbl',
    );
    final payload = const WidgetPayloadFactory().from(
      profile: profile,
      departure: NextDeparture(
        entry: TimetableEntry(
          serviceDay: ServiceDay.weekday,
          hour: 8,
          minute: 19,
          kindCode: 'X',
          destinationCode: 'a',
        ),
        departureAt: DateTime(2026, 5, 23, 8, 19),
        remaining: Duration(minutes: 5),
      ),
      timetable: Timetable(
        kinds: {},
        destinations: {
          'a': Destination(code: 'a', name: '府中本町', shortName: '府'),
        },
        entries: [],
      ),
      expressMode: false,
    );

    expect(payload.countdown, '5:00');
  });

  test('keeps countdown for long daytime gaps', () {
    const profile = TrainProfile(
      id: 'test',
      name: 'test',
      station: '舞浜',
      line: '京葉線',
      direction: '東京方面',
      timetableAsset: 'assets/timetable/sample.tbl',
    );
    const first = TimetableEntry(
      serviceDay: ServiceDay.weekday,
      hour: 6,
      minute: 18,
      kindCode: 'X',
      destinationCode: 'a',
    );
    const next = TimetableEntry(
      serviceDay: ServiceDay.weekday,
      hour: 12,
      minute: 0,
      kindCode: 'X',
      destinationCode: 'a',
    );
    final payload = const WidgetPayloadFactory().from(
      profile: profile,
      departure: NextDeparture(
        entry: next,
        departureAt: DateTime(2026, 5, 25, 12),
        remaining: Duration(minutes: 90),
      ),
      timetable: Timetable(
        kinds: {},
        destinations: {
          'a': Destination(code: 'a', name: '府中本町', shortName: '府'),
        },
        entries: [first, next],
      ),
      expressMode: false,
    );

    expect(payload.countdown, 'あと 90分');
  });

  test('marks first departures in widget cache for native refresh', () {
    const profile = TrainProfile(
      id: 'test',
      name: 'test',
      station: '舞浜',
      line: '京葉線',
      direction: '東京方面',
      timetableAsset: 'assets/timetable/sample.tbl',
    );
    const first = TimetableEntry(
      serviceDay: ServiceDay.weekday,
      hour: 4,
      minute: 36,
      kindCode: 'X',
      destinationCode: 'a',
    );
    const second = TimetableEntry(
      serviceDay: ServiceDay.weekday,
      hour: 4,
      minute: 50,
      kindCode: 'X',
      destinationCode: 'a',
    );
    final payload = const WidgetPayloadFactory().from(
      profile: profile,
      departure: NextDeparture(
        entry: first,
        departureAt: DateTime(2026, 5, 25, 4, 36),
        remaining: Duration(hours: 3),
      ),
      timetable: Timetable(
        kinds: {},
        destinations: {
          'a': Destination(code: 'a', name: '府中本町', shortName: '府'),
        },
        entries: [first, second],
      ),
      expressMode: false,
    );
    final departures = jsonDecode(payload.departuresJson) as List<dynamic>;

    expect(departures.first['isFirstDeparture'], isTrue);
    expect(departures[1]['isFirstDeparture'], isFalse);
  });
}
