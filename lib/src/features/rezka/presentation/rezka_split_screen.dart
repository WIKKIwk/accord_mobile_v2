import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../../core/scanner/reliable_mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../gscale/gscale_mobile_app.dart'
    show
        DiscoveredServer,
        driverUrlForRs,
        printTargetLabel,
        showPrintDevicePicker;
import '../../shared/models/app_models.dart';

const _rezkaScrapWarehouse = 'brak - ombori - A';

enum _RezkaRemainderAction { forgot, scrap }

class RezkaSplitScreen extends StatefulWidget {
  const RezkaSplitScreen({super.key});

  @override
  State<RezkaSplitScreen> createState() => _RezkaSplitScreenState();
}

class _RezkaSplitScreenState extends State<RezkaSplitScreen> {
  final _barcodeController = TextEditingController();
  final _reasonController = TextEditingController();
  final _driverUrlController = TextEditingController(
    text: 'http://gscale.local:39117',
  );
  final _printerController = TextEditingController(text: 'godex');
  final _printModeController = TextEditingController(text: 'label');
  final List<_RezkaOutputDraft> _outputs = [];
  RezkaSourceEntry? _source;
  DiscoveredServer? _selectedPrinterServer;
  bool _loadingSource = false;
  bool _submitting = false;
  bool _detectingOfflinePrinter = false;
  UsbPrinterProfile? _offlinePrinter;
  BluetoothPrinterProfile? _bluetoothPrinter;
  String? _offlinePrinterError;
  PrintTransport _printTransport = PrintTransport.offline;

  @override
  void initState() {
    super.initState();
    unawaited(_detectOfflinePrinter());
  }

  Future<UsbPrinterProfile?> _detectOfflinePrinter() async {
    if (mounted) {
      setState(() {
        _detectingOfflinePrinter = true;
        _offlinePrinterError = null;
      });
    }
    try {
      final profile = await PrintService.detectOfflinePrinter();
      if (mounted) {
        setState(() {
          _offlinePrinter = profile;
          _detectingOfflinePrinter = false;
        });
      }
      return profile;
    } catch (error) {
      if (mounted) {
        setState(() {
          _offlinePrinter = null;
          _detectingOfflinePrinter = false;
          _offlinePrinterError = error.toString();
        });
      }
      return null;
    }
  }

  Future<void> _selectPrinter() async {
    final selection = await showPrintDevicePicker(context);
    if (!mounted || selection == null) {
      return;
    }
    setState(() {
      _printTransport = selection.transport;
      _offlinePrinter = selection.offlinePrinter;
      _bluetoothPrinter = selection.bluetoothPrinter;
      _selectedPrinterServer = selection.server;
      if (selection.server != null) {
        _driverUrlController.text = driverUrlForRs(selection.server!);
      }
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _reasonController.dispose();
    _driverUrlController.dispose();
    _printerController.dispose();
    _printModeController.dispose();
    for (final output in _outputs) {
      output.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => const _RezkaScannerDialog(),
    );
    if (!mounted || value == null || value.trim().isEmpty) {
      return;
    }
    _barcodeController.text = _extractLookupBarcode(value) ?? value.trim();
    await _loadSource();
  }

  Future<void> _loadSource() async {
    final barcode = _extractLookupBarcode(_barcodeController.text) ??
        _barcodeController.text.trim();
    if (barcode.isEmpty || _loadingSource) {
      return;
    }
    _barcodeController.text = barcode;
    setState(() => _loadingSource = true);
    try {
      final response = await MobileApi.instance.rezkaSource(barcode: barcode);
      if (!mounted) {
        return;
      }
      setState(() {
        _source = response.source;
        for (final output in _outputs) {
          output.dispose();
        }
        _outputs
          ..clear()
          ..add(_RezkaOutputDraft.fromSource(response.source))
          ..add(_RezkaOutputDraft.fromSource(response.source));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _loadingSource = false);
      }
    }
  }

  void _addOutput() {
    final source = _source;
    if (source == null) {
      return;
    }
    setState(() => _outputs.add(_RezkaOutputDraft.fromSource(source)));
  }

  void _removeOutput(int index) {
    if (_outputs.length <= 2) {
      return;
    }
    setState(() {
      final removed = _outputs.removeAt(index);
      removed.dispose();
    });
  }

  void _addRemainderOutput(
    RezkaSourceEntry source,
    double remainder, {
    bool scrap = false,
  }) {
    final output = _RezkaOutputDraft.fromSource(source);
    output.qtyController.text = remainder.gscale;
    if (scrap) {
      output.itemCode = source.itemCode;
      output.itemName = source.itemName;
      output.printQr = false;
      output.warehouseController.text = _rezkaScrapWarehouse;
      output.reasonController.text = 'Atxot / brak mahsulot';
    }
    setState(() => _outputs.add(output));
  }

  Future<bool> _validateOutputTotal(
    RezkaSourceEntry source,
    List<double> quantities,
  ) async {
    final total = quantities.fold<double>(0, (sum, qty) => sum + qty);
    final diff = source.qty - total;
    if (diff.abs() <= 0.0001) {
      return true;
    }
    if (diff > 0) {
      final action = await _askRemainderAction(
        source: source,
        total: total,
        remainder: diff,
      );
      if (!mounted || action == null) {
        return false;
      }
      _addRemainderOutput(
        source,
        diff,
        scrap: action == _RezkaRemainderAction.scrap,
      );
      final message = action == _RezkaRemainderAction.scrap
          ? 'Qoldiq ${diff.gscale} ${source.uom} brak sifatida $_rezkaScrapWarehouse omborga yozildi.'
          : 'Qoldiq ${diff.gscale} ${source.uom} yangi bo‘lakka ochildi, mahsulotini tanlang.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bo‘laklar jami ${total.gscale} ${source.uom} bo‘lib ketdi. '
          'Asl mahsulot ${source.qty.gscale} ${source.uom}. '
          '${(-diff).gscale} ${source.uom} ortiq yozilgan.',
        ),
      ),
    );
    return false;
  }

  Future<_RezkaRemainderAction?> _askRemainderAction({
    required RezkaSourceEntry source,
    required double total,
    required double remainder,
  }) {
    return showDialog<_RezkaRemainderAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Miqdor yetmayapti'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bo‘linayotgan mahsulot ${source.qty.gscale} ${source.uom}. '
                'Siz kiritgan bo‘laklar jami ${total.gscale} ${source.uom}. '
                '${remainder.gscale} ${source.uom} qoldi. Xato qildingizmi?',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_RezkaRemainderAction.forgot),
                  child: const Text('Unutibman'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.of(context).pop(_RezkaRemainderAction.scrap),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Brak mahsulot'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bekor qilish'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickItem(_RezkaOutputDraft output) async {
    final item = await showModalBottomSheet<SupplierItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _RezkaItemPickerSheet(),
    );
    if (!mounted || item == null) {
      return;
    }
    setState(() {
      output.itemCode = item.code;
      output.itemName = item.name;
      output.uomController.text = item.uom.trim().isEmpty ? 'kg' : item.uom;
      if (item.warehouse.trim().isNotEmpty) {
        output.warehouseController.text = item.warehouse;
      }
    });
  }

  Future<void> _submit() async {
    final source = _source;
    if (source == null || _submitting) {
      return;
    }
    final outputs = <RezkaSplitOutputRequest>[];
    final local = _printTransport.isLocal;
    final offline = _printTransport.isOffline;
    final wifiDriverUrl = _driverUrlController.text.trim();
    final wifiPrinter = _printerController.text.trim();
    final wifiPrintMode = _printModeController.text.trim();
    if (!local &&
        (wifiDriverUrl.isEmpty ||
            wifiPrinter.isEmpty ||
            wifiPrintMode.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer sozlamasi to‘liq emas.')),
      );
      return;
    }
    final quantities = <double>[];
    for (final output in _outputs) {
      final qty = double.tryParse(output.qtyController.text.trim()) ?? 0;
      final itemCode = output.itemCode.trim().isEmpty && !output.printQr
          ? source.itemCode
          : output.itemCode;
      final itemName = output.itemName.trim().isEmpty && !output.printQr
          ? source.itemName
          : output.itemName;
      if ((output.printQr && itemCode.trim().isEmpty) ||
          qty <= 0 ||
          output.warehouseController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR chiqadigan bo‘lakda mahsulot, qty va location bo‘lsin. Atxotda qty va location yetarli.',
            ),
          ),
        );
        return;
      }
      quantities.add(qty);
      outputs.add(
        RezkaSplitOutputRequest(
          itemCode: itemCode,
          itemName: itemName,
          qty: qty,
          uom: output.uomController.text.trim().isEmpty
              ? source.uom
              : output.uomController.text.trim(),
          targetWarehouse: output.warehouseController.text.trim(),
          reason: output.reasonController.text,
          printQr: output.printQr,
        ),
      );
    }
    if (!await _validateOutputTotal(source, quantities)) {
      return;
    }
    final offlinePrinter = offline ? await _detectOfflinePrinter() : null;
    if (offline && offlinePrinter == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('GoDEX yoki Zebra USB printer topilmadi.')),
        );
      }
      return;
    }
    final bluetoothPrinter =
        _printTransport.isBluetooth ? _bluetoothPrinter : null;
    if (_printTransport.isBluetooth && bluetoothPrinter == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('XP-P323B Bluetooth printer tanlang.')),
        );
      }
      return;
    }
    final driverUrl = local ? offlineUsbDriverUrl : wifiDriverUrl;
    final printer = offline
        ? offlinePrinter!.printer
        : bluetoothPrinter?.printer ?? wifiPrinter;
    final printMode = offline
        ? offlinePrinter!.printMode
        : bluetoothPrinter?.printMode ?? wifiPrintMode;
    setState(() => _submitting = true);
    try {
      final request = RezkaSplitRequest(
        sourceBarcode: source.barcode,
        sourceStockEntry: source.stockEntryName,
        sourceLineIndex: source.lineIndex,
        reason: _reasonController.text,
        driverUrl: driverUrl,
        printer: printer,
        printMode: printMode,
        outputs: outputs,
      );
      final RezkaSplitResponse response;
      if (local) {
        final prepared =
            await MobileApi.instance.rezkaSplitClientPrintPrepare(request);
        for (final output in prepared.outputs) {
          if (!output.printQr || output.epc.trim().isEmpty) {
            continue;
          }
          await PrintService.printRps(
            UsbRpsPrintRequest(
              epc: output.epc,
              itemCode: output.itemCode,
              itemName: output.itemName,
              warehouse: output.warehouse,
              printer: printer,
              printMode: printMode,
              grossQty: output.qty,
              unit: output.uom,
            ),
            printerProfile: offlinePrinter,
            bluetoothPrinter: bluetoothPrinter,
            transport: _printTransport,
          );
        }
        response = await MobileApi.instance.rezkaSplitClientPrintConfirm(
          request.withPreparedOutputs(prepared.outputs),
        );
      } else {
        response = await MobileApi.instance.rezkaSplit(request);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response.outputs.where((item) => item.printQr).length} ta QR chiqarildi.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showRezkaSubmitError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(Object error) {
    final message =
        error is MobileApiException ? error.message : error.toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRezkaSubmitError(Object error) {
    final message =
        error is MobileApiException ? error.message : error.toString();
    final parsed = RegExp(
      r'output_total_must_equal_source_qty:([0-9.]+)!=([0-9.]+)',
    ).firstMatch(message);
    if (parsed == null) {
      _showError(error);
      return;
    }
    final total = double.tryParse(parsed.group(1) ?? '') ?? 0;
    final sourceQty = double.tryParse(parsed.group(2) ?? '') ?? 0;
    final diff = sourceQty - total;
    final source = _source;
    if (source != null && diff > 0.0001) {
      _addRemainderOutput(source, diff);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bo‘linayotgan mahsulot ${sourceQty.gscale} ${source.uom}. '
            'Bo‘laklar jami ${total.gscale} ${source.uom}. '
            '${diff.gscale} ${source.uom} kam. Qolganini yangi bo‘lakka ochdim.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bo‘laklar jami ${total.gscale}, asl mahsulot ${sourceQty.gscale}. '
          'Miqdorlarni teng qilib yozing.',
        ),
      ),
    );
  }

  String? _extractLookupBarcode(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.pathSegments.isNotEmpty) {
      final queryBarcode =
          (uri.queryParameters['barcode'] ?? uri.queryParameters['epc'] ?? '')
              .trim();
      if (queryBarcode.isNotEmpty) {
        return queryBarcode;
      }
      final segments = uri.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty || segments.first.trim().toUpperCase() == 'A') {
        return null;
      }
      return segments.last.trim();
    }
    if (trimmed.contains('/A/')) {
      return null;
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = _source;
    final printerIcon = switch (_printTransport) {
      PrintTransport.offline => Icons.usb_rounded,
      PrintTransport.bluetooth => Icons.bluetooth_rounded,
      PrintTransport.wifi => Icons.wifi_rounded,
    };
    final printerTitle = switch (_printTransport) {
      PrintTransport.offline =>
        _offlinePrinter?.displayName ?? 'USB printer tanlanmagan',
      PrintTransport.bluetooth =>
        _bluetoothPrinter?.displayName ?? 'Bluetooth printer tanlanmagan',
      PrintTransport.wifi => _selectedPrinterServer == null
          ? 'Wi‑Fi printer tanlanmagan'
          : printTargetLabel(_selectedPrinterServer!),
    };
    final printerSubtitle = switch (_printTransport) {
      PrintTransport.offline => _detectingOfflinePrinter
          ? 'USB printer aniqlanmoqda...'
          : _offlinePrinterError != null
              ? 'USB printer topilmadi'
              : 'Mahalliy USB orqali chop etish',
      PrintTransport.bluetooth =>
        _bluetoothPrinter?.address ?? 'Bluetooth printer tanlash uchun bosing',
      PrintTransport.wifi => _selectedPrinterServer == null
          ? 'Wi‑Fi printer tanlash uchun bosing'
          : _driverUrlController.text,
    };
    return AppShell(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: 'Rezka',
      subtitle: 'Mahsulotni bo‘lish',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          TextField(
            controller: _barcodeController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadSource(),
            decoration: InputDecoration(
              labelText: 'Source QR',
              prefixIcon: const Icon(Icons.qr_code_rounded),
              suffixIcon: IconButton(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loadingSource ? null : _loadSource,
            icon: _loadingSource
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: const Text('QR ni tekshirish'),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(printerIcon),
              title: Text(printerTitle),
              subtitle: Text(printerSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => unawaited(_selectPrinter()),
            ),
          ),
          if (source != null) ...[
            const SizedBox(height: 16),
            _SourceCard(source: source),
            const SizedBox(height: 16),
            Text(
              'Bo‘laklar',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _outputs.length; index++)
              _OutputCard(
                index: index,
                output: _outputs[index],
                onPickItem: () => _pickItem(_outputs[index]),
                onRemove: () => _removeOutput(index),
                canRemove: _outputs.length > 2,
              ),
            OutlinedButton.icon(
              onPressed: _addOutput,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Bo‘lak qo‘shish'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Sabab',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Printer'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                TextField(
                  controller: _driverUrlController,
                  decoration: const InputDecoration(labelText: 'Driver URL'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _printerController,
                        decoration: const InputDecoration(labelText: 'Printer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _printModeController,
                        decoration: const InputDecoration(labelText: 'Mode'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded),
              label: const Text('Bo‘lish va QR chiqarish'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final RezkaSourceEntry source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(source.itemCode),
            Text('${source.qty.gscale} ${source.uom}'),
            Text(source.warehouse),
          ],
        ),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.index,
    required this.output,
    required this.onPickItem,
    required this.onRemove,
    required this.canRemove,
  });

  final int index;
  final _RezkaOutputDraft output;
  final VoidCallback onPickItem;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemLabel = output.printQr
        ? output.itemCode.trim().isEmpty
            ? 'Mahsulot tanlang'
            : '${output.itemName} (${output.itemCode})'
        : 'Atxot: QR chiqarilmaydi';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    output.printQr
                        ? 'Bo‘lak ${index + 1}'
                        : 'Atxot ${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if (output.printQr)
              OutlinedButton.icon(
                onPressed: onPickItem,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(itemLabel, overflow: TextOverflow.ellipsis),
              )
            else
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.do_not_disturb_on_outlined),
                title: Text(itemLabel),
                subtitle: const Text('Mahsulot tanlash shart emas'),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: output.qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: output.uomController,
                    decoration: const InputDecoration(labelText: 'UOM'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: output.warehouseController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: output.reasonController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bo‘lak sababi',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RezkaItemPickerSheet extends StatefulWidget {
  const _RezkaItemPickerSheet();

  @override
  State<_RezkaItemPickerSheet> createState() => _RezkaItemPickerSheetState();
}

class _RezkaItemPickerSheetState extends State<_RezkaItemPickerSheet> {
  final _queryController = TextEditingController();
  Future<List<SupplierItem>>? _future;
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<List<SupplierItem>> _load({String? query}) {
    return MobileApi.instance.gscaleItemsPage(
      query: query ?? _queryController.text,
      limit: 30,
    );
  }

  void _search({Duration delay = Duration.zero}) {
    _debounce?.cancel();
    final query = _queryController.text;
    final generation = ++_searchGeneration;
    void run() {
      if (!mounted || generation != _searchGeneration) {
        return;
      }
      setState(() => _future = _load(query: query));
    }

    if (delay == Duration.zero) {
      run();
      return;
    }
    _debounce = Timer(delay, run);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onChanged: (_) =>
                  _search(delay: const Duration(milliseconds: 220)),
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'ERPNext item qidirish',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<SupplierItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? const <SupplierItem>[];
                  if (items.isEmpty) {
                    return const Center(child: Text('Mahsulot topilmadi'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        title: Text(item.name.isEmpty ? item.code : item.name),
                        subtitle: Text(
                          '${item.code} • ${item.uom} • ${item.warehouse}',
                        ),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RezkaScannerDialog extends StatefulWidget {
  const _RezkaScannerDialog();

  @override
  State<_RezkaScannerDialog> createState() => _RezkaScannerDialogState();
}

class _RezkaScannerDialogState extends State<_RezkaScannerDialog> {
  ReliableScannerSession? _scannerSession;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (_supportsScanner) {
      _scannerSession = ReliableScannerSession(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    final session = _scannerSession;
    if (session != null) {
      unawaited(session.dispose());
    }
    super.dispose();
  }

  static bool get _supportsScanner {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  void _detect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      _done = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _scannerSession;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('QR scan')),
        body: session == null
            ? const Center(child: Text('Scanner bu qurilmada ishlamaydi'))
            : ReliableMobileScanner(session: session, onDetect: _detect),
      ),
    );
  }
}

class _RezkaOutputDraft {
  _RezkaOutputDraft({
    required this.uomController,
    required this.qtyController,
    required this.warehouseController,
    required this.reasonController,
  });

  factory _RezkaOutputDraft.fromSource(RezkaSourceEntry source) {
    return _RezkaOutputDraft(
      uomController: TextEditingController(
        text: source.uom.trim().isEmpty ? 'kg' : source.uom,
      ),
      qtyController: TextEditingController(),
      warehouseController: TextEditingController(text: source.warehouse),
      reasonController: TextEditingController(),
    );
  }

  String itemCode = '';
  String itemName = '';
  bool printQr = true;
  final TextEditingController uomController;
  final TextEditingController qtyController;
  final TextEditingController warehouseController;
  final TextEditingController reasonController;

  void dispose() {
    uomController.dispose();
    qtyController.dispose();
    warehouseController.dispose();
    reasonController.dispose();
  }
}

extension _RezkaQtyFormat on num {
  String get gscale {
    final value = toDouble();
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(3);
  }
}
