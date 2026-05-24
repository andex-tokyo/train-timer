import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_providers.dart';
import 'background_interaction.dart';
import 'features/automation/domain/auto_switch_rule.dart';
import 'features/profiles/domain/profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.registerInteractivityCallback(trainTimerInteractiveCallback);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TrainTimerApp(),
    ),
  );
}

class TrainTimerApp extends StatelessWidget {
  const TrainTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Timer',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A60)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66D8C8),
          brightness: Brightness.dark,
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ProfilesPage(),
      const AutoSwitchPage(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.train), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: '乗る電車'),
          NavigationDestination(icon: Icon(Icons.schedule), label: '自動切替'),
        ],
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(trainTimerControllerProvider.notifier).refresh();
      _startTimer();
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(trainTimerControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(trainTimerControllerProvider);
    return timer.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => ErrorView(message: error.toString()),
      data: (state) {
        final payload = state.widgetPayload;
        final countdown = _appCountdownText(state);
        final followingDeparture = _followingDepartureLabel(state);
        final lastDeparture =
            state.nextDeparture != null && payload.isLastDeparture;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Text(
                  'Train Timer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                ProfileSelector(
                  profiles: state.profiles,
                  selectedProfileId: state.selectedProfileId,
                  onSelected: (profileId) => ref
                      .read(trainTimerControllerProvider.notifier)
                      .selectProfile(profileId, manual: true),
                ),
                const SizedBox(height: 34),
                Text(
                  payload.station,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  payload.direction,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                CurrentCountdownPanel(
                  countdown: countdown,
                  departureTime: payload.departureTime,
                  lastDeparture: lastDeparture,
                ),
                if (followingDeparture != null) ...[
                  const SizedBox(height: 12),
                  FollowingDepartureTile(label: followingDeparture),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileSelector extends StatelessWidget {
  const ProfileSelector({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
  });

  final List<TrainProfile> profiles;
  final String selectedProfileId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final profile in profiles) ...[
            ChoiceChip(
              label: Text(profile.name),
              selected: profile.id == selectedProfileId,
              onSelected: (_) => onSelected(profile.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(trainTimerControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('乗る電車'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportSettings(context, ref);
              }
              if (value == 'import') {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ImportSettingsSheet(),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('エクスポート')),
              PopupMenuItem(value: 'import', child: Text('インポート')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '追加',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const ProfileEditSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: timer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(message: error.toString()),
        data: (state) => ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: state.profiles.length,
          onReorderItem: ref
              .read(trainTimerControllerProvider.notifier)
              .reorderProfiles,
          itemBuilder: (context, index) {
            final profile = state.profiles[index];
            final selected = profile.id == state.selectedProfileId;
            return ProfileListItem(
              key: ValueKey(profile.id),
              profile: profile,
              selected: selected,
              onEdit: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProfileEditSheet(profile: profile),
              ),
              onSelect: () => ref
                  .read(trainTimerControllerProvider.notifier)
                  .selectProfile(profile.id, manual: true),
              onDelete: () => ref
                  .read(trainTimerControllerProvider.notifier)
                  .deleteProfile(profile.id),
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportSettings(BuildContext context, WidgetRef ref) async {
    final settings = await ref
        .read(trainTimerControllerProvider.notifier)
        .exportSettings();
    final json = const JsonEncoder.withIndent('  ').convert(settings);
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定JSONをコピーしました')));
    }
  }
}

class ProfileListItem extends StatelessWidget {
  const ProfileListItem({
    super.key,
    required this.profile,
    required this.selected,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final TrainProfile profile;
  final bool selected;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.55)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? colorScheme.primary : colorScheme.outline,
          ),
          title: Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${profile.station} ${profile.direction} / ${profile.line}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: onEdit,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '選択',
                onPressed: selected ? null : onSelect,
                icon: const Icon(Icons.check_circle_outline),
              ),
              IconButton(
                tooltip: '削除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImportSettingsSheet extends ConsumerStatefulWidget {
  const ImportSettingsSheet({super.key});

  @override
  ConsumerState<ImportSettingsSheet> createState() =>
      _ImportSettingsSheetState();
}

class _ImportSettingsSheetState extends ConsumerState<ImportSettingsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'インポート',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('貼り付け'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '{\n  "schemaVersion": 1,\n  "profiles": []\n}',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.upload_file),
            label: const Text('読み込む'),
          ),
        ],
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
  }

  Future<void> _import() async {
    try {
      final decoded = jsonDecode(_controller.text) as Map<String, dynamic>;
      await ref
          .read(trainTimerControllerProvider.notifier)
          .importSettings(decoded);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定を読み込みました')));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('JSONを読み込めませんでした')));
      }
    }
  }
}

class AutoSwitchPage extends ConsumerWidget {
  const AutoSwitchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(trainTimerControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('自動切替')),
      floatingActionButton: FloatingActionButton(
        tooltip: '追加',
        onPressed: () => timer.whenData(
          (state) => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => AutoSwitchRuleSheet(
              profiles: state.profiles,
              existingRules: state.autoSwitchRules,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: timer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(message: error.toString()),
        data: (state) {
          final profilesById = {
            for (final profile in state.profiles) profile.id: profile,
          };
          if (state.autoSwitchRules.isEmpty) {
            return const EmptyState(
              icon: Icons.schedule,
              title: '自動切替は未設定です',
              message: '右下の追加ボタンから時間帯ごとの切替を作れます',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: state.autoSwitchRules.length,
            itemBuilder: (context, index) {
              final rule = state.autoSwitchRules[index];
              final profile = profilesById[rule.profileId];
              return AutoSwitchRuleItem(
                rule: rule,
                profileName: profile?.name ?? '未設定',
                onEdit: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AutoSwitchRuleSheet(
                    rule: rule,
                    profiles: state.profiles,
                    existingRules: state.autoSwitchRules,
                  ),
                ),
                onDelete: () => ref
                    .read(trainTimerControllerProvider.notifier)
                    .deleteAutoSwitchRule(rule.id),
              );
            },
          );
        },
      ),
    );
  }
}

class AutoSwitchRuleItem extends StatelessWidget {
  const AutoSwitchRuleItem({
    super.key,
    required this.rule,
    required this.profileName,
    required this.onEdit,
    required this.onDelete,
  });

  final AutoSwitchRule rule;
  final String profileName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            rule.enabled ? Icons.schedule : Icons.pause_circle_outline,
            color: rule.enabled ? colorScheme.primary : colorScheme.outline,
          ),
          title: Text(
            rule.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${_weekdaysLabel(rule.weekdays)} '
            '${_timeLabel(rule.startMinuteOfDay)}-${_timeLabel(rule.endMinuteOfDay)}'
            ' / $profileName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: onEdit,
          trailing: IconButton(
            tooltip: '削除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }
}

class AutoSwitchRuleSheet extends ConsumerStatefulWidget {
  const AutoSwitchRuleSheet({
    super.key,
    this.rule,
    required this.profiles,
    required this.existingRules,
  });

  final AutoSwitchRule? rule;
  final List<TrainProfile> profiles;
  final List<AutoSwitchRule> existingRules;

  @override
  ConsumerState<AutoSwitchRuleSheet> createState() =>
      _AutoSwitchRuleSheetState();
}

class _AutoSwitchRuleSheetState extends ConsumerState<AutoSwitchRuleSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late String _profileId;
  late Set<int> _weekdays;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _startController = TextEditingController(
      text: _timeLabel(rule?.startMinuteOfDay ?? 5 * 60),
    );
    _endController = TextEditingController(
      text: _timeLabel(rule?.endMinuteOfDay ?? 10 * 60),
    );
    _profileId = rule?.profileId ?? widget.profiles.first.id;
    _weekdays = {
      ...(rule?.weekdays ?? {1, 2, 3, 4, 5}),
    };
    _enabled = rule?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.rule == null ? '自動切替を追加' : '自動切替を編集',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Switch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名前',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _profileId,
            decoration: const InputDecoration(
              labelText: '乗る電車',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final profile in widget.profiles)
                DropdownMenuItem(value: profile.id, child: Text(profile.name)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _profileId = value);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '開始',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '終了',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in const [
                (1, '月'),
                (2, '火'),
                (3, '水'),
                (4, '木'),
                (5, '金'),
                (6, '土'),
                (7, '日'),
              ])
                FilterChip(
                  label: Text(day.$2),
                  selected: _weekdays.contains(day.$1),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _weekdays.add(day.$1);
                      } else {
                        _weekdays.remove(day.$1);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final start = _parseTime(_startController.text.trim());
    final end = _parseTime(_endController.text.trim());
    if (name.isEmpty || start == null || end == null || _weekdays.isEmpty) {
      return;
    }
    final rule = (widget.rule ?? _newRule()).copyWith(
      name: name,
      profileId: _profileId,
      weekdays: _weekdays,
      startMinuteOfDay: start,
      endMinuteOfDay: end,
      enabled: _enabled,
    );
    final controller = ref.read(trainTimerControllerProvider.notifier);
    if (widget.rule == null) {
      await controller.addAutoSwitchRule(rule);
    } else {
      await controller.updateAutoSwitchRule(rule);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  AutoSwitchRule _newRule() {
    return AutoSwitchRule(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      profileId: widget.profiles.first.id,
      weekdays: const {1, 2, 3, 4, 5},
      startMinuteOfDay: 5 * 60,
      endMinuteOfDay: 10 * 60,
    );
  }
}

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key, this.profile});

  final TrainProfile? profile;

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _stationController;
  late final TextEditingController _lineController;
  late final TextEditingController _directionController;
  late final TextEditingController _tblController;
  var _loadingTbl = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _stationController = TextEditingController(text: profile?.station ?? '舞浜');
    _lineController = TextEditingController(text: profile?.line ?? '京葉線');
    _directionController = TextEditingController(
      text: profile?.direction ?? '東京方面',
    );
    _tblController = TextEditingController(
      text: profile?.customTimetableText ?? '',
    );
    if (_tblController.text.trim().isEmpty) {
      _loadConfiguredTbl();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stationController.dispose();
    _lineController.dispose();
    _directionController.dispose();
    _tblController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.profile == null ? '乗る電車を追加' : '乗る電車を編集',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stationController,
                decoration: const InputDecoration(
                  labelText: '駅名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _directionController,
                decoration: const InputDecoration(
                  labelText: '方面',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lineController,
                decoration: const InputDecoration(
                  labelText: '路線',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TBL',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loadSampleTbl,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('サンプル'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tblController,
                minLines: 8,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: _loadingTbl
                      ? '読み込み中'
                      : 'A:快速;快;#4040FF\nX:普通;無印;#000000\n[MON][TUE]...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存して更新'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadSampleTbl() async {
    final sample = await rootBundle.loadString('assets/timetable/sample.tbl');
    _tblController.text = sample;
  }

  Future<void> _loadConfiguredTbl() async {
    setState(() => _loadingTbl = true);
    final asset =
        widget.profile?.timetableAsset ?? 'assets/timetable/sample.tbl';
    final source = await rootBundle.loadString(asset);
    if (!mounted) {
      return;
    }
    if (_tblController.text.trim().isEmpty) {
      _tblController.text = source;
    }
    setState(() => _loadingTbl = false);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final station = _stationController.text.trim();
    final direction = _directionController.text.trim();
    final line = _lineController.text.trim();
    if (name.isEmpty || station.isEmpty || direction.isEmpty || line.isEmpty) {
      return;
    }
    final customTbl = _tblController.text.trim();
    final profile = (widget.profile ?? _newProfile()).copyWith(
      name: name,
      station: station,
      direction: direction,
      line: line,
      customTimetableText: customTbl.isEmpty ? null : customTbl,
    );
    final controller = ref.read(trainTimerControllerProvider.notifier);
    if (widget.profile == null) {
      await controller.addProfile(profile);
    } else {
      await controller.updateProfile(profile);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  TrainProfile _newProfile() {
    return TrainProfile(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      station: '',
      line: '',
      direction: '',
      timetableAsset: 'assets/timetable/sample.tbl',
    );
  }
}

class CurrentCountdownPanel extends StatelessWidget {
  const CurrentCountdownPanel({
    super.key,
    required this.countdown,
    required this.departureTime,
    required this.lastDeparture,
  });

  final String countdown;
  final String departureTime;
  final bool lastDeparture;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeCountdown = countdown != '運行終了' && countdown != '終電後';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  departureTime,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (lastDeparture) ...[
                  const SizedBox(width: 8),
                  Text(
                    '終電',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            if (activeCountdown) ...[
              Text(
                'あと',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountdownDisplay(value: countdown),
            ),
          ],
        ),
      ),
    );
  }
}

class CountdownDisplay extends StatelessWidget {
  const CountdownDisplay({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final match = RegExp(r'^(あと\s*)?(\d+)(分)$').firstMatch(value);
    if (match == null) {
      final isTimerValue = value.contains(':');
      return Text(
        value,
        style: (isTimerValue ? theme.displayLarge : theme.displayMedium)
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          if (match.group(1) != null)
            TextSpan(
              text: match.group(1),
              style: theme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          TextSpan(
            text: match.group(2),
            style: theme.displayLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          TextSpan(
            text: match.group(3),
            style: theme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class FollowingDepartureTile extends StatelessWidget {
  const FollowingDepartureTile({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.train_outlined, color: colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '次の一本',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _appCountdownText(TrainTimerState state) {
  final payload = state.widgetPayload;
  if (payload.countdown == '運行終了' || payload.countdown == '終電後') {
    return payload.countdown;
  }
  final remaining = state.nextDeparture?.remaining;
  if (remaining == null) {
    return payload.countdown;
  }
  final totalSeconds = remaining.inSeconds;
  if (totalSeconds <= 0) {
    return '0:00';
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String? _followingDepartureLabel(TrainTimerState state) {
  final departure = state.followingDeparture;
  if (departure == null) {
    return null;
  }
  final destination =
      state.timetable.destinations[departure.entry.destinationCode];
  final destinationName = destination?.name.trim();
  final destinationLabel = destinationName == null || destinationName.isEmpty
      ? state.selectedProfile.direction
      : '$destinationName行';
  return '${_departureTimeLabel(departure.departureAt)}  $destinationLabel';
}

String _departureTimeLabel(DateTime departureAt) {
  final hour = departureAt.hour.toString().padLeft(2, '0');
  final minute = departureAt.minute.toString().padLeft(2, '0');
  return '$hour:$minute発';
}

String _weekdaysLabel(Set<int> weekdays) {
  if (weekdays.length == 7) {
    return '毎日';
  }
  if (_setEquals(weekdays, {1, 2, 3, 4, 5})) {
    return '平日';
  }
  if (_setEquals(weekdays, {6, 7})) {
    return '土日';
  }
  const labels = {1: '月', 2: '火', 3: '水', 4: '木', 5: '金', 6: '土', 7: '日'};
  return weekdays.map((day) => labels[day] ?? '').join('');
}

bool _setEquals(Set<int> a, Set<int> b) {
  return a.length == b.length && a.containsAll(b);
}

String _timeLabel(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

int? _parseTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour < 0 || hour > 24) {
    return null;
  }
  if (minute < 0 || minute > 59 || (hour == 24 && minute != 0)) {
    return null;
  }
  return hour * 60 + minute;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
    );
  }
}
