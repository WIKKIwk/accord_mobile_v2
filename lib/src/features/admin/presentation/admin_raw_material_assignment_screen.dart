import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/production_map_models.dart';
import 'raw_material_scan_dialog.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminRawMaterialAssignmentScreen extends StatefulWidget {
  const AdminRawMaterialAssignmentScreen({super.key});

  @override
  State<AdminRawMaterialAssignmentScreen> createState() =>
      _AdminRawMaterialAssignmentScreenState();
}

class _AdminRawMaterialAssignmentScreenState
    extends State<AdminRawMaterialAssignmentScreen> {
  late Future<_RawMaterialAssignmentData> _future;
  List<AdminRawMaterialAssignment> _assignments = const [];
  String _selectedOrderId = '';
  String _scannedBarcode = '';
  AdminRawMaterialLookup? _scannedMaterial;
  String _scanLookupError = '';
  bool _scanLookupLoading = false;
  bool _saving = false;

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

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
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

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminRawMaterialAssignments,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Homashyoni zakazga ulash',
      subtitle: '',
      nativeTopBar: true,
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
      child: FutureBuilder<_RawMaterialAssignmentData>(
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
          final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
          return ListView(
            padding: EdgeInsets.fromLTRB(0, 6, 0, bottomPadding),
            children: [
              _AssignmentEditor(
                orders: data.orders,
                selectedOrderId: _selectedOrderId,
                scannedBarcode: _scannedBarcode,
                scannedMaterial: _scannedMaterial,
                scanLookupError: _scanLookupError,
                scanLookupLoading: _scanLookupLoading,
                saving: _saving,
                onOrderChanged: (value) {
                  setState(() => _selectedOrderId = value);
                },
                onScan: _scan,
                onSave: _save,
              ),
              const SizedBox(height: 12),
              for (final assignment in _assignments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AssignmentTile(assignment: assignment),
                ),
            ],
          );
        },
      ),
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
    required this.selectedOrderId,
    required this.scannedBarcode,
    required this.scannedMaterial,
    required this.scanLookupError,
    required this.scanLookupLoading,
    required this.saving,
    required this.onOrderChanged,
    required this.onScan,
    required this.onSave,
  });

  final List<ProductionMapSaved> orders;
  final String selectedOrderId;
  final String scannedBarcode;
  final AdminRawMaterialLookup? scannedMaterial;
  final String scanLookupError;
  final bool scanLookupLoading;
  final bool saving;
  final ValueChanged<String> onOrderChanged;
  final VoidCallback onScan;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(selectedOrderId),
              initialValue: selectedOrderId.isEmpty ? null : selectedOrderId,
              decoration: const InputDecoration(
                labelText: 'Zakaz',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final order in orders)
                  DropdownMenuItem(
                    value: order.map.id.trim(),
                    child: Text(_orderLabel(order)),
                  ),
              ],
              onChanged: saving || orders.isEmpty
                  ? null
                  : (value) {
                      if (value != null) {
                        onOrderChanged(value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: saving ? null : onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('QR skanerlash'),
            ),
            if (scannedBarcode.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
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
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment});

  final AdminRawMaterialAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.qr_code_2_rounded),
        title: Text('${assignment.orderId} · ${assignment.barcode}'),
        subtitle: Text(
          [
            assignment.apparatus,
            assignment.itemCode,
            assignment.itemName,
            assignment.itemGroup,
          ].where((item) => item.trim().isNotEmpty).join(' · '),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Homashyo ma’lumoti',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
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
