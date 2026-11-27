import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../gscale/gscale_mobile_app.dart' show showPrintDevicePicker;
import 'waste_bin_configuration_dialog.dart';
import 'waste_bin_details.dart';
import 'waste_navigation.dart';
import 'waste_warehouses_screen.dart';
import 'waste_weigh_dialog.dart';

class WasteReceivingScreen extends StatefulWidget {
  const WasteReceivingScreen({super.key});

  @override
  State<WasteReceivingScreen> createState() => _WasteReceivingScreenState();
}

class _WasteReceivingScreenState extends State<WasteReceivingScreen> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  List<WasteBin> _bins = const [];
  WasteBin? _selected;
  ({WasteBinFormResult values, String requestId})? _registrationAttempt;
  String? _scannedCycleId;
  bool _busy = false;
  String? _error;

  bool get _current => mounted && currentSessionReadScope() == _scope;

  @override
  void initState() {
    super.initState();
    _run(_refresh);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (_current) setState(() => _error = wasteErrorText(error));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final bins = await _api.wasteBins();
    if (!_current) return;
    setState(() => _bins = bins);
  }

  Future<void> _open(String code, {bool scanned = false}) => _run(() async {
        final bin = await _api.wasteBinDetail(code);
        if (!_current) return;
        setState(() {
          _selected = bin;
          _scannedCycleId = scanned ? bin.cycle?.id : null;
        });
      });

  Future<String?> _scanCode() => showRawMaterialScanDialog(
        context,
        title: 'Chiqindi qutisini skan qiling',
        manualLabel: 'Quti kodi',
        acceptCameraCode: isWasteBinQr,
      );

  Future<void> _scan() async {
    final value = await _scanCode();
    if (_current && value != null) await _open(value, scanned: true);
  }

  Future<bool> _scanMatching(WasteBin expected) async {
    final value = await _scanCode();
    if (!_current || value == null) return false;
    var matches = false;
    await _run(() async {
      final code = wasteBinCode(value);
      if (code != expected.code) {
        throw FormatException('${expected.code} qutisini skan qiling.');
      }
      final bin = await _api.wasteBinDetail(code);
      if (!_current) return;
      setState(() {
        _selected = bin;
        _scannedCycleId = bin.cycle?.id;
      });
      if (bin.cycle?.id != expected.cycle?.id ||
          bin.status != expected.status) {
        throw const FormatException('Quti holati o‘zgargan.');
      }
      matches = true;
    });
    return matches;
  }

  Future<void> _editBin([WasteBin? existing]) async {
    WasteBinOptions? options;
    await _run(() async => options = await _api.wasteBinOptions());
    final available = options;
    if (!mounted || !_current || available == null) return;
    final values = await showDialog<WasteBinFormResult>(
      context: context,
      builder: (_) => WasteBinConfigurationDialog(
        options: available,
        bin: existing,
      ),
    );
    if (!_current || values == null) return;
    WasteBin? saved;
    await _run(() async {
      final bin = existing == null
          ? await _registerBin(values)
          : await _api.configureWasteBin(
              code: existing.code,
              configuration: values.configuration,
            );
      if (!_current) return;
      saved = bin;
      setState(() => _selected = bin);
      await _refresh();
    });
    final bin = saved;
    if (_current && existing == null && bin != null) await _showQr(bin);
  }

  Future<WasteBin> _registerBin(WasteBinFormResult values) async {
    final attempt = _registrationAttempt;
    if (attempt == null || !values.sameRegistrationAs(attempt.values)) {
      _registrationAttempt = (values: values, requestId: newWasteRequestId());
    }
    final bin = await _api.registerWasteBin(
      requestId: _registrationAttempt!.requestId,
      tareKg: values.tareKg,
      toleranceKg: values.toleranceKg,
      configuration: values.configuration,
    );
    _registrationAttempt = null;
    return bin;
  }

  Future<void> _showQr(WasteBin bin) {
    var printing = false;
    bool? printed;
    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, update) => PopScope(
          canPop: !printing,
          child: AlertDialog(
            title: Text(bin.label),
            scrollable: true,
            insetPadding: m3DialogInsetPadding,
            constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
            content: SizedBox(
              width: m3DialogMaxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 200,
                    child: QrImageView(
                      data: bin.qrPayload,
                      padding: const EdgeInsets.all(12),
                      backgroundColor: Colors.white,
                    ),
                  ),
                  if (printed case final success?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(success
                          ? 'QR yorlig‘i printerga yuborildi'
                          : 'QR yorlig‘ini chop etib bo‘lmadi'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: printing ? null : () => Navigator.pop(dialogContext),
                child: const Text('Yopish'),
              ),
              TextButton.icon(
                onPressed: printing ? null : () => _shareQr(dialogContext, bin),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Ulashish'),
              ),
              FilledButton.icon(
                onPressed: printing
                    ? null
                    : () async {
                        if (printing || !_current) return;
                        update(() {
                          printing = true;
                          printed = null;
                        });
                        final result = await _printQr(dialogContext, bin);
                        if (!dialogContext.mounted) return;
                        update(() {
                          printing = false;
                          printed = result;
                        });
                      },
                icon: const Icon(Icons.print_outlined),
                label: Text(printing ? 'Chop etilmoqda…' : 'Chop etish'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _printQr(BuildContext dialogContext, WasteBin bin) async {
    try {
      final selection =
          await showPrintDevicePicker(dialogContext, bluetoothOnly: true);
      final printer = selection?.bluetoothPrinter;
      if (selection == null ||
          printer == null ||
          !dialogContext.mounted ||
          !_current) {
        return null;
      }
      final result = await PrintService.printRps(
        UsbRpsPrintRequest(
          epc: bin.qrPayload,
          itemCode: bin.code,
          itemName: bin.name,
          warehouse: '',
          printer: printer.printer,
          printMode: printer.printMode,
          grossQty: 1,
          unit: 'dona',
          labelKind: 'waste_bin',
        ),
        bluetoothPrinter: printer,
        transport: selection.transport,
        bluetoothQrCode: true,
      );
      return result.ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _shareQr(BuildContext dialogContext, WasteBin bin) async {
    // Capture the popover anchor before preparing the PDF on iPad.
    final box = dialogContext.findRenderObject() as RenderBox?;
    final anchor = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final font = pw.Font.ttf(await rootBundle
          .load('assets/fonts/google_sans/GoogleSans-Regular.ttf'));
      final arabic = pw.Font.ttf(await rootBundle
          .load('assets/fonts/noto_naskh_arabic/NotoNaskhArabic.ttf'));
      final label = pw.Document(
        theme: pw.ThemeData.withFont(base: font, fontFallback: [arabic]),
      );
      label.addPage(pw.Page(
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('Chiqindi qutisi'),
              pw.SizedBox(height: 12),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: bin.qrPayload,
                width: 140,
                height: 140,
              ),
              pw.SizedBox(height: 12),
              if (bin.name != bin.code) pw.Text(bin.name),
              pw.Text(bin.code),
            ],
          ),
        ),
      ));
      final data = await label.save();
      if (!dialogContext.mounted || !_current) return;
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(data,
              name: '${bin.code}.pdf', mimeType: 'application/pdf')
        ],
        fileNameOverrides: ['${bin.code}.pdf'],
        sharePositionOrigin: anchor,
      ));
    } catch (_) {
      if (!dialogContext.mounted) return;
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('QR yorlig‘ini ulashib bo‘lmadi')),
      );
    }
  }

  Future<void> _receive(WasteBin bin) async {
    if (_scannedCycleId != bin.cycle?.id && !await _scanMatching(bin)) return;
    final scanned = _selected;
    if (!_current || scanned == null || !scanned.canBeReceived) return;
    final warehouses = await _loadWarehouses();
    if (!mounted || !_current || warehouses == null) return;
    final result = await showDialog<WasteMeasurement>(
      context: context,
      builder: (_) => WasteWeighDialog(bin: scanned, warehouses: warehouses),
    );
    if (!_current || result == null) return;
    await _run(() async {
      final WasteBin updated;
      try {
        updated = await _api.receiveWasteBin(
          bin: scanned,
          warehouseId: result.warehouseId,
          grossKg: result.grossKg,
          source: result.source,
          note: result.note,
        );
      } on MobileApiException catch (error) {
        if (_current && error.code == 'waste_expected_weight_changed') {
          final current = await _api.wasteBinDetail(scanned.code);
          if (_current) setState(() => _selected = current);
        }
        rethrow;
      }
      if (!_current) return;
      setState(() => _selected = updated);
      await _refresh();
    });
  }

  Future<List<WasteWarehouse>?> _loadWarehouses() async {
    List<WasteWarehouse>? warehouses;
    await _run(() async {
      final available = await _api.wasteWarehouses();
      if (available.isEmpty) {
        throw const FormatException(wasteNoWarehouseMessage);
      }
      warehouses = available;
    });
    return warehouses;
  }

  Future<void> _assignDestination(WasteBin bin) async {
    if (_scannedCycleId != bin.cycle?.id && !await _scanMatching(bin)) return;
    final warehouses = await _loadWarehouses();
    if (!mounted || !_current || warehouses == null) return;
    final warehouseId = await showDialog<String>(
      context: context,
      builder: (context) => _WasteDestinationDialog(warehouses: warehouses),
    );
    if (!_current || warehouseId == null) return;
    await _run(() async {
      final updated = await _api.assignWasteReceiptDestination(
        bin: bin,
        warehouseId: warehouseId,
      );
      if (!_current) return;
      setState(() => _selected = updated);
      await _refresh();
    });
  }

  Future<void> _reset(WasteBin bin) async {
    if (!await _scanMatching(bin) || !mounted || !_current) return;
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: '${bin.label} qutisi bo‘shatildimi?',
      message:
          'Qutini bo‘shatganingizdan keyin tasdiqlang. Yopilgan partiya tarixda saqlanadi.',
      cancelLabel: 'Bekor qilish',
      confirmLabel: 'Bo‘sh deb belgilash',
      verticalActions: true,
    );
    if (!_current || confirmed != true) return;
    await _run(() async {
      final updated = await _api.resetWasteBin(bin);
      if (!_current) return;
      setState(() => _selected = updated);
      await _refresh();
    });
  }

  Future<void> _showHistory(WasteBin bin) async {
    List<WasteCycle>? cycles;
    await _run(() async => cycles = await _api.wasteBinHistory(bin.code));
    final history = cycles;
    if (!mounted || !_current || history == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (historyContext) => AppShell(
        title: '${bin.label} tarixi',
        subtitle: '',
        nativeTopBar: true,
        child: history.isEmpty
            ? const Center(child: Text('Quti tarixi bo‘sh'))
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final cycle in history)
                    AppSegmentSurfaceCard(
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.of(historyContext).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _WasteHistoryDetail(
                            code: bin.code,
                            label: bin.label,
                            cycleId: cycle.id,
                          ),
                        ),
                      ),
                      child: ListTile(
                        title: Text(cycle.apparatusName.isEmpty
                            ? cycle.apparatusId
                            : cycle.apparatusName),
                        subtitle:
                            Text(wasteWhen(historyContext, cycle.openedAt)),
                        trailing: Text(wasteKgLabel(cycle.expectedKg)),
                      ),
                    ),
                ],
              ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bin = _selected;
    final cycle = bin?.cycle;
    final visible = [..._bins]..sort((a, b) {
        const ranks = {
          WasteBinStatus.sealed: 0,
          WasteBinStatus.received: 1,
          WasteBinStatus.open: 2,
          WasteBinStatus.empty: 3,
          WasteBinStatus.reset: 4,
        };
        final status = ranks[a.status]!.compareTo(ranks[b.status]!);
        return status == 0 ? a.label.compareTo(b.label) : status;
      });
    return AppShell(
      title: 'Chiqindi qabul qilish',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: const WasteDrawer(activeTab: WasteDockTab.receive),
      bottom: const WasteDock(activeTab: WasteDockTab.receive),
      appBarBottomLoading: _busy,
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          onPressed: _busy ? null : () => _run(_refresh),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 16),
        children: [
          AppSegmentSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _scan,
                  style: appFilledActionButtonStyle(),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Qutini skan qilish'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _editBin,
                  style: appOutlinedActionButtonStyle(),
                  icon: const Icon(Icons.add),
                  label: const Text('Yangi quti'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppSegmentSurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(_error!),
              ),
            ),
          ],
          if (bin != null) ...[
            const SizedBox(height: 12),
            AppSegmentSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(bin.label,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '${wasteStatusLabel(bin.status)} · Tara ${wasteKgLabel(bin.tareKg)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(bin.configured
                      ? '${bin.apparatusIds.length} ta apparat'
                      : 'Apparat biriktirilmagan'),
                  const SizedBox(height: 12),
                  if (bin.canBeReceived)
                    FilledButton(
                      onPressed: _busy ? null : () => _receive(bin),
                      style: appFilledActionButtonStyle(),
                      child: const Text('Tortish va qabul qilish'),
                    ),
                  if (cycle != null && bin.status == WasteBinStatus.received)
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : cycle.receipt?.warehouseId == null
                              ? () => _assignDestination(bin)
                              : () => _reset(bin),
                      style: appFilledActionButtonStyle(),
                      child: Text(cycle.receipt?.warehouseId == null
                          ? 'Qabul omborini belgilash'
                          : 'Qutini bo‘shatish'),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (bin.status == WasteBinStatus.empty)
                        TextButton.icon(
                          onPressed: _busy ? null : () => _editBin(bin),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Qutini sozlash'),
                        ),
                      TextButton.icon(
                        onPressed: _busy ? null : () => _showQr(bin),
                        icon: const Icon(Icons.qr_code_rounded),
                        label: const Text('QR'),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : () => _showHistory(bin),
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Tarix'),
                      ),
                    ],
                  ),
                  if (cycle != null) WasteCycleDetails(cycle: cycle),
                ],
              ),
            ),
          ],
          if (!_busy && visible.isEmpty) ...[
            const SizedBox(height: 12),
            const AppSegmentSurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(title: Text('Chiqindi qutilari yo‘q')),
            ),
          ],
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 8),
            M3SegmentSpacedColumn(
              children: [
                for (final (index, item) in visible.indexed)
                  Semantics(
                    key: ValueKey(item.code),
                    selected: item.code == bin?.code,
                    child: AdminCatalogListRow(
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index,
                        visible.length,
                      ),
                      icon: Icons.inventory_2_outlined,
                      title: item.label,
                      titleMaxLines: 2,
                      subtitle: [
                        wasteStatusLabel(item.status),
                        if (!item.configured &&
                            item.status == WasteBinStatus.empty)
                          'Biriktirilmagan',
                        if (item.cycle?.apparatusName case final name?
                            when name.isNotEmpty)
                          name,
                      ].join(' · '),
                      subtitleMaxLines: 2,
                      value: item.cycle == null
                          ? ''
                          : wasteKgLabel(item.cycle!.expectedKg),
                      backgroundColor: item.code == bin?.code
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      onTap: _busy ? null : () => _open(item.code),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WasteHistoryDetail extends StatefulWidget {
  const _WasteHistoryDetail({
    required this.code,
    required this.label,
    required this.cycleId,
  });

  final String code, label, cycleId;

  @override
  State<_WasteHistoryDetail> createState() => _WasteHistoryDetailState();
}

class _WasteHistoryDetailState extends State<_WasteHistoryDetail> {
  late final _cycle =
      MobileApi.instance.wasteBinDetail(widget.code, cycleId: widget.cycleId);

  @override
  Widget build(BuildContext context) => AppShell(
        title: widget.label,
        subtitle: '',
        nativeTopBar: true,
        child: FutureBuilder<WasteBin>(
          future: _cycle,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(wasteErrorText(snapshot.error!)));
            }
            if (snapshot.data?.cycle case final cycle?) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  AppSegmentSurfaceCard(child: WasteCycleDetails(cycle: cycle)),
                ],
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
}

class _WasteDestinationDialog extends StatefulWidget {
  const _WasteDestinationDialog({required this.warehouses});

  final List<WasteWarehouse> warehouses;

  @override
  State<_WasteDestinationDialog> createState() =>
      _WasteDestinationDialogState();
}

class _WasteDestinationDialogState extends State<_WasteDestinationDialog> {
  late String? _warehouseId =
      widget.warehouses.length == 1 ? widget.warehouses.single.id : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Qabul omborini belgilash'),
        scrollable: true,
        insetPadding: m3DialogInsetPadding,
        constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
        content: SizedBox(
          width: m3DialogMaxWidth,
          child: WasteWarehouseField(
            warehouses: widget.warehouses,
            selectedId: _warehouseId,
            onChanged: (id) => setState(() => _warehouseId = id),
          ),
        ),
        actions: [
          OutlinedButton(
            style: appOutlinedActionButtonStyle(),
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: appFilledActionButtonStyle(),
            onPressed: _warehouseId == null
                ? null
                : () => Navigator.pop(context, _warehouseId),
            child: const Text('Saqlash'),
          ),
        ],
      );
}
