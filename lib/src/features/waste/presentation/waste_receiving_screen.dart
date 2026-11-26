import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/forms/app_input_decoration.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
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

  Future<void> _register() async {
    final values = await showDialog<(String, double, double?)>(
      context: context,
      builder: (_) => const _RegisterWasteBinDialog(),
    );
    if (!_current || values == null) return;
    await _run(() async {
      final (code, tare, tolerance) = values;
      final bin = await _api.registerWasteBin(
          code: code, tareKg: tare, toleranceKg: tolerance);
      if (!_current) return;
      setState(() => _selected = bin);
      await _refresh();
      if (_current) await _showQr(bin);
    });
  }

  Future<void> _showQr(WasteBin bin) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(bin.code),
          insetPadding: m3DialogInsetPadding,
          constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
          content: SizedBox(
            width: m3DialogMaxWidth,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: QrImageView(
                data: bin.qrPayload,
                size: 200,
                padding: const EdgeInsets.all(12),
                backgroundColor: Colors.white,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Yopish'),
            ),
            FilledButton.icon(
              onPressed: () async {
                // Capture the popover anchor before preparing the PDF on iPad.
                final box = dialogContext.findRenderObject() as RenderBox?;
                final anchor = box == null || !box.hasSize
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size;
                try {
                  final label = pw.Document();
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
                          pw.Text(bin.code),
                        ],
                      ),
                    ),
                  ));
                  await SharePlus.instance.share(ShareParams(
                    files: [
                      XFile.fromData(await label.save(),
                          name: '${bin.code}.pdf', mimeType: 'application/pdf')
                    ],
                    fileNameOverrides: ['${bin.code}.pdf'],
                    sharePositionOrigin: anchor,
                  ));
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('QR yorlig‘ini ulashib bo‘lmadi')),
                  );
                }
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('QR yorlig‘i'),
            ),
          ],
        ),
      );

  Future<void> _receive(WasteBin bin) async {
    if (_scannedCycleId != bin.cycle?.id && !await _scanMatching(bin)) return;
    final warehouses = await _loadWarehouses();
    if (!mounted || !_current || warehouses == null) return;
    final result = await showDialog<WasteMeasurement>(
      context: context,
      builder: (_) => WasteWeighDialog(bin: bin, warehouses: warehouses),
    );
    if (!_current || result == null) return;
    await _run(() async {
      final updated = await _api.receiveWasteBin(
        bin: bin,
        warehouseId: result.warehouseId,
        grossKg: result.grossKg,
        source: result.source,
        note: result.note,
      );
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
      title: '${bin.code} qutisi bo‘shatildimi?',
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
        title: '${bin.code} tarixi',
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
        return status == 0 ? a.code.compareTo(b.code) : status;
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
                  onPressed: _busy ? null : _register,
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
                  Text('Quti ${bin.code}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '${wasteStatusLabel(bin.status)} · Tara ${wasteKgLabel(bin.tareKg)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (cycle != null && bin.status == WasteBinStatus.sealed)
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
          for (final bin in visible) ...[
            const SizedBox(height: 8),
            AppSegmentSurfaceCard(
              padding: EdgeInsets.zero,
              onTap: _busy ? null : () => _open(bin.code),
              child: ListTile(
                selected: bin.code == _selected?.code,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(bin.code),
                subtitle: Text([
                  wasteStatusLabel(bin.status),
                  if (bin.cycle?.apparatusName case final name?
                      when name.isNotEmpty)
                    name,
                ].join(' · ')),
                trailing: bin.cycle == null
                    ? null
                    : Text(wasteKgLabel(bin.cycle!.expectedKg)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WasteHistoryDetail extends StatefulWidget {
  const _WasteHistoryDetail({required this.code, required this.cycleId});

  final String code, cycleId;

  @override
  State<_WasteHistoryDetail> createState() => _WasteHistoryDetailState();
}

class _WasteHistoryDetailState extends State<_WasteHistoryDetail> {
  late final _cycle =
      MobileApi.instance.wasteBinDetail(widget.code, cycleId: widget.cycleId);

  @override
  Widget build(BuildContext context) => AppShell(
        title: widget.code,
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

class _RegisterWasteBinDialog extends StatefulWidget {
  const _RegisterWasteBinDialog();

  @override
  State<_RegisterWasteBinDialog> createState() =>
      _RegisterWasteBinDialogState();
}

class _RegisterWasteBinDialogState extends State<_RegisterWasteBinDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _tare = TextEditingController();
  final _tolerance = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _tare.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Chiqindi qutisini ro‘yxatga olish'),
        scrollable: true,
        insetPadding: m3DialogInsetPadding,
        constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
        content: SizedBox(
          width: m3DialogMaxWidth,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: appSurfaceInputDecoration(
                    context,
                    labelText: 'Quti kodi',
                  ),
                  validator: (value) {
                    try {
                      wasteBinCode(value ?? '');
                      return null;
                    } on FormatException catch (error) {
                      return error.message;
                    }
                  },
                ),
                const SizedBox(height: 12),
                _kgField(_tare, 'Bo‘sh quti vazni (kg)', required: true),
                const SizedBox(height: 12),
                _kgField(_tolerance, 'Ruxsat etilgan farq (kg)'),
                const SizedBox(height: 20),
                AppDialogActionRow(
                  cancelLabel: 'Bekor qilish',
                  confirmLabel: 'Saqlash',
                  onCancel: () => Navigator.pop(context),
                  onConfirm: () {
                    if (!_form.currentState!.validate()) return;
                    Navigator.pop(context, (
                      _code.text,
                      wasteKgInput(_tare.text)!,
                      wasteKgInput(_tolerance.text),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
      );

  Widget _kgField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: required ? TextInputAction.next : TextInputAction.done,
        decoration: appSurfaceInputDecoration(context, labelText: label),
        validator: (value) {
          if (!required && (value ?? '').trim().isEmpty) return null;
          return wasteKgInput(value ?? '') == null
              ? 'Vaznni kg’da kiriting'
              : null;
        },
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
