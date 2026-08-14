import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/admin_apparatus_scope_picker.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_surface_tab_bar.dart';
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

String _workerLevelLabel(String level, AppLocalizations l10n) {
  switch (level) {
    case 'Brigader':
      return l10n.adminText('worker.level.brigader');
    case 'Master':
      return l10n.adminText('worker.level.master');
    case '1 - darajali':
      return l10n.adminText('worker.level.one');
    case '2 - darajali':
      return l10n.adminText('worker.level.two');
    case '3 - darajali':
      return l10n.adminText('worker.level.three');
    default:
      return level;
  }
}

String _workerStartDayLabel(String day, AppLocalizations l10n) {
  final key = switch (day) {
    'monday' => 'day.monday',
    'tuesday' => 'day.tuesday',
    'wednesday' => 'day.wednesday',
    'thursday' => 'day.thursday',
    'friday' => 'day.friday',
    'saturday' => 'day.saturday',
    'sunday' => 'day.sunday',
    _ => null,
  };
  return key == null
      ? (adminWorkerStartDayLabels[day] ?? day)
      : l10n.adminText('worker.$key');
}

String _workerShiftLabel(String shift, AppLocalizations l10n) {
  final normalized = shift.trim().toLowerCase();
  switch (normalized) {
    case 'kunduz':
      return l10n.adminText('worker.shift.day');
    case 'tun':
      return l10n.adminText('worker.shift.night');
    case 'ab navbat':
    case 'ab':
      return l10n.adminText('worker.shift.ab');
    default:
      return shift;
  }
}

String _workerDeletionDependencyLabel(
  AdminWorkerDeletionDependency dependency,
  AppLocalizations l10n,
) {
  switch (dependency.kind) {
    case 'active_order':
      final status = dependency.status == 'paused'
          ? l10n.adminText('worker.status.paused')
          : l10n.adminText('worker.status.in_progress');
      return l10n.adminText(
        'worker.dependency.order',
        values: {
          'order': dependency.orderId,
          'apparatus': dependency.apparatus,
          'status': status,
        },
      );
    case 'worker_group':
      final apparatus = dependency.apparatus.trim();
      return apparatus.isEmpty || apparatus == _workerGroupsScope
          ? l10n.adminText(
              'worker.dependency.group',
              values: {'label': dependency.label},
            )
          : l10n.adminText(
              'worker.dependency.group_apparatus',
              values: {'label': dependency.label, 'apparatus': apparatus},
            );
    case 'apparatus':
      return l10n.adminText(
        'worker.dependency.apparatus',
        values: {'label': dependency.label},
      );
    case 'role_assignment':
      return l10n.adminText(
        'worker.dependency.role',
        values: {'label': dependency.label},
      );
    case 'item_group':
      return l10n.adminText(
        'worker.dependency.item_group',
        values: {'label': dependency.label},
      );
    case 'qolip_checkout':
      final apparatusName = dependency.apparatus.trim();
      return apparatusName.isEmpty
          ? l10n.adminText(
              'worker.dependency.mold',
              values: {'label': dependency.label},
            )
          : l10n.adminText(
              'worker.dependency.mold_apparatus',
              values: {'label': dependency.label, 'apparatus': apparatusName},
            );
    default:
      return dependency.label;
  }
}

String _workerGroupCodeKey(String code) =>
    code.trim().split(RegExp(r'\s+')).join(' ').toUpperCase();

AdminWorkerGroup _newWorkerGroup(String code) {
  return AdminWorkerGroup(
    apparatus: _workerGroupsScope,
    groupCode: _workerGroupCodeKey(code),
    shift: 'kunduz',
    startTime: '08:00',
    endTime: '20:00',
    workDaysPerWeek: 6,
    startDay: 'monday',
    accountingEnabled: false,
  );
}

class _WorkerSettingsData {
  const _WorkerSettingsData({
    required this.workers,
    required this.apparatus,
    required this.assignmentsByWorker,
  });

  final List<AdminWorker> workers;
  final List<AdminApparatus> apparatus;
  final Map<String, AdminRoleAssignment> assignmentsByWorker;
}

class AdminWorkerSettingsScreen extends StatefulWidget {
  const AdminWorkerSettingsScreen({super.key});

  @override
  State<AdminWorkerSettingsScreen> createState() =>
      _AdminWorkerSettingsScreenState();
}

class _AdminWorkerSettingsScreenState extends State<AdminWorkerSettingsScreen>
    with SingleTickerProviderStateMixin {
  late Future<_WorkerSettingsData> _future;
  late TabController _tabController;
  int _workersVersion = 0;
  int _groupsVersion = 0;
  String? _selectedWorkerId;
  String? _deactivatingWorkerId;
  final Set<String> _savingApparatusWorkerIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _notifyWorkerSettingsLoadFailure() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        context.l10n.adminText('worker.load_failed'),
        icon: Icons.error,
      );
    });
  }

  Future<List<AdminApparatus>> _loadWorkerApparatus() async {
    try {
      return await MobileApi.instance.adminApparatus(limit: 300);
    } catch (_) {
      _notifyWorkerSettingsLoadFailure();
      return const <AdminApparatus>[];
    }
  }

  Future<List<AdminRoleAssignment>> _loadWorkerRoleAssignments() async {
    try {
      return await MobileApi.instance.adminRoleAssignments();
    } catch (_) {
      _notifyWorkerSettingsLoadFailure();
      return const <AdminRoleAssignment>[];
    }
  }

  Future<_WorkerSettingsData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminWorkers(),
      _loadWorkerApparatus(),
      _loadWorkerRoleAssignments(),
    ]);
    final assignments = results[2] as List<AdminRoleAssignment>;
    return _WorkerSettingsData(
      workers: results[0] as List<AdminWorker>,
      apparatus: results[1] as List<AdminApparatus>,
      assignmentsByWorker: {
        for (final assignment in assignments)
          if (assignment.principalRole == UserRole.aparatchi &&
              assignment.principalRef.trim().isNotEmpty)
            assignment.principalRef.trim(): assignment,
      },
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<bool> _saveWorkerApparatus(
    AdminWorker worker,
    Set<String> selected,
    AdminRoleAssignment? currentAssignment,
  ) async {
    final workerId = worker.id.trim();
    if (workerId.isEmpty || _savingApparatusWorkerIds.contains(workerId)) {
      return false;
    }
    final assignedApparatus = selected
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: true)
      ..sort();
    setState(() => _savingApparatusWorkerIds.add(workerId));
    try {
      await MobileApi.instance.adminUpsertRoleAssignment(
        AdminRoleAssignment(
          principalRole: UserRole.aparatchi,
          principalRef: workerId,
          roleId: currentAssignment?.roleId.trim().isNotEmpty == true
              ? currentAssignment!.roleId.trim()
              : 'aparatchi',
          assignedApparatus: assignedApparatus,
          assignedItemGroups:
              currentAssignment?.assignedItemGroups ?? const <String>[],
        ),
      );
      if (mounted) {
        showAdminTopNotice(context, context.l10n.adminText('scope.saved'));
        setState(() => _future = _load());
      }
      return true;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText(
            'scope.save_failed',
            values: {'error': error},
          ),
          icon: Icons.error,
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _savingApparatusWorkerIds.remove(workerId));
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
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.level_saved'),
        );
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.level_save_failed'),
          icon: Icons.error,
        );
      }
    }
  }

  Future<void> _openWorkerNameEditor(AdminWorker worker) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _WorkerNameEditDialogCard(
            worker: worker,
            onSaved: () async {
              if (!mounted) {
                return;
              }
              setState(() {
                _future = _load();
                _workersVersion++;
              });
              showAdminTopNotice(
                context,
                context.l10n.adminText('worker.name_saved'),
              );
            },
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _openWorkerLevelPicker(AdminWorker worker) async {
    final currentLevel = adminWorkerLevels.contains(worker.level)
        ? worker.level
        : adminWorkerLevels.last;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3PickerSheet<String>(
          title: context.l10n.adminText('worker.level_title'),
          hintText: context.l10n.adminText('worker.level_search_title'),
          items: adminWorkerLevels,
          itemTitle: (item) => _workerLevelLabel(item, context.l10n),
          itemSubtitle: (_) => context.l10n.adminText('worker.level_subtitle'),
          matchesQuery: (item, query) =>
              item.toLowerCase().contains(query.trim().toLowerCase()),
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || picked == currentLevel || !mounted) {
      return;
    }
    await _updateLevel(worker, picked);
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  Future<void> _openWorkerCreateDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _WorkerCreateDialogCard(
            onSaved: () async {
              if (!mounted) {
                return;
              }
              setState(() {
                _future = _load();
                _workersVersion++;
              });
              showAdminTopNotice(
                context,
                context.l10n.adminText('worker.saved'),
              );
            },
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _openWorkerGroupCreateDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _WorkerGroupCreateDialogCard(
            onSaved: () async {
              if (!mounted) {
                return;
              }
              setState(() => _groupsVersion++);
              showAdminTopNotice(
                context,
                context.l10n.adminText('worker.group_created'),
              );
            },
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _deactivateWorker(
    AdminWorker worker,
  ) async {
    if (_deactivatingWorkerId != null) {
      return;
    }
    setState(() => _deactivatingWorkerId = worker.id);
    try {
      final check =
          await MobileApi.instance.adminWorkerDeletionCheck(worker.id);
      if (!mounted) {
        return;
      }
      final confirmed = await _showWorkerDeactivationDialog(worker, check);
      if (!confirmed || !mounted) {
        return;
      }
      await MobileApi.instance.adminDeactivateWorker(
        id: worker.id,
        confirmConnections: check.requiresConfirmation,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedWorkerId = null;
        _future = _load();
        _workersVersion++;
        _groupsVersion++;
      });
      showAdminTopNotice(
        context,
        context.l10n.adminText('worker.deactivated'),
      );
    } on AdminWorkerDeletionRejected catch (error) {
      if (!mounted) {
        return;
      }
      if (error.check.blocked) {
        await _showWorkerDeactivationDialog(worker, error.check);
      } else {
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.connections_changed'),
          icon: Icons.error,
        );
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        showAdminTopNotice(context, error.message, icon: Icons.error);
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.deactivation_failed'),
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted && _deactivatingWorkerId == worker.id) {
        setState(() => _deactivatingWorkerId = null);
      }
    }
  }

  Future<bool> _showWorkerDeactivationDialog(
    AdminWorker worker,
    AdminWorkerDeletionCheck check,
  ) async {
    final blocked = check.blocked;
    final dependencies = blocked ? check.activeWork : check.connections;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(
            blocked ? Icons.block_rounded : Icons.person_off_outlined,
            color: blocked ? scheme.error : scheme.onSurface,
          ),
          title: Text(
            blocked
                ? dialogContext.l10n.adminText(
                    'worker.deactivate_blocked_title',
                  )
                : dialogContext.l10n.adminText('worker.deactivate_title'),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blocked
                        ? dialogContext.l10n.adminText(
                            'worker.deactivate_blocked_message',
                            values: {'name': worker.name},
                          )
                        : dependencies.isEmpty
                            ? dialogContext.l10n.adminText(
                                'worker.deactivate_confirm_message',
                                values: {'name': worker.name},
                              )
                            : dialogContext.l10n.adminText(
                                'worker.deactivate_connections_message',
                                values: {'name': worker.name},
                              ),
                  ),
                  if (dependencies.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (final dependency in dependencies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              blocked
                                  ? Icons.work_history_outlined
                                  : Icons.link_rounded,
                              size: 18,
                              color: blocked
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _workerDeletionDependencyLabel(
                                  dependency,
                                  dialogContext.l10n,
                                ),
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (!blocked)
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          dialogContext.l10n.adminText('action.cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                        ),
                        child: Text(
                          dialogContext.l10n.adminText('action.deactivate'),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.l10n.adminText('action.close')),
              ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.adminWorkerSettings,
        onNavigate: _openDrawerRoute,
      ),
      title: context.l10n.adminText('worker.title'),
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(
        activeTab: null,
        primaryFabActions: [
          AdminFabMenuAction(
            title: context.l10n.adminText('worker.add'),
            icon: Icons.person_add_alt_1_rounded,
            onTap: _openWorkerCreateDialog,
          ),
          AdminFabMenuAction(
            title: context.l10n.adminText('worker.group_add'),
            icon: Icons.groups_2_outlined,
            onTap: _openWorkerGroupCreateDialog,
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          AdminSurfaceTabBar(
            controller: _tabController,
            tabs: [
              Tab(
                height: 38,
                text: context.l10n.adminText('worker.tabs_workers'),
              ),
              Tab(
                height: 38,
                text: context.l10n.adminText('worker.tabs_groups'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWorkersTab(),
                _WorkerGroupsTab(
                  workersVersion: _workersVersion,
                  groupsVersion: _groupsVersion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersTab() {
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: AppRefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            _workerSettingsPanelGap,
            _workerSettingsPanelGap,
            _workerSettingsPanelGap,
            116,
          ),
          children: [
            FutureBuilder<_WorkerSettingsData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: AppLoadingIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return AppSegmentSurfaceCard(
                    child: Center(
                      child: Text(
                        context.l10n.adminText('worker.load_failed'),
                      ),
                    ),
                  );
                }
                final data = snapshot.data;
                final workers = data?.workers ?? const <AdminWorker>[];
                if (workers.isEmpty) {
                  return Center(
                    child: Text(context.l10n.adminText('worker.empty')),
                  );
                }
                return M3SegmentSpacedColumn(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var index = 0; index < workers.length; index++)
                      _WorkerSettingsCard(
                        slot:
                            M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index,
                          workers.length,
                        ),
                        worker: workers[index],
                        apparatus: data?.apparatus ?? const <AdminApparatus>[],
                        assignedApparatus: data
                                ?.assignmentsByWorker[workers[index].id.trim()]
                                ?.assignedApparatus ??
                            const <String>[],
                        savingApparatus: _savingApparatusWorkerIds
                            .contains(workers[index].id.trim()),
                        expanded: _selectedWorkerId == workers[index].id,
                        onExpandedChanged: (expanded) {
                          setState(() {
                            _selectedWorkerId =
                                expanded ? workers[index].id : null;
                          });
                        },
                        onEditLevel: () =>
                            unawaited(_openWorkerLevelPicker(workers[index])),
                        onEditName: () =>
                            unawaited(_openWorkerNameEditor(workers[index])),
                        onSaveApparatus: (selected) => _saveWorkerApparatus(
                          workers[index],
                          selected,
                          data?.assignmentsByWorker[workers[index].id.trim()],
                        ),
                        deleting: _deactivatingWorkerId == workers[index].id,
                        onDelete: () => unawaited(
                          _deactivateWorker(workers[index]),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerCreateDialogCard extends StatefulWidget {
  const _WorkerCreateDialogCard({
    required this.onSaved,
    required this.onClose,
  });

  final Future<void> Function() onSaved;
  final VoidCallback onClose;

  @override
  State<_WorkerCreateDialogCard> createState() =>
      _WorkerCreateDialogCardState();
}

class _WorkerCreateDialogCardState extends State<_WorkerCreateDialogCard> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedLevel = adminWorkerLevels.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
      await widget.onSaved();
      if (mounted) {
        widget.onClose();
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.add_failed'),
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickLevel() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3PickerSheet<String>(
          title: context.l10n.adminText('worker.create_level_title'),
          hintText: context.l10n.adminText('worker.level_search'),
          items: adminWorkerLevels,
          itemTitle: (item) => _workerLevelLabel(item, context.l10n),
          itemSubtitle: (_) => context.l10n.adminText('worker.level_subtitle'),
          matchesQuery: (item, query) =>
              item.toLowerCase().contains(query.trim().toLowerCase()),
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedLevel = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.adminText('worker.create_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.adminText('worker.close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: context.l10n.adminText('worker.name'),
                ),
              ),
              const SizedBox(height: 12),
              _WorkerLevelPickerField(
                value: _selectedLevel,
                onTap: _pickLevel,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(context.l10n.adminText('worker.add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerNameEditDialogCard extends StatefulWidget {
  const _WorkerNameEditDialogCard({
    required this.worker,
    required this.onSaved,
    required this.onClose,
  });

  final AdminWorker worker;
  final Future<void> Function() onSaved;
  final VoidCallback onClose;

  @override
  State<_WorkerNameEditDialogCard> createState() =>
      _WorkerNameEditDialogCardState();
}

class _WorkerNameEditDialogCardState extends State<_WorkerNameEditDialogCard> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.worker.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminUpdateWorkerName(
        id: widget.worker.id,
        name: name,
      );
      await widget.onSaved();
      if (mounted) {
        widget.onClose();
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.name_save_failed'),
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.adminText('worker.edit_name'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.adminText('worker.close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('worker-name-field'),
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: context.l10n.adminText('worker.name'),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.adminText('action.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerGroupCreateDialogCard extends StatefulWidget {
  const _WorkerGroupCreateDialogCard({
    required this.onSaved,
    required this.onClose,
  });

  final Future<void> Function() onSaved;
  final VoidCallback onClose;

  @override
  State<_WorkerGroupCreateDialogCard> createState() =>
      _WorkerGroupCreateDialogCardState();
}

class _WorkerGroupCreateDialogCardState
    extends State<_WorkerGroupCreateDialogCard> {
  final TextEditingController _groupCodeController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _groupCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _workerGroupCodeKey(_groupCodeController.text);
    if (code.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final groups = await MobileApi.instance.adminWorkerGroups();
      final exists = groups.any(
        (group) => _workerGroupCodeKey(group.groupCode) == code,
      );
      if (exists) {
        if (mounted) {
          showAdminTopNotice(
            context,
            context.l10n.adminText(
              'worker.group_already_exists',
              values: {'code': code},
            ),
          );
        }
        return;
      }
      await MobileApi.instance.adminSaveWorkerGroup(_newWorkerGroup(code));
      await widget.onSaved();
      if (mounted) {
        widget.onClose();
      }
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText(
            'worker.group_create_failed',
            values: {'code': code},
          ),
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.adminText('worker.group_create_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.adminText('worker.close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('worker-group-code-dialog-input'),
                controller: _groupCodeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: context.l10n.adminText('worker.group_name'),
                ).copyWith(hintText: 'AB, BA, DD'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(context.l10n.adminText('action.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerLevelPickerField extends StatelessWidget {
  const _WorkerLevelPickerField({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appSurfaceInputDecoration(
          context,
          labelText: context.l10n.adminText('worker.level_label'),
          prefixIcon: const Icon(Icons.badge_outlined),
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Text(
          _workerLevelLabel(value, context.l10n),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WorkerGroupsTab extends StatefulWidget {
  const _WorkerGroupsTab({
    required this.workersVersion,
    required this.groupsVersion,
  });

  final int workersVersion;
  final int groupsVersion;

  @override
  State<_WorkerGroupsTab> createState() => _WorkerGroupsTabState();
}

class _WorkerGroupsTabState extends State<_WorkerGroupsTab>
    with AutomaticKeepAliveClientMixin<_WorkerGroupsTab> {
  List<AdminWorker> _workers = const [];
  Map<String, AdminWorkerGroup> _groupsByCode = const {};
  bool _loading = true;
  final Set<String> _savingCodes = <String>{};
  String? _selectedGroupCode;
  String? _editingGroupCode;
  AdminWorkerGroup? _editingOriginalGroup;
  int _loadedWorkersVersion = -1;
  int _loadedGroupsVersion = -1;

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
    if (oldWidget.groupsVersion != widget.groupsVersion &&
        _loadedGroupsVersion != widget.groupsVersion) {
      unawaited(_loadGroups());
    }
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MobileApi.instance.adminWorkers(),
        MobileApi.instance.adminWorkerGroups(),
      ]).timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      final workers = results[0] as List<AdminWorker>;
      final groups = results[1] as List<AdminWorkerGroup>;
      setState(() {
        _workers = workers;
        _loadedWorkersVersion = widget.workersVersion;
        _loadedGroupsVersion = widget.groupsVersion;
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
          _editingOriginalGroup = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.group_load_failed'),
          icon: Icons.error,
        );
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
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.load_failed'),
          icon: Icons.error,
        );
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
        final loadedGroups = <String, AdminWorkerGroup>{
          for (final group in groups) _groupKey(group.groupCode): group,
        };
        final editingCode = _editingGroupCode;
        final editingDraft =
            editingCode == null ? null : _groupsByCode[editingCode];
        if (editingCode != null &&
            editingDraft != null &&
            loadedGroups.containsKey(editingCode)) {
          loadedGroups[editingCode] = editingDraft;
        }
        _groupsByCode = loadedGroups;
        _loadedGroupsVersion = widget.groupsVersion;
        if (_selectedGroupCode != null &&
            !_groupsByCode.containsKey(_selectedGroupCode)) {
          _selectedGroupCode = null;
        }
        if (_editingGroupCode != null &&
            !_groupsByCode.containsKey(_editingGroupCode)) {
          _editingGroupCode = null;
          _editingOriginalGroup = null;
        }
      });
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('worker.group_load_failed'),
          icon: Icons.error,
        );
      }
    }
  }

  String _groupKey(String code) => _workerGroupCodeKey(code);

  void _setGroup(AdminWorkerGroup group) {
    final currentCode = _editingGroupCode ?? _selectedGroupCode;
    final code = _groupKey(group.groupCode);
    final editingExistingGroup =
        _editingOriginalGroup != null && currentCode != null;
    final mapKey = editingExistingGroup
        ? currentCode
        : code.isEmpty
            ? currentCode ?? code
            : code;
    setState(() {
      final groups = {..._groupsByCode};
      if (currentCode != null && currentCode != mapKey) {
        groups.remove(currentCode);
      }
      groups[mapKey] = group;
      _groupsByCode = groups;
      if (!editingExistingGroup && code.isNotEmpty) {
        _selectedGroupCode = code;
        _editingGroupCode = code;
      }
    });
  }

  void _startEditingGroup(AdminWorkerGroup group) {
    final code = _groupKey(group.groupCode);
    setState(() {
      _selectedGroupCode = code;
      _editingGroupCode = code;
      _editingOriginalGroup = group;
    });
  }

  void _cancelEditingGroup({bool collapse = false}) {
    final original = _editingOriginalGroup;
    final currentCode = _editingGroupCode;
    if (original == null) {
      setState(() {
        _editingGroupCode = null;
        if (collapse) {
          _selectedGroupCode = null;
        }
      });
      return;
    }
    final originalCode = _groupKey(original.groupCode);
    final groups = {..._groupsByCode};
    if (currentCode != null) {
      groups.remove(currentCode);
    }
    groups.remove(originalCode);
    groups[originalCode] = original;
    setState(() {
      _groupsByCode = groups;
      _selectedGroupCode = collapse ? null : originalCode;
      _editingGroupCode = null;
      _editingOriginalGroup = null;
    });
  }

  Future<void> _saveGroup(AdminWorkerGroup group) async {
    final code = _groupKey(group.groupCode);
    if (code.isEmpty) {
      return;
    }
    final original = _editingOriginalGroup;
    final previousGroupCode =
        original == null ? null : _groupKey(original.groupCode);
    final previousApparatus = original?.apparatus.trim();
    setState(() => _savingCodes.add(code));
    try {
      // Keep the legacy group field for API/DB compatibility. Apparatus access
      // is saved on each worker from the Workers tab.
      final saved = await MobileApi.instance.adminSaveWorkerGroup(
        group.copyWith(
          apparatus: group.apparatus.trim().isEmpty
              ? _workerGroupsScope
              : group.apparatus.trim(),
          groupCode: code,
        ),
        previousApparatus: previousApparatus,
        previousGroupCode: previousGroupCode,
      );
      if (!mounted) {
        return;
      }
      final originalCode = previousGroupCode ?? code;
      setState(() {
        final groups = {..._groupsByCode};
        groups.remove(originalCode);
        groups.remove(code);
        groups[_groupKey(saved.groupCode)] = saved;
        _groupsByCode = {
          ...groups,
        };
        _selectedGroupCode = _groupKey(saved.groupCode);
        _editingGroupCode = null;
        _editingOriginalGroup = null;
      });
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          'worker.group_saved',
          values: {'code': saved.groupCode},
        ),
      );
      await _loadGroups();
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText(
            'worker.group_save_failed',
            values: {'code': code},
          ),
          icon: Icons.error,
        );
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

  List<MapEntry<String, AdminWorkerGroup>> _sortedGroupEntries() {
    final groups = _groupsByCode.entries.toList();
    groups.sort(
        (left, right) => left.value.groupCode.compareTo(right.value.groupCode));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final groups = _sortedGroupEntries();
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: AppRefreshIndicator(
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
              AppSegmentSurfaceCard(
                child: Row(
                  children: [
                    AppLoadingIndicator(size: 28, glyphSize: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.adminText('worker.load_groups'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_groupsByCode.isEmpty)
              Center(
                child: Text(context.l10n.adminText('worker.group_empty')),
              )
            else
              M3SegmentSpacedColumn(
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in groups)
                    _WorkerGroupExpandableCard(
                      group: entry.value,
                      identityKey: entry.key,
                      workers: _workers,
                      assignedWorkerGroups: _assignedWorkerGroups(
                        exceptGroupCode: entry.value.groupCode,
                      ),
                      expanded: _selectedGroupCode == entry.key,
                      editing: _editingGroupCode == entry.key,
                      saving: _savingCodes.contains(entry.key),
                      onExpandedChanged: (expanded) {
                        final code = entry.key;
                        if (!expanded && _editingGroupCode == code) {
                          _cancelEditingGroup(collapse: true);
                          return;
                        }
                        setState(() {
                          _selectedGroupCode = expanded ? code : null;
                        });
                      },
                      onEditChanged: (editing) {
                        if (editing) {
                          _startEditingGroup(entry.value);
                        } else {
                          _cancelEditingGroup();
                        }
                      },
                      onChanged: _setGroup,
                      onSave: () => unawaited(_saveGroup(entry.value)),
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        groups.indexOf(entry),
                        groups.length,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkerGroupExpandableCard extends StatelessWidget {
  const _WorkerGroupExpandableCard({
    required this.group,
    required this.identityKey,
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
  final String identityKey;
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
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final summary = '${_workerShiftLabel(group.shift, context.l10n)} • '
        '${group.startTime}-${group.endTime} • '
        '${context.l10n.adminText(
      'worker.day_count',
      values: {'count': group.workDaysPerWeek},
    )} • '
        '${context.l10n.adminText(
      'worker.workers_count',
      values: {'count': group.workerIds.length},
    )}';

    return Material(
      key: ValueKey('worker-group-card-$identityKey'),
      color: scheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.groups_2_rounded,
                          size: 16,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.l10n.adminText(
                              'worker.group_title',
                              values: {'code': group.groupCode},
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: _WorkerGroupExpandedControls(
                      group: group,
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
    );
  }
}

class _WorkerGroupExpandedControls extends StatelessWidget {
  const _WorkerGroupExpandedControls({
    required this.group,
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
    final visibleWorkers = _visibleWorkers();
    final selectedWorkerNames = [
      for (final worker in workers)
        if (selected.contains(worker.id)) worker.name,
    ];
    final workerFieldValue = selectedWorkerNames.isEmpty
        ? selected.isEmpty
            ? context.l10n.adminText('worker.unassigned')
            : context.l10n.adminText(
                'worker.selected_count',
                values: {'count': selected.length},
              )
        : selectedWorkerNames.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(
          editing
              ? context.l10n.adminText(
                  'worker.group_settings',
                  values: {'code': group.groupCode},
                )
              : context.l10n.adminText(
                  'worker.group_info',
                  values: {'code': group.groupCode},
                ),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        if (editing) ...[
          _WorkerGroupScheduleFields(
            group: group,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          if (workers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(context.l10n.adminText('worker.worker_empty')),
              ),
            )
          else ...[
            _WorkerGroupWorkerPickerField(
              value: workerFieldValue,
              onTap: visibleWorkers.isEmpty
                  ? null
                  : () => unawaited(_openWorkerPicker(context)),
            ),
            if (visibleWorkers.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    context.l10n.adminText('worker.assigned_all'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onCancelEdit,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(context.l10n.adminText('action.cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('worker-group-save'),
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(context.l10n.adminText('action.save')),
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
              tooltip: context.l10n.adminText('worker.edit'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ],
    );
  }

  List<AdminWorker> _visibleWorkers() {
    final selected = group.workerIds.toSet();
    return [
      for (final worker in workers)
        if (selected.contains(worker.id) ||
            !assignedWorkerGroups.containsKey(worker.id))
          worker,
    ];
  }

  Future<void> _openWorkerPicker(BuildContext context) async {
    final visibleWorkers = _visibleWorkers();
    if (visibleWorkers.isEmpty) {
      return;
    }
    final selected = group.workerIds.toSet();
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (sheetContext) {
        return M3AsyncPickerSheet<AdminWorker>(
          title: sheetContext.l10n.adminText('worker.add'),
          supportingText: sheetContext.l10n.adminText('worker.assigned_all'),
          hintText: sheetContext.l10n.adminText('worker.search'),
          pageSize: visibleWorkers.isEmpty ? 1 : visibleWorkers.length,
          loadPage: (query, offset, limit) async {
            final needle = query.trim().toLowerCase();
            final filtered = visibleWorkers.where((worker) {
              return needle.isEmpty ||
                  worker.name.toLowerCase().contains(needle) ||
                  worker.level.toLowerCase().contains(needle);
            }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (worker) => worker.name,
          itemSubtitle: (worker) =>
              _workerLevelLabel(worker.level, sheetContext.l10n),
          itemKey: (worker) => worker.id,
          itemSelected: (worker) => selected.contains(worker.id),
          initialSelectedKeys: selected.map<Object>((id) => id).toSet(),
          multiSelectOnTap: true,
          onSelected: (worker) => Navigator.of(sheetContext).pop({worker.id}),
          onMultiSelected: (items) => Navigator.of(sheetContext).pop(
            items.map((worker) => worker.id).toSet(),
          ),
          selectedCountLabel: (count) => sheetContext.l10n.adminText(
            'worker.selected_count',
            values: {'count': count},
          ),
          confirmSelectionTooltip:
              sheetContext.l10n.adminText('worker.confirm_workers'),
        );
      },
    );
    if (picked == null) {
      return;
    }
    onChanged(group.copyWith(workerIds: picked.toList(growable: false)));
  }
}

class _WorkerGroupWorkerPickerField extends StatelessWidget {
  const _WorkerGroupWorkerPickerField({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const Key('worker-group-worker-picker'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appSurfaceInputDecoration(
          context,
          labelText: context.l10n.adminText('worker.add'),
          prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ).copyWith(enabled: onTap != null),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color:
                    onTap == null ? scheme.onSurfaceVariant : scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkerGroupInfoRow(
          label: l10n.adminText('worker.shift_label'),
          value: _workerShiftLabel(group.shift, l10n),
        ),
        _WorkerGroupInfoRow(
          label: l10n.adminText('worker.work_time'),
          value: '${group.startTime} - ${group.endTime}',
        ),
        _WorkerGroupInfoRow(
          label: l10n.adminText('worker.weekly_days'),
          value: l10n.adminText(
            'worker.day_count',
            values: {'count': group.workDaysPerWeek},
          ),
        ),
        _WorkerGroupInfoRow(
          label: l10n.adminText('worker.start_day'),
          value: _workerStartDayLabel(group.startDay, l10n),
        ),
        _WorkerGroupInfoRow(
          label: l10n.adminText('worker.accounting'),
          value: group.accountingEnabled
              ? l10n.adminText('worker.accounting_yes')
              : l10n.adminText('worker.accounting_no'),
        ),
        _WorkerGroupInfoRow(
          label: l10n.adminText('worker.group_workers'),
          value: workerNames.isEmpty
              ? l10n.adminText('worker.unassigned')
              : workerNames.join(', '),
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
    required this.onChanged,
  });

  final AdminWorkerGroup group;
  final ValueChanged<AdminWorkerGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('worker-group-name-field'),
          initialValue: group.groupCode,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: context.l10n.adminText('worker.group_name'),
            filled: true,
          ),
          onChanged: (value) => onChanged(group.copyWith(groupCode: value)),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.adminText('worker.work_time'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: group.shift,
          decoration: InputDecoration(
            labelText: context.l10n.adminText('worker.shift'),
            hintText: context.l10n.adminText('worker.shift_hint'),
            filled: true,
          ),
          onChanged: (value) => onChanged(group.copyWith(shift: value)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TimePickerField(
                label: context.l10n.adminText('worker.start_time'),
                value: group.startTime,
                onChanged: (value) =>
                    onChanged(group.copyWith(startTime: value)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimePickerField(
                label: context.l10n.adminText('worker.end_time'),
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
          decoration: InputDecoration(
            labelText: context.l10n.adminText('worker.weekly_days'),
            filled: true,
          ),
          items: [
            for (var day = 1; day <= 7; day++)
              DropdownMenuItem(
                value: day,
                child: Text(
                  context.l10n.adminText(
                    'worker.day_count',
                    values: {'count': day},
                  ),
                ),
              ),
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
          decoration: InputDecoration(
            labelText: context.l10n.adminText('worker.start_day'),
            filled: true,
          ),
          items: [
            for (final entry in adminWorkerStartDayLabels.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  _workerStartDayLabel(entry.key, context.l10n),
                ),
              ),
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
            title: Text(context.l10n.adminText('worker.accounting')),
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

class _WorkerSettingsCard extends StatelessWidget {
  const _WorkerSettingsCard({
    required this.slot,
    required this.worker,
    required this.apparatus,
    required this.assignedApparatus,
    required this.savingApparatus,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onEditName,
    required this.onEditLevel,
    required this.onSaveApparatus,
    required this.deleting,
    required this.onDelete,
  });

  final M3SegmentVerticalSlot slot;
  final AdminWorker worker;
  final List<AdminApparatus> apparatus;
  final List<String> assignedApparatus;
  final bool savingApparatus;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onEditName;
  final VoidCallback onEditLevel;
  final Future<bool> Function(Set<String> selected) onSaveApparatus;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final phone = worker.phone.trim();
    final level = adminWorkerLevels.contains(worker.level)
        ? worker.level
        : adminWorkerLevels.last;
    final l10n = context.l10n;
    return Material(
      key: ValueKey('worker-settings-card-${worker.id}'),
      color: scheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.engineering_rounded,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            worker.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              _workerLevelLabel(level, l10n),
                              if (phone.isNotEmpty) phone,
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          l10n.adminText(
                            'worker.worker_details',
                            values: {'name': worker.name},
                          ),
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        _WorkerGroupInfoRow(
                          label: l10n.adminText('worker.name_label'),
                          value: worker.name,
                        ),
                        _WorkerGroupInfoRow(
                          label: l10n.adminText('worker.level'),
                          value: _workerLevelLabel(level, l10n),
                        ),
                        _WorkerGroupInfoRow(
                          label: l10n.adminText('worker.phone_label'),
                          value: phone.isEmpty
                              ? l10n.adminText('worker.not_entered')
                              : phone,
                        ),
                        _WorkerGroupInfoRow(
                          label: l10n.adminText('worker.id'),
                          value: worker.id,
                        ),
                        const SizedBox(height: 4),
                        _WorkerApparatusAssignmentField(
                          workerId: worker.id,
                          apparatus: apparatus,
                          selected: assignedApparatus.toSet(),
                          saving: savingApparatus,
                          onSave: onSaveApparatus,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton.filledTonal(
                              tooltip: l10n.adminText('worker.edit_name'),
                              onPressed: deleting ? null : onEditName,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: l10n.adminText('worker.edit_level'),
                              onPressed: deleting ? null : onEditLevel,
                              icon: const Icon(Icons.stars_outlined),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: l10n.adminText(
                                'worker.deactivate_tooltip',
                              ),
                              onPressed: deleting ? null : onDelete,
                              style: IconButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              icon: deleting
                                  ? const Icon(Icons.hourglass_top_rounded)
                                  : const Icon(Icons.person_off_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _WorkerApparatusAssignmentField extends StatelessWidget {
  const _WorkerApparatusAssignmentField({
    required this.workerId,
    required this.apparatus,
    required this.selected,
    required this.saving,
    required this.onSave,
  });

  final String workerId;
  final List<AdminApparatus> apparatus;
  final Set<String> selected;
  final bool saving;
  final Future<bool> Function(Set<String> selected) onSave;

  Future<void> _openPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkerApparatusAssignmentSheet(
        apparatus: apparatus,
        selected: selected,
        onSave: onSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selectedNames = selected.toList()..sort();
    final value = selectedNames.isEmpty
        ? l10n.adminText('scope.none_selected')
        : selectedNames.join(', ');
    final enabled = !saving && apparatus.isNotEmpty;
    return InkWell(
      key: ValueKey('worker-apparatus-picker-$workerId'),
      onTap: enabled ? () => unawaited(_openPicker(context)) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appSurfaceInputDecoration(
          context,
          labelText: l10n.adminText('scope.operator_title'),
          prefixIcon: const Icon(Icons.precision_manufacturing_outlined),
          suffixIcon: saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.expand_more_rounded),
        ).copyWith(enabled: enabled),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _WorkerApparatusAssignmentSheet extends StatefulWidget {
  const _WorkerApparatusAssignmentSheet({
    required this.apparatus,
    required this.selected,
    required this.onSave,
  });

  final List<AdminApparatus> apparatus;
  final Set<String> selected;
  final Future<bool> Function(Set<String> selected) onSave;

  @override
  State<_WorkerApparatusAssignmentSheet> createState() =>
      _WorkerApparatusAssignmentSheetState();
}

class _WorkerApparatusAssignmentSheetState
    extends State<_WorkerApparatusAssignmentSheet> {
  late final Set<String> _selected = Set<String>.of(widget.selected);
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(Set<String>.of(_selected));
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adminText('scope.operator_title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    l10n.adminText('scope.operator_description'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminApparatusScopePicker(
                    apparatus: widget.apparatus,
                    selected: _selected,
                    onChanged: (apparatusName, checked) {
                      setState(() {
                        if (checked) {
                          _selected.add(apparatusName);
                        } else {
                          _selected.remove(apparatusName);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('worker-apparatus-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? l10n.adminText('action.saving')
                        : l10n.adminText('scope.save_action'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
