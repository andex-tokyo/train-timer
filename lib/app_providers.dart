import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/timetable/next_departure_calculator.dart';
import 'core/timetable/tbl_parser.dart';
import 'core/timetable/timetable.dart';
import 'core/widget/home_widget_service.dart';
import 'core/widget/widget_payload.dart';
import 'features/automation/domain/auto_switch_rule.dart';
import 'features/profiles/data/profile_repository.dart';
import 'features/profiles/domain/profile.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences is provided at startup.');
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(sharedPreferencesProvider));
});

final homeWidgetServiceProvider = Provider((ref) => HomeWidgetService());

final trainTimerControllerProvider =
    AsyncNotifierProvider<TrainTimerController, TrainTimerState>(
      TrainTimerController.new,
    );

class TrainTimerState {
  const TrainTimerState({
    required this.profiles,
    required this.selectedProfileId,
    required this.expressMode,
    required this.nextDeparture,
    required this.followingDeparture,
    required this.timetable,
    required this.parseWarnings,
    required this.autoSwitchRules,
  });

  final List<TrainProfile> profiles;
  final String selectedProfileId;
  final bool expressMode;
  final NextDeparture? nextDeparture;
  final NextDeparture? followingDeparture;
  final Timetable timetable;
  final List<String> parseWarnings;
  final List<AutoSwitchRule> autoSwitchRules;

  TrainProfile get selectedProfile {
    return profiles.firstWhere((profile) => profile.id == selectedProfileId);
  }

  WidgetPayload get widgetPayload {
    return const WidgetPayloadFactory().from(
      profile: selectedProfile,
      departure: nextDeparture,
      timetable: timetable,
      expressMode: expressMode,
    );
  }

  TrainTimerState copyWith({
    List<TrainProfile>? profiles,
    String? selectedProfileId,
    bool? expressMode,
    Object? nextDeparture = _unset,
    Object? followingDeparture = _unset,
    Timetable? timetable,
    List<String>? parseWarnings,
    List<AutoSwitchRule>? autoSwitchRules,
  }) {
    return TrainTimerState(
      profiles: profiles ?? this.profiles,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      expressMode: expressMode ?? this.expressMode,
      nextDeparture: nextDeparture == _unset
          ? this.nextDeparture
          : nextDeparture as NextDeparture?,
      followingDeparture: followingDeparture == _unset
          ? this.followingDeparture
          : followingDeparture as NextDeparture?,
      timetable: timetable ?? this.timetable,
      parseWarnings: parseWarnings ?? this.parseWarnings,
      autoSwitchRules: autoSwitchRules ?? this.autoSwitchRules,
    );
  }
}

const _unset = Object();

class TrainTimerController extends AsyncNotifier<TrainTimerState> {
  final _calculator = const NextDepartureCalculator();

  @override
  Future<TrainTimerState> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    final profiles = repository.loadProfiles();
    final rules = repository.loadAutoSwitchRules();
    final selectedId = _autoSelectedProfileId(repository, profiles, rules);
    const expressMode = false;
    final parsed = await _loadTimetable(
      profiles.firstWhere((profile) => profile.id == selectedId),
    );
    final upcoming = _calculator.findUpcoming(parsed.timetable, DateTime.now());
    final initial = TrainTimerState(
      profiles: profiles,
      selectedProfileId: selectedId,
      expressMode: expressMode,
      nextDeparture: upcoming.firstOrNull,
      followingDeparture: upcoming.secondOrNull,
      timetable: parsed.timetable,
      parseWarnings: parsed.warnings,
      autoSwitchRules: rules,
    );
    await ref.read(homeWidgetServiceProvider).update(initial.widgetPayload);
    return initial;
  }

  Future<void> refresh() async {
    final current = await future;
    final repository = ref.read(profileRepositoryProvider);
    final autoSelectedId = _autoSelectedProfileId(
      repository,
      current.profiles,
      current.autoSwitchRules,
    );
    if (autoSelectedId != current.selectedProfileId) {
      await selectProfile(autoSelectedId);
      return;
    }

    final upcoming = _calculator.findUpcoming(
      current.timetable,
      DateTime.now(),
    );
    final next = upcoming.firstOrNull;
    final refreshed = current.copyWith(
      nextDeparture: next,
      followingDeparture: upcoming.secondOrNull,
    );
    if (current.expressMode && next?.entry != current.nextDeparture?.entry) {
      await setExpressMode(false);
      return;
    }
    state = AsyncData(refreshed);
    if (_shouldUpdateHomeWidget(current, refreshed)) {
      await ref.read(homeWidgetServiceProvider).update(refreshed.widgetPayload);
    }
  }

  bool _shouldUpdateHomeWidget(TrainTimerState previous, TrainTimerState next) {
    if (_sameDepartureUsesNativeCountdown(previous, next)) {
      return false;
    }
    final previousPayload = previous.widgetPayload.toMap();
    final nextPayload = next.widgetPayload.toMap();
    return previousPayload.toString() != nextPayload.toString();
  }

  bool _sameDepartureUsesNativeCountdown(
    TrainTimerState previous,
    TrainTimerState next,
  ) {
    final previousDeparture = previous.nextDeparture;
    final nextDeparture = next.nextDeparture;
    if (previousDeparture == null || nextDeparture == null) {
      return false;
    }
    if (previousDeparture.departureAt != nextDeparture.departureAt) {
      return false;
    }
    return previous.widgetPayload.countdown != '運行終了' &&
        next.widgetPayload.countdown != '運行終了';
  }

  Future<void> cycleProfile() async {
    final current = await future;
    final index = current.profiles.indexWhere(
      (profile) => profile.id == current.selectedProfileId,
    );
    final nextProfile = current.profiles[(index + 1) % current.profiles.length];
    await selectProfile(nextProfile.id, manual: true);
  }

  Future<void> selectProfile(String id, {bool manual = false}) async {
    final current = await future;
    final repository = ref.read(profileRepositoryProvider);
    await repository.saveSelectedProfileId(id, manual: manual);
    final selected = current.profiles.firstWhere((profile) => profile.id == id);
    final parsed = await _loadTimetable(selected);
    final upcoming = _upcoming(parsed.timetable);
    final updated = current.copyWith(
      selectedProfileId: id,
      timetable: parsed.timetable,
      parseWarnings: parsed.warnings,
      nextDeparture: upcoming.firstOrNull,
      followingDeparture: upcoming.secondOrNull,
    );
    state = AsyncData(updated);
    await ref.read(homeWidgetServiceProvider).update(updated.widgetPayload);
  }

  Future<void> setExpressMode(bool value) async {
    final current = await future;
    await ref.read(profileRepositoryProvider).setExpressMode(value);
    final updated = current.copyWith(expressMode: value);
    state = AsyncData(updated);
    await ref.read(homeWidgetServiceProvider).update(updated.widgetPayload);
  }

  Future<void> reorderProfiles(int oldIndex, int newIndex) async {
    final current = await future;
    final profiles = [...current.profiles];
    final moved = profiles.removeAt(oldIndex);
    profiles.insert(newIndex, moved);
    await ref.read(profileRepositoryProvider).saveProfiles(profiles);
    state = AsyncData(current.copyWith(profiles: profiles));
  }

  Future<void> addProfile(TrainProfile profile) async {
    final current = await future;
    final profiles = [...current.profiles, profile];
    await ref.read(profileRepositoryProvider).saveProfiles(profiles);
    final parsed = await _loadTimetable(profile);
    final upcoming = _calculator.findUpcoming(parsed.timetable, DateTime.now());
    final updated = current.copyWith(
      profiles: profiles,
      selectedProfileId: profile.id,
      timetable: parsed.timetable,
      parseWarnings: parsed.warnings,
      nextDeparture: upcoming.firstOrNull,
      followingDeparture: upcoming.secondOrNull,
    );
    state = AsyncData(updated);
    await ref.read(homeWidgetServiceProvider).update(updated.widgetPayload);
  }

  Future<void> updateProfile(TrainProfile profile) async {
    final current = await future;
    final profiles = current.profiles
        .map((item) => item.id == profile.id ? profile : item)
        .toList();
    await ref.read(profileRepositoryProvider).saveProfiles(profiles);
    var updated = current.copyWith(profiles: profiles);
    if (current.selectedProfileId == profile.id) {
      final parsed = await _loadTimetable(profile);
      final upcoming = _calculator.findUpcoming(
        parsed.timetable,
        DateTime.now(),
      );
      updated = updated.copyWith(
        timetable: parsed.timetable,
        parseWarnings: parsed.warnings,
        nextDeparture: upcoming.firstOrNull,
        followingDeparture: upcoming.secondOrNull,
      );
    }
    state = AsyncData(updated);
    await ref.read(homeWidgetServiceProvider).update(updated.widgetPayload);
  }

  Future<void> deleteProfile(String id) async {
    final current = await future;
    if (current.profiles.length <= 1) {
      return;
    }
    final profiles = current.profiles
        .where((profile) => profile.id != id)
        .toList();
    await ref.read(profileRepositoryProvider).saveProfiles(profiles);
    final selectedId = current.selectedProfileId == id
        ? profiles.first.id
        : current.selectedProfileId;
    final selected = profiles.firstWhere((profile) => profile.id == selectedId);
    final parsed = await _loadTimetable(selected);
    final upcoming = _calculator.findUpcoming(parsed.timetable, DateTime.now());
    final updated = current.copyWith(
      profiles: profiles,
      selectedProfileId: selectedId,
      timetable: parsed.timetable,
      parseWarnings: parsed.warnings,
      nextDeparture: upcoming.firstOrNull,
      followingDeparture: upcoming.secondOrNull,
    );
    state = AsyncData(updated);
    await ref.read(homeWidgetServiceProvider).update(updated.widgetPayload);
  }

  Future<void> addAutoSwitchRule(AutoSwitchRule rule) async {
    final current = await future;
    final rules = [...current.autoSwitchRules, rule];
    await ref.read(profileRepositoryProvider).saveAutoSwitchRules(rules);
    state = AsyncData(current.copyWith(autoSwitchRules: rules));
  }

  Future<void> updateAutoSwitchRule(AutoSwitchRule rule) async {
    final current = await future;
    final rules = current.autoSwitchRules
        .map((item) => item.id == rule.id ? rule : item)
        .toList();
    await ref.read(profileRepositoryProvider).saveAutoSwitchRules(rules);
    state = AsyncData(current.copyWith(autoSwitchRules: rules));
  }

  Future<void> deleteAutoSwitchRule(String id) async {
    final current = await future;
    final rules = current.autoSwitchRules
        .where((rule) => rule.id != id)
        .toList();
    await ref.read(profileRepositoryProvider).saveAutoSwitchRules(rules);
    state = AsyncData(current.copyWith(autoSwitchRules: rules));
  }

  Future<Map<String, Object?>> exportSettings() async {
    await future;
    return ref.read(profileRepositoryProvider).exportSettings();
  }

  Future<void> importSettings(Map<String, Object?> json) async {
    final repository = ref.read(profileRepositoryProvider);
    await repository.importSettings(json);
    final profiles = repository.loadProfiles();
    final rules = repository.loadAutoSwitchRules();
    final selectedId = repository.loadSelectedProfileId(profiles);
    final selected = profiles.firstWhere((profile) => profile.id == selectedId);
    final parsed = await _loadTimetable(selected);
    final upcoming = _calculator.findUpcoming(parsed.timetable, DateTime.now());
    final updated = TrainTimerState(
      profiles: profiles,
      selectedProfileId: selectedId,
      expressMode: false,
      nextDeparture: upcoming.firstOrNull,
      followingDeparture: upcoming.secondOrNull,
      timetable: parsed.timetable,
      parseWarnings: parsed.warnings,
      autoSwitchRules: rules,
    );
    state = AsyncData(updated);
    await ref.read(homeWidgetServiceProvider).update(updated.widgetPayload);
  }

  String _autoSelectedProfileId(
    ProfileRepository repository,
    List<TrainProfile> profiles,
    List<AutoSwitchRule> rules,
  ) {
    if (repository.manualOverrideActive) {
      return repository.loadSelectedProfileId(profiles);
    }
    final now = DateTime.now();
    for (final rule in rules) {
      if (rule.matches(now) &&
          profiles.any((profile) => profile.id == rule.profileId)) {
        return rule.profileId;
      }
    }
    return repository.loadSelectedProfileId(profiles);
  }

  Future<TblParseResult> _loadTimetable(TrainProfile profile) async {
    final custom = profile.customTimetableText?.trim();
    final source = custom == null || custom.isEmpty
        ? await rootBundle.loadString(profile.timetableAsset)
        : custom;
    return TblParser().parse(source);
  }

  List<NextDeparture> _upcoming(Timetable timetable) {
    return _calculator.findUpcoming(timetable, DateTime.now());
  }
}

extension _SecondOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get secondOrNull => length < 2 ? null : this[1];
}
