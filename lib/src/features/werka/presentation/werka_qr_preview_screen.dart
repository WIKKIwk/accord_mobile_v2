import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'werka_paddon_receive_screen.dart';
import 'widgets/werka_dock.dart';

/// Opening a QR result only displays the server's preview. Receiving always
/// requires a separate action and confirmation against that exact snapshot.
class WerkaQrPreviewScreen extends StatelessWidget {
  const WerkaQrPreviewScreen({super.key, required this.preview});
  final WerkaQrPreview preview;

  @override
  Widget build(BuildContext context) {
    final paddon = preview.paddon;
    if (paddon != null) {
      return WerkaPaddonReceiveScreen(
        initialCode: paddon.snapshot.paddon.code,
        initialPreview: paddon,
        loadPreview: (code) async {
          final fresh = await MobileApi.instance.werkaQrPreview(code);
          if (fresh.paddon == null) {
            throw const MobileApiException(
                code: 'qr_preview_invalid', message: 'Paddon topilmadi');
          }
          return fresh.paddon!;
        },
      );
    }
    return WerkaWipPreviewScreen(
        code: preview.code, initialPreview: preview.wip!);
  }
}

class WerkaWipPreviewScreen extends StatefulWidget {
  const WerkaWipPreviewScreen({
    super.key,
    required this.code,
    required this.initialPreview,
    this.loadPreview,
    this.receive,
  });
  final String code;
  final WerkaWipPreview initialPreview;
  final Future<WerkaQrPreview> Function(String)? loadPreview;
  final Future<Map<String, dynamic>> Function(WerkaWipPreview, String)? receive;

  @override
  State<WerkaWipPreviewScreen> createState() => _WerkaWipPreviewScreenState();
}

class _WerkaWipPreviewScreenState extends State<WerkaWipPreviewScreen> {
  late WerkaWipPreview _preview = widget.initialPreview;
  late Map<String, dynamic>? _receipt = _preview.receipt;
  late String? _warehouse =
      _preview.warehouses.length == 1 ? _preview.warehouses.single : null;
  bool _busy = false, _confirming = false, _mustReload = false;
  String _error = '';

  bool get _canReceive =>
      !_busy &&
      !_mustReload &&
      _receipt == null &&
      _preview.canReceive &&
      _preview.snapshotToken.isNotEmpty &&
      _preview.batch.batchId.isNotEmpty &&
      _preview.batch.qrPayload.isNotEmpty &&
      _warehouse != null;

  String _label(String value) => value.replaceAllMapped(
        RegExp(r'apparatus:[^\s,;•()\[\]{}]+', caseSensitive: false),
        (match) =>
            _preview.apparatusNames[match.group(0)!] ??
            'Apparat nomi mavjud emas',
      );

  String _message(Object error, {bool receiving = false}) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'forbidden' => 'Bu amalga yoki omborga ruxsat yo‘q.',
        'wip_receipt_conflict' ||
        'progress_batch_revision_conflict' =>
          'WIP ma’lumoti o‘zgargan. Qayta tekshiring.',
        'progress_batch_not_accepted' =>
          'WIP kirimga tayyor emas yoki avval ishlatilgan. Qayta tekshiring.',
        'wip_already_received' => 'WIP avval kirim qilingan. Qayta tekshiring.',
        'qr_not_found' ||
        'progress_batch_not_found' ||
        'progress_qr_invalid' =>
          'WIP topilmadi yoki QR kodi noto‘g‘ri.',
        _ => receiving
            ? 'Kirim natijasi tasdiqlanmadi. Qayta tekshiring.'
            : 'WIP ma’lumotini olib bo‘lmadi. Qayta tekshiring.',
      };
    }
    return receiving
        ? 'Server javobi olinmadi. Kirim bajarilgan bo‘lishi mumkin. Qayta tekshiring.'
        : 'Server javobi olinmadi. Qayta tekshiring.';
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await (widget.loadPreview ??
          MobileApi.instance.werkaQrPreview)(widget.code);
      final fresh = result.wip;
      if (fresh == null || fresh.batch.batchId != _preview.batch.batchId) {
        throw const MobileApiException(
            code: 'qr_preview_invalid', message: 'WIP identity changed');
      }
      if (!mounted) return;
      setState(() {
        _preview = fresh;
        _receipt = fresh.receipt;
        _mustReload = false;
        _warehouse = fresh.warehouses.contains(_warehouse)
            ? _warehouse
            : fresh.warehouses.length == 1
                ? fresh.warehouses.single
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

  Future<void> _accept() async {
    if (!_canReceive) return;
    final preview = _preview;
    final warehouse = _warehouse!;
    setState(() {
      _busy = true;
      _confirming = true;
    });
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'WIPni kirim qilish',
      message:
          '${_label(preview.batch.labelItemName)} WIP «${_label(warehouse)}» '
          'omboriga qabul qilinadi.',
      cancelLabel: 'Bekor qilish',
      confirmLabel: 'Kirim qilish',
      confirmButtonKey: const ValueKey('werka-wip-confirm'),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _busy = confirmed == true;
    });
    if (confirmed != true) return;
    try {
      final receipt = await (widget.receive ??
          MobileApi.instance.werkaReceiveWip)(preview, warehouse);
      if (mounted) {
        setState(() {
          _receipt = receipt;
          _error = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error, receiving: true);
          // A timeout can mean the write committed. Never retry the write
          // automatically; resolve the server's current receipt first.
          _mustReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _status {
    if (_receipt != null) return 'Omborga kirim qilingan';
    final reason = switch (_preview.receiveBlockedReason) {
      'paddon_item_already_assigned' =>
        'WIP ${_preview.paddonCode} paddoniga biriktirilgan. Paddon QR orqali kirim qiling.',
      'order_not_active' => 'Buyurtma faol emas. Kirim mumkin emas.',
      'apparatus_inactive' => 'Apparat faol emas. Kirim mumkin emas.',
      'wip_location_mismatch' => 'WIP joylashuvi o‘zgargan. Kirim mumkin emas.',
      'already_received' => 'WIP avval kirim qilingan.',
      _ => '',
    };
    if (reason.isNotEmpty) return reason;
    return switch (_preview.batch.wipStatus) {
      'in_use' => 'WIP hozir ishlatilmoqda. Kirim mumkin emas.',
      'processed' => 'WIP avval ishlatilgan. Kirim mumkin emas.',
      _ => _preview.canReceive
          ? 'Kirimga tayyor'
          : 'Bu WIP hozir omborga kirim qilish uchun tayyor emas.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final batch = _preview.batch;
    final receipt = _receipt;
    final quantities = [
      if (batch.finishedGoodsKg != null)
        '${formatQuantity(batch.finishedGoodsKg!, decimalPlaces: 6, trimTrailingZeros: true)} kg',
      if (batch.finishedGoodsMeter != null)
        '${formatQuantity(batch.finishedGoodsMeter!, decimalPlaces: 6, trimTrailingZeros: true)} m',
    ];
    return PopScope(
      key: const ValueKey('werka-wip-pop-guard'),
      canPop: !_busy,
      child: AppShell(
        title: 'WIP ma’lumoti',
        subtitle: '',
        nativeTopBar: true,
        bottom: _busy
            ? null
            : const WerkaDock(activeTab: null, showPrimaryFab: false),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 140),
          children: [
            if (_busy && !_confirming) const LinearProgressIndicator(),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error,
                    key: const ValueKey('werka-wip-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _label(batch.labelItemName.isEmpty
                            ? batch.labelItemCode
                            : batch.labelItemName),
                        key: const ValueKey('werka-wip-product'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('WIP: ${batch.batchId}'),
                    Text('Buyurtma: ${batch.orderId}'),
                    Text('QR: ${batch.qrPayload}'),
                    Text(quantities.isEmpty
                        ? '${formatQuantity(batch.producedQty, decimalPlaces: 6, trimTrailingZeros: true)} ${batch.uom}'
                        : quantities.join(' • ')),
                    Text(
                        'Joylashuv: ${_label(receipt?['warehouse']?.toString() ?? batch.currentLocation)}'),
                    if (batch.workerDisplayName.isNotEmpty)
                      Text('Ishchi: ${batch.workerDisplayName}'),
                    if (batch.description.isNotEmpty) Text(batch.description),
                    const SizedBox(height: 8),
                    Text(_status, key: const ValueKey('werka-wip-status')),
                  ],
                ),
              ),
            ),
            if (receipt != null)
              Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Omborga kirim qilingan',
                          key: ValueKey('werka-wip-received')),
                      Text('Ombor: ${_label('${receipt['warehouse'] ?? ''}')}'),
                      Text(
                          'Qabul qildi: ${receipt['accepted_by_display_name'] ?? ''}'),
                      if (receipt['accepted_at_unix'] is num)
                        Text(
                            'Vaqt: ${DateTime.fromMillisecondsSinceEpoch((receipt['accepted_at_unix'] as num).toInt() * 1000).toLocal()}'),
                    ],
                  ),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('werka-wip-warehouse-$_warehouse'),
                initialValue: _warehouse,
                decoration:
                    const InputDecoration(labelText: 'Qabul qiluvchi ombor'),
                items: _preview.warehouses
                    .map((w) =>
                        DropdownMenuItem(value: w, child: Text(_label(w))))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _warehouse = value),
              ),
              FilledButton.icon(
                key: const ValueKey('werka-wip-receive'),
                onPressed: _canReceive ? _accept : null,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Omborga kirim qilish'),
              ),
            ],
            TextButton(
              key: const ValueKey('werka-wip-reload'),
              onPressed: _busy ? null : _reload,
              child: const Text('Qayta tekshirish'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.werkaStockEntryQrScan),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Keyingi QR kodni skanerlash'),
            ),
          ],
        ),
      ),
    );
  }
}
