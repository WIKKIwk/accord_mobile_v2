import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/common_widgets.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';

const List<String> adminWorkerLevels = [
  'Brigader',
  'Master',
  '1 - darajali',
  '2 - darajali',
  '3 - darajali',
];

const Map<String, String> adminWorkerStartDayLabels = {
  'monday': 'Dushanba',
  'tuesday': 'Seshanba',
  'wednesday': 'Chorshanba',
  'thursday': 'Payshanba',
  'friday': 'Juma',
  'saturday': 'Shanba',
  'sunday': 'Yakshanba',
};

const String _workerGroupsScope = 'worker-settings';
const double _workerSettingsPanelGap = 4;
const double _workerSettingsCardRadius = M3SegmentedListGeometry.cornerLarge;

class AdminWorkerSettingsScreen extends StatefulWidget {
  const AdminWorkerSettingsScreen({super.key});

  @override
  State<AdminWorkerSettingsScreen> createState() =>
      _AdminWorkerSettingsScreenState();
}

class _AdminWorkerSettingsScreenState extends State<AdminWorkerSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedLevel = adminWorkerLevels.first;
  late Future<List<AdminWorker>> _future;
  bool _saving = false;
  bool _openingRoute = false;
  int _workersVersion = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<List<AdminWorker>> _load() {
    return MobileApi.instance.adminWorkers();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _createWorker() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminCreateWorker(
        name: name,
        level: _selectedLevel,
      );
      _nameController.clear();
      if (mounted) {
        setState(() {
          _selectedLevel = adminWorkerLevels.first;
          _future = _load();
          _workersVersion++;
        });
        showAdminTopNotice(context, 'Ishchi saqlandi');
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Ishchi qo‘shilmadi', icon: Icons.error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _updateLevel(AdminWorker worker, String level) async {
    try {
      await MobileApi.instance.adminUpdateWorkerLevel(
        id: worker.id,
        level: level,
      );
      if (mounted) {
        setState(() {
          _future = _load();
          _workersVersion++;
        });
        showAdminTopNotice(context, 'Ishchi darajasi saqlandi');
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          'Ishchi darajasi saqlanmadi',
          icon: Icons.error,
        );
      }
    }
  }

  void _openDrawerRoute(String routeName) {
    if (_openingRoute) {
      return;
    }
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    _openingRoute = true;
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.adminWorkerSettings,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Ishchi sozlamalari',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
      contentPadding: EdgeInsets.zero,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Material(
              color: theme.appBarTheme.backgroundColor ??
                  theme.colorScheme.surfaceContainer,
              child: TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                unselectedLabelStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(height: 38, text: 'Ishchilar'),
                  Tab(height: 38, text: 'Guruhlar'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildWorkersTab(),
                  _WorkerGroupsTab(workersVersion: _workersVersion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersTab() {
    return AppRefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          _workerSettingsPanelGap,
          _workerSettingsPanelGap,
          _workerSettingsPanelGap,
          116,
        ),
        children: [
          SoftCard(
            borderRadius: _workerSettingsCardRadius,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Ishchi nomi',
                    filled: true,
                  ),
                  onSubmitted: (_) => unawaited(_createWorker()),
                ),
                const SizedBox(height: 12),
                _WorkerLevelPicker(
                  value: _selectedLevel,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedLevel = value);
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving ? null : _createWorker,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Ishchi qo‘shish'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<AdminWorker>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: AppLoadingIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const SoftCard(
                  borderRadius: _workerSettingsCardRadius,
                  child: Center(child: Text('Ishchilar yuklanmadi')),
                );
              }
              final workers = snapshot.data ?? const <AdminWorker>[];
              if (workers.isEmpty) {
                return const SoftCard(
                  borderRadius: _workerSettingsCardRadius,
                  child: Center(child: Text('Ishchi topilmadi')),
                );
              }
              return Column(
                children: [
                  for (final worker in workers) ...[
                    _WorkerLevelTile(
                      worker: worker,
                      onLevelChanged: (level) =>
                          unawaited(_updateLevel(worker, level)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkerGroupsTab extends StatefulWidget {
  const _WorkerGroupsTab({required this.workersVersion});

  final int workersVersion;

  @override
  State<_WorkerGroupsTab> createState() => _WorkerGroupsTabState();
}

class _WorkerGroupsTabState extends State<_WorkerGroupsTab>
    with AutomaticKeepAliveClientMixin<_WorkerGroupsTab> {
  final TextEditingController _groupCodeController = TextEditingController();
  List<AdminWarehouse> _apparatus = const [];
  List<AdminWorker> _workers = const [];
  Map<String, AdminWorkerGroup> _groupsByCode = const {};
  bool _loading = true;
  bool _creatingGroup = false;
  final Set<String> _savingCodes = <String>{};
  String? _selectedGroupCode;
  String? _editingGroupCode;
  int _loadedWorkersVersion = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _WorkerGroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workersVersion != widget.workersVersion &&
        _loadedWorkersVersion != widget.workersVersion) {
      unawaited(_reloadWorkers());
    }
  }

  @override
  void dispose() {
    _groupCodeController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 300),
        MobileApi.instance.adminWorkers(),
        MobileApi.instance.adminWorkerGroups(),
      ]).timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      final apparatus = results[0] as List<AdminWarehouse>;
      final workers = results[1] as List<AdminWorker>;
      final groups = results[2] as List<AdminWorkerGroup>;
      setState(() {
        _apparatus = apparatus;
        _workers = workers;
        _loadedWorkersVersion = widget.workersVersion;
        _groupsByCode = {
          for (final group in groups) _groupKey(group.groupCode): group,
        };
        if (_selectedGroupCode != null &&
            !_groupsByCode.containsKey(_selectedGroupCode)) {
          _selectedGroupCode = null;
        }
        if (_editingGroupCode != null &&
            !_groupsByCode.containsKey(_editingGroupCode)) {
          _editingGroupCode = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        showAdminTopNotice(context, 'Guruhlar yuklanmadi', icon: Icons.error);
      }
    }
  }

  Future<void> _reloadWorkers() async {
    try {
      final workers = await MobileApi.instance
          .adminWorkers()
          .timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      setState(() {
        _workers = workers;
        _loadedWorkersVersion = widget.workersVersion;
      });
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Ishchilar yuklanmadi', icon: Icons.error);
      }
    }
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await MobileApi.instance
          .adminWorkerGroups()
          .timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      setState(() {
        _groupsByCode = {
          for (final group in groups) _groupKey(group.groupCode): group,
        };
        if (_selectedGroupCode != null &&
            !_groupsByCode.containsKey(_selectedGroupCode)) {
          _selectedGroupCode = null;
        }
        if (_editingGroupCode != null &&
            !_groupsByCode.containsKey(_editingGroupCode)) {
          _editingGroupCode = null;
        }
      });
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Guruhlar yuklanmadi', icon: Icons.error);
      }
    }
  }

  String _groupKey(String code) =>
      code.trim().split(RegExp(r'\s+')).join(' ').toUpperCase();

  AdminWorkerGroup _newGroup(String code) {
    return AdminWorkerGroup(
      apparatus: _workerGroupsScope,
      groupCode: _groupKey(code),
      shift: 'kunduz',
      startTime: '08:00',
      endTime: '20:00',
      workDaysPerWeek: 6,
      startDay: 'monday',
      accountingEnabled: false,
    );
  }

  void _setGroup(AdminWorkerGroup group) {
    final code = _groupKey(group.groupCode);
    setState(() {
      _groupsByCode = {
        ..._groupsByCode,
        code: group.copyWith(groupCode: code),
      };
    });
  }

  Future<void> _createGroup() async {
    final code = _groupKey(_groupCodeController.text);
    if (code.isEmpty || _groupsByCode.containsKey(code) || _creatingGroup) {
      return;
    }
    setState(() => _creatingGroup = true);
    try {
      final saved = await MobileApi.instance.adminSaveWorkerGroup(
        _newGroup(code),
      );
      if (!mounted) {
        return;
      }
      _groupCodeController.clear();
      setState(() {
        _selectedGroupCode = _groupKey(saved.groupCode);
        _groupsByCode = {
          ..._groupsByCode,
          _groupKey(saved.groupCode): saved,
        };
      });
      showAdminTopNotice(context, '${saved.groupCode} guruh yaratildi');
      await _loadGroups();
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, '$code guruh yaratilmadi',
            icon: Icons.error);
      }
    } finally {
      if (mounted) {
        setState(() => _creatingGroup = false);
      }
    }
  }

  Future<void> _saveGroup(AdminWorkerGroup group) async {
    final code = _groupKey(group.groupCode);
    if (code.isEmpty) {
      return;
    }
    setState(() => _savingCodes.add(code));
    try {
      final saved = await MobileApi.instance.adminSaveWorkerGroup(
        group.copyWith(
          apparatus: group.apparatus.trim().isEmpty
              ? _workerGroupsScope
              : group.apparatus.trim(),
          groupCode: code,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _groupsByCode = {
          ..._groupsByCode,
          _groupKey(saved.groupCode): saved,
        };
        _selectedGroupCode = _groupKey(saved.groupCode);
        _editingGroupCode = null;
      });
      showAdminTopNotice(context, '${saved.groupCode} guruh saqlandi');
      await _loadGroups();
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, '$code guruh saqlanmadi',
            icon: Icons.error);
      }
    } finally {
      if (mounted) {
        setState(() => _savingCodes.remove(code));
      }
    }
  }

  Map<String, String> _assignedWorkerGroups({String exceptGroupCode = ''}) {
    final except = _groupKey(exceptGroupCode);
    final result = <String, String>{};
    for (final group in _groupsByCode.values) {
      final code = _groupKey(group.groupCode);
      if (code == except) {
        continue;
      }
      for (final workerId in group.workerIds) {
        result[workerId] = code;
      }
    }
    return result;
  }

  List<AdminWorkerGroup> _sortedGroups() {
    final groups = _groupsByCode.values.toList();
    groups.sort((left, right) => left.groupCode.compareTo(right.groupCode));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey<String>('worker-groups-list'),
        padding: const EdgeInsets.fromLTRB(
          _workerSettingsPanelGap,
          _workerSettingsPanelGap,
          _workerSettingsPanelGap,
          116,
        ),
        children: [
          if (_loading) ...[
            const SoftCard(
              borderRadius: _workerSettingsCardRadius,
              padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  AppLoadingIndicator(size: 28, glyphSize: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Guruhlar yuklanmoqda')),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          _WorkerGroupCreateCard(
            controller: _groupCodeController,
            saving: _creatingGroup,
            onSave: () => unawaited(_createGroup()),
          ),
          const SizedBox(height: 12),
          if (_groupsByCode.isEmpty)
            const SoftCard(
              borderRadius: _workerSettingsCardRadius,
              child: Center(child: Text('Guruh topilmadi')),
            )
          else ...[
            Text('Guruhlar', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            M3SegmentSpacedColumn(
              children: [
                for (var index = 0; index < _sortedGroups().length; index++)
                  _WorkerGroupExpandableCard(
                    group: _sortedGroups()[index],
                    apparatus: _apparatus,
                    workers: _workers,
                    assignedWorkerGroups: _assignedWorkerGroups(
                      exceptGroupCode: _sortedGroups()[index].groupCode,
                    ),
                    expanded: _selectedGroupCode ==
                        _groupKey(_sortedGroups()[index].groupCode),
                    editing: _editingGroupCode ==
                        _groupKey(_sortedGroups()[index].groupCode),
                    saving: _savingCodes.contains(
                      _groupKey(_sortedGroups()[index].groupCode),
                    ),
                    onExpandedChanged: (expanded) {
                      setState(() {
                        final code =
                            _groupKey(_sortedGroups()[index].groupCode);
                        _selectedGroupCode = expanded ? code : null;
                        if (!expanded && _editingGroupCode == code) {
                          _editingGroupCode = null;
                        }
                      });
                    },
                    onEditChanged: (editing) {
                      setState(() {
                        final code =
                            _groupKey(_sortedGroups()[index].groupCode);
                        _selectedGroupCode = code;
                        _editingGroupCode = editing ? code : null;
                      });
                    },
                    onChanged: _setGroup,
                    onSave: () => unawaited(_saveGroup(_sortedGroups()[index])),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      _sortedGroups().length,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkerGroupCreateCard extends StatelessWidget {
  const _WorkerGroupCreateCard({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      borderRadius: _workerSettingsCardRadius,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Guruh yaratish', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          TextField(
            key: const Key('worker-group-code-input'),
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Guruh kodi',
              hintText: 'AB, BA, DD',
              filled: true,
            ),
            onSubmitted: (_) => onSave(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}

class _WorkerGroupExpandableCard extends StatelessWidget {
  const _WorkerGroupExpandableCard({
    required this.group,
    required this.apparatus,
    required this.workers,
    required this.assignedWorkerGroups,
    required this.expanded,
    required this.editing,
    required this.saving,
    required this.onExpandedChanged,
    required this.onEditChanged,
    required this.onChanged,
    required this.onSave,
    required this.slot,
  });

  final AdminWorkerGroup group;
  final List<AdminWarehouse> apparatus;
  final List<AdminWorker> workers;
  final Map<String, String> assignedWorkerGroups;
  final bool expanded;
  final bool editing;
  final bool saving;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<bool> onEditChanged;
  final ValueChanged<AdminWorkerGroup> onChanged;
  final VoidCallback onSave;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return M3SegmentFilledSurface(
      key: ValueKey('worker-group-card-${group.groupCode}'),
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onExpandedChanged(!expanded),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.groupCode} guruh',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${group.shift} • ${group.startTime}-${group.endTime} • ${group.workDaysPerWeek} kun • ${group.workerIds.length} odam',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: expanded ? 'Yopish' : 'Sozlash',
                    onPressed: () => onExpandedChanged(!expanded),
                    icon: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 36, right: 4),
                      child: _WorkerGroupExpandedControls(
                        group: group,
                        apparatus: apparatus,
                        workers: workers,
                        assignedWorkerGroups: assignedWorkerGroups,
                        editing: editing,
                        saving: saving,
                        onEdit: () => onEditChanged(true),
                        onCancelEdit: () => onEditChanged(false),
                        onChanged: onChanged,
                        onSave: onSave,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerGroupExpandedControls extends StatelessWidget {
  const _WorkerGroupExpandedControls({
    required this.group,
    required this.apparatus,
    required this.workers,
    required this.assignedWorkerGroups,
    required this.editing,
    required this.saving,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onChanged,
    required this.onSave,
  });

  final AdminWorkerGroup group;
  final List<AdminWarehouse> apparatus;
  final List<AdminWorker> workers;
  final Map<String, String> assignedWorkerGroups;
  final bool editing;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancelEdit;
  final ValueChanged<AdminWorkerGroup> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final selected = group.workerIds.toSet();
    final visibleWorkers = [
      for (final worker in workers)
        if (selected.contains(worker.id) ||
            !assignedWorkerGroups.containsKey(worker.id))
          worker,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(
          editing
              ? '${group.groupCode} guruh sozlamalari'
              : '${group.groupCode} guruh ma’lumoti',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        if (editing) ...[
          _WorkerGroupScheduleFields(
            group: group,
            apparatus: apparatus,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          if (workers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Ishchi topilmadi')),
            )
          else if (visibleWorkers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('ishchilar guruhlarga taqsimlanib bo‘lingan'),
              ),
            )
          else
            for (final worker in visibleWorkers)
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: selected.contains(worker.id),
                  title: Text(worker.name),
                  subtitle: Text(
                    assignedWorkerGroups[worker.id] == null
                        ? worker.level
                        : '${assignedWorkerGroups[worker.id]} guruhga ulangan',
                  ),
                  onChanged: (checked) {
                    final next = selected.toSet();
                    if (checked == true) {
                      next.add(worker.id);
                    } else {
                      next.remove(worker.id);
                    }
                    onChanged(
                      group.copyWith(
                        workerIds: next.toList(growable: false),
                      ),
                    );
                  },
                ),
              ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onCancelEdit,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Bekor qilish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ] else ...[
          _WorkerGroupInfoRows(group: group, workers: workers),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              tooltip: 'Tahrirlash',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ],
    );
  }
}

class _WorkerGroupInfoRows extends StatelessWidget {
  const _WorkerGroupInfoRows({
    required this.group,
    required this.workers,
  });

  final AdminWorkerGroup group;
  final List<AdminWorker> workers;

  @override
  Widget build(BuildContext context) {
    final workerNames = [
      for (final workerId in group.workerIds)
        for (final worker in workers)
          if (worker.id == workerId) worker.name,
    ];
    final startDay = adminWorkerStartDayLabels[group.startDay] ??
        adminWorkerStartDayLabels['monday']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkerGroupInfoRow(label: 'Smena', value: group.shift),
        _WorkerGroupInfoRow(
          label: 'Aparat',
          value: group.apparatus == _workerGroupsScope
              ? 'Tanlanmagan'
              : group.apparatus,
        ),
        _WorkerGroupInfoRow(
          label: 'Ish vaqti',
          value: '${group.startTime} - ${group.endTime}',
        ),
        _WorkerGroupInfoRow(
          label: 'Haftalik ish kuni',
          value: '${group.workDaysPerWeek} kun',
        ),
        _WorkerGroupInfoRow(label: 'Ishga chiqish kuni', value: startDay),
        _WorkerGroupInfoRow(
          label: 'Schot',
          value: group.accountingEnabled ? 'Hisoblanadi' : 'Hisoblanmaydi',
        ),
        _WorkerGroupInfoRow(
          label: 'Ishchilar',
          value:
              workerNames.isEmpty ? 'Biriktirilmagan' : workerNames.join(', '),
        ),
      ],
    );
  }
}

class _WorkerGroupInfoRow extends StatelessWidget {
  const _WorkerGroupInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerGroupScheduleFields extends StatelessWidget {
  const _WorkerGroupScheduleFields({
    required this.group,
    required this.apparatus,
    required this.onChanged,
  });

  final AdminWorkerGroup group;
  final List<AdminWarehouse> apparatus;
  final ValueChanged<AdminWorkerGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedApparatus = apparatus.any(
      (item) => item.warehouse.trim() == group.apparatus.trim(),
    )
        ? group.apparatus.trim()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('worker-group-apparatus-picker'),
          initialValue: selectedApparatus,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Aparat',
            filled: true,
          ),
          hint: const Text('Aparat tanlanmagan'),
          items: [
            for (final item in apparatus)
              DropdownMenuItem(
                value: item.warehouse,
                child: Text(item.warehouse, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: apparatus.isEmpty
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  onChanged(group.copyWith(apparatus: value));
                },
        ),
        const SizedBox(height: 12),
        Text('Ish vaqti', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: group.shift,
          decoration: const InputDecoration(
            labelText: 'Smena',
            hintText: 'Kunduz, tun, AB navbat',
            filled: true,
          ),
          onChanged: (value) => onChanged(group.copyWith(shift: value)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TimePickerField(
                label: 'Boshlanish',
                value: group.startTime,
                onChanged: (value) =>
                    onChanged(group.copyWith(startTime: value)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimePickerField(
                label: 'Tugash',
                value: group.endTime,
                onChanged: (value) => onChanged(group.copyWith(endTime: value)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: group.workDaysPerWeek.clamp(1, 7).toInt(),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Haftalik ish kuni',
            filled: true,
          ),
          items: [
            for (var day = 1; day <= 7; day++)
              DropdownMenuItem(value: day, child: Text('$day kun')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onChanged(group.copyWith(workDaysPerWeek: value));
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: adminWorkerStartDayLabels.containsKey(group.startDay)
              ? group.startDay
              : 'monday',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ishga chiqish kuni',
            filled: true,
          ),
          items: [
            for (final entry in adminWorkerStartDayLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onChanged(group.copyWith(startDay: value));
          },
        ),
        const SizedBox(height: 4),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: group.accountingEnabled,
            title: const Text('Schot hisoblanadi'),
            onChanged: (value) =>
                onChanged(group.copyWith(accountingEnabled: value)),
          ),
        ),
      ],
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _timeOfDay(value),
        );
        if (picked == null) {
          return;
        }
        onChanged(_formatTime(picked));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  TimeOfDay _timeOfDay(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _WorkerLevelTile extends StatelessWidget {
  const _WorkerLevelTile({
    required this.worker,
    required this.onLevelChanged,
  });

  final AdminWorker worker;
  final ValueChanged<String> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      borderRadius: _workerSettingsCardRadius,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              worker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: _WorkerLevelPicker(
              value: adminWorkerLevels.contains(worker.level)
                  ? worker.level
                  : adminWorkerLevels.last,
              onChanged: (value) {
                if (value == null || value == worker.level) {
                  return;
                }
                onLevelChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerLevelPicker extends StatelessWidget {
  const _WorkerLevelPicker({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Daraja',
        filled: true,
      ),
      items: [
        for (final level in adminWorkerLevels)
          DropdownMenuItem(value: level, child: Text(level)),
      ],
      onChanged: onChanged,
    );
  }
}
