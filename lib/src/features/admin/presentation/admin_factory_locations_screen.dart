import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'package:flutter/material.dart';

class AdminFactoryLocationsScreen extends StatefulWidget {
  const AdminFactoryLocationsScreen({super.key});

  @override
  State<AdminFactoryLocationsScreen> createState() =>
      _AdminFactoryLocationsScreenState();
}

class _AdminFactoryLocationsScreenState
    extends State<AdminFactoryLocationsScreen> {
  List<AdminFactoryLocation> _locations = const [];
  List<AdminApparatus> _apparatus = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminFactoryLocations(),
        MobileApi.instance.adminApparatus(limit: 10000),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _locations = results[0] as List<AdminFactoryLocation>;
        _apparatus = _orderedApparatus(
          results[1] as List<AdminApparatus>,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'State’lar yuklanmadi';
      });
    }
  }

  Future<void> _openEditor([AdminFactoryLocation? location]) async {
    if (_saving) {
      return;
    }
    final result = await showDialog<_FactoryLocationEditorResult>(
      context: context,
      builder: (context) => _FactoryLocationEditorDialog(
        location: location,
        apparatus: _apparatus,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      AdminFactoryLocation saved;
      if (location == null) {
        saved = await MobileApi.instance.adminCreateFactoryLocation(
          name: result.name,
          apparatusIds: result.apparatusIds,
        );
      } else {
        saved = location;
        final currentIds = location.apparatus.map((item) => item.id).toSet();
        final nextIds = result.apparatusIds.toSet();
        if (currentIds.length != nextIds.length ||
            !currentIds.containsAll(nextIds)) {
          saved = await MobileApi.instance.adminReplaceFactoryLocationApparatus(
            id: location.id,
            apparatusIds: result.apparatusIds,
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        final items = [..._locations];
        final index = items.indexWhere((item) => item.id == saved.id);
        if (index < 0) {
          items.add(saved);
        } else {
          items[index] = saved;
        }
        items.sort(
          (left, right) =>
              left.name.toLowerCase().compareTo(right.name.toLowerCase()),
        );
        _locations = items;
      });
    } on MobileApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('State saqlanmadi');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _rename(AdminFactoryLocation location) async {
    if (_saving) {
      return;
    }
    final controller = TextEditingController(text: location.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('State nomini o‘zgartirish'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'State nomi',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted || name == location.name) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminUpdateFactoryLocation(
        id: location.id,
        name: name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final items = [
          for (final item in _locations)
            if (item.id == saved.id) saved else item,
        ]..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
        _locations = items;
      });
    } on MobileApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('State nomi yangilanmadi');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setActive(
    AdminFactoryLocation location,
    bool active,
  ) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminUpdateFactoryLocation(
        id: location.id,
        active: active,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _locations = [
          for (final item in _locations)
            if (item.id == saved.id) saved else item,
        ];
      });
    } on MobileApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('State holati yangilanmadi');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 120;
    return AdminShell(
      title: context.l10n.adminFactoryStatesNavTitle,
      selectedRouteName: AppRoutes.adminFactoryLocations,
      activeTab: AdminDockTab.home,
      actions: [
        IconButton(
          tooltip: 'State ochish',
          onPressed: _saving ? null : () => _openEditor(),
          icon: const Icon(Icons.add_location_alt_outlined),
        ),
      ],
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
              ? AppRetryState(onRetry: _load, message: _error)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(4, 10, 4, bottomPadding),
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _openEditor(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('State ochish'),
                      ),
                      const SizedBox(height: 10),
                      if (_locations.isEmpty)
                        const _EmptyFactoryLocations()
                      else
                        M3SegmentSpacedColumn(
                          children: [
                            for (var index = 0;
                                index < _locations.length;
                                index++)
                              _FactoryLocationTile(
                                location: _locations[index],
                                slot: M3SegmentedListGeometry
                                    .standaloneListSlotForIndex(
                                  index,
                                  _locations.length,
                                ),
                                disabled: _saving,
                                onEdit: () => _openEditor(_locations[index]),
                                onRename: () => _rename(_locations[index]),
                                onActiveChanged: (value) =>
                                    _setActive(_locations[index], value),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _FactoryLocationTile extends StatelessWidget {
  const _FactoryLocationTile({
    required this.location,
    required this.slot,
    required this.disabled,
    required this.onEdit,
    required this.onRename,
    required this.onActiveChanged,
  });

  final AdminFactoryLocation location;
  final M3SegmentVerticalSlot slot;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onRename;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: disabled ? null : onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              location.isApparatusState
                  ? Icons.precision_manufacturing_outlined
                  : Icons.place_outlined,
              color: location.active ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    location.id,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StateBadge(
                        label: location.isApparatusState
                            ? 'Aparat state'
                            : 'Oddiy state',
                        color: location.isApparatusState
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                      ),
                      if (!location.active)
                        _StateBadge(
                          label: 'Nofaol',
                          color: scheme.errorContainer,
                        ),
                    ],
                  ),
                  if (location.apparatus.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      location.apparatus.map((item) => item.name).join(', '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !disabled,
              tooltip: 'State amallari',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'rename') {
                  onRename();
                } else if (value == 'active') {
                  onActiveChanged(!location.active);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Apparatlarni tahrirlash'),
                ),
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Nomini o‘zgartirish'),
                ),
                PopupMenuItem(
                  value: 'active',
                  child: Text(
                    location.active ? 'Nofaol qilish' : 'Faollashtirish',
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

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

class _EmptyFactoryLocations extends StatelessWidget {
  const _EmptyFactoryLocations();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            'Hali state ochilmagan',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FactoryLocationEditorResult {
  const _FactoryLocationEditorResult({
    required this.name,
    required this.apparatusIds,
  });

  final String name;
  final List<String> apparatusIds;
}

class _FactoryLocationEditorDialog extends StatefulWidget {
  const _FactoryLocationEditorDialog({
    required this.location,
    required this.apparatus,
  });

  final AdminFactoryLocation? location;
  final List<AdminApparatus> apparatus;

  @override
  State<_FactoryLocationEditorDialog> createState() =>
      _FactoryLocationEditorDialogState();
}

class _FactoryLocationEditorDialogState
    extends State<_FactoryLocationEditorDialog> {
  late final TextEditingController _name;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.location?.name ?? '');
    _selected =
        widget.location?.apparatus.map((item) => item.id).toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _openApparatusPicker() async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApparatusPickerBottomSheet(
        apparatus: widget.apparatus,
        initialSelected: _selected,
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _selected = selected);
  }

  List<AdminApparatus> get _selectedApparatus => widget.apparatus
      .where((item) => _selected.contains(item.id))
      .toList(growable: false);

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('State nomini kiriting')),
      );
      return;
    }
    Navigator.of(context).pop(
      _FactoryLocationEditorResult(
        name: name,
        apparatusIds: _selected.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedApparatus = _selectedApparatus;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(widget.location == null ? 'State ochish' : 'State tahriri'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.location == null,
              readOnly: widget.location != null,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'State nomi',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.location != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Apparat biriktirish ID va nomni o‘zgartirmaydi: '
                  '${widget.location!.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openApparatusPicker,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Aparat ulash'),
              ),
            ),
            const SizedBox(height: 8),
            if (selectedApparatus.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aparat ulanmagan — oddiy state',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final item in selectedApparatus)
                      InputChip(
                        label: Text(item.name),
                        onDeleted: () =>
                            setState(() => _selected.remove(item.id)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Saqlash'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Bekor qilish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApparatusPickerBottomSheet extends StatefulWidget {
  const _ApparatusPickerBottomSheet({
    required this.apparatus,
    required this.initialSelected,
  });

  final List<AdminApparatus> apparatus;
  final Set<String> initialSelected;

  @override
  State<_ApparatusPickerBottomSheet> createState() =>
      _ApparatusPickerBottomSheetState();
}

class _ApparatusPickerBottomSheetState
    extends State<_ApparatusPickerBottomSheet> {
  final TextEditingController _search = TextEditingController();
  late final Set<String> _selected = {...widget.initialSelected};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = widget.apparatus
        .where(
          (item) => _query.isEmpty || item.name.toLowerCase().contains(_query),
        )
        .toList(growable: false);
    final defaults = visible.where((item) => item.isDefault).toList();
    final customs = visible.where((item) => !item.isDefault).toList();
    return FractionallySizedBox(
      heightFactor: 0.78,
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
                      'Aparat ulash',
                      style: theme.textTheme.titleLarge?.copyWith(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Aparat qidiring',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Mos apparat topilmadi'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      children: [
                        if (defaults.isNotEmpty) ...[
                          const _ApparatusSectionTitle('Default aparatlar'),
                          for (final item in defaults) _apparatusTile(item),
                        ],
                        if (customs.isNotEmpty) ...[
                          const _ApparatusSectionTitle('Custom aparatlar'),
                          for (final item in customs) _apparatusTile(item),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop({..._selected}),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _selected.isEmpty
                        ? 'Tanlamasdan davom etish'
                        : 'Tanlash (${_selected.length})',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apparatusTile(AdminApparatus item) {
    final selected = _selected.contains(item.id);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(item.name),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () {
        setState(() {
          if (selected) {
            _selected.remove(item.id);
          } else {
            _selected.add(item.id);
          }
        });
      },
    );
  }
}

class _ApparatusSectionTitle extends StatelessWidget {
  const _ApparatusSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

List<AdminApparatus> _orderedApparatus(List<AdminApparatus> apparatus) {
  final defaults = apparatus.where((item) => item.isDefault).toList()
    ..sort(
      (left, right) => left.sortOrder.compareTo(right.sortOrder),
    );
  final customs = apparatus.where((item) => !item.isDefault).toList()
    ..sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
  return [...defaults, ...customs];
}
