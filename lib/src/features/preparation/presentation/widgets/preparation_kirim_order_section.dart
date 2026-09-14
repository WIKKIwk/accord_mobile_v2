import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/search/search_normalizer.dart';
import '../../../admin/presentation/widgets/admin_picker_field.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../../models/preparation_models.dart';

/// Tayyorlov kirim ekranidagi order field'i.
///
/// Order tanlanadi — kirim shu order kontekstida bo'ladi (chop etilgan
/// homashyo avtomatik shu orderga ulanadi). Ro'yxat backend filtrlab beradi
/// (faqat biriktirilgan homashyoli orderlar). QR skaner va alohida ulash
/// tugmasi yo'q.
class PreparationKirimOrderSection extends StatefulWidget {
  const PreparationKirimOrderSection({
    super.key,
    this.onOrderChanged,
  });

  final ValueChanged<PreparationOrder?>? onOrderChanged;

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
        final stillThere = _selectedOrderId != null &&
            _orders.any((order) => order.id == _selectedOrderId);
        if (!stillThere) {
          _selectedOrderId = null;
          widget.onOrderChanged?.call(null);
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

  PreparationOrder? get _selectedOrder {
    for (final order in _orders) {
      if (order.id == _selectedOrderId) {
        return order;
      }
    }
    return null;
  }

  /// Rulon eni diapazoni (backend qoidasi bilan bir xil):
  /// rulon >= order eni, ortiqcha: bosma +20 mm / laminatsiya +30 mm.
  /// Apparat operatsiyasi kirimda noma'lum — maksimal (+30) ko'rsatiladi,
  /// aniq tekshiruv ulashda backend'da bo'ladi.
  String? get _widthRangeText {
    final width = _selectedOrder?.widthMm;
    if (width == null || !width.isFinite || width <= 0) {
      return null;
    }
    String fmt(double value) => value == value.roundToDouble()
        ? '${value.round()}'
        : '$value';
    return 'Rulon eni: ${fmt(width)}–${fmt(width + 30)} mm '
        '(order eni ${fmt(width)} mm)';
  }

  Future<void> _openOrderPicker() async {
    if (_orders.isEmpty) {
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
        itemSubtitle: (order) => '${preparationDisplay(order.kg)} kg',
        onSelected: (order) => Navigator.of(sheetContext).pop(order),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedOrderId = picked.id);
    widget.onOrderChanged?.call(picked);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminOrderPickerField(
            key: const ValueKey('preparation-kirim-order-field'),
            labelText: 'Order',
            valueText: _selectedOrderLabel,
            emptyText: 'Buyurtma topilmadi',
            selectText: 'Order tanlang',
            hasOptions: _orders.isNotEmpty,
            onPick: _openOrderPicker,
          ),
          if (_widthRangeText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.straighten_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _widthRangeText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
