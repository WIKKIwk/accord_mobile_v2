import 'dart:async';

import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/widgets/paddon_weight_totals.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/print_service.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'widgets/werka_dock.dart';
import '../../../core/localization/urdu_aware_text.dart';

class WerkaPaddonReceiveScreen extends StatefulWidget {
  const WerkaPaddonReceiveScreen(
      {super.key,
      this.initialCode,
      this.initialPreview,
      this.loadPreview,
      this.receive,
      this.loadApparatusNames});
  final String? initialCode;
  final WerkaPaddonPreview? initialPreview;
  final Future<WerkaPaddonPreview> Function(String)? loadPreview;
  final Future<Map<String, dynamic>> Function(WerkaPaddonPreview, String)?
      receive;
  final Future<Map<String, String>> Function()? loadApparatusNames;
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
  Map<String, String> _apparatusNames = const {};
  static final _apparatusIdPattern = RegExp(
    r'apparatus:[^\s,;•()\[\]{}]+',
    caseSensitive: false,
  );
  @override
  void initState() {
    super.initState();
    if (widget.loadApparatusNames != null) unawaited(_loadApparatusNames());
    if (widget.initialPreview != null) {
      _code = widget.initialCode ?? widget.initialPreview!.snapshot.paddon.code;
      _applyPreview(widget.initialPreview!);
    } else if (widget.initialCode != null) {
      _load(widget.initialCode!);
    }
  }

  Future<void> _loadApparatusNames() async {
    try {
      final names = widget.loadApparatusNames != null
          ? await widget.loadApparatusNames!()
          : const <String, String>{};
      if (!mounted) return;
      setState(() {
        _apparatusNames = {
          for (final entry in names.entries)
            if (entry.value.trim().isNotEmpty &&
                !_apparatusIdPattern.hasMatch(entry.value))
              entry.key.trim(): entry.value.trim(),
        };
      });
    } catch (_) {
      // Catalog access is optional; pallet actions use the original preview.
    }
  }

  String _displayLabel(String value) {
    final l10n = context.l10n;
    final unavailable = l10n.isUrdu
        ? 'مشین کا نام دستیاب نہیں'
        : l10n.isUzbek
            ? 'Apparat nomi mavjud emas'
            : l10n.isRussian
                ? 'Название аппарата недоступно'
                : 'Machine name unavailable';
    return value.replaceAllMapped(_apparatusIdPattern,
        (match) => _apparatusNames[match.group(0)!] ?? unavailable);
  }

  Future<void> _load(String raw) async {
    if (_busy) return;
    final code = raw.trim();
    if (code.isEmpty) {
      setState(() => _error = context.l10n.isUrdu
          ? 'QR کوڈ اسکین کریں یا درج کریں۔'
          : 'QR kodni skanerlang yoki kiriting.');
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
        _applyPreview(preview);
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

  void _applyPreview(WerkaPaddonPreview preview) {
    _preview = preview;
    _receipt = preview.receipt;
    _mustReload = false;
    _apparatusNames = {..._apparatusNames, ...preview.apparatusNames};
    _warehouse = preview.warehouses.contains(_warehouse)
        ? _warehouse
        : preview.warehouses.length == 1
            ? preview.warehouses.single
            : null;
  }

  String _message(Object error, {bool receiving = false}) {
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
    return receiving
        ? 'Server javobi olinmadi. Kirim bajarilgan bo‘lishi mumkin. Qayta tekshiring.'
        : 'Server javobi olinmadi. Qayta tekshiring.';
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

  double? _wipGrossKg(AdminProgressBatch batch) {
    final raw = batch.payloadJson['gross_qty'];
    final gross = (raw as num?)?.toDouble() ?? batch.finishedGoodsKg;
    if (gross == null || !gross.isFinite || gross <= 0) return null;
    return gross;
  }

  double? _wipNetKg(AdminProgressBatch batch) {
    final gross = _wipGrossKg(batch);
    final tare = batch.bobinaKg;
    if (gross == null) return null;
    if (tare == null || !tare.isFinite || tare < 0) return null;
    final net = gross - tare;
    if (!net.isFinite || net < 0) return null;
    return net;
  }

  String _wipGrossNetLabel(AdminProgressBatch batch) {
    final gross = _wipGrossKg(batch);
    final net = _wipNetKg(batch);
    final grossText = gross == null ? '—' : '${formatQuantity(gross)} kg';
    final netText = net == null ? '—' : '${formatQuantity(net)} kg';
    return 'Brutto: $grossText • Netto: $netText';
  }

  Future<void> _showWipReprint(AdminProgressBatch batch) async {
    final payload = batch.qrPayload.trim();
    if (payload.isEmpty) {
      return;
    }
    final orderId = batch.orderId.trim().isEmpty ? '—' : batch.orderId.trim();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RpsQrReprintSheet(
        title: 'WIP QR',
        payload: payload,
        itemName: 'Buyurtma: $orderId',
        previewKey: ValueKey('werka-paddon-wip-preview-${batch.batchId}'),
        reprintButtonKey: ValueKey('werka-paddon-wip-reprint-${batch.batchId}'),
        details: [
          RpsQrDetail('Buyurtma', orderId),
          RpsQrDetail('QR', payload),
          RpsQrDetail('Miqdor', _batchQuantity(batch)),
          RpsQrDetail('Brutto/Netto', _wipGrossNetLabel(batch)),
        ],
        onReprint: () => _reprintWip(batch),
        errorMessage: (error) => error is MobileApiException
            ? 'Qayta chop etib bo‘lmadi: ${error.code}'
            : 'Qayta chop etib bo‘lmadi. Qayta urining.',
        successMessage: 'WIP QR qayta chop etildi',
      ),
    );
  }

  Future<String?> _reprintWip(AdminProgressBatch batch) async {
    final printer = await pickProgressPrinter(context);
    if (printer == null) {
      throw StateError('Printer tanlanmadi yoki printer ulanmagan');
    }
    final prepared = await MobileApi.instance.adminProgressQrReprint(
      qrPayload: batch.qrPayload,
      progressBatchId: batch.batchId,
      driverUrl: printer.driverUrl,
      printer: printer.printer,
      printMode: printer.printMode,
      printTransport: printer.transport,
    );
    if (!prepared.ok) {
      final status = prepared.printStatus.trim();
      throw StateError(
        status.isEmpty ? 'Server WIP QR kodini chop etmadi' : status,
      );
    }
    if (printer.transport.isLocal) {
      final printJob = prepared.printJob;
      if (printJob == null) {
        throw StateError('WIP QR uchun local print ma’lumoti kelmadi');
      }
      final result = await PrintService.printRps(
        printJob,
        printerProfile: printer.offlinePrinter,
        bluetoothPrinter: printer.bluetoothPrinter,
        transport: printer.transport,
      );
      if (!result.ok) {
        throw StateError('Printer WIP QR kodini chop etmadi');
      }
    }
    return null;
  }

  Future<void> _accept() async {
    final preview = _preview;
    final warehouse = _warehouse;
    if (_busy ||
        _mustReload ||
        preview == null ||
        warehouse == null ||
        _receipt != null ||
        !preview.canReceive ||
        preview.snapshotToken.isEmpty) {
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
            '${preview.snapshot.paddon.code} paddonidagi ${preview.snapshot.items.length} ta rulon «${_displayLabel(warehouse)}» omboriga qabul qilinadi.',
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
          _error = _message(error, receiving: true);
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
    return PopScope(
      canPop: !_busy,
      child: AppShell(
          title: 'Paddon kirimi',
          subtitle: '',
          nativeTopBar: true,
          bottom: _busy
              ? null
              : const WerkaDock(activeTab: null, showPrimaryFab: false),
          child:
              ListView(padding: const EdgeInsets.only(bottom: 140), children: [
            if (_busy && !_confirming) const LinearProgressIndicator(),
            if (_error.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error,
                      key: const ValueKey('werka-paddon-error'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            if (preview == null) ...[
              ProductionQuickScannerPanel(
                  key: const ValueKey('werka-paddon-scanner'),
                  onCodeDetected: _load,
                  statusText: 'Paddon QR kodini skanerlang',
                  busy: _busy),
              if (_mustReload)
                TextButton(
                    onPressed: _busy ? null : () => _load(_code),
                    child: const UrduAwareText('Qayta tekshirish')),
            ] else ...[
              ListTile(
                  title:
                      UrduAwareText('Paddon ${preview.snapshot.paddon.code}'),
                  subtitle: UrduAwareText(
                      '${preview.snapshot.items.length} ta rulon • ${_displayLabel('${receipt?['warehouse'] ?? preview.snapshot.paddon.location}')}')),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PaddonWeightTotals(
                  key: const ValueKey('werka-paddon-weights'),
                  paddon: receipt?['paddon'] is Map
                      ? AdminPaddon.fromJson(
                          (receipt!['paddon'] as Map).cast<String, dynamic>())
                      : preview.snapshot.paddon,
                ),
              ),
              if (receipt != null)
                Card.filled(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const UrduAwareText('Omborga kirim qilingan',
                                  key: ValueKey('werka-paddon-received')),
                              UrduAwareText(
                                  'Ombor: ${_displayLabel('${receipt['warehouse']}')}'),
                              UrduAwareText(
                                  'Qabul qildi: ${receipt['accepted_by_display_name']}'),
                              if (receipt['accepted_at_unix'] is num)
                                UrduAwareText(
                                    'Vaqt: ${DateTime.fromMillisecondsSinceEpoch((receipt['accepted_at_unix'] as num).toInt() * 1000).toLocal()}'),
                            ])))
              else ...[
                if (!preview.canReceive)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: UrduAwareText(
                          'Kirim mumkin emas: paddon bo‘sh yoki tarkibida tayyor bo‘lmagan / qabul qilingan rulon bor.')),
                DropdownButtonFormField<String>(
                    key: ValueKey('werka-paddon-warehouse-$_warehouse'),
                    initialValue: _warehouse,
                    decoration: InputDecoration(
                        labelText: localizeUrduUiText('Qabul qiluvchi ombor')),
                    items: preview.warehouses
                        .map((w) => DropdownMenuItem(
                            value: w, child: Text(_displayLabel(w))))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _warehouse = value)),
              ],
              for (final batch in preview.snapshot.items)
                Card.filled(
                    child: ListTile(
                        key: ValueKey('werka-paddon-roll-${batch.batchId}'),
                        title: Text(_displayLabel(
                            batch.labelItemName.trim().isEmpty
                                ? batch.labelItemCode
                                : batch.labelItemName)),
                        subtitle: UrduAwareText(
                            'Buyurtma: ${batch.orderId}\nQR: ${batch.qrPayload}\n${_batchQuantity(batch)}\n${_wipGrossNetLabel(batch)}'),
                        isThreeLine: true,
                        onLongPress:
                            _busy ? null : () => _showWipReprint(batch))),
              if (receipt == null)
                FilledButton.icon(
                    key: const ValueKey('werka-paddon-receive'),
                    onPressed: _busy ||
                            _mustReload ||
                            !preview.canReceive ||
                            preview.snapshotToken.isEmpty ||
                            _warehouse == null
                        ? null
                        : _accept,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const UrduAwareText('Omborga kirim qilish')),
              TextButton(
                  onPressed: _busy ? null : () => _load(_code),
                  child: const UrduAwareText('Qayta tekshirish')),
              OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pushReplacementNamed(
                          AppRoutes.werkaStockEntryQrScan),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const UrduAwareText('Keyingi QR kodni skanerlash')),
            ],
          ])),
    );
  }
}
