import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/common_widgets.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';

const List<String> adminWorkerLevels = [
  'Brigader',
  'Master',
  '1 - darajali',
  '2 - darajali',
  '3 - darajali',
];

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
  String _statusMessage = '';
  bool _statusIsError = false;

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
          _statusMessage = 'Ishchi qo‘shildi';
          _statusIsError = false;
          _future = _load();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ishchi saqlandi')));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Ishchi qo‘shilmadi';
          _statusIsError = true;
        });
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
          _statusMessage = 'Ishchi darajasi saqlandi';
          _statusIsError = false;
          _future = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Ishchi darajasi saqlanmadi';
          _statusIsError = true;
        });
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
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => AppShellDrawerScope.maybeOf(context)?.openDrawer(),
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
                  const _WorkerGroupsTab(),
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 116),
        children: [
          if (_statusMessage.isNotEmpty) ...[
            _WorkerStatusBanner(
              message: _statusMessage,
              isError: _statusIsError,
            ),
            const SizedBox(height: 10),
          ],
          SoftCard(
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
                  child: Center(child: Text('Ishchilar yuklanmadi')),
                );
              }
              final workers = snapshot.data ?? const <AdminWorker>[];
              if (workers.isEmpty) {
                return const SoftCard(
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

class _WorkerStatusBanner extends StatelessWidget {
  const _WorkerStatusBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: isError ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isError ? scheme.error : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerGroupsTab extends StatefulWidget {
  const _WorkerGroupsTab();

  @override
  State<_WorkerGroupsTab> createState() => _WorkerGroupsTabState();
}

class _WorkerGroupsTabState extends State<_WorkerGroupsTab> {
  List<AdminWarehouse> _apparatus = const [];
  List<AdminWorker> _workers = const [];
  Map<String, AdminWorkerGroup> _groupsByCode = const {};
  AdminWarehouse? _selectedApparatus;
  bool _loading = true;
  bool _savingA = false;
  bool _savingB = false;
  String _statusMessage = '';
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 300),
        MobileApi.instance.adminWorkers(),
      ]);
      if (!mounted) {
        return;
      }
      final apparatus = results[0] as List<AdminWarehouse>;
      final workers = results[1] as List<AdminWorker>;
      final previous = _selectedApparatus?.warehouse.trim().toLowerCase();
      AdminWarehouse? selected;
      for (final item in apparatus) {
        if (item.warehouse.trim().toLowerCase() == previous) {
          selected = item;
          break;
        }
      }
      setState(() {
        _apparatus = apparatus;
        _workers = workers;
        _selectedApparatus =
            selected ?? (apparatus.isEmpty ? null : apparatus.first);
        _loading = false;
      });
      await _loadGroups();
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Guruhlar yuklanmadi';
          _statusIsError = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadGroups() async {
    final apparatus = _selectedApparatus?.warehouse.trim() ?? '';
    if (apparatus.isEmpty) {
      setState(() => _groupsByCode = const {});
      return;
    }
    try {
      final groups = await MobileApi.instance.adminWorkerGroups(
        apparatus: apparatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _groupsByCode = {
          for (final group in groups) group.groupCode.toUpperCase(): group,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Guruhlar yuklanmadi';
          _statusIsError = true;
        });
      }
    }
  }

  AdminWorkerGroup _group(String code) {
    final apparatus = _selectedApparatus?.warehouse.trim() ?? '';
    return _groupsByCode[code] ??
        AdminWorkerGroup(
          apparatus: apparatus,
          groupCode: code,
          shift: code == 'A' ? 'day' : 'night',
        );
  }

  void _setGroup(AdminWorkerGroup group) {
    final code = group.groupCode.toUpperCase();
    final oppositeCode = code == 'A' ? 'B' : 'A';
    final opposite = _group(oppositeCode).copyWith(
      shift: group.shift == 'day' ? 'night' : 'day',
      workerIds: _group(oppositeCode)
          .workerIds
          .where((id) => !group.workerIds.contains(id))
          .toList(growable: false),
    );
    setState(() {
      _groupsByCode = {
        ..._groupsByCode,
        code: group,
        oppositeCode: opposite,
      };
    });
  }

  Future<void> _saveGroup(String code) async {
    final apparatus = _selectedApparatus?.warehouse.trim() ?? '';
    if (apparatus.isEmpty) {
      return;
    }
    setState(() {
      if (code == 'A') {
        _savingA = true;
      } else {
        _savingB = true;
      }
    });
    try {
      final saved = await MobileApi.instance.adminSaveWorkerGroup(
        _group(code).copyWith(apparatus: apparatus),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = '${saved.groupCode} guruh saqlandi';
        _statusIsError = false;
      });
      await _loadGroups();
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = '$code guruh saqlanmadi';
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (code == 'A') {
            _savingA = false;
          } else {
            _savingB = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 116),
        children: [
          if (_statusMessage.isNotEmpty) ...[
            _WorkerStatusBanner(
              message: _statusMessage,
              isError: _statusIsError,
            ),
            const SizedBox(height: 10),
          ],
          if (_apparatus.isEmpty)
            const SoftCard(child: Center(child: Text('Aparat topilmadi')))
          else ...[
            _ApparatusPickerCard(
              apparatus: _apparatus,
              selected: _selectedApparatus!,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedApparatus = value;
                  _groupsByCode = const {};
                });
                unawaited(_loadGroups());
              },
            ),
            const SizedBox(height: 12),
            _WorkerGroupCard(
              group: _group('A'),
              workers: _workers,
              saving: _savingA,
              onChanged: _setGroup,
              onSave: () => unawaited(_saveGroup('A')),
            ),
            const SizedBox(height: 12),
            _WorkerGroupCard(
              group: _group('B'),
              workers: _workers,
              saving: _savingB,
              onChanged: _setGroup,
              onSave: () => unawaited(_saveGroup('B')),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApparatusPickerCard extends StatelessWidget {
  const _ApparatusPickerCard({
    required this.apparatus,
    required this.selected,
    required this.onChanged,
  });

  final List<AdminWarehouse> apparatus;
  final AdminWarehouse selected;
  final ValueChanged<AdminWarehouse?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: DropdownButtonFormField<AdminWarehouse>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Aparat',
          filled: true,
        ),
        items: [
          for (final item in apparatus)
            DropdownMenuItem(
              value: item,
              child: Text(
                item.warehouse,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _WorkerGroupCard extends StatelessWidget {
  const _WorkerGroupCard({
    required this.group,
    required this.workers,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final AdminWorkerGroup group;
  final List<AdminWorker> workers;
  final bool saving;
  final ValueChanged<AdminWorkerGroup> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final selected = group.workerIds.toSet();
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${group.apparatus} ${group.groupCode} guruh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${selected.length} odam'),
            ],
          ),
          const SizedBox(height: 12),
          _ShiftPicker(
            value: group.shift,
            onChanged: (shift) {
              if (shift == null || shift == group.shift) {
                return;
              }
              onChanged(group.copyWith(shift: shift));
            },
          ),
          const SizedBox(height: 12),
          if (workers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Ishchi topilmadi')),
            )
          else
            for (final worker in workers)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: selected.contains(worker.id),
                title: Text(worker.name),
                subtitle: Text(worker.level),
                onChanged: (checked) {
                  final next = selected.toSet();
                  if (checked == true) {
                    next.add(worker.id);
                  } else {
                    next.remove(worker.id);
                  }
                  onChanged(
                    group.copyWith(workerIds: next.toList(growable: false)),
                  );
                },
              ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.groups_2_rounded),
            label: Text('${group.groupCode} guruhni saqlash'),
          ),
        ],
      ),
    );
  }
}

class _ShiftPicker extends StatelessWidget {
  const _ShiftPicker({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value == 'night' ? 'night' : 'day',
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Smena',
        filled: true,
      ),
      items: const [
        DropdownMenuItem(value: 'day', child: Text('Kunduzgi')),
        DropdownMenuItem(value: 'night', child: Text('Tungi')),
      ],
      onChanged: onChanged,
    );
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
