import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';

class RezkaSplitScreen extends StatefulWidget {
  const RezkaSplitScreen({super.key});

  @override
  State<RezkaSplitScreen> createState() => _RezkaSplitScreenState();
}

class _RezkaSplitScreenState extends State<RezkaSplitScreen> {
  final _barcodeController = TextEditingController();
  final _reasonController = TextEditingController();
  final _driverUrlController =
      TextEditingController(text: 'http://gscale.local:39117');
  final _printerController = TextEditingController(text: 'godex');
  final _printModeController = TextEditingController(text: 'label');
  final List<_RezkaOutputDraft> _outputs = [];
  RezkaSourceEntry? _source;
  bool _loadingSource = false;
  bool _submitting = false;

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
    for (final output in _outputs) {
      final qty = double.tryParse(output.qtyController.text.trim()) ?? 0;
      if (output.itemCode.trim().isEmpty ||
          qty <= 0 ||
          output.warehouseController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Har bir bo‘lakda item, qty va location bo‘lsin.')),
        );
        return;
      }
      outputs.add(
        RezkaSplitOutputRequest(
          itemCode: output.itemCode,
          itemName: output.itemName,
          qty: qty,
          uom: output.uomController.text.trim().isEmpty
              ? source.uom
              : output.uomController.text.trim(),
          targetWarehouse: output.warehouseController.text.trim(),
        ),
      );
    }
    setState(() => _submitting = true);
    try {
      final response = await MobileApi.instance.rezkaSplit(
        RezkaSplitRequest(
          sourceBarcode: source.barcode,
          sourceStockEntry: source.stockEntryName,
          sourceLineIndex: source.lineIndex,
          reason: _reasonController.text,
          driverUrl: _driverUrlController.text,
          printer: _printerController.text,
          printMode: _printModeController.text,
          outputs: outputs,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response.outputs.length} ta QR chiqarildi.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(error);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    return AppShell(
      title: 'Rezka',
      subtitle: 'Mahsulotni bo‘lish',
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
    final itemLabel = output.itemCode.trim().isEmpty
        ? 'Mahsulot tanlang'
        : '${output.itemName} (${output.itemCode})';
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
                    'Bo‘lak ${index + 1}',
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
            OutlinedButton.icon(
              onPressed: onPickItem,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(itemLabel, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: output.qtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<List<SupplierItem>> _load() {
    return MobileApi.instance.gscaleItemsPage(
      query: _queryController.text,
      limit: 30,
    );
  }

  void _search() {
    setState(() => _future = _load());
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
                        tileColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        title: Text(item.name.isEmpty ? item.code : item.name),
                        subtitle: Text(
                            '${item.code} • ${item.uom} • ${item.warehouse}'),
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
  MobileScannerController? _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (_supportsScanner) {
      _controller = MobileScannerController(
        autoStart: true,
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose());
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
    final controller = _controller;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('QR scan')),
        body: controller == null
            ? const Center(child: Text('Scanner bu qurilmada ishlamaydi'))
            : MobileScanner(
                controller: controller,
                onDetect: _detect,
              ),
      ),
    );
  }
}

class _RezkaOutputDraft {
  _RezkaOutputDraft({
    required this.uomController,
    required this.qtyController,
    required this.warehouseController,
  });

  factory _RezkaOutputDraft.fromSource(RezkaSourceEntry source) {
    return _RezkaOutputDraft(
      uomController: TextEditingController(
        text: source.uom.trim().isEmpty ? 'kg' : source.uom,
      ),
      qtyController: TextEditingController(),
      warehouseController: TextEditingController(text: source.warehouse),
    );
  }

  String itemCode = '';
  String itemName = '';
  final TextEditingController uomController;
  final TextEditingController qtyController;
  final TextEditingController warehouseController;

  void dispose() {
    uomController.dispose();
    qtyController.dispose();
    warehouseController.dispose();
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
