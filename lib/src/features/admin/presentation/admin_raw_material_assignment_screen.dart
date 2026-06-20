import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/production_map_models.dart';
import 'raw_material_scan_dialog.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

const double _rawMaterialAssignmentPanelGap = 4;

InputDecoration _rawMaterialAssignmentFieldDecoration(
  BuildContext context, {
  required String labelText,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder outline({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: color ?? scheme.outlineVariant, width: width),
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

Widget _rawMaterialAssignmentSurfaceCard({
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

class AdminRawMaterialAssignmentScreen extends StatelessWidget {
  const AdminRawMaterialAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminRawMaterialSettings,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      title: 'Homashyo sozlamalari',
      subtitle: '',
      nativeTopBar: true,
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: EdgeInsets.zero,
      child: AdminRawMaterialAssignmentPanel(bottomPadding: bottomPadding),
    );
  }
}

class AdminRawMaterialAssignmentPanel extends StatefulWidget {
  const AdminRawMaterialAssignmentPanel({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  State<AdminRawMaterialAssignmentPanel> createState() =>
      _AdminRawMaterialAssignmentPanelState();
}

class _AdminRawMaterialAssignmentPanelState
    extends State<AdminRawMaterialAssignmentPanel> {
  late Future<_RawMaterialAssignmentData> _future;
  List<AdminRawMaterialAssignment> _assignments = const [];
  String _selectedOrderId = '';
  String _scannedBarcode = '';
  AdminRawMaterialLookup? _scannedMaterial;
  String _scanLookupError = '';
  bool _scanLookupLoading = false;
  bool _saving = false;
  String? _expandedAssignmentKey;
  String _unlinkingAssignmentKey = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RawMaterialAssignmentData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminProductionMaps(),
      MobileApi.instance.adminRawMaterialAssignments(),
    ]);
    final orders = results[0] as List<ProductionMapSaved>;
    final assignments = results[1] as List<AdminRawMaterialAssignment>;
    _assignments = assignments;
    if (_selectedOrderId.isEmpty && orders.isNotEmpty) {
      _selectedOrderId = orders.first.map.id.trim();
    }
    return _RawMaterialAssignmentData(
      orders: orders,
      assignments: assignments,
    );
  }

  String _selectedOrderLabel(List<ProductionMapSaved> orders) {
    for (final order in orders) {
      if (order.map.id.trim() == _selectedOrderId.trim()) {
        return _orderLabel(order);
      }
    }
    return _selectedOrderId.trim();
  }

  Future<void> _openOrderPicker(List<ProductionMapSaved> orders) async {
    if (_saving || orders.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<ProductionMapSaved>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<ProductionMapSaved>(
          title: 'Zakaz tanlang',
          hintText: 'Zakaz qidiring',
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? orders
                : orders.where((order) {
                    final map = order.map;
                    return searchMatches(normalizedQuery, [
                      map.id,
                      map.code,
                      map.orderNumber,
                      map.title,
                      map.productCode,
                      _orderLabel(order),
                    ]);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: _orderLabel,
          itemSubtitle: (order) => order.map.id.trim(),
          onSelected: (order) => Navigator.of(context).pop(order),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedOrderId = picked.map.id.trim());
  }

  Future<void> _scan() async {
    final barcode = await showRawMaterialScanDialog(context);
    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }
    final normalized = rawMaterialBarcodeFromQr(barcode);
    setState(() {
      _scannedBarcode = normalized;
      _scannedMaterial = null;
      _scanLookupError = '';
      _scanLookupLoading = true;
    });
    try {
      final detail = await MobileApi.instance.adminRawMaterialLookup(
        barcode: normalized,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scannedMaterial = detail;
        _scanLookupError = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanLookupError =
            error is MobileApiException ? error.message : 'Homashyo topilmadi';
      });
    } finally {
      if (mounted) {
        setState(() => _scanLookupLoading = false);
      }
    }
  }

  Future<void> _save() async {
    final orderId = _selectedOrderId.trim();
    final barcode = rawMaterialBarcodeFromQr(_scannedBarcode);
    if (orderId.isEmpty || barcode.isEmpty || _saving) {
      showAdminTopNotice(context, 'Zakaz tanlang va homashyo QR skaner qiling');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: orderId,
        barcode: barcode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scannedBarcode = '';
        _scannedMaterial = null;
        _scanLookupError = '';
        _assignments = [
          saved,
          for (final item in _assignments)
            if (item.orderId.trim() != saved.orderId.trim() ||
                item.barcode.trim() != saved.barcode.trim())
              item,
        ];
      });
      showAdminTopNotice(context, 'Homashyo zakazga ulandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Homashyo ulanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _unlink(AdminRawMaterialAssignment assignment) async {
    final key = _assignmentKey(assignment);
    if (_saving || _unlinkingAssignmentKey.isNotEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Homashyoni uzish'),
          content: const Text('Bu homashyoni zakazdan uzasizmi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Uzish'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _unlinkingAssignmentKey = key);
    try {
      await MobileApi.instance.adminUnlinkRawMaterialAssignment(
        orderId: assignment.orderId,
        barcode: assignment.barcode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _assignments = [
          for (final item in _assignments)
            if (_assignmentKey(item) != key) item,
        ];
        if (_expandedAssignmentKey == key) {
          _expandedAssignmentKey = null;
        }
      });
      showAdminTopNotice(context, 'Homashyo zakazdan uzildi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Homashyo uzilmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _unlinkingAssignmentKey = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RawMaterialAssignmentData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return AppRetryState(
            onRetry: () async {
              setState(() => _future = _load());
            },
          );
        }
        final data = snapshot.data!;
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              _rawMaterialAssignmentPanelGap,
              10,
              _rawMaterialAssignmentPanelGap,
              widget.bottomPadding,
            ),
              children: [
                _AssignmentEditor(
                  orders: data.orders,
                  selectedOrderLabel: _selectedOrderLabel(data.orders),
                  scannedBarcode: _scannedBarcode,
                  scannedMaterial: _scannedMaterial,
                  scanLookupError: _scanLookupError,
                  scanLookupLoading: _scanLookupLoading,
                  saving: _saving,
                  onPickOrder: () => _openOrderPicker(data.orders),
                  onScan: _scan,
                  onSave: _save,
                ),
                if (_assignments.isEmpty) ...[
                  const SizedBox(height: 10),
                  _rawMaterialAssignmentSurfaceCard(
                    context: context,
                    child: const Center(
                      child: Text('Ulangan homashyo topilmadi'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  M3SegmentSpacedColumn(
                    padding: EdgeInsets.zero,
                    children: [
                      for (var index = 0; index < _assignments.length; index++)
                        _AssignmentTile(
                          slot: M3SegmentedListGeometry
                              .standaloneListSlotForIndex(
                            index,
                            _assignments.length,
                          ),
                          assignment: _assignments[index],
                          expanded: _expandedAssignmentKey ==
                              _assignmentKey(_assignments[index]),
                          unlinking: _unlinkingAssignmentKey ==
                              _assignmentKey(_assignments[index]),
                          onExpandedChanged: (expanded) {
                            setState(() {
                              _expandedAssignmentKey = expanded
                                  ? _assignmentKey(_assignments[index])
                                  : null;
                            });
                          },
                          onUnlink: () => _unlink(_assignments[index]),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
  }
}

class _RawMaterialAssignmentData {
  const _RawMaterialAssignmentData({
    required this.orders,
    required this.assignments,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminRawMaterialAssignment> assignments;
}

class _AssignmentEditor extends StatelessWidget {
  const _AssignmentEditor({
    required this.orders,
    required this.selectedOrderLabel,
    required this.scannedBarcode,
    required this.scannedMaterial,
    required this.scanLookupError,
    required this.scanLookupLoading,
    required this.saving,
    required this.onPickOrder,
    required this.onScan,
    required this.onSave,
  });

  final List<ProductionMapSaved> orders;
  final String selectedOrderLabel;
  final String scannedBarcode;
  final AdminRawMaterialLookup? scannedMaterial;
  final String scanLookupError;
  final bool scanLookupLoading;
  final bool saving;
  final VoidCallback onPickOrder;
  final VoidCallback onScan;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _rawMaterialAssignmentSurfaceCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: saving || orders.isEmpty ? null : onPickOrder,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _rawMaterialAssignmentFieldDecoration(
                context,
                labelText: 'Zakaz',
              ).copyWith(
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
              isEmpty: selectedOrderLabel.trim().isEmpty,
              child: Text(
                selectedOrderLabel.trim().isEmpty
                    ? (orders.isEmpty ? 'Zakaz topilmadi' : 'Tanlang')
                    : selectedOrderLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('QR skanerlash'),
          ),
          if (scannedBarcode.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ScannedRawMaterialCard(
              barcode: scannedBarcode,
              detail: scannedMaterial,
              loading: scanLookupLoading,
              error: scanLookupError,
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: const Text('Ulash'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.slot,
    required this.assignment,
    required this.expanded,
    required this.unlinking,
    required this.onExpandedChanged,
    required this.onUnlink,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialAssignment assignment;
  final bool expanded;
  final bool unlinking;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final summary = [
      assignment.apparatus,
      assignment.itemName,
      assignment.itemGroup,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    final assignee = _assignmentAssignee(assignment);
    final status = assignment.stockStatus.trim();
    final canUnlink = status.isEmpty || status.toLowerCase() == 'available';

    return Material(
      key: ValueKey('raw-material-assignment-${_assignmentKey(assignment)}'),
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onExpandedChanged(!expanded),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 12 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
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
                            assignment.orderId.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assignment.barcode.trim(),
                            maxLines: expanded ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              summary,
                              maxLines: expanded ? 4 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.2,
                              ),
                            ),
                          ],
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
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding:
                            const EdgeInsets.only(left: 44, top: 8, right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MaterialInfoRow(
                              label: 'Zakaz',
                              value: assignment.orderId,
                            ),
                            _MaterialInfoRow(
                              label: 'QR',
                              value: assignment.barcode,
                            ),
                            _MaterialInfoRow(
                              label: 'Aparat',
                              value: assignment.apparatus,
                            ),
                            _MaterialInfoRow(
                              label: 'Ombor',
                              value: assignment.stockWarehouse,
                            ),
                            _MaterialInfoRow(
                              label: 'Kod',
                              value: assignment.itemCode,
                            ),
                            _MaterialInfoRow(
                              label: 'Nomi',
                              value: assignment.itemName,
                            ),
                            _MaterialInfoRow(
                              label: 'Guruh',
                              value: assignment.itemGroup,
                            ),
                            _MaterialInfoRow(
                              label: 'Status',
                              value: _assignmentStockStatusLabel(
                                assignment.stockStatus,
                              ),
                            ),
                            _MaterialInfoRow(
                              label: 'Band zakaz',
                              value: assignment.reservedOrderId,
                            ),
                            _MaterialInfoRow(
                              label: 'Kim uladi',
                              value: assignee,
                            ),
                            _MaterialInfoRow(
                              label: 'Vaqt',
                              value: _formatAssignmentTimestamp(
                                assignment.assignedAt,
                              ),
                            ),
                            if (canUnlink) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: unlinking ? null : onUnlink,
                                  icon: unlinking
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.link_off_rounded),
                                  label: const Text('Uzish'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannedRawMaterialCard extends StatelessWidget {
  const _ScannedRawMaterialCard({
    required this.barcode,
    required this.detail,
    required this.loading,
    required this.error,
  });

  final String barcode;
  final AdminRawMaterialLookup? detail;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = this.detail;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Homashyo ma’lumoti',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _MaterialInfoRow(label: 'QR', value: barcode.trim()),
            if (detail != null) ...[
              _MaterialInfoRow(label: 'Ombor', value: detail.warehouse),
              _MaterialInfoRow(label: 'Turi', value: detail.itemGroup),
              _MaterialInfoRow(label: 'Nomi', value: detail.itemName),
              _MaterialInfoRow(
                label: 'Miqdori',
                value: _formatQty(detail.qty, detail.uom),
              ),
              _MaterialInfoRow(label: 'Item code', value: detail.itemCode),
            ],
            if (error.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                error.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialInfoRow extends StatelessWidget {
  const _MaterialInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              cleanValue,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _orderLabel(ProductionMapSaved order) {
  final map = order.map;
  final code = map.code.trim().isNotEmpty
      ? map.code.trim()
      : map.orderNumber.trim().isNotEmpty
          ? map.orderNumber.trim()
          : map.id.trim();
  final title = map.title.trim().isNotEmpty ? map.title.trim() : 'Zakaz';
  return '$code · $title';
}

String _formatQty(double value, String uom) {
  final qty = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  return [qty, if (uom.trim().isNotEmpty) uom.trim()].join(' ');
}

String _assignmentKey(AdminRawMaterialAssignment assignment) {
  return '${assignment.orderId.trim()}|${assignment.barcode.trim()}';
}

String _assignmentAssignee(AdminRawMaterialAssignment assignment) {
  final name = assignment.assignedByName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  return assignment.assignedByRef.trim();
}

String _assignmentStockStatusLabel(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'available' => 'Mavjud',
    'reserved' => 'Band',
    'consumed' => 'Ishlatilgan',
    '' => '',
    _ => raw.trim(),
  };
}

String _formatAssignmentTimestamp(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final local = parsed.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
