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
import 'admin_queue_policy_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';

const double _apparatusSettingsPanelGap = 4;
const double _apparatusSettingsPanelTopGap = 8;

enum AdminApparatusSettingsTab { create, groups, queue }

int _apparatusSettingsTabIndex(AdminApparatusSettingsTab tab) {
  return switch (tab) {
    AdminApparatusSettingsTab.create => 0,
    AdminApparatusSettingsTab.groups => 1,
    AdminApparatusSettingsTab.queue => 2,
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
  final TextEditingController _name = TextEditingController();
  final TextEditingController _apparatusName = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _apparatusNameFocus = FocusNode();
  final ScrollController _createScrollController = ScrollController();
  final ScrollController _groupsScrollController = ScrollController();
  late final TabController _tabController;
  List<AdminWarehouse> _apparatus = const [];
  List<AdminApparatusGroup> _groups = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  bool _creatingApparatus = false;
  String? _loadError;
  String? _editingGroupName;
  String? _expandedGroupName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      initialIndex: _apparatusSettingsTabIndex(widget.initialTab),
      vsync: this,
    );
    _load();
    if (widget.focusApparatusName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apparatusNameFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _name.dispose();
    _apparatusName.dispose();
    _nameFocus.dispose();
    _apparatusNameFocus.dispose();
    _createScrollController.dispose();
    _groupsScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminApparatusGroups(),
        MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = results[0] as List<AdminApparatusGroup>;
        _apparatus = results[1] as List<AdminWarehouse>;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) {
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
        if (item.warehouse.trim().toLowerCase() == normalized) {
          yield item.warehouse;
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

  String? _groupOwningApparatus(String warehouseTitle) {
    for (final group in _groups) {
      for (final name in group.apparatus) {
        if (productionMapWarehouseTitlesMatch(name, warehouseTitle)) {
          return group.name;
        }
      }
    }
    return null;
  }

  List<AdminWarehouse> _selectableApparatusForEditor() {
    final editingKey = _editingGroupName?.trim().toLowerCase() ?? '';
    return _apparatus.where((item) {
      final owner = _groupOwningApparatus(item.warehouse);
      if (owner == null) {
        return true;
      }
      return editingKey.isNotEmpty && owner.trim().toLowerCase() == editingKey;
    }).toList(growable: false);
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
    setState(() => _creatingApparatus = true);
    try {
      final created = await MobileApi.instance.adminCreateApparatus(name);
      if (!mounted) {
        return;
      }
      setState(() {
        final key = created.warehouse.toLowerCase();
        final next = [
          for (final item in _apparatus)
            if (item.warehouse.toLowerCase() != key) item,
          created,
        ]..sort(
            (left, right) => left.warehouse.toLowerCase().compareTo(
                  right.warehouse.toLowerCase(),
                ),
          );
        _apparatus = next;
        _selected.add(created.warehouse);
        _apparatusName.clear();
      });
      showAdminTopNotice(context, 'Aparat qo\'shildi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Aparat qo\'shilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _creatingApparatus = false);
      }
    }
  }

  Widget _buildCreateTab(BuildContext context, double bottomPadding) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        controller: _createScrollController,
        padding: EdgeInsets.fromLTRB(
          _apparatusSettingsPanelGap,
          _apparatusSettingsPanelTopGap,
          _apparatusSettingsPanelGap,
          bottomPadding,
        ),
        children: [
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
          FilledButton.icon(
            onPressed: _creatingApparatus ? null : _createApparatus,
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: Text(
              _creatingApparatus ? 'Qo\'shilmoqda...' : 'Aparat qo\'shish',
            ),
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
                    title: _apparatus[index].warehouse,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab(BuildContext context, double bottomPadding) {
    final scheme = Theme.of(context).colorScheme;
    final selectableApparatus = _selectableApparatusForEditor();
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
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
                    title: selectableApparatus[index].warehouse,
                    selected: _selected.contains(
                      selectableApparatus[index].warehouse,
                    ),
                    onToggle: () {
                      final warehouse = selectableApparatus[index].warehouse;
                      setState(() {
                        if (_selected.contains(warehouse)) {
                          _selected.remove(warehouse);
                        } else {
                          _selected.add(warehouse);
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
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCreateTab(context, bottomPadding),
                          _buildGroupsTab(context, bottomPadding),
                          ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: AdminQueuePolicyPanel(
                              bottomPadding: bottomPadding,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

IconData _apparatusIcon(String title) {
  if (productionMapPechatColorCount(title) != null) {
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
  if (productionMapPechatColorCount(title) != null) {
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
    required this.title,
  });

  final M3SegmentVerticalSlot slot;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      title: title,
      subtitle: _apparatusKindLabel(title),
      value: '',
      showChevron: false,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      elevation: 2,
      leading: _apparatusLeading(context, title),
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
      elevation: 2,
      backgroundColor: selected
          ? scheme.primaryContainer.withValues(alpha: 0.34)
          : scheme.surface,
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
          : scheme.surface,
      elevation: expanded || editing ? 0 : 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
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
