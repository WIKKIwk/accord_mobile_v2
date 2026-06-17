import 'dart:async';
import 'dart:math' as math;

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
        autoZoom: true,
        cameraResolution: const Size(1920, 1080),
        lensType: CameraLensType.normal,
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final shortest = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final guideSize = shortest.clamp(220.0, 340.0);
                        final scanWindow = Rect.fromCenter(
                          center: Offset(
                            constraints.maxWidth / 2,
                            constraints.maxHeight / 2,
                          ),
                          width: guideSize,
                          height: guideSize,
                        );
                        return MobileScanner(
                          controller: controller,
                          fit: BoxFit.cover,
                          scanWindow: scanWindow,
                          tapToFocus: true,
                          onDetect: _detect,
                          overlayBuilder: (context, _) =>
                              const RawMaterialScannerGuide(),
                        );
                      },
                    ),
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
                      SizedBox(
                        width: 92,
                        child: FilledButton.icon(
                          onPressed: () => _complete(_manualController.text),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            'OK',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                            ),
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

class RawMaterialScannerGuide extends StatelessWidget {
  const RawMaterialScannerGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: CustomPaint(
              key: const ValueKey('raw-material-scanner-grid'),
              size: const Size.square(260),
              painter: _RawMaterialScannerGridPainter(),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.74),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  'QR kodni shu to‘r ichiga olib keling',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawMaterialScannerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.34);
    final brightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = Colors.white;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.52);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      dimPaint,
    );

    final third = size.width / 3;
    canvas
      ..drawLine(Offset(third, 0), Offset(third, size.height), gridPaint)
      ..drawLine(
        Offset(third * 2, 0),
        Offset(third * 2, size.height),
        gridPaint,
      )
      ..drawLine(Offset(0, third), Offset(size.width, third), gridPaint)
      ..drawLine(
        Offset(0, third * 2),
        Offset(size.width, third * 2),
        gridPaint,
      );

    const corner = 52.0;
    final radius = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas
      ..drawLine(radius.tlRadius.x == 0 ? Offset.zero : const Offset(24, 0),
          const Offset(corner, 0), brightPaint)
      ..drawLine(const Offset(0, 24), const Offset(0, corner), brightPaint)
      ..drawLine(
        Offset(size.width - corner, 0),
        Offset(size.width - 24, 0),
        brightPaint,
      )
      ..drawLine(
        Offset(size.width, 24),
        Offset(size.width, corner),
        brightPaint,
      )
      ..drawLine(
        Offset(0, size.height - corner),
        Offset(0, size.height - 24),
        brightPaint,
      )
      ..drawLine(
        Offset(24, size.height),
        Offset(corner, size.height),
        brightPaint,
      )
      ..drawLine(
        Offset(size.width - corner, size.height),
        Offset(size.width - 24, size.height),
        brightPaint,
      )
      ..drawLine(
        Offset(size.width, size.height - corner),
        Offset(size.width, size.height - 24),
        brightPaint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
