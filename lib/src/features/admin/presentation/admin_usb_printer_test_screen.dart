import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/native_usb_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/admin_shell.dart';

class AdminUsbPrinterTestScreen extends StatefulWidget {
  const AdminUsbPrinterTestScreen({super.key});

  @override
  State<AdminUsbPrinterTestScreen> createState() =>
      _AdminUsbPrinterTestScreenState();
}

class _AdminUsbPrinterTestScreenState extends State<AdminUsbPrinterTestScreen> {
  final _payloadController = TextEditingController(text: 'ACCORD-USB-TEST');
  bool _printing = false;
  String _status = '';

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _printTest() async {
    if (_printing) {
      return;
    }
    setState(() {
      _printing = true;
      _status = 'Yuborilmoqda...';
    });
    try {
      final result = await NativeUsbPrinter.printRpsTest(
        UsbRpsPrintRequest.test(
          epc: _payloadController.text.trim().isEmpty
              ? 'RPS-USB-TEST'
              : _payloadController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _printing = false;
        _status =
            '${result.status.toUpperCase()}: ${result.epc} • ${result.bytes} byte, ${result.deviceName}, VID ${result.vendorId}, PID ${result.productId}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _printing = false;
        _status = _usbPrinterErrorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminShell(
      title: 'USB printer test',
      selectedRouteName: AppRoutes.adminUsbPrinterTest,
      activeTab: null,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 128,
        ),
        children: [
          TextField(
            controller: _payloadController,
            decoration: const InputDecoration(
              labelText: 'QR payload',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _printing ? null : () => unawaited(_printTest()),
              icon: _printing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded),
              label: const Text('Test print'),
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_status),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _usbPrinterErrorText(Object error) {
  if (error is! PlatformException) {
    return 'USB print xatosi';
  }
  return switch (error.code) {
    'usb_printer_not_found' => 'USB printer topilmadi',
    'usb_printer_permission_denied' => 'USB printer ruxsati berilmadi',
    'usb_printer_busy' => 'USB printer ruxsat oynasi ochiq',
    'usb_printer_write_failed' =>
      'USB printerga yozib bo‘lmadi: ${error.message ?? ''}',
    _ => error.message?.trim().isNotEmpty == true
        ? error.message!
        : 'USB print xatosi',
  };
}
