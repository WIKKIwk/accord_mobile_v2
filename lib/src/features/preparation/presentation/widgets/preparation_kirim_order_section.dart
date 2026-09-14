import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/search/search_normalizer.dart';
import '../../../admin/presentation/raw_material_scan_dialog.dart';
import '../../../admin/presentation/widgets/admin_picker_field.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../../models/preparation_models.dart';

/// Tayyorlov kirim ekranidagi order tanlash + homashyo ulash qatori.
///
/// Order ro'yxati backend filtrlab beradi (faqat biriktirilgan homashyoli
/// orderlar). Uлаш esa material ta'minotchiniki bilan bir xil API:
/// tanlangan order + barcode.
class PreparationKirimOrderSection extends StatefulWidget {
  const PreparationKirimOrderSection({super.key});

  @override
  State<PreparationKirimOrderSection> createState() =>
      _PreparationKirimOrderSectionState();
}

class _PreparationKirimOrderSectionState
    extends State<PreparationKirimOrderSection> {
  List<PreparationOrder> _orders = const [];
  String? _selectedOrderId;
  bool _loadingOrders = true;
  Object? _ordersError;
  final _barcodeController = TextEditingController();
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _loadingOrders = true;
        _ordersError = null;
      });
    }
    try {
      final snapshot = await MobileApi.instance.preparationSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = snapshot.orders
            .where((order) => !order.saved)
            .toList(growable: false);
        if (_selectedOrderId != null &&
            _orders.every((order) => order.id != _selectedOrderId)) {
          _selectedOrderId = null;
        }
        _loadingOrders = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingOrders = false;
          _ordersError = e;
        });
      }
    }
  }

  String _orderLabel(PreparationOrder order) {
    final code = order.code.trim().isEmpty ? order.id : order.code;
    final title = order.title.trim();
    return title.isEmpty ? code : '$code — $title';
  }

  String get _selectedOrderLabel {
    for (final order in _orders) {
      if (order.id == _selectedOrderId) {
        return _orderLabel(order);
      }
    }
    return _selectedOrderId ?? '';
  }

  Future<void> _openOrderPicker() async {
    if (_linking || _orders.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<PreparationOrder>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (sheetContext) => M3AsyncPickerSheet<PreparationOrder>(
        title: 'Order tanlang',
        hintText: 'Qidirish',
        pageSize: 50,
        loadPage: (query, offset, limit) async {
          final normalizedQuery = query.trim().toLowerCase();
          final filtered = normalizedQuery.isEmpty
              ? _orders
              : _orders
                  .where((order) => searchMatches(normalizedQuery, [
                        order.id,
                        order.code,
                        order.title,
                        _orderLabel(order),
                      ]))
                  .toList(growable: false);
          return filtered.skip(offset).take(limit).toList(growable: false);
        },
        itemTitle: _orderLabel,
        itemSubtitle: (order) =>
            '${preparationDisplay(order.kg)} kg',
        onSelected: (order) => Navigator.of(sheetContext).pop(order),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedOrderId = picked.id);
  }

  Future<void> _scanBarcode() async {
    final barcode = await showRawMaterialScanDialog(context);
    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }
    setState(
      () => _barcodeController.text = rawMaterialBarcodeFromQr(barcode),
    );
  }

  Future<void> _linkToOrder() async {
    final orderId = _selectedOrderId?.trim() ?? '';
    final barcode = _barcodeController.text.trim();
    if (orderId.isEmpty || barcode.isEmpty || _linking) {
      return;
    }
    setState(() => _linking = true);
    try {
      await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: orderId,
        barcode: barcode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _linking = false;
        _barcodeController.clear();
      });
      await _loadOrders();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homashyo orderga ulandi')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _linking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_loadingOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_ordersError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Orderlar yuklanmadi: $_ordersError',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Yangilash',
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }
    final canLink = _selectedOrderId != null &&
        _barcodeController.text.trim().isNotEmpty &&
        !_linking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AdminOrderPickerField(
            key: const ValueKey('preparation-kirim-order-field'),
            labelText: 'Order',
            valueText: _selectedOrderLabel,
            emptyText: 'Buyurtma topilmadi',
            selectText: 'Order tanlang',
            hasOptions: _orders.isNotEmpty,
            disabled: _linking,
            onPick: _openOrderPicker,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('preparation-kirim-barcode'),
                  controller: _barcodeController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Homashyo shtrix-kodi',
                    prefixIcon:
                        Icon(Icons.qr_code_scanner_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Skanerlash',
                onPressed: _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey('preparation-kirim-link'),
            onPressed: canLink ? _linkToOrder : null,
            icon: _linking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: Text(
                _linking ? 'Ulanmoqda…' : 'Orderga ulash'),
          ),
        ),
      ],
    );
  }
}
