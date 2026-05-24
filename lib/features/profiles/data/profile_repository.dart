import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../automation/domain/auto_switch_rule.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._prefs);

  static const _profilesKey = 'profiles';
  static const _selectedProfileKey = 'selectedProfileId';
  static const _manualUntilKey = 'manualProfileUntil';
  static const _expressModeKey = 'expressMode';
  static const _autoRulesKey = 'autoSwitchRules';

  final SharedPreferences _prefs;

  List<TrainProfile> loadProfiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null) {
      return defaultProfiles;
    }
    final list = jsonDecode(raw) as List<dynamic>;
    final profiles = list
        .map((item) => TrainProfile.fromJson(item as Map<String, Object?>))
        .where((profile) => profile.id != 'free' || profile.name != '任意')
        .toList();
    return profiles.isEmpty ? defaultProfiles : profiles;
  }

  Future<void> saveProfiles(List<TrainProfile> profiles) {
    return _prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  List<AutoSwitchRule> loadAutoSwitchRules() {
    final raw = _prefs.getString(_autoRulesKey);
    if (raw == null) {
      return defaultAutoSwitchRules;
    }
    final list = jsonDecode(raw) as List<dynamic>;
    final rules = list
        .map((item) => AutoSwitchRule.fromJson(item as Map<String, Object?>))
        .toList();
    return rules.isEmpty ? defaultAutoSwitchRules : rules;
  }

  Future<void> saveAutoSwitchRules(List<AutoSwitchRule> rules) {
    return _prefs.setString(
      _autoRulesKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    );
  }

  Map<String, Object?> exportSettings() {
    final profiles = loadProfiles();
    final rules = loadAutoSwitchRules();
    return {
      'schemaVersion': 1,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'autoSwitchRules': rules.map((rule) => rule.toJson()).toList(),
      'selectedProfileId': loadSelectedProfileId(profiles),
    };
  }

  Future<void> importSettings(Map<String, Object?> json) async {
    final profiles = (json['profiles'] as List<dynamic>)
        .map((item) => TrainProfile.fromJson(item as Map<String, Object?>))
        .toList();
    final rules = (json['autoSwitchRules'] as List<dynamic>? ?? [])
        .map((item) => AutoSwitchRule.fromJson(item as Map<String, Object?>))
        .toList();
    if (profiles.isEmpty) {
      throw const FormatException('profiles is empty');
    }
    await saveProfiles(profiles);
    await saveAutoSwitchRules(rules.isEmpty ? defaultAutoSwitchRules : rules);
    final selectedId = json['selectedProfileId'] as String?;
    await saveSelectedProfileId(
      selectedId != null && profiles.any((profile) => profile.id == selectedId)
          ? selectedId
          : profiles.first.id,
      manual: true,
    );
  }

  String loadSelectedProfileId(List<TrainProfile> profiles) {
    final id = _prefs.getString(_selectedProfileKey);
    if (id != null && profiles.any((profile) => profile.id == id)) {
      return id;
    }
    return profiles.first.id;
  }

  Future<void> saveSelectedProfileId(String id, {required bool manual}) async {
    await _prefs.setString(_selectedProfileKey, id);
    if (manual) {
      await _prefs.setInt(
        _manualUntilKey,
        DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );
    }
  }

  bool get manualOverrideActive {
    final until = _prefs.getInt(_manualUntilKey);
    return until != null && DateTime.now().millisecondsSinceEpoch < until;
  }

  bool get expressMode => _prefs.getBool(_expressModeKey) ?? false;

  Future<void> setExpressMode(bool value) =>
      _prefs.setBool(_expressModeKey, value);
}
