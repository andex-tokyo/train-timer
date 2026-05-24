import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/timetable/next_departure_calculator.dart';
import 'core/timetable/tbl_parser.dart';
import 'core/widget/home_widget_service.dart';
import 'core/widget/widget_payload.dart';
import 'features/profiles/data/profile_repository.dart';

@pragma('vm:entry-point')
Future<void> trainTimerInteractiveCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = ProfileRepository(prefs);
  final profiles = repository.loadProfiles();
  var selectedId = repository.loadSelectedProfileId(profiles);

  if (uri?.host == 'cycleProfile') {
    final index = profiles.indexWhere((profile) => profile.id == selectedId);
    selectedId = profiles[(index + 1) % profiles.length].id;
    await repository.saveSelectedProfileId(selectedId, manual: true);
  }
  final profile = profiles.firstWhere((profile) => profile.id == selectedId);
  final custom = profile.customTimetableText?.trim();
  final source = custom == null || custom.isEmpty
      ? await rootBundle.loadString(profile.timetableAsset)
      : custom;
  final parsed = TblParser().parse(source);
  final next = const NextDepartureCalculator().findNext(
    parsed.timetable,
    DateTime.now(),
  );
  final payload = const WidgetPayloadFactory().from(
    profile: profile,
    departure: next,
    timetable: parsed.timetable,
    expressMode: false,
  );
  await HomeWidgetService().update(payload);
}
