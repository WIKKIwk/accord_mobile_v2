import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_groups.dart';
import 'admin_apparatus_capacity_panel.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_queue_policy_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';

enum AdminApparatusSettingsTab { create, groups, queue, capacity }

int _apparatusSettingsTabIndex(AdminApparatusSettingsTab tab) {
  return switch (tab) {
    AdminApparatusSettingsTab.create => 0,
    AdminApparatusSettingsTab.groups => 1,
    AdminApparatusSettingsTab.queue => 2,
    AdminApparatusSettingsTab.capacity => 3,
  };
}

class AdminApparatusSettingsScreen extends StatefulWidget {
  const AdminApparatusSettingsScreen({
    super.key,
    this.initialTab = AdminApparatusSettingsTab.create,
    this.focusApparatusName = false,
  });

  final AdminApparatusSettingsTab initialTab;
  final bool focusApparatusName;

  @override
  State<AdminApparatusSettingsScreen> createState() =>
      _AdminApparatusSettingsScreenState();
}

class _AdminApparatusSettingsScreenState
    extends State<AdminApparatusSettingsScreen>
    with SingleTickerProviderStateMixin {
  static _AdminApparatusSettingsCache? _cache;

  late final TabController _tabController;
  List<AdminApparatus> _apparatus = const [];
  late AdminApparatusMasterOptions _options;
  bool _loading = true;
  bool _saving = false;
  bool _focusedEditorOpened = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: _apparatusSettingsTabIndex(widget.initialTab),
      vsync: this,
    );
    final cached = _cache;
    if (cached != null) {
      _apparatus = cached.apparatus;
      _options = cached.options;
      _loading = false;
      unawaited(_load(showLoading: false));
      _maybeOpenFocusedEditor();
    } else {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminApparatus(limit: 500),
        MobileApi.instance.adminApparatusMasterOptions(),
      ]);
      if (!mounted) return;
      final apparatus = [
        ...(results[0] as List<AdminApparatus>).where((item) => item.isActive),
      ]..sort(_compareApparatus);
      final options = results[1] as AdminApparatusMasterOptions;
      setState(() {
        _apparatus = apparatus;
        _options = options;
        _loading = false;
        _loadError = null;
      });
      _cache = _AdminApparatusSettingsCache(
        apparatus: apparatus,
        options: options,
      );
      _maybeOpenFocusedEditor();
    } catch (error, stackTrace) {
      debugPrint('Canonical apparatus load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      if (_cache != null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  void _maybeOpenFocusedEditor() {
    if (!widget.focusApparatusName ||
        _focusedEditorOpened ||
        _loading ||
        !mounted) {
      return;
    }
    _focusedEditorOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showEditor());
    });
  }

  AdminApparatus _latest(AdminApparatus apparatus) {
    for (final item in _apparatus) {
      if (item.id == apparatus.id) return item;
    }
    return apparatus;
  }

  void _replaceApparatus(AdminApparatus saved) {
    final next = [
      for (final item in _apparatus)
        if (item.id != saved.id) item,
      saved,
    ]..sort(_compareApparatus);
    setState(() => _apparatus = next);
    _cache = _AdminApparatusSettingsCache(apparatus: next, options: _options);
  }

  Future<void> _showEditor([AdminApparatus? current]) async {
    if (_saving) return;
    final name = TextEditingController(text: current?.name ?? '');
    final colorStations = TextEditingController(
      text: current?.colorStations?.toString() ?? '',
    );
    var family = current?.family == 'other' ? null : current?.family;
    var kind = current?.kind == 'other' ? null : current?.kind;
    final capabilities = <String>{
      ...?current?.capabilities,
    }.where(_options.supportsCapability).toSet();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final displayName = name.text.trim();
              final selectedFamily = family;
              final selectedKind = kind;
              if (displayName.isEmpty ||
                  selectedFamily == null ||
                  selectedKind == null) {
                showAdminTopNotice(
                  context,
                  context.l10n.adminText('apparatus.kind_required'),
                );
                return;
              }
              final operationCapability = _operationCapabilityForFamily(
                selectedFamily,
              );
              if (operationCapability.isEmpty) return;
              capabilities.add(operationCapability);
              final colorText = colorStations.text.trim();
              final parsedColor =
                  colorText.isEmpty ? null : int.tryParse(colorText);
              if (selectedKind == 'color_pechat' &&
                  (parsedColor == null ||
                      parsedColor < _options.colorStationsMin ||
                      parsedColor > _options.colorStationsMax)) {
                showAdminTopNotice(
                  context,
                  this.context.l10n.adminText(
                    'apparatus.color_stations_range',
                    values: {
                      'min': _options.colorStationsMin,
                      'max': _options.colorStationsMax,
                    },
                  ),
                );
                return;
              }
              setState(() => _saving = true);
              setDialogState(() {});
              try {
                final previousLevels = {
                  for (final profile in current?.capabilityProfiles ??
                      const <AdminApparatusCapabilityProfile>[])
                    profile.code: profile.level,
                };
                final saved = await MobileApi.instance.adminCreateApparatus(
                  displayName,
                  id: current?.id ?? '',
                  family: selectedFamily,
                  kind: selectedKind,
                  capabilities: capabilities,
                  capabilityProfiles: [
                    for (final code in capabilities)
                      AdminApparatusCapabilityProfile(
                        code: code,
                        level: previousLevels[code] ?? 1,
                      ),
                  ],
                  colorStations:
                      selectedKind == 'color_pechat' || selectedKind == 'flexo'
                          ? parsedColor
                          : null,
                  factoryMapObjectId: current?.factoryMapObjectId,
                );
                if (!mounted) return;
                _replaceApparatus(saved);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                showAdminTopNotice(
                  this.context,
                  this.context.l10n.adminText(
                        current == null
                            ? 'apparatus.added'
                            : 'apparatus.master_saved',
                      ),
                );
              } catch (error) {
                if (mounted) {
                  showAdminTopNotice(
                    this.context,
                    error is MobileApiException
                        ? error.message
                        : this.context.l10n.adminText('apparatus.add_failed'),
                  );
                }
              } finally {
                if (mounted) setState(() => _saving = false);
                if (dialogContext.mounted) setDialogState(() {});
              }
            }

            return AlertDialog(
              title: Text(
                context.l10n.adminText(
                  current == null ? 'apparatus.add' : 'apparatus.master_edit',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: name,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.adminText('apparatus.name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: family,
                        decoration: InputDecoration(
                          labelText: context.l10n.adminText('apparatus.family'),
                        ),
                        items: [
                          for (final value in _options.families)
                            DropdownMenuItem(
                              value: value,
                              child: Text(
                                _apparatusOptionLabel(value, context.l10n),
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  family = value;
                                  if (!_options
                                      .kindsForFamily(value)
                                      .contains(kind)) {
                                    kind = null;
                                  }
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('$family:$kind'),
                        initialValue: kind,
                        decoration: InputDecoration(
                          labelText: context.l10n.adminText('apparatus.kind'),
                        ),
                        items: [
                          for (final value in _options.kindsForFamily(family))
                            DropdownMenuItem(
                              value: value,
                              child: Text(
                                _apparatusOptionLabel(value, context.l10n),
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setDialogState(() => kind = value),
                      ),
                      if (kind == 'color_pechat' || kind == 'flexo') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: colorStations,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'apparatus.color_stations',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.adminText('apparatus.capabilities'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final capability in _options.capabilities)
                            FilterChip(
                              label: Text(
                                _apparatusOptionLabel(capability, context.l10n),
                              ),
                              selected: capabilities.contains(capability),
                              onSelected: _saving
                                  ? null
                                  : (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          capabilities.add(capability);
                                        } else {
                                          capabilities.remove(capability);
                                        }
                                      });
                                    },
                            ),
                        ],
                      ),
                      if (current != null) ...[
                        const SizedBox(height: 16),
                        SelectableText(
                          current.id,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.adminText('action.cancel')),
                ),
                FilledButton(
                  onPressed: _saving ? null : save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.adminText('action.save')),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      name.dispose();
      colorStations.dispose();
    }
  }

  Future<AdminApparatus?> _savePlacement(
    AdminApparatus apparatus,
    String objectId,
  ) async {
    final current = _latest(apparatus);
    final normalized = objectId.trim();
    if (normalized.isNotEmpty &&
        _apparatus.any(
          (item) =>
              item.id != current.id &&
              item.factoryMapObjectId.trim() == normalized,
        )) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('apparatus.map_duplicate'),
      );
      return null;
    }
    try {
      final saved = await MobileApi.instance.adminPatchCanonicalApparatus(
        apparatus: current,
        patch: {
          'placement':
              normalized.isEmpty ? null : {'factory_map_object_id': normalized},
        },
      );
      if (normalized != saved.factoryMapObjectId.trim()) {
        throw const MobileApiException(
          code: 'canonical_placement_not_applied',
          message: 'Canonical joylashuv yangilanmadi',
        );
      }
      if (!mounted) return null;
      _replaceApparatus(saved);
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          normalized.isEmpty
              ? 'apparatus.map_removed'
              : 'apparatus.map_assigned',
        ),
      );
      return saved;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('apparatus.map_save_failed'),
        );
      }
      return null;
    }
  }

  Future<AdminApparatus?> _saveTraining(
    AdminApparatus apparatus,
    bool enabled,
  ) async {
    final current = _latest(apparatus);
    final profiles = {
      for (final profile in current.capabilityProfiles)
        profile.code: profile.level,
    };
    if (enabled) {
      profiles['training'] = profiles['training'] ?? 1;
    } else {
      profiles.remove('training');
    }
    try {
      final saved = await MobileApi.instance.adminPatchCanonicalApparatus(
        apparatus: current,
        patch: {
          'capabilities': [
            for (final entry in profiles.entries)
              {'code': entry.key, 'level': entry.value},
          ],
          'training': {
            'enabled': enabled,
            'queue_enabled': enabled,
            'material_tracking_enabled': enabled,
          },
        },
      );
      if (!mounted) return null;
      _replaceApparatus(saved);
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          enabled
              ? 'apparatus.training_enabled'
              : 'apparatus.training_disabled',
        ),
      );
      return saved;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('apparatus.training_save_failed'),
        );
      }
      return null;
    }
  }

  Future<void> _showSettings(AdminApparatus apparatus) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _CanonicalApparatusSettingsCard(
          apparatus: _latest(apparatus),
          onClose: () => Navigator.of(dialogContext).pop(),
          onPlacementChanged: _savePlacement,
          onTrainingChanged: _saveTraining,
        ),
      ),
    );
  }

  Widget _buildCatalog(double bottomPadding) {
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(8, 10, 8, bottomPadding),
        children: [
          FilledButton.icon(
            onPressed: _saving ? null : () => _showEditor(),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.adminText('apparatus.add')),
          ),
          const SizedBox(height: 12),
          if (_apparatus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(context.l10n.adminText('apparatus.empty')),
              ),
            )
          else
            for (final apparatus in _apparatus)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(_apparatusIcon(apparatus)),
                    title: Text(apparatus.name),
                    subtitle: Text(
                      '${_apparatusOptionLabel(apparatus.family, context.l10n)}'
                      ' · ${apparatus.id}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') {
                          unawaited(_showEditor(apparatus));
                        } else if (action == 'settings') {
                          unawaited(_showSettings(apparatus));
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'settings',
                          child: Text(
                            context.l10n.adminText('apparatus.settings'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(context.l10n.adminText('action.edit')),
                        ),
                      ],
                    ),
                    onTap: () => _showSettings(apparatus),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildGroups(double bottomPadding) {
    final groups = canonicalApparatusGroups(_apparatus);
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        key: const ValueKey('canonical-apparatus-groups-list'),
        padding: EdgeInsets.fromLTRB(8, 10, 8, bottomPadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_tree_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.adminText(
                        'apparatus.groups_canonical_description',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  context.l10n.adminText('apparatus.groups_empty'),
                ),
              ),
            )
          else
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: ValueKey(
                      'canonical-apparatus-group-${group.operation}',
                    ),
                    leading: Icon(_apparatusGroupIcon(group.operation)),
                    title: Text(
                      canonicalApparatusGroupLabel(group, context.l10n),
                    ),
                    subtitle: Text(
                      context.l10n.adminText(
                        'apparatus.count',
                        values: {'count': '${group.apparatus.length}'},
                      ),
                    ),
                    children: [
                      for (final apparatus in group.apparatus)
                        ListTile(
                          key: ValueKey(
                            'canonical-apparatus-group-item-${apparatus.id}',
                          ),
                          leading: Icon(_apparatusIcon(apparatus)),
                          title: Text(apparatus.name),
                          subtitle: SelectableText(apparatus.id),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showSettings(apparatus),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AppShell(
      title: context.l10n.adminText('apparatus.title'),
      subtitle: '',
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminApparatusSettings,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : _loadError != null
              ? AppRetryState(onRetry: _load)
              : Column(
                  children: [
                    AdminSurfaceTabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('apparatus.add'),
                        ),
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('apparatus.groups'),
                        ),
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('apparatus.tabs_queue'),
                        ),
                        Tab(
                          height: 38,
                          text:
                              context.l10n.adminText('apparatus.tabs_capacity'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCatalog(bottomPadding),
                          _buildGroups(bottomPadding),
                          AdminQueuePolicyPanel(bottomPadding: bottomPadding),
                          AdminApparatusCapacityPanel(
                            apparatus: _apparatus,
                            bottomPadding: bottomPadding,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CanonicalApparatusSettingsCard extends StatefulWidget {
  const _CanonicalApparatusSettingsCard({
    required this.apparatus,
    required this.onClose,
    required this.onPlacementChanged,
    required this.onTrainingChanged,
  });

  final AdminApparatus apparatus;
  final VoidCallback onClose;
  final Future<AdminApparatus?> Function(
    AdminApparatus apparatus,
    String objectId,
  ) onPlacementChanged;
  final Future<AdminApparatus?> Function(AdminApparatus apparatus, bool enabled)
      onTrainingChanged;

  @override
  State<_CanonicalApparatusSettingsCard> createState() =>
      _CanonicalApparatusSettingsCardState();
}

class _CanonicalApparatusSettingsCardState
    extends State<_CanonicalApparatusSettingsCard> {
  late AdminApparatus _apparatus;
  bool _savingPlacement = false;
  bool _savingTraining = false;

  @override
  void initState() {
    super.initState();
    _apparatus = widget.apparatus;
  }

  Future<void> _choosePlacement() async {
    if (_savingPlacement) return;
    final selection = await showAdminFactoryMapObjectPicker(
      context,
      initialObjectId: _apparatus.factoryMapObjectId,
    );
    if (selection == null || !mounted) return;
    setState(() => _savingPlacement = true);
    try {
      final saved = await widget.onPlacementChanged(
        _apparatus,
        selection.objectId,
      );
      if (saved != null && mounted) setState(() => _apparatus = saved);
    } finally {
      if (mounted) setState(() => _savingPlacement = false);
    }
  }

  Future<void> _clearPlacement() async {
    if (_savingPlacement || _apparatus.factoryMapObjectId.isEmpty) return;
    setState(() => _savingPlacement = true);
    try {
      final saved = await widget.onPlacementChanged(_apparatus, '');
      if (saved != null && mounted) setState(() => _apparatus = saved);
    } finally {
      if (mounted) setState(() => _savingPlacement = false);
    }
  }

  Future<void> _toggleTraining(bool enabled) async {
    if (_savingTraining) return;
    setState(() => _savingTraining = true);
    try {
      final saved = await widget.onTrainingChanged(_apparatus, enabled);
      if (saved != null && mounted) setState(() => _apparatus = saved);
    } finally {
      if (mounted) setState(() => _savingTraining = false);
    }
  }

  Widget _mapTab() {
    final objectId = _apparatus.factoryMapObjectId.trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (objectId.isNotEmpty) SelectableText(objectId),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _savingPlacement ? null : _choosePlacement,
          icon: const Icon(Icons.map_outlined),
          label: Text(context.l10n.adminText('apparatus.choose_map_object')),
        ),
        if (objectId.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _savingPlacement ? null : _clearPlacement,
            icon: const Icon(Icons.link_off_rounded),
            label: Text(context.l10n.adminText('apparatus.remove_link')),
          ),
        ],
      ],
    );
  }

  Widget _trainingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _apparatus.trainingEnabled,
          onChanged: _savingTraining ? null : _toggleTraining,
          title: Text(context.l10n.adminText('apparatus.training_switch')),
          subtitle: Text(
            context.l10n.adminText(
              _apparatus.trainingEnabled
                  ? 'apparatus.training_on_description'
                  : 'apparatus.training_off_description',
            ),
          ),
          secondary: _savingTraining
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.school_outlined),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 16;
    final height = (MediaQuery.sizeOf(context).height * 0.68).clamp(
      420.0,
      640.0,
    );
    return SizedBox(
      height: height.toDouble(),
      child: DefaultTabController(
        length: 4,
        child: Material(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: Icon(_apparatusIcon(_apparatus)),
                title: Text(_apparatus.name),
                subtitle: SelectableText(_apparatus.id),
                trailing: IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: context.l10n.adminText('apparatus.tabs_queue')),
                  Tab(text: context.l10n.adminText('apparatus.tabs_capacity')),
                  Tab(text: context.l10n.adminText('apparatus.tabs_map')),
                  Tab(text: context.l10n.adminText('apparatus.tabs_training')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    AdminQueuePolicyPanel(
                      bottomPadding: bottomPadding,
                      apparatusId: _apparatus.id,
                    ),
                    AdminApparatusCapacityPanel(
                      apparatus: [_apparatus],
                      bottomPadding: bottomPadding,
                      showApparatusSelector: false,
                    ),
                    _mapTab(),
                    _trainingTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminApparatusSettingsCache {
  const _AdminApparatusSettingsCache({
    required this.apparatus,
    required this.options,
  });

  final List<AdminApparatus> apparatus;
  final AdminApparatusMasterOptions options;
}

int _compareApparatus(AdminApparatus left, AdminApparatus right) {
  final order = left.sortOrder.compareTo(right.sortOrder);
  return order != 0
      ? order
      : left.name.toLowerCase().compareTo(right.name.toLowerCase());
}

String _operationCapabilityForFamily(String family) {
  return switch (family) {
    'pechat' => 'print',
    'laminatsiya' => 'laminate',
    'rezka' => 'cut',
    'paket' => 'package',
    'kley' => 'glue',
    _ => '',
  };
}

IconData _apparatusIcon(AdminApparatus apparatus) {
  return switch (apparatus.operation) {
    'print' => Icons.print_outlined,
    'laminate' => Icons.layers_outlined,
    'cut' => Icons.content_cut_rounded,
    'package' => Icons.inventory_2_outlined,
    'glue' => Icons.water_drop_outlined,
    _ => Icons.precision_manufacturing_outlined,
  };
}

IconData _apparatusGroupIcon(String operation) {
  return switch (operation) {
    'print' => Icons.print_outlined,
    'laminate' => Icons.layers_outlined,
    'cut' => Icons.content_cut_rounded,
    'package' => Icons.inventory_2_outlined,
    'glue' => Icons.water_drop_outlined,
    _ => Icons.help_outline_rounded,
  };
}

String _apparatusOptionLabel(String value, AppLocalizations l10n) {
  return switch (value) {
    'pechat' => l10n.adminText('apparatus.option.pechat'),
    'laminatsiya' => l10n.adminText('apparatus.option.laminatsiya'),
    'rezka' => l10n.adminText('apparatus.option.rezka'),
    'paket' => l10n.adminText('apparatus.option.paket'),
    'kley' => l10n.adminText('apparatus.option.kley'),
    'color_pechat' => l10n.adminText('apparatus.option.color_pechat'),
    'flexo' => l10n.adminText('apparatus.option.flexo'),
    'extruder_laminatsiya' => l10n.adminText(
        'apparatus.option.extruder_laminatsiya',
      ),
    'holodniy_kley' => l10n.adminText('apparatus.option.holodniy_kley'),
    'print' => l10n.adminText('apparatus.option.print'),
    'laminate' => l10n.adminText('apparatus.option.laminate'),
    'cut' => l10n.adminText('apparatus.option.cut'),
    'package' => l10n.adminText('apparatus.option.package'),
    'glue' => l10n.adminText('apparatus.option.glue'),
    _ => value,
  };
}
