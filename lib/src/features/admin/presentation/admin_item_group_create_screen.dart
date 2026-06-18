import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_item_group_items_tab.dart';
import 'widgets/admin_item_group_parent_move_tab.dart';
import 'widgets/admin_item_group_tree_tab.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

const double _itemGroupPanelGap = 4;

InputDecoration _itemGroupFieldDecoration(
  BuildContext context, {
  required String labelText,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder outline({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color ?? scheme.outlineVariant, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    filled: true,
    fillColor: scheme.surface,
    border: outline(),
    enabledBorder: outline(),
    focusedBorder: outline(color: scheme.primary, width: 1.2),
    errorBorder: outline(color: scheme.error),
    focusedErrorBorder: outline(color: scheme.error, width: 1.2),
  );
}

Widget _itemGroupSurfaceCard({
  required BuildContext context,
  required Widget child,
  M3SegmentVerticalSlot? slot,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
}) {
  final scheme = Theme.of(context).colorScheme;
  final resolvedSlot = slot ?? M3SegmentVerticalSlot.top;
  final radius = M3SegmentedListGeometry.borderRadius(
    resolvedSlot,
    slot == null
        ? M3SegmentedListGeometry.cornerLarge
        : M3SegmentedListGeometry.cornerRadiusForSlot(resolvedSlot),
  );
  return Material(
    color: scheme.surface,
    elevation: 2,
    shadowColor: scheme.shadow.withValues(alpha: 0.16),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: radius),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class AdminItemGroupCreateScreen extends StatefulWidget {
  const AdminItemGroupCreateScreen({super.key});

  @override
  State<AdminItemGroupCreateScreen> createState() =>
      _AdminItemGroupCreateScreenState();
}

class _AdminItemGroupCreateScreenState extends State<AdminItemGroupCreateScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController name = TextEditingController();
  final TextEditingController parent = TextEditingController();
  late Future<List<String>> itemGroupsFuture;
  late Future<List<AdminItemGroupTreeEntry>> itemGroupTreeFuture;
  late TabController _tabController;
  final List<String> optimisticParentGroups = [];
  bool saving = false;
  bool isGroup = true;
  String? selectedItemGroup;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    itemGroupsFuture = _loadParentGroups();
    itemGroupTreeFuture = _loadItemGroupTree();
  }

  @override
  void dispose() {
    _tabController.dispose();
    name.dispose();
    parent.dispose();
    super.dispose();
  }

  Future<List<String>> _loadParentGroups() async {
    final groups = await MobileApi.instance.adminItemGroups();
    return _mergeParentGroups(groups);
  }

  Future<List<AdminItemGroupTreeEntry>> _loadItemGroupTree() {
    return MobileApi.instance.adminItemGroupTree();
  }

  List<String> _mergeParentGroups(List<String> groups) {
    final seen = <String>{};
    final merged = <String>[];
    for (final group in [...groups, ...optimisticParentGroups]) {
      final trimmed = group.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      merged.add(trimmed);
    }
    return merged;
  }

  void _refreshParentGroups() {
    itemGroupsFuture = _loadParentGroups();
    itemGroupTreeFuture = _loadItemGroupTree();
  }

  Future<void> _reloadItemGroupTree() async {
    final groupsFuture = _loadParentGroups();
    final treeFuture = _loadItemGroupTree();
    setState(() {
      itemGroupsFuture = groupsFuture;
      itemGroupTreeFuture = treeFuture;
    });
    await Future.wait([groupsFuture, treeFuture]);
  }

  void _addOptimisticParentGroup(AdminItemGroup group) {
    if (!group.isGroup) {
      return;
    }
    optimisticParentGroups.add(group.name);
    if (group.itemGroupName != group.name) {
      optimisticParentGroups.add(group.itemGroupName);
    }
  }

  void _handleMoved(AdminItemGroup group) {
    setState(() {
      _addOptimisticParentGroup(group);
      _refreshParentGroups();
    });
  }

  void _selectItemGroupForItems(String group) {
    setState(() => selectedItemGroup = group);
  }

  void _syncParentSelection(List<String> groups) {
    final current = parent.text.trim();
    if (current.isNotEmpty && groups.contains(current)) {
      return;
    }
    final fallback = groups.contains('All Item Groups')
        ? 'All Item Groups'
        : (groups.isNotEmpty ? groups.first : '');
    if (fallback.isNotEmpty) {
      parent.text = fallback;
    }
  }

  Future<void> _openParentPicker(List<String> groups) async {
    if (saving || groups.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<String>(
          title: 'Parent group tanlang',
          hintText: 'Parent group qidiring',
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? groups
                : groups.where((group) {
                    return group.toLowerCase().contains(normalizedQuery);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (group) => group,
          itemSubtitle: (_) => '',
          onSelected: (group) => Navigator.of(context).pop(group),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => parent.text = picked);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final group = await MobileApi.instance.adminCreateItemGroup(
        name: name.text.trim(),
        parent: parent.text.trim(),
        isGroup: isGroup,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _addOptimisticParentGroup(group);
        _refreshParentGroups();
      });
      name.clear();
      showAdminTopNotice(context, 'Item Group yaratildi: ${group.name}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item Group yaratilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Item Group yaratish',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          AdminSurfaceTabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(height: 38, text: 'Group yaratish'),
              Tab(height: 38, text: 'Parent ko‘chirish'),
              Tab(height: 38, text: 'Tree'),
              Tab(height: 38, text: 'Items'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CreateGroupTab(
                  name: name,
                  parent: parent,
                  itemGroupsFuture: itemGroupsFuture,
                  saving: saving,
                  isGroup: isGroup,
                  onSyncParent: _syncParentSelection,
                  onOpenParentPicker: _openParentPicker,
                  onIsGroupChanged: saving
                      ? null
                      : (value) => setState(() => isGroup = value),
                  onSave: saving ? null : _save,
                ),
                AdminItemGroupParentMoveTab(
                  itemGroupsFuture: itemGroupsFuture,
                  onMoved: _handleMoved,
                ),
                AdminItemGroupTreeTab(
                  itemGroupTreeFuture: itemGroupTreeFuture,
                  onRefresh: _reloadItemGroupTree,
                  onShowItems: _selectItemGroupForItems,
                  onNavigateToItemsTab: () => _tabController.animateTo(3),
                ),
                AdminItemGroupItemsTab(
                  itemGroupsFuture: itemGroupsFuture,
                  selectedGroup: selectedItemGroup,
                  onSelectGroup: _selectItemGroupForItems,
                  loadItemsPage: (group, limit, offset) =>
                      MobileApi.instance.adminItemsPage(
                        group: group,
                        limit: limit,
                        offset: offset,
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

class _CreateGroupTab extends StatelessWidget {
  const _CreateGroupTab({
    required this.name,
    required this.parent,
    required this.itemGroupsFuture,
    required this.saving,
    required this.isGroup,
    required this.onSyncParent,
    required this.onOpenParentPicker,
    required this.onIsGroupChanged,
    required this.onSave,
  });

  final TextEditingController name;
  final TextEditingController parent;
  final Future<List<String>> itemGroupsFuture;
  final bool saving;
  final bool isGroup;
  final ValueChanged<List<String>> onSyncParent;
  final Future<void> Function(List<String> groups) onOpenParentPicker;
  final ValueChanged<bool>? onIsGroupChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 116;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _itemGroupPanelGap,
          _itemGroupPanelGap,
          _itemGroupPanelGap,
          bottomPadding,
        ),
        children: [
          _itemGroupSurfaceCard(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: _itemGroupFieldDecoration(
                    context,
                    labelText: 'Group nomi',
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: itemGroupsFuture,
                  builder: (context, snapshot) {
                    final groups = snapshot.data ?? const <String>[];
                    if (snapshot.connectionState == ConnectionState.done &&
                        !snapshot.hasError) {
                      onSyncParent(groups);
                    }
                    final selectedParent = parent.text.trim().isEmpty
                        ? null
                        : parent.text.trim();
                    final pickerReady =
                        snapshot.connectionState == ConnectionState.done &&
                        !snapshot.hasError &&
                        !saving;
                    return _ItemGroupPickerField(
                      label: 'Parent group',
                      value: selectedParent,
                      placeholder: 'Parent tanlang',
                      enabled: pickerReady,
                      onTap: pickerReady
                          ? () => onOpenParentPicker(groups)
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: isGroup,
                  onChanged: onIsGroupChanged,
                  title: const Text('Ichida yana guruh bo‘ladi'),
                  subtitle: const Text(
                    'Parent sifatida ishlatiladigan group uchun yoqing. '
                    'Oxirgi/leaf group bo‘lsa o‘chiring.',
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onSave,
                  child: Text(
                    saving ? 'Yaratilmoqda...' : 'Item Group yaratish',
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

class _ItemGroupPickerField extends StatelessWidget {
  const _ItemGroupPickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
