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

part 'rezka_split_screen__RezkaSplitScreenState_methods_01.dart';
part 'rezka_split_screen__RezkaSplitScreenState_methods_02.dart';
part 'rezka_split_screen_declarations_part_01.dart';

const _rezkaScrapWarehouse = 'brak - ombori - A';

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
