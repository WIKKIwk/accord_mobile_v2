import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/production_map_pechat_rules.dart';
import 'admin_apparatus_capacity_panel.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_queue_policy_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_picker_field.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _apparatusSettingsPanelGap = 4;
const double _apparatusSettingsPanelTopGap = 8;

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
    this.initialTab = AdminApparatusSettingsTab.groups,
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

  final TextEditingController _name = TextEditingController();
  final TextEditingController _apparatusName = TextEditingController();
  final TextEditingController _apparatusColorStations = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _apparatusNameFocus = FocusNode();
  final ScrollController _createScrollController = ScrollController();
  final ScrollController _groupsScrollController = ScrollController();
  late final TabController _tabController;
  List<AdminApparatus> _apparatus = const [];
  List<AdminApparatusGroup> _groups = const [];
  AdminApparatusMasterOptions _apparatusOptions =
      AdminApparatusMasterOptions.fallback();
  final Set<String> _selected = {};
  String? _selectedApparatusFamily;
  String? _selectedApparatusKind;
  Set<String> _selectedApparatusCapabilities = {};
  bool _loading = true;
  bool _saving = false;
  bool _creatingApparatus = false;
  String? _loadError;
  String? _editingGroupName;
  String? _editingApparatusId;
  List<AdminApparatusCapabilityProfile> _editingCapabilityProfiles = const [];
  String? _expandedGroupName;
  StateSetter? _createEditorDialogSetState;
  VoidCallback? _closeCreateEditorDialog;
  bool _createEditorDialogOpen = false;
  bool _focusEditorOpened = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: _apparatusSettingsTabIndex(widget.initialTab),
      vsync: this,
    );
    final restored = _restoreCache();
    if (!restored) {
      _load();
    } else {
      _maybeOpenFocusedEditor();
      unawaited(_load(showLoading: false));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _name.dispose();
    _apparatusName.dispose();
    _apparatusColorStations.dispose();
    _nameFocus.dispose();
    _apparatusNameFocus.dispose();
    _createScrollController.dispose();
    _groupsScrollController.dispose();
    super.dispose();
  }

  bool _restoreCache() {
    final cache = _cache;
    if (cache == null) {
      return false;
    }
    _groups = cache.groups;
    _apparatus = cache.apparatus;
    _apparatusOptions = cache.options;
    _loading = false;
    _loadError = null;
    return true;
  }

  void _saveCache() {
    _cache = _AdminApparatusSettingsCache(
      groups: _groups,
      apparatus: _apparatus,
      options: _apparatusOptions,
    );
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
        MobileApi.instance.adminApparatusGroups(),
        MobileApi.instance.adminTrainingApparatus(),
        MobileApi.instance.adminApparatusMasterOptions(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = results[0] as List<AdminApparatusGroup>;
        _apparatus = results[1] as List<AdminApparatus>;
        _apparatusOptions = results[2] as AdminApparatusMasterOptions;
        _loading = false;
        _loadError = null;
      });
      _saveCache();
      _maybeOpenFocusedEditor();
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (_cache != null) {
        setState(() {
          _loading = false;
        });
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Aparat sozlamalari yuklanmadi';
      });
    }
  }

  void _editGroup(AdminApparatusGroup group) {
    setState(() {
      _expandedGroupName = null;
      _editingGroupName = group.name;
      _name.text = group.name;
      _selected
        ..clear()
        ..addAll(_matchedApparatusNames(group.apparatus));
    });
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_groupsScrollController.hasClients) {
        unawaited(
          _groupsScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      _nameFocus.requestFocus();
    });
  }

  Iterable<String> _matchedApparatusNames(List<String> groupApparatus) sync* {
    for (final apparatusName in groupApparatus) {
      final normalized = apparatusName.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      for (final item in _apparatus) {
        if (item.name.trim().toLowerCase() == normalized) {
          yield item.name;
          break;
        }
      }
    }
  }

  void _clearEditor() {
    setState(() {
      _editingGroupName = null;
      _name.clear();
      _selected.clear();
    });
  }

  void _editApparatus(AdminApparatus apparatus) {
    if (apparatus.isDefault) {
      showAdminTopNotice(
          context, 'Standart aparat master-data\'si o\'zgarmaydi');
      return;
    }
    setState(() {
      _editingApparatusId = apparatus.id;
      _apparatusName.text = apparatus.name;
      final family = _apparatusOptions.families.contains(
        apparatus.family.trim().toLowerCase(),
      )
          ? apparatus.family.trim().toLowerCase()
          : null;
      final kind = _apparatusOptions
              .kindsForFamily(family)
              .contains(apparatus.kind.trim().toLowerCase())
          ? apparatus.kind.trim().toLowerCase()
          : null;
      final storedCapabilities = {
        ...apparatus.capabilities.map((item) => item.trim().toLowerCase()),
        ...apparatus.capabilityProfiles
            .map((profile) => profile.code.trim().toLowerCase()),
      };
      _selectedApparatusFamily = family;
      _selectedApparatusKind = kind;
      _selectedApparatusCapabilities = _apparatusOptions.capabilities
          .where(storedCapabilities.contains)
          .toSet();
      _editingCapabilityProfiles = apparatus.capabilityProfiles;
      _apparatusColorStations.text = apparatus.colorStations?.toString() ?? '';
    });
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _apparatusNameFocus.requestFocus();
      }
    });
  }

  void _updateCreateEditorState(VoidCallback update) {
    if (mounted) {
      setState(update);
    }
    _createEditorDialogSetState?.call(() {});
  }

  void _maybeOpenFocusedEditor() {
    if (!widget.focusApparatusName || _focusEditorOpened || _loading) {
      return;
    }
    _focusEditorOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showApparatusEditor();
      }
    });
  }

  void _clearApparatusEditor() {
    _updateCreateEditorState(() {
      _editingApparatusId = null;
      _apparatusName.clear();
      _apparatusColorStations.clear();
      _selectedApparatusFamily = null;
      _selectedApparatusKind = null;
      _selectedApparatusCapabilities = {};
      _editingCapabilityProfiles = const [];
    });
  }

  Future<void> _showApparatusEditor() async {
    if (_createEditorDialogOpen) {
      return;
    }
    _createEditorDialogOpen = true;
    var focusRequested = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              _createEditorDialogSetState = setDialogState;
              _closeCreateEditorDialog =
                  () => Navigator.of(dialogContext).pop();
              if (!focusRequested) {
                focusRequested = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _apparatusNameFocus.requestFocus();
                  }
                });
              }
              final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _buildCreateEditorCard(context),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _createEditorDialogSetState = null;
      _closeCreateEditorDialog = null;
      _createEditorDialogOpen = false;
    }
  }

  void _closeCreateEditor() {
    _updateCreateEditorState(() {
      _editingApparatusId = null;
      _apparatusName.clear();
      _apparatusColorStations.clear();
      _selectedApparatusFamily = null;
      _selectedApparatusKind = null;
      _selectedApparatusCapabilities = {};
      _editingCapabilityProfiles = const [];
    });
    final closeDialog = _closeCreateEditorDialog;
    _createEditorDialogSetState = null;
    _closeCreateEditorDialog = null;
    closeDialog?.call();
  }

  Future<void> _pickApparatusFamily() async {
    final picked = await _showApparatusSinglePicker(
      context,
      title: 'Aparat oilasi tanlang',
      options: _apparatusOptions.families,
      selected: _selectedApparatusFamily,
    );
    if (picked == null || !mounted) {
      return;
    }
    _updateCreateEditorState(() {
      _selectedApparatusFamily = picked;
      if (!_apparatusOptions.kindsForFamily(picked).contains(
            _selectedApparatusKind,
          )) {
        _selectedApparatusKind = null;
      }
      if (_selectedApparatusKind != 'color_pechat') {
        _apparatusColorStations.clear();
      }
    });
  }

  Future<void> _pickApparatusKind() async {
    final family = _selectedApparatusFamily;
    if (family == null) {
      showAdminTopNotice(context, 'Avval aparat oilasini tanlang');
      return;
    }
    final picked = await _showApparatusSinglePicker(
      context,
      title: 'Aparat turi tanlang',
      options: _apparatusOptions.kindsForFamily(family),
      selected: _selectedApparatusKind,
    );
    if (picked == null || !mounted) {
      return;
    }
    _updateCreateEditorState(() {
      _selectedApparatusKind = picked;
      if (picked != 'color_pechat') {
        _apparatusColorStations.clear();
      }
    });
  }

  Future<void> _pickApparatusCapabilities() async {
    final picked = await _showApparatusCapabilitiesPicker(
      context,
      options: _apparatusOptions.capabilities,
      selected: _selectedApparatusCapabilities,
    );
    if (picked == null || !mounted) {
      return;
    }
    _updateCreateEditorState(() => _selectedApparatusCapabilities = picked);
  }

  void _toggleGroupExpanded(AdminApparatusGroup group) {
    final key = group.name.trim().toLowerCase();
    setState(() {
      if (_expandedGroupName?.trim().toLowerCase() == key) {
        _expandedGroupName = null;
      } else {
        _expandedGroupName = group.name;
      }
    });
  }

  String? _groupOwningApparatus(String apparatusTitle) {
    for (final group in _groups) {
      for (final name in group.apparatus) {
        if (productionMapWarehouseTitlesMatch(name, apparatusTitle)) {
          return group.name;
        }
      }
    }
    return null;
  }

  List<AdminApparatus> _selectableApparatusForEditor() {
    final editingKey = _editingGroupName?.trim().toLowerCase() ?? '';
    return _apparatus.where((item) {
      final owner = _groupOwningApparatus(item.name);
      if (owner == null) {
        return true;
      }
      return editingKey.isNotEmpty && owner.trim().toLowerCase() == editingKey;
    }).toList(growable: false);
  }

  Future<void> _assignApparatusToGroup(
    AdminApparatus apparatus,
    String? groupName,
  ) async {
    final targetKey = groupName?.trim().toLowerCase() ?? '';
    if (targetKey.isNotEmpty &&
        !_groups.any((group) => group.name.trim().toLowerCase() == targetKey)) {
      showAdminTopNotice(context, 'Bunday guruh topilmadi');
      return;
    }

    final changedGroups = <AdminApparatusGroup>[];
    final nextGroups = <AdminApparatusGroup>[];
    for (final group in _groups) {
      final nextApparatus = [
        for (final item in group.apparatus)
          if (!productionMapWarehouseTitlesMatch(item, apparatus.name)) item,
      ];
      if (group.name.trim().toLowerCase() == targetKey) {
        nextApparatus.add(apparatus.name);
      }
      final next = AdminApparatusGroup(
        name: group.name,
        apparatus: nextApparatus,
      );
      nextGroups.add(next);
      if (next.apparatus.length != group.apparatus.length ||
          next.apparatus.asMap().entries.any(
                (entry) => entry.value != group.apparatus[entry.key],
              )) {
        changedGroups.add(next);
      }
    }
    if (changedGroups.isEmpty) {
      showAdminTopNotice(
        context,
        targetKey.isEmpty
            ? 'Aparat guruhdan chiqarilgan'
            : 'Aparat shu guruhda allaqachon bor',
      );
      return;
    }

    setState(() => _groups = nextGroups);
    try {
      for (final group in changedGroups) {
        await MobileApi.instance.adminSaveApparatusGroup(group);
      }
      _saveCache();
      if (mounted) {
        showAdminTopNotice(
          context,
          targetKey.isEmpty
              ? 'Aparat guruhdan chiqarildi'
              : 'Aparat guruhga biriktirildi',
        );
      }
    } catch (_) {
      await _load(showLoading: false);
      if (mounted) {
        showAdminTopNotice(context, 'Aparat guruhi saqlanmadi');
      }
    }
  }

  Future<void> _showApparatusSettings(AdminApparatus apparatus) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: _ApparatusSettingsCard(
            apparatus: apparatus,
            groups: _groups,
            currentGroupName: _groupOwningApparatus(apparatus.name),
            onClose: () => Navigator.of(dialogContext).pop(),
            onAssignGroup: (groupName) =>
                _assignApparatusToGroup(apparatus, groupName),
            onMapObjectChanged: (objectId) =>
                _saveApparatusFactoryMapObject(apparatus, objectId),
            onTrainingChanged: (enabled) =>
                _saveApparatusTraining(apparatus, enabled),
          ),
        );
      },
    );
  }

  Future<AdminApparatus?> _saveApparatusFactoryMapObject(
    AdminApparatus apparatus,
    String objectId,
  ) async {
    final normalizedObjectId = objectId.trim();
    if (normalizedObjectId.isNotEmpty) {
      for (final item in _apparatus) {
        if (item.id != apparatus.id &&
            item.factoryMapObjectId.trim() == normalizedObjectId) {
          showAdminTopNotice(
            context,
            'Bu 3D obyekt ${item.name} apparatiga biriktirilgan',
          );
          return null;
        }
      }
    }

    try {
      final saved = await MobileApi.instance.adminCreateApparatus(
        apparatus.name,
        id: apparatus.id,
        family: apparatus.family,
        kind: apparatus.kind,
        capabilities: apparatus.capabilities,
        capabilityProfiles: apparatus.capabilityProfiles,
        colorStations: apparatus.colorStations,
        factoryMapObjectId: normalizedObjectId,
      );
      if (!mounted) {
        return null;
      }
      final visibleSaved =
          saved.copyWith(trainingEnabled: apparatus.trainingEnabled);
      setState(() {
        _apparatus = [
          for (final item in _apparatus)
            if (item.id == saved.id) visibleSaved else item,
        ];
      });
      _saveCache();
      showAdminTopNotice(
        context,
        normalizedObjectId.isEmpty
            ? '3D xarita bog‘lanishi olib tashlandi'
            : 'Aparat 3D xaritaga biriktirildi',
      );
      return visibleSaved;
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, '3D xarita bog‘lanishi saqlanmadi');
      }
      return null;
    }
  }

  Future<AdminApparatus?> _saveApparatusTraining(
    AdminApparatus apparatus,
    bool enabled,
  ) async {
    var current = apparatus;
    for (final item in _apparatus) {
      if (item.id == apparatus.id) {
        current = item;
        break;
      }
    }
    try {
      await MobileApi.instance.adminSetTrainingApparatusMode(
        apparatus: current.name,
        enabled: enabled,
      );
      final saved = current.copyWith(trainingEnabled: enabled);
      if (!mounted) {
        return null;
      }
      setState(() {
        _apparatus = [
          for (final item in _apparatus)
            if (item.id == saved.id) saved else item,
        ];
      });
      _saveCache();
      showAdminTopNotice(
        context,
        enabled ? 'Training rejimi yoqildi' : 'Training rejimi o‘chirildi',
      );
      return saved;
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Training rejimi saqlanmadi');
      }
      return null;
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _selected.isEmpty || _saving) {
      showAdminTopNotice(context, 'Guruh nomi va aparatlar kerak');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminSaveApparatusGroup(
        AdminApparatusGroup(
          name: name,
          apparatus: _selected.toList(growable: false),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final key = saved.name.toLowerCase();
        final next = [
          for (final group in _groups)
            if (group.name.toLowerCase() != key) group,
          saved,
        ]..sort((left, right) => left.name.compareTo(right.name));
        _groups = next;
        _clearEditor();
        _expandedGroupName = saved.name;
      });
      _saveCache();
      showAdminTopNotice(context, 'Aparat guruhi saqlandi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Aparat guruhi saqlanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createApparatus() async {
    final name = _apparatusName.text.trim();
    if (name.isEmpty || _creatingApparatus) {
      showAdminTopNotice(context, 'Aparat nomi kerak');
      return;
    }
    final family = _selectedApparatusFamily;
    final kind = _selectedApparatusKind;
    if (family == null ||
        kind == null ||
        _selectedApparatusCapabilities.isEmpty) {
      showAdminTopNotice(context, 'Aparat oilasi, turi va capability tanlang');
      return;
    }
    final colorStationsText = _apparatusColorStations.text.trim();
    final parsedColorStations =
        colorStationsText.isEmpty ? null : int.tryParse(colorStationsText);
    final colorStations = kind == 'color_pechat' ? parsedColorStations : null;
    if (colorStationsText.isNotEmpty &&
        kind == 'color_pechat' &&
        (colorStations == null ||
            colorStations < _apparatusOptions.colorStationsMin ||
            colorStations > _apparatusOptions.colorStationsMax)) {
      showAdminTopNotice(
        context,
        'Rang stansiyalari ${_apparatusOptions.colorStationsMin}-'
        '${_apparatusOptions.colorStationsMax} oralig\'ida bo\'lsin',
      );
      return;
    }
    final capabilities = _apparatusOptions.capabilities
        .where(_selectedApparatusCapabilities.contains)
        .toList(growable: false);
    final previousProfiles = {
      for (final profile in _editingCapabilityProfiles)
        profile.code.trim().toLowerCase(): profile,
    };
    final capabilityProfiles = <AdminApparatusCapabilityProfile>[];
    for (final code in capabilities) {
      final previous = previousProfiles[code];
      capabilityProfiles.add(
        AdminApparatusCapabilityProfile(
          code: code,
          level: previous?.level ?? 1,
          validFromUnix: previous?.validFromUnix,
          validToUnix: previous?.validToUnix,
          enabled: previous?.enabled ?? true,
        ),
      );
    }
    final previousId = _editingApparatusId;
    AdminApparatus? previous;
    if (previousId != null) {
      for (final item in _apparatus) {
        if (item.id == previousId) {
          previous = item;
          break;
        }
      }
    }
    _updateCreateEditorState(() => _creatingApparatus = true);
    try {
      final created = await MobileApi.instance.adminCreateApparatus(
        name,
        id: previousId ?? '',
        family: family,
        kind: kind,
        capabilities: capabilities,
        capabilityProfiles: capabilityProfiles,
        colorStations: colorStations,
        factoryMapObjectId: previous?.factoryMapObjectId,
      );
      if (!mounted) {
        return;
      }
      final visibleCreated = created.copyWith(
        trainingEnabled: previous?.trainingEnabled ?? false,
      );
      setState(() {
        final key = created.id.trim();
        final next = [
          for (final item in _apparatus)
            if (previousId != null
                ? item.id != previousId
                : item.id != key &&
                    item.name.toLowerCase() != created.name.toLowerCase())
              item,
          visibleCreated,
        ]..sort(
            (left, right) => left.name.toLowerCase().compareTo(
                  right.name.toLowerCase(),
                ),
          );
        _apparatus = next;
        if (previous != null && previous.name != created.name) {
          _selected
            ..remove(previous.name)
            ..add(created.name);
        }
        _selected.add(created.name);
        _editingApparatusId = null;
        _apparatusName.clear();
        _apparatusColorStations.clear();
        _selectedApparatusFamily = null;
        _selectedApparatusKind = null;
        _selectedApparatusCapabilities = {};
        _editingCapabilityProfiles = const [];
      });
      _saveCache();
      final closeDialog = _closeCreateEditorDialog;
      _createEditorDialogSetState = null;
      _closeCreateEditorDialog = null;
      closeDialog?.call();
      showAdminTopNotice(
        context,
        previousId == null
            ? 'Aparat qo\'shildi'
            : 'Aparat master-data\'si saqlandi',
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Aparat qo\'shilmadi');
      }
    } finally {
      if (mounted) {
        _updateCreateEditorState(() => _creatingApparatus = false);
      }
    }
  }

  Widget _buildCreateTab(BuildContext context, double bottomPadding) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        controller: _createScrollController,
        padding: EdgeInsets.fromLTRB(
          _apparatusSettingsPanelGap,
          _apparatusSettingsPanelTopGap,
          _apparatusSettingsPanelGap,
          bottomPadding,
        ),
        children: [
          FilledButton.icon(
            onPressed: _creatingApparatus
                ? null
                : () {
                    _clearApparatusEditor();
                    unawaited(_showApparatusEditor());
                  },
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Aparat qo\'shish'),
          ),
          const SizedBox(height: 16),
          Text(
            'Mavjud aparatlar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_apparatus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aparatlar topilmadi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < _apparatus.length; index++)
                  _ApparatusListRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      _apparatus.length,
                    ),
                    apparatus: _apparatus[index],
                    onTap: () =>
                        unawaited(_showApparatusSettings(_apparatus[index])),
                    onLongPress: () =>
                        unawaited(_showApparatusSettings(_apparatus[index])),
                    onEdit: _apparatus[index].isDefault
                        ? null
                        : () => _editApparatus(_apparatus[index]),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCreateEditorCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editingApparatusId == null
                        ? 'Aparat qo\'shish'
                        : 'Aparatni tahrirlash',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Yopish',
                  onPressed: _closeCreateEditor,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            _buildCreateEditor(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateEditor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editingApparatusId != null) ...[
          Material(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Master-data tahriri',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _closeCreateEditor();
                    },
                    child: const Text('Bekor qilish'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _apparatusName,
          focusNode: _apparatusNameFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createApparatus(),
          decoration: appSurfaceInputDecoration(
            context,
            labelText: 'Aparat nomi',
            hintText: 'Bobst 1',
          ),
        ),
        const SizedBox(height: 8),
        AdminPickerField(
          label: 'Aparat oilasi (family)',
          value: _selectedApparatusFamily == null
              ? null
              : _apparatusOptionLabel(_selectedApparatusFamily!),
          placeholder: 'Aparat oilasini tanlang',
          enabled: !_creatingApparatus,
          onTap: _pickApparatusFamily,
        ),
        const SizedBox(height: 8),
        AdminPickerField(
          label: 'Aparat turi (kind)',
          value: _selectedApparatusKind == null
              ? null
              : _apparatusOptionLabel(_selectedApparatusKind!),
          placeholder: _selectedApparatusFamily == null
              ? 'Avval oilani tanlang'
              : 'Aparat turini tanlang',
          enabled: !_creatingApparatus && _selectedApparatusFamily != null,
          onTap: _pickApparatusKind,
        ),
        const SizedBox(height: 8),
        AdminPickerField(
          label: 'Capability lar',
          value: _selectedApparatusCapabilities.isEmpty
              ? null
              : _selectedApparatusCapabilities
                  .map(_apparatusOptionLabel)
                  .join(', '),
          placeholder: 'Capability tanlang',
          enabled: !_creatingApparatus,
          onTap: _pickApparatusCapabilities,
        ),
        if (_selectedApparatusKind == 'color_pechat') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _apparatusColorStations,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: appSurfaceInputDecoration(
              context,
              labelText: 'Rang stansiyalari (ixtiyoriy)',
              hintText: '${_apparatusOptions.colorStationsMin}-'
                  '${_apparatusOptions.colorStationsMax}',
            ),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _creatingApparatus ? null : _createApparatus,
          icon: const Icon(Icons.precision_manufacturing_outlined),
          label: Text(
            _creatingApparatus
                ? 'Saqlanmoqda...'
                : _editingApparatusId == null
                    ? 'Aparat qo\'shish'
                    : 'Master-data\'ni saqlash',
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsTab(BuildContext context, double bottomPadding) {
    final scheme = Theme.of(context).colorScheme;
    final selectableApparatus = _selectableApparatusForEditor();
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        controller: _groupsScrollController,
        padding: EdgeInsets.fromLTRB(
          _apparatusSettingsPanelGap,
          _apparatusSettingsPanelTopGap,
          _apparatusSettingsPanelGap,
          bottomPadding,
        ),
        children: [
          if (_editingGroupName != null) ...[
            Material(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tahrirlanmoqda: $_editingGroupName',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearEditor,
                      child: const Text('Bekor qilish'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _name,
            focusNode: _nameFocus,
            decoration: appSurfaceInputDecoration(
              context,
              labelText: 'Guruh nomi',
              hintText: 'bosma',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Guruh aparatlari',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_apparatus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aparatlar topilmadi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            )
          else if (selectableApparatus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _editingGroupName == null
                    ? 'Bo\'sh aparatlar yo\'q. Barcha aparatlar boshqa guruhlarga biriktirilgan.'
                    : 'Tanlash uchun bo\'sh aparat qolmadi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
              ),
            )
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < selectableApparatus.length; index++)
                  _ApparatusSelectRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      selectableApparatus.length,
                    ),
                    title: selectableApparatus[index].name,
                    selected: _selected.contains(
                      selectableApparatus[index].name,
                    ),
                    onToggle: () {
                      final apparatusName = selectableApparatus[index].name;
                      setState(() {
                        if (_selected.contains(apparatusName)) {
                          _selected.remove(apparatusName);
                        } else {
                          _selected.add(apparatusName);
                        }
                      });
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
          ),
          const SizedBox(height: 20),
          Text(
            'Saqlangan guruhlar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Guruhlar topilmadi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < _groups.length; index++)
                  _ApparatusGroupListTile(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      _groups.length,
                    ),
                    group: _groups[index],
                    expanded: _expandedGroupName?.trim().toLowerCase() ==
                        _groups[index].name.trim().toLowerCase(),
                    editing: _editingGroupName?.trim().toLowerCase() ==
                        _groups[index].name.trim().toLowerCase(),
                    onToggle: () => _toggleGroupExpanded(_groups[index]),
                    onEdit: () => _editGroup(_groups[index]),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AppShell(
      title: 'Aparat sozlamalari',
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
              ? AppRetryState(
                  onRetry: () async {
                    setState(() {
                      _loading = true;
                      _loadError = null;
                    });
                    await _load();
                  },
                )
              : Column(
                  children: [
                    AdminSurfaceTabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(height: 38, text: 'Aparat qo\'shish'),
                        Tab(height: 38, text: 'Aparat guruhlari'),
                        Tab(height: 38, text: 'Aparat navbati'),
                        Tab(height: 38, text: 'Quvvat / jadval'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCreateTab(context, bottomPadding),
                          _buildGroupsTab(context, bottomPadding),
                          ColoredBox(
                            color: AppTheme.shellStart(context),
                            child: AdminQueuePolicyPanel(
                              bottomPadding: bottomPadding,
                            ),
                          ),
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

String _apparatusOptionLabel(String value) {
  return switch (value) {
    'pechat' => 'Pechat',
    'laminatsiya' => 'Laminatsiya',
    'rezka' => 'Rezka',
    'paket' => 'Paket',
    'kley' => 'Kley',
    'other' => 'Boshqa',
    'color_pechat' => 'Rangli pechat',
    'flexo' => 'Flexo',
    'extruder_laminatsiya' => 'Extruder laminatsiya',
    'holodniy_kley' => 'Holodniy kley',
    'print' => 'Bosma (print)',
    'laminate' => 'Laminatsiya (laminate)',
    'cut' => 'Rezka (cut)',
    'package' => 'Paket (package)',
    'glue' => 'Kley (glue)',
    'apparatus' => 'Aparat',
    _ => value,
  };
}

Future<String?> _showApparatusSinglePicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ApparatusSinglePickerSheet(
      title: title,
      options: options,
      selected: selected,
    ),
  );
}

class _ApparatusSinglePickerSheet extends StatelessWidget {
  const _ApparatusSinglePickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.58,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  return ListTile(
                    title: Text(_apparatusOptionLabel(option)),
                    subtitle: Text(option),
                    selected: isSelected,
                    trailing: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: scheme.surfaceContainerHighest,
                    selectedTileColor: scheme.primaryContainer,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Set<String>?> _showApparatusCapabilitiesPicker(
  BuildContext context, {
  required List<String> options,
  required Set<String> selected,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ApparatusCapabilitiesPickerSheet(
      options: options,
      selected: selected,
    ),
  );
}

class _ApparatusCapabilitiesPickerSheet extends StatefulWidget {
  const _ApparatusCapabilitiesPickerSheet({
    required this.options,
    required this.selected,
  });

  final List<String> options;
  final Set<String> selected;

  @override
  State<_ApparatusCapabilitiesPickerSheet> createState() =>
      _ApparatusCapabilitiesPickerSheetState();
}

class _ApparatusCapabilitiesPickerSheetState
    extends State<_ApparatusCapabilitiesPickerSheet> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Capability tanlang',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: widget.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isSelected = _selected.contains(option);
                  return CheckboxListTile(
                    title: Text(_apparatusOptionLabel(option)),
                    subtitle: Text(option),
                    value: isSelected,
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: scheme.surfaceContainerHighest,
                    selectedTileColor: scheme.primaryContainer,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(option);
                        } else {
                          _selected.remove(option);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop({..._selected}),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Tasdiqlash'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _apparatusIcon(String title) {
  if (productionMapIsPechatApparatus(title)) {
    return Icons.print_outlined;
  }
  if (productionMapIsLaminatsiyaApparatus(title)) {
    return Icons.layers_outlined;
  }
  if (productionMapIsRezkaApparatus(title)) {
    return Icons.content_cut_outlined;
  }
  return Icons.precision_manufacturing_rounded;
}

String _apparatusKindLabel(String title) {
  if (productionMapIsPechatApparatus(title)) {
    return 'Bosma aparat';
  }
  if (productionMapIsLaminatsiyaApparatus(title)) {
    return 'Laminatsiya mashinasi';
  }
  if (productionMapIsRezkaApparatus(title)) {
    return 'Rezka mashinasi';
  }
  return 'Aparat';
}

String _apparatusMetadataLabel(AdminApparatus apparatus) {
  final kind = apparatus.kind.trim();
  final capabilities = apparatus.capabilities.join(', ');
  if (kind.isNotEmpty && capabilities.isNotEmpty) {
    return '$kind • $capabilities';
  }
  if (kind.isNotEmpty) {
    return kind;
  }
  return _apparatusKindLabel(apparatus.name);
}

Widget _apparatusLeading(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  return SizedBox.square(
    dimension: 30,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        _apparatusIcon(title),
        size: 16,
        color: scheme.onSecondaryContainer,
      ),
    ),
  );
}

class _ApparatusListRow extends StatelessWidget {
  const _ApparatusListRow({
    required this.slot,
    required this.apparatus,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
  });

  final M3SegmentVerticalSlot slot;
  final AdminApparatus apparatus;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      title: apparatus.name,
      subtitle: _apparatusMetadataLabel(apparatus),
      value: '',
      showChevron: true,
      onTap: onTap,
      onLongPress: onLongPress,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      elevation: 4,
      leading: _apparatusLeading(context, apparatus.name),
      trailing: onEdit == null
          ? null
          : IconButton(
              tooltip: 'Master-data tahriri',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              visualDensity: VisualDensity.compact,
            ),
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.05,
          ),
    );
  }
}

class _ApparatusSelectRow extends StatelessWidget {
  const _ApparatusSelectRow({
    required this.slot,
    required this.title,
    required this.selected,
    required this.onToggle,
  });

  final M3SegmentVerticalSlot slot;
  final String title;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      title: title,
      subtitle: _apparatusKindLabel(title),
      value: '',
      showChevron: false,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      elevation: 4,
      backgroundColor: selected
          ? scheme.primaryContainer.withValues(alpha: 0.34)
          : scheme.surfaceContainerLowest,
      leading: _apparatusLeading(context, title),
      trailing: Checkbox(
        value: selected,
        onChanged: (_) => onToggle(),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onTap: onToggle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
    );
  }
}

class _ApparatusSettingsCard extends StatefulWidget {
  const _ApparatusSettingsCard({
    required this.apparatus,
    required this.groups,
    required this.currentGroupName,
    required this.onClose,
    required this.onAssignGroup,
    required this.onMapObjectChanged,
    required this.onTrainingChanged,
  });

  final AdminApparatus apparatus;
  final List<AdminApparatusGroup> groups;
  final String? currentGroupName;
  final VoidCallback onClose;
  final Future<void> Function(String? groupName) onAssignGroup;
  final Future<AdminApparatus?> Function(String objectId) onMapObjectChanged;
  final Future<AdminApparatus?> Function(bool enabled) onTrainingChanged;

  @override
  State<_ApparatusSettingsCard> createState() => _ApparatusSettingsCardState();
}

class _ApparatusSettingsCardState extends State<_ApparatusSettingsCard> {
  late String _selectedGroupName;
  late AdminApparatus _apparatus;
  bool _savingGroup = false;
  bool _savingMapObject = false;
  bool _savingTraining = false;

  @override
  void initState() {
    super.initState();
    _apparatus = widget.apparatus;
    final current = widget.currentGroupName?.trim() ?? '';
    _selectedGroupName = widget.groups.any(
      (group) => group.name.trim().toLowerCase() == current.toLowerCase(),
    )
        ? current
        : '';
  }

  Future<void> _chooseMapObject() async {
    if (_savingMapObject) {
      return;
    }
    final selection = await showAdminFactoryMapObjectPicker(
      context,
      initialObjectId: _apparatus.factoryMapObjectId,
    );
    if (selection == null || !mounted) {
      return;
    }
    setState(() => _savingMapObject = true);
    try {
      final saved = await widget.onMapObjectChanged(selection.objectId);
      if (saved != null && mounted) {
        setState(() => _apparatus = saved);
      }
    } finally {
      if (mounted) {
        setState(() => _savingMapObject = false);
      }
    }
  }

  Future<void> _clearMapObject() async {
    if (_savingMapObject || _apparatus.factoryMapObjectId.trim().isEmpty) {
      return;
    }
    setState(() => _savingMapObject = true);
    try {
      final saved = await widget.onMapObjectChanged('');
      if (saved != null && mounted) {
        setState(() => _apparatus = saved);
      }
    } finally {
      if (mounted) {
        setState(() => _savingMapObject = false);
      }
    }
  }

  Widget _buildMapTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final objectId = _apparatus.factoryMapObjectId.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: objectId.isEmpty
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                objectId.isEmpty
                    ? Icons.location_off_outlined
                    : Icons.view_in_ar_rounded,
                color:
                    objectId.isEmpty ? scheme.onSurfaceVariant : scheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                objectId.isEmpty
                    ? '3D xaritada belgilanmagan'
                    : '3D xaritaga biriktirilgan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                objectId.isEmpty
                    ? 'Zavod xaritasidan shu apparatga mos qizil obyektni tanlang.'
                    : objectId,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _savingMapObject ? null : _chooseMapObject,
          icon: _savingMapObject
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.map_outlined),
          label: Text(
            objectId.isEmpty ? 'Xaritadan tanlash' : 'Xaritadan qayta tanlash',
          ),
        ),
        if (objectId.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _savingMapObject ? null : _clearMapObject,
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Bog‘lanishni olib tashlash'),
          ),
        ],
      ],
    );
  }

  Future<void> _setTrainingEnabled(bool enabled) async {
    if (_savingTraining) {
      return;
    }
    setState(() => _savingTraining = true);
    try {
      final saved = await widget.onTrainingChanged(enabled);
      if (saved != null && mounted) {
        setState(() => _apparatus = saved);
      }
    } finally {
      if (mounted) {
        setState(() => _savingTraining = false);
      }
    }
  }

  Widget _buildTrainingTab(BuildContext context) {
    final enabled = _apparatus.trainingEnabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: _savingTraining ? null : _setTrainingEnabled,
          title: const Text('Training’ni yoqish'),
          subtitle: Text(
            enabled
                ? 'Training rejimi faol. Keyingi bosqichda demo orderlar shu apparatda ko‘rinadi.'
                : 'Production rejimi faol.',
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

  Future<void> _saveGroup() async {
    if (_savingGroup) {
      return;
    }
    setState(() => _savingGroup = true);
    try {
      await widget.onAssignGroup(
        _selectedGroupName.trim().isEmpty ? null : _selectedGroupName,
      );
    } finally {
      if (mounted) {
        setState(() => _savingGroup = false);
      }
    }
  }

  Widget _buildGroupTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(
          'Aparatni qaysi guruhda ishlatishni belgilang.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _selectedGroupName,
          decoration: const InputDecoration(
            labelText: 'Aparat guruhi',
            prefixIcon: Icon(Icons.folder_copy_outlined),
          ),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Guruhsiz'),
            ),
            for (final group in widget.groups)
              DropdownMenuItem(
                value: group.name,
                child: Text(group.name),
              ),
          ],
          onChanged: _savingGroup
              ? null
              : (value) => setState(() => _selectedGroupName = value ?? ''),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _savingGroup ? null : _saveGroup,
          icon: _savingGroup
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_rounded),
          label: Text(_savingGroup ? 'Saqlanmoqda...' : 'Guruhni saqlash'),
        ),
        const SizedBox(height: 20),
        Text(
          'Mavjud guruhlar',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (widget.groups.isEmpty)
          Text(
            'Hali guruh yaratilmagan.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )
        else
          for (final group in widget.groups)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.folder_outlined),
              title: Text(group.name),
              subtitle: Text('${group.apparatus.length} ta aparat'),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardHeight =
        (MediaQuery.sizeOf(context).height * 0.68).clamp(420.0, 640.0);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 16;
    return SizedBox(
      height: cardHeight.toDouble(),
      child: DefaultTabController(
        length: 5,
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
                child: Row(
                  children: [
                    _apparatusLeading(context, widget.apparatus.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aparat sozlamalari',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.apparatus.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yopish',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Guruh'),
                  Tab(text: 'Navbat'),
                  Tab(text: 'Quvvat / jadval'),
                  Tab(text: '3D xarita'),
                  Tab(text: 'Training'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGroupTab(context),
                    AdminQueuePolicyPanel(
                      bottomPadding: bottomPadding,
                      apparatusName: widget.apparatus.name,
                    ),
                    AdminApparatusCapacityPanel(
                      apparatus: [_apparatus],
                      bottomPadding: bottomPadding,
                      showApparatusSelector: false,
                    ),
                    _buildMapTab(context),
                    _buildTrainingTab(context),
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
    required this.groups,
    required this.apparatus,
    required this.options,
  });

  final List<AdminApparatusGroup> groups;
  final List<AdminApparatus> apparatus;
  final AdminApparatusMasterOptions options;
}

class _ApparatusGroupListTile extends StatelessWidget {
  const _ApparatusGroupListTile({
    required this.slot,
    required this.group,
    required this.expanded,
    required this.editing,
    required this.onToggle,
    required this.onEdit,
  });

  final M3SegmentVerticalSlot slot;
  final AdminApparatusGroup group;
  final bool expanded;
  final bool editing;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: editing
          ? scheme.secondaryContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerLowest,
      elevation: expanded || editing ? 0 : 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_copy_outlined,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.apparatus.length} ta aparat',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.05,
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
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.65),
                      ),
                      if (group.apparatus.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Text(
                            'Bu guruhda aparat yo‘q',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        )
                      else
                        for (final name in group.apparatus)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            child: Row(
                              children: [
                                _apparatusLeading(context, name),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        _apparatusKindLabel(name),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Tahrirlash'),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
