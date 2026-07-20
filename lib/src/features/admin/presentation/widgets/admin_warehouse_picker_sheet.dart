import 'package:flutter/material.dart';

Future<String?> showAdminWarehousePicker(
  BuildContext context, {
  required List<String> available,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AdminWarehousePickerSheet(available: available),
  );
}

class _AdminWarehousePickerSheet extends StatefulWidget {
  const _AdminWarehousePickerSheet({required this.available});

  final List<String> available;

  @override
  State<_AdminWarehousePickerSheet> createState() =>
      _AdminWarehousePickerSheetState();
}

class _AdminWarehousePickerSheetState
    extends State<_AdminWarehousePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedWarehouse;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = widget.available.where((warehouse) {
      return _query.isEmpty || warehouse.toLowerCase().contains(_query);
    }).toList(growable: false);
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
                      'Ombor biriktirish',
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
                key: const ValueKey('admin-material-warehouses-search'),
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Ombor qidiring',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Ombor topilmadi'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final warehouse = visible[index];
                        final selected = _selectedWarehouse == warehouse;
                        return ListTile(
                          key: ValueKey(
                            'admin-material-warehouse-${warehouse.toLowerCase()}',
                          ),
                          leading: const Icon(Icons.warehouse_outlined),
                          title: Text(warehouse),
                          selected: selected,
                          trailing: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          tileColor: scheme.surfaceContainerHighest,
                          selectedTileColor: scheme.primaryContainer,
                          onTap: () {
                            setState(() => _selectedWarehouse = warehouse);
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
                  key: const ValueKey('admin-material-warehouse-confirm'),
                  onPressed: _selectedWarehouse == null
                      ? null
                      : () => Navigator.of(context).pop(_selectedWarehouse),
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
