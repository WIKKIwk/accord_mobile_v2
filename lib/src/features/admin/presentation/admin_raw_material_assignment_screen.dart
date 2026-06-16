import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
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
  final _barcodeController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemGroupController = TextEditingController();
  late Future<_RawMaterialAssignmentData> _future;
  List<AdminRawMaterialAssignment> _assignments = const [];
  String _selectedOrderId = '';
  String _selectedItemCode = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _itemCodeController.dispose();
    _itemNameController.dispose();
    _itemGroupController.dispose();
    super.dispose();
  }

  Future<_RawMaterialAssignmentData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminProductionMaps(),
      MobileApi.instance.adminItems(),
      MobileApi.instance.adminRawMaterialAssignments(),
    ]);
    final orders = results[0] as List<ProductionMapSaved>;
    final items = results[1] as List<SupplierItem>;
    final assignments = results[2] as List<AdminRawMaterialAssignment>;
    _assignments = assignments;
    if (_selectedOrderId.isEmpty && orders.isNotEmpty) {
      _selectedOrderId = orders.first.map.id.trim();
    }
    if (_selectedItemCode.isEmpty && items.isNotEmpty) {
      _selectItem(items.first);
    }
    return _RawMaterialAssignmentData(
      orders: orders,
      items: items,
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

  void _selectItem(SupplierItem item) {
    _selectedItemCode = item.code.trim();
    _itemCodeController.text = item.code.trim();
    _itemNameController.text = item.name.trim();
    _itemGroupController.text = item.itemGroup.trim();
  }

  Future<void> _scan() async {
    final barcode = await showRawMaterialScanDialog(context);
    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }
    setState(() {
      _barcodeController.text = barcode.trim();
    });
  }

  Future<void> _save() async {
    final orderId = _selectedOrderId.trim();
    final barcode = rawMaterialBarcodeFromQr(_barcodeController.text);
    final itemCode = _itemCodeController.text.trim();
    final itemName = _itemNameController.text.trim();
    final itemGroup = _itemGroupController.text.trim();
    if (orderId.isEmpty ||
        barcode.isEmpty ||
        itemCode.isEmpty ||
        itemName.isEmpty ||
        itemGroup.isEmpty ||
        _saving) {
      showAdminTopNotice(context, 'Zakaz, QR va homashyo ma’lumotini kiriting');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: orderId,
        barcode: barcode,
        itemCode: itemCode,
        itemName: itemName,
        itemGroup: itemGroup,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _barcodeController.text = barcode;
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
                items: data.items,
                selectedOrderId: _selectedOrderId,
                selectedItemCode: _selectedItemCode,
                barcodeController: _barcodeController,
                itemCodeController: _itemCodeController,
                itemNameController: _itemNameController,
                itemGroupController: _itemGroupController,
                saving: _saving,
                onOrderChanged: (value) {
                  setState(() => _selectedOrderId = value);
                },
                onItemChanged: (item) {
                  setState(() => _selectItem(item));
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
    required this.items,
    required this.assignments,
  });

  final List<ProductionMapSaved> orders;
  final List<SupplierItem> items;
  final List<AdminRawMaterialAssignment> assignments;
}

class _AssignmentEditor extends StatelessWidget {
  const _AssignmentEditor({
    required this.orders,
    required this.items,
    required this.selectedOrderId,
    required this.selectedItemCode,
    required this.barcodeController,
    required this.itemCodeController,
    required this.itemNameController,
    required this.itemGroupController,
    required this.saving,
    required this.onOrderChanged,
    required this.onItemChanged,
    required this.onScan,
    required this.onSave,
  });

  final List<ProductionMapSaved> orders;
  final List<SupplierItem> items;
  final String selectedOrderId;
  final String selectedItemCode;
  final TextEditingController barcodeController;
  final TextEditingController itemCodeController;
  final TextEditingController itemNameController;
  final TextEditingController itemGroupController;
  final bool saving;
  final ValueChanged<String> onOrderChanged;
  final ValueChanged<SupplierItem> onItemChanged;
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Homashyo QR / barcode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: saving ? null : onScan,
                  tooltip: 'QR skanerlash',
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedItemCode),
              initialValue: selectedItemCode.isEmpty ? null : selectedItemCode,
              decoration: const InputDecoration(
                labelText: 'Homashyo',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in items)
                  DropdownMenuItem(
                    value: item.code.trim(),
                    child: Text('${item.code.trim()} · ${item.name.trim()}'),
                  ),
              ],
              onChanged: saving || items.isEmpty
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      for (final item in items) {
                        if (item.code.trim() == value) {
                          onItemChanged(item);
                          return;
                        }
                      }
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: itemCodeController,
              decoration: const InputDecoration(
                labelText: 'Item code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item nomi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: itemGroupController,
              decoration: const InputDecoration(
                labelText: 'Item group',
                border: OutlineInputBorder(),
              ),
            ),
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
