import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> showRawMaterialScanDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    useSafeArea: false,
    builder: (_) => const RawMaterialScanDialog(),
  );
}

String rawMaterialBarcodeFromQr(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(value);
  if (uri != null) {
    for (final key in const ['barcode', 'epc', 'qr']) {
      final candidate = uri.queryParameters[key]?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    if (uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) {
        return last;
      }
    }
  }
  return value;
}

class RawMaterialScanDialog extends StatefulWidget {
  const RawMaterialScanDialog({super.key});

  @override
  State<RawMaterialScanDialog> createState() => _RawMaterialScanDialogState();
}

class _RawMaterialScanDialogState extends State<RawMaterialScanDialog> {
  final _manualController = TextEditingController();
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
    _manualController.dispose();
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

  void _complete(String rawValue) {
    if (_done) {
      return;
    }
    final barcode = rawMaterialBarcodeFromQr(rawValue);
    if (barcode.isEmpty) {
      return;
    }
    _done = true;
    Navigator.of(context).pop(barcode);
  }

  void _detect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
      if (value.isNotEmpty) {
        _complete(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = _controller;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('Homashyo QR')),
        body: Column(
          children: [
            Expanded(
              child: controller == null
                  ? const Center(child: Text('Scanner bu qurilmada ishlamaydi'))
                  : MobileScanner(controller: controller, onDetect: _detect),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          decoration: const InputDecoration(
                            labelText: 'Barcode',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: _complete,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _complete(_manualController.text),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          'OK',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
