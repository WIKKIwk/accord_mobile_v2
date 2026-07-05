import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_item_group_items_tab.dart';
import 'widgets/admin_item_group_parent_move_panel.dart';
import 'widgets/admin_item_group_tree_tab.dart';
import 'widgets/admin_picker_field.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminItemGroupCreateScreen extends StatefulWidget {
  const AdminItemGroupCreateScreen({super.key});

  @override
  State<AdminItemGroupCreateScreen> createState() =>
      _AdminItemGroupCreateScreenState();
}

class _AdminItemGroupCreateScreenState extends State<AdminItemGroupCreateScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<String>> itemGroupsFuture;
  late Future<List<AdminItemGroupTreeEntry>> itemGroupTreeFuture;
  late TabController _tabController;
  final List<String> optimisticParentGroups = [];
  String? selectedItemGroup;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    itemGroupsFuture = _loadParentGroups();
    itemGroupTreeFuture = _loadItemGroupTree();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _openGroupCreateDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ItemGroupCreateDialogCard(
            loadParentGroups: _loadParentGroups,
            onSaved: (group) async {
              if (!mounted) {
                return;
              }
              setState(() {
                _addOptimisticParentGroup(group);
                _refreshParentGroups();
              });
              showAdminTopNotice(
                  context, 'Item Group qo‘shildi: ${group.name}');
            },
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _openParentMoveDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ItemGroupParentMoveDialogCard(
            itemGroupsFuture: _loadParentGroups(),
            onMoved: _handleMoved,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Item Group',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(
        activeTab: AdminDockTab.settings,
        primaryFabActions: [
          AdminFabMenuAction(
            title: 'Group qo‘shish',
            icon: Icons.create_new_folder_outlined,
            onTap: _openGroupCreateDialog,
          ),
          AdminFabMenuAction(
            title: 'Parent ko‘chirish',
            icon: Icons.drive_file_move_outline,
            onTap: _openParentMoveDialog,
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          AdminSurfaceTabBar(
            controller: _tabController,
            tabs: const [
              Tab(height: 38, text: 'Tree'),
              Tab(height: 38, text: 'Items'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AdminItemGroupTreeTab(
                  itemGroupTreeFuture: itemGroupTreeFuture,
                  onRefresh: _reloadItemGroupTree,
                  onShowItems: _selectItemGroupForItems,
                  onNavigateToItemsTab: () => _tabController.animateTo(1),
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

class _ItemGroupCreateDialogCard extends StatefulWidget {
  const _ItemGroupCreateDialogCard({
    required this.loadParentGroups,
    required this.onSaved,
    required this.onClose,
  });

  final Future<List<String>> Function() loadParentGroups;
  final Future<void> Function(AdminItemGroup group) onSaved;
  final VoidCallback onClose;

  @override
  State<_ItemGroupCreateDialogCard> createState() =>
      _ItemGroupCreateDialogCardState();
}

class _ItemGroupCreateDialogCardState
    extends State<_ItemGroupCreateDialogCard> {
  final TextEditingController _nameController = TextEditingController();
  late Future<List<String>> _parentsFuture;
  String? _parent;
  bool _isGroup = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parentsFuture = widget.loadParentGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncParentSelection(List<String> groups) {
    final current = _parent?.trim() ?? '';
    if (current.isNotEmpty && groups.contains(current)) {
      return;
    }
    final fallback = groups.contains('All Item Groups')
        ? 'All Item Groups'
        : (groups.isNotEmpty ? groups.first : '');
    if (fallback.isNotEmpty) {
      _parent = fallback;
    }
  }

  Future<void> _openParentPicker(List<String> groups) async {
    if (_saving || groups.isEmpty) {
      return;
    }
    final picked = await _showItemGroupPicker(
      context: context,
      title: 'Parent group tanlang',
      hintText: 'Parent group qidiring',
      groups: groups,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _parent = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final parent = _parent?.trim() ?? '';
    if (name.isEmpty || parent.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final group = await MobileApi.instance.adminCreateItemGroup(
        name: name,
        parent: parent,
        isGroup: _isGroup,
      );
      await widget.onSaved(group);
      if (mounted) {
        widget.onClose();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item Group qo‘shilmadi: $error')),
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
                      'Group qo‘shish',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Yopish',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: 'Group nomi',
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<String>>(
                future: _parentsFuture,
                builder: (context, snapshot) {
                  final groups = snapshot.data ?? const <String>[];
                  if (snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError) {
                    _syncParentSelection(groups);
                  }
                  final pickerReady =
                      snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError &&
                          !_saving;
                  return AdminPickerField(
                    label: 'Parent group',
                    value: _parent,
                    placeholder:
                        snapshot.connectionState == ConnectionState.done
                            ? 'Parent tanlang'
                            : 'Yuklanmoqda...',
                    enabled: pickerReady,
                    onTap: pickerReady ? () => _openParentPicker(groups) : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isGroup,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isGroup = value),
                title: const Text('Ichida yana guruh bo‘ladi'),
                subtitle: const Text(
                  'Parent sifatida ishlatiladigan group uchun yoqing. '
                  'Oxirgi/leaf group bo‘lsa o‘chiring.',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                child:
                    Text(_saving ? 'Qo‘shilmoqda...' : 'Item Group qo‘shish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemGroupParentMoveDialogCard extends StatelessWidget {
  const _ItemGroupParentMoveDialogCard({
    required this.itemGroupsFuture,
    required this.onMoved,
    required this.onClose,
  });

  final Future<List<String>> itemGroupsFuture;
  final ValueChanged<AdminItemGroup> onMoved;
  final VoidCallback onClose;

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
                      'Parent ko‘chirish',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Yopish',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<String>>(
                future: itemGroupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: AppLoadingIndicator()),
                    );
                  }
                  if (snapshot.hasError ||
                      (snapshot.data ?? const []).isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Item grouplar yuklanmadi')),
                    );
                  }
                  return AdminItemGroupParentMovePanel(
                    groups: snapshot.data ?? const <String>[],
                    onMoved: onMoved,
                    showHeader: false,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _showItemGroupPicker({
  required BuildContext context,
  required String title,
  required String hintText,
  required List<String> groups,
}) {
  return showModalBottomSheet<String>(
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
        title: title,
        hintText: hintText,
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
}
