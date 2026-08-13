import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
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
    final l10n = context.l10n;
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
          SnackBar(
            content: Text(
              l10n.adminText('warehouse.assignment_available_empty'),
            ),
          ),
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
        throw MobileApiException(
          code: 'warehouse_assignment_not_confirmed',
          message: l10n.adminText(
            'warehouse.assignment_not_confirmed',
          ),
        );
      }
      if (mounted) {
        widget.onChanged(normalizeAdminWarehouseNames(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.adminText(
                'warehouse.assigned',
                values: {'warehouse': assignment.warehouse},
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.adminText(
                'warehouse.assign_failed',
                values: {'error': error},
              ),
            ),
          ),
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
    final l10n = context.l10n;
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: l10n.adminText('warehouse.unassign_title'),
      message: l10n.adminText(
        'warehouse.unassign_message',
        values: {'warehouse': warehouse, 'name': widget.displayName},
      ),
      cancelLabel: l10n.adminText('action.no'),
      confirmLabel: l10n.adminText('action.yes'),
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
        throw MobileApiException(
          code: 'warehouse_unassignment_not_confirmed',
          message: l10n.adminText(
            'warehouse.unassignment_not_confirmed',
          ),
        );
      }
      if (mounted) {
        widget.onChanged(normalizeAdminWarehouseNames(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.adminText(
                'warehouse.unassigned',
                values: {'warehouse': warehouse},
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.adminText(
                'warehouse.unassign_failed',
                values: {'error': error},
              ),
            ),
          ),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminText('warehouse.assigned_title'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.assignedWarehouses.isEmpty
              ? l10n.adminText('warehouse.none_assigned')
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
            label: Text(
              _adding
                  ? l10n.adminText('action.loading')
                  : l10n.adminText('warehouse.add'),
            ),
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
