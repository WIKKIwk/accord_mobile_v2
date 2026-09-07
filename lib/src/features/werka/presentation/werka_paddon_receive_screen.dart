import 'package:flutter/material.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'widgets/werka_dock.dart';

class WerkaPaddonReceiveScreen extends StatefulWidget {
  const WerkaPaddonReceiveScreen(
      {super.key, this.initialCode, this.loadPreview, this.receive});
  final String? initialCode;
  final Future<WerkaPaddonPreview> Function(String)? loadPreview;
  final Future<Map<String, dynamic>> Function(WerkaPaddonPreview, String)?
      receive;
  @override
  State<WerkaPaddonReceiveScreen> createState() =>
      _WerkaPaddonReceiveScreenState();
}

class _WerkaPaddonReceiveScreenState extends State<WerkaPaddonReceiveScreen> {
  WerkaPaddonPreview? _preview;
  Map<String, dynamic>? _receipt;
  String? _warehouse;
  String _error = '', _code = '';
  bool _busy = false, _mustReload = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) _load(widget.initialCode!);
  }

  Future<void> _load(String raw) async {
    if (_busy) return;
    final code = raw.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      setState(() =>
          _error = 'Paddonning 5 xonali QR kodini skanerlang yoki kiriting.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _code = code;
    });
    try {
      final preview = await (widget.loadPreview ??
          MobileApi.instance.werkaPaddonPreview)(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _receipt = preview.receipt;
        _mustReload = false;
        _warehouse = preview.warehouses.contains(_warehouse)
            ? _warehouse
            : preview.warehouses.length == 1
                ? preview.warehouses.single
                : null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _mustReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'forbidden' =>
          'Bu amalga yoki omborga ruxsat yo‘q. Sizga ombor biriktirilganini tekshiring.',
        'paddon_not_found' => 'Paddon topilmadi. QR kodni tekshiring.',
        'paddon_receipt_conflict' =>
          'Paddon tarkibi yoki rulon ma’lumoti o‘zgargan. Qayta tekshiring.',
        'paddon_already_received' =>
          'Paddon avval kirim qilingan. Qayta tekshiring.',
        'progress_batch_not_accepted' =>
          'Paddonda kirimga tayyor bo‘lmagan yoki avval qabul qilingan rulon bor.',
        'paddon_invalid_input' =>
          'Paddon bo‘sh yoki kirim ma’lumotlari yetarli emas.',
        _ => 'Kirimni tekshirib bo‘lmadi. Qayta tekshiring.',
      };
    }
    return 'Server javobi olinmadi. Kirim bajarilgan bo‘lishi mumkin — qayta tekshiring.';
  }

  String _batchQuantity(AdminProgressBatch batch) {
    final kg = batch.finishedGoodsKg ?? 0;
    final meters = batch.finishedGoodsMeter ?? 0;
    if (kg > 0) {
      return '${formatQuantity(kg)} kg${meters > 0 ? ' • ${formatQuantity(meters)} m' : ''}';
    }
    if (meters > 0) return '${formatQuantity(meters)} m';
    return '${formatQuantity(batch.producedQty)} ${batch.uom}';
  }

  Future<void> _accept() async {
    final preview = _preview;
    final warehouse = _warehouse;
    if (_busy ||
        _mustReload ||
        preview == null ||
        warehouse == null ||
        _receipt != null ||
        !preview.canReceive) {
      return;
    }
    setState(() {
      _busy = true;
      _confirming = true;
    });
    final confirmed = await showM3ConfirmDialog(
        context: context,
        title: 'Paddonni kirim qilish',
        message:
            '${preview.snapshot.paddon.code} paddonidagi ${preview.snapshot.items.length} ta rulon «$warehouse» omboriga qabul qilinadi.',
        cancelLabel: 'Bekor qilish',
        confirmLabel: 'Kirim qilish',
        confirmButtonKey: const ValueKey('werka-paddon-confirm'));
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _busy = confirmed == true;
    });
    if (confirmed != true) return;
    try {
      final receipt = await (widget.receive ??
          MobileApi.instance.werkaReceivePaddon)(preview, warehouse);
      if (mounted) {
        setState(() {
          _receipt = receipt;
          _error = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _mustReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final receipt = _receipt;
    return AppShell(
        title: 'Paddon kirimi',
        subtitle: '',
        nativeTopBar: true,
        bottom: const WerkaDock(activeTab: null, showPrimaryFab: false),
        child: ListView(padding: const EdgeInsets.only(bottom: 140), children: [
          if (_busy && !_confirming) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error,
                    key: const ValueKey('werka-paddon-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (preview == null) ...[
            ProductionQuickScannerPanel(
                key: const ValueKey('werka-paddon-scanner'),
                onCodeDetected: _load,
                statusText: 'Paddon QR kodini skanerlang',
                busy: _busy),
            if (_mustReload)
              TextButton(
                  onPressed: _busy ? null : () => _load(_code),
                  child: const Text('Qayta tekshirish')),
          ] else ...[
            ListTile(
                title: Text('Paddon ${preview.snapshot.paddon.code}'),
                subtitle: Text(
                    '${preview.snapshot.items.length} ta rulon • ${receipt?['warehouse'] ?? preview.snapshot.paddon.location}')),
            if (receipt != null)
              Card.filled(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Omborga kirim qilingan',
                                key: ValueKey('werka-paddon-received')),
                            Text('Ombor: ${receipt['warehouse']}'),
                            Text(
                                'Qabul qildi: ${receipt['accepted_by_display_name']}'),
                            if (receipt['accepted_at_unix'] is num)
                              Text(
                                  'Vaqt: ${DateTime.fromMillisecondsSinceEpoch((receipt['accepted_at_unix'] as num).toInt() * 1000).toLocal()}'),
                          ])))
            else ...[
              if (!preview.canReceive)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                        'Kirim mumkin emas: paddon bo‘sh yoki tarkibida tayyor bo‘lmagan / qabul qilingan rulon bor.')),
              DropdownButtonFormField<String>(
                  key: ValueKey('werka-paddon-warehouse-$_warehouse'),
                  initialValue: _warehouse,
                  decoration:
                      const InputDecoration(labelText: 'Qabul qiluvchi ombor'),
                  items: preview.warehouses
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _warehouse = value)),
            ],
            for (final batch in preview.snapshot.items)
              Card.filled(
                  child: ListTile(
                      key: ValueKey('werka-paddon-roll-${batch.batchId}'),
                      title: Text(batch.labelItemName.isEmpty
                          ? batch.labelItemCode
                          : batch.labelItemName),
                      subtitle: Text(
                          'Buyurtma: ${batch.orderId}\nQR: ${batch.qrPayload}\n${_batchQuantity(batch)}'),
                      isThreeLine: true)),
            if (receipt == null)
              FilledButton.icon(
                  key: const ValueKey('werka-paddon-receive'),
                  onPressed: _busy ||
                          _mustReload ||
                          !preview.canReceive ||
                          _warehouse == null
                      ? null
                      : _accept,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Omborga kirim qilish')),
            TextButton(
                onPressed: _busy ? null : () => _load(_code),
                child: const Text('Qayta tekshirish')),
            OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _preview = null;
                          _receipt = null;
                          _error = '';
                          _mustReload = false;
                          _code = '';
                        }),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Keyingi paddonni skanerlash')),
          ],
        ]));
  }
}
