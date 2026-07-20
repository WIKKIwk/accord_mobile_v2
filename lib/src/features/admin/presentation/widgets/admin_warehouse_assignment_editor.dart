import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../shared/models/app_models.dart';
import 'admin_warehouse_picker_sheet.dart';

typedef AdminWarehouseEditorAssigner = Future<AdminWarehouseAssignment>
    Function({
  required String warehouse,
  required UserRole principalRole,
  required String principalRef,
  required String displayName,
});
typedef AdminWarehouseEditorUnassigner = Future<AdminWarehouseAssignment>
    Function({
  required String warehouse,
  required UserRole principalRole,
  required String principalRef,
});

class AdminWarehouseAssignmentEditor extends StatefulWidget {
  const AdminWarehouseAssignmentEditor({
    super.key,
    required this.assignedWarehouses,
    required this.principalRole,
    required this.principalRef,
    required this.displayName,
    required this.reloadAssignedWarehouses,
    required this.onChanged,
    required this.assignedMessage,
    required this.chipKeyPrefix,
    required this.addButtonKey,
    this.warehousesLoader,
    this.warehouseAssigner,
    this.warehouseUnassigner,
    this.buttonRadius = 14,
  });

  final List<String> assignedWarehouses;
  final UserRole principalRole;
  final String principalRef;
  final String displayName;
  final Future<List<String>> Function() reloadAssignedWarehouses;
  final ValueChanged<List<String>> onChanged;
  final String assignedMessage;
  final String chipKeyPrefix;
  final String addButtonKey;
  final Future<List<AdminWarehouse>> Function()? warehousesLoader;
  final AdminWarehouseEditorAssigner? warehouseAssigner;
  final AdminWarehouseEditorUnassigner? warehouseUnassigner;
  final double buttonRadius;

  @override
  State<AdminWarehouseAssignmentEditor> createState() =>
      _AdminWarehouseAssignmentEditorState();
}

class _AdminWarehouseAssignmentEditorState
    extends State<AdminWarehouseAssignmentEditor> {
  bool _adding = false;
  String? _removingWarehouse;

  Future<void> _addWarehouse() async {
    if (_adding) {
      return;
    }
    setState(() => _adding = true);
    try {
      final warehouses = widget.warehousesLoader == null
          ? await MobileApi.instance.adminWarehouses(limit: 500)
          : await widget.warehousesLoader!();
      final assignedKeys = widget.assignedWarehouses
          .map((warehouse) => warehouse.trim().toLowerCase())
          .toSet();
      final available = normalizeAdminWarehouseNames(
        warehouses
            .where((warehouse) => !warehouse.isGroup)
            .map((warehouse) => warehouse.warehouse)
            .where(
              (warehouse) =>
                  !assignedKeys.contains(warehouse.trim().toLowerCase()),
            ),
      );
      if (!mounted) {
        return;
      }
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biriktirilmagan ombor topilmadi')),
        );
        return;
      }
      final warehouse = await showAdminWarehousePicker(
        context,
        available: available,
      );
      if (!mounted || warehouse == null) {
        return;
      }
      final assignWarehouse =
          widget.warehouseAssigner ?? MobileApi.instance.adminAssignWarehouse;
      final assignment = await assignWarehouse(
        warehouse: warehouse,
        principalRole: widget.principalRole,
        principalRef: widget.principalRef,
        displayName: widget.displayName,
      );
      final updated = await widget.reloadAssignedWarehouses();
      final assignmentConfirmed = updated.any(
        (item) =>
            item.trim().toLowerCase() ==
            assignment.warehouse.trim().toLowerCase(),
      );
      if (!assignmentConfirmed) {
        throw const MobileApiException(
          code: 'warehouse_assignment_not_confirmed',
          message: 'Server ombor biriktirilganini tasdiqlamadi',
        );
      }
      if (mounted) {
        widget.onChanged(normalizeAdminWarehouseNames(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${assignment.warehouse} biriktirildi')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ombor biriktirilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _removeWarehouse(String warehouse) async {
    if (_removingWarehouse != null) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Omborni uzish',
      message: '$warehouse omborini ${widget.displayName} profilidan uzaymi?',
      cancelLabel: 'Yo‘q',
      confirmLabel: 'Ha',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _removingWarehouse = warehouse);
    try {
      final unassignWarehouse = widget.warehouseUnassigner ??
          MobileApi.instance.adminUnassignWarehouse;
      await unassignWarehouse(
        warehouse: warehouse,
        principalRole: widget.principalRole,
        principalRef: widget.principalRef,
      );
      final updated = await widget.reloadAssignedWarehouses();
      final assignmentStillExists = updated.any(
        (item) => item.trim().toLowerCase() == warehouse.trim().toLowerCase(),
      );
      if (assignmentStillExists) {
        throw const MobileApiException(
          code: 'warehouse_unassignment_not_confirmed',
          message: 'Server ombor uzilganini tasdiqlamadi',
        );
      }
      if (mounted) {
        widget.onChanged(normalizeAdminWarehouseNames(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$warehouse profildan uzildi')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ombor uzilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingWarehouse = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Biriktirilgan omborlar', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          widget.assignedWarehouses.isEmpty
              ? 'Ombor biriktirilmagan.'
              : widget.assignedMessage,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.assignedWarehouses.isEmpty
                ? scheme.error
                : scheme.onSurfaceVariant,
          ),
        ),
        if (widget.assignedWarehouses.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final warehouse in widget.assignedWarehouses)
                InputChip(
                  key: ValueKey('${widget.chipKeyPrefix}$warehouse'),
                  avatar: const Icon(Icons.warehouse_outlined, size: 17),
                  label: Text(warehouse),
                  deleteIcon: _removingWarehouse == warehouse
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded, size: 18),
                  onDeleted: _removingWarehouse == null
                      ? () => _removeWarehouse(warehouse)
                      : null,
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: ValueKey(widget.addButtonKey),
            style: appOutlinedActionButtonStyle(
              borderRadius: widget.buttonRadius,
            ),
            onPressed: _adding ? null : _addWarehouse,
            icon: _adding
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(_adding ? 'Yuklanmoqda...' : 'Ombor biriktirish'),
          ),
        ),
      ],
    );
  }
}

List<String> normalizeAdminWarehouseNames(Iterable<String> values) {
  final byKey = <String, String>{};
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      byKey.putIfAbsent(normalized.toLowerCase(), () => normalized);
    }
  }
  final result = byKey.values.toList(growable: false);
  result
      .sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return result;
}
