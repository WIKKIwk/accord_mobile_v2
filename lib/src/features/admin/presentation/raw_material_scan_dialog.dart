import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/scanner/reliable_mobile_scanner.dart';
import '../../../core/theme/app_motion.dart';

Future<String?> showRawMaterialScanDialog(
  BuildContext context, {
  String title = '',
  String manualLabel = '',
}) {
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    useSafeArea: false,
    builder: (_) => RawMaterialScanDialog(
      title: title.trim().isEmpty
          ? l10n.productionText('worker.material.scanner.title')
          : title,
      manualLabel: manualLabel.trim().isEmpty
          ? l10n.productionText('worker.material.scanner.manual')
          : manualLabel,
    ),
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

class ProductionQuickScannerPanel extends StatefulWidget {
  const ProductionQuickScannerPanel({
    super.key,
    required this.onCodeDetected,
    required this.statusText,
    this.busy = false,
    this.allowConcurrentDetections = false,
  });

  final Future<void> Function(String rawValue) onCodeDetected;
  final String statusText;
  final bool busy;
  final bool allowConcurrentDetections;

  @override
  State<ProductionQuickScannerPanel> createState() =>
      _ProductionQuickScannerPanelState();
}

class _ProductionQuickScannerPanelState
    extends State<ProductionQuickScannerPanel> {
  ReliableScannerSession? _scannerSession;
  final _manualController = TextEditingController();
  int _activeDetections = 0;
  bool _manualEntryVisible = false;
  bool _cameraReady = false;

  bool get _processing => _activeDetections > 0;

  @override
  void initState() {
    super.initState();
    if (_supportsScanner) {
      final session = ReliableScannerSession(
        autoZoom: false,
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      _scannerSession = session;
      session.addListener(_syncScannerPhase);
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    final session = _scannerSession;
    if (session != null) {
      session.removeListener(_syncScannerPhase);
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

  void _syncScannerPhase() {
    final phase = _scannerSession?.phase;
    final cameraReady = phase == ReliableScannerPhase.running ||
        phase == ReliableScannerPhase.error;
    if (mounted && _cameraReady != cameraReady) {
      setState(() => _cameraReady = cameraReady);
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (!widget.allowConcurrentDetections && (_processing || widget.busy)) {
      return;
    }
    final rawValue = _firstBarcodeValue(capture);
    if (rawValue.isEmpty) {
      return;
    }

    final operation = _handleDetectedValue(rawValue);
    if (widget.allowConcurrentDetections) {
      unawaited(operation);
      return;
    }
    await operation;
  }

  Future<void> _handleDetectedValue(String rawValue) async {
    if (!mounted) {
      return;
    }
    setState(() => _activeDetections += 1);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await widget.onCodeDetected(rawValue);
    } finally {
      if (mounted) {
        setState(() {
          _activeDetections = _activeDetections > 0 ? _activeDetections - 1 : 0;
        });
      }
    }
  }

  String _firstBarcodeValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim() ?? '';
      if (rawValue.isNotEmpty) {
        return rawValue;
      }
      final displayValue = barcode.displayValue?.trim() ?? '';
      if (displayValue.isNotEmpty) {
        return displayValue;
      }
    }
    return '';
  }

  void _submitManualValue() {
    final value = _manualController.text.trim();
    if (value.isEmpty || _processing) {
      return;
    }
    unawaited(_handleManualValue(value));
  }

  Future<void> _handleManualValue(String value) async {
    if (!mounted) {
      return;
    }
    setState(() => _activeDetections += 1);
    try {
      await widget.onCodeDetected(value);
      _manualController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _activeDetections = _activeDetections > 0 ? _activeDetections - 1 : 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = _scannerSession;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 248,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (session == null)
                  const _QuickScannerUnavailableView()
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final frameSize = math.min(
                        constraints.maxWidth,
                        218.0,
                      );
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox.square(
                            dimension: frameSize,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AnimatedOpacity(
                                    opacity: _cameraReady ? 1 : 0,
                                    duration: AppMotion.fast,
                                    curve: AppMotion.standardDecelerate,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ReliableMobileScanner(
                                          session: session,
                                          fit: BoxFit.cover,
                                          tapToFocus: false,
                                          onDetect: _handleDetect,
                                          errorBuilder: (context, error) =>
                                              const _QuickScannerUnavailableView(),
                                        ),
                                        IgnorePointer(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CustomPaint(
                                                painter:
                                                    _RawMaterialScannerGridPainter(),
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 12,
                                                  ),
                                                  child: _QuickScannerStatus(
                                                    text: _processing ||
                                                            widget.busy
                                                        ? context.l10n
                                                            .productionText(
                                                            'worker.scanner.checking',
                                                          )
                                                        : widget.statusText,
                                                    busy: _processing ||
                                                        widget.busy,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_cameraReady)
                                    ColoredBox(
                                      color: scheme.surfaceContainerHighest,
                                      child: Center(
                                        child: Icon(
                                          Icons.qr_code_scanner_rounded,
                                          color: scheme.primary,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      key: const ValueKey(
                        'production-quick-scanner-manual-toggle',
                      ),
                      tooltip: _manualEntryVisible
                          ? context.l10n.productionText(
                              'worker.scanner.manual.hide',
                            )
                          : context.l10n.productionText(
                              'worker.scanner.manual.show',
                            ),
                      onPressed: () {
                        setState(() {
                          _manualEntryVisible = !_manualEntryVisible;
                        });
                      },
                      color: scheme.onPrimary,
                      icon: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        switchInCurve: AppMotion.standardDecelerate,
                        switchOutCurve: AppMotion.standardAccelerate,
                        child: Icon(
                          _manualEntryVisible
                              ? Icons.close_rounded
                              : Icons.edit_rounded,
                          key: ValueKey(
                            _manualEntryVisible
                                ? 'manual-close'
                                : 'manual-edit',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            key: const ValueKey('production-quick-scanner-manual-motion'),
            duration: AppMotion.medium,
            curve: AppMotion.standardDecelerate,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              switchInCurve: AppMotion.standardDecelerate,
              switchOutCurve: AppMotion.standardAccelerate,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: _manualEntryVisible
                  ? ColoredBox(
                      key: const ValueKey(
                          'production-quick-scanner-manual-visible'),
                      color: scheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey(
                                  'production-quick-scanner-manual',
                                ),
                                controller: _manualController,
                                enabled: !_processing && !widget.busy,
                                decoration: InputDecoration(
                                  labelText: context.l10n.productionText(
                                    'worker.scanner.manual.label',
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submitManualValue(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: context.l10n.productionText(
                                'worker.scanner.accept',
                              ),
                              onPressed: _processing || widget.busy
                                  ? null
                                  : _submitManualValue,
                              icon: AnimatedSwitcher(
                                duration: AppMotion.fast,
                                child: _processing || widget.busy
                                    ? const SizedBox.square(
                                        key: ValueKey('manual-submit-busy'),
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        key: ValueKey('manual-submit-ready'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('production-quick-scanner-manual-hidden'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickScannerStatus extends StatelessWidget {
  const _QuickScannerStatus({required this.text, required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: AppMotion.fast,
                switchInCurve: AppMotion.standardDecelerate,
                switchOutCurve: AppMotion.standardAccelerate,
                child: busy
                    ? const SizedBox.square(
                        key: ValueKey('quick-scanner-status-busy'),
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.qr_code_scanner_rounded,
                        key: ValueKey('quick-scanner-status-ready'),
                        size: 17,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  switchInCurve: AppMotion.standardDecelerate,
                  switchOutCurve: AppMotion.standardAccelerate,
                  child: Text(
                    text,
                    key: ValueKey(text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickScannerUnavailableView extends StatelessWidget {
  const _QuickScannerUnavailableView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            context.l10n.productionText('worker.scanner.unavailable'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class RawMaterialScanDialog extends StatefulWidget {
  const RawMaterialScanDialog({
    super.key,
    this.title = '',
    this.manualLabel = '',
  });

  final String title;
  final String manualLabel;

  @override
  State<RawMaterialScanDialog> createState() => _RawMaterialScanDialogState();
}

class _RawMaterialScanDialogState extends State<RawMaterialScanDialog> {
  final _manualController = TextEditingController();
  ReliableScannerSession? _scannerSession;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (_supportsScanner) {
      _scannerSession = ReliableScannerSession(
        autoZoom: true,
        cameraResolution: const Size(1920, 1080),
        lensType: CameraLensType.normal,
        facing: CameraFacing.back,
        // This dialog closes after the first valid barcode. Keep retrying
        // frames until the Dart callback accepts it, instead of letting the
        // native no-duplicates gate consume a frame before scanWindow or the
        // listener is ready.
        detectionSpeed: DetectionSpeed.normal,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
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
    final session = _scannerSession;
    final title = widget.title.trim().isEmpty
        ? context.l10n.productionText('worker.material.scanner.title')
        : widget.title;
    final manualLabel = widget.manualLabel.trim().isEmpty
        ? context.l10n.productionText('worker.material.scanner.manual')
        : widget.manualLabel;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(
          children: [
            Expanded(
              child: session == null
                  ? Center(
                      child: Text(
                        context.l10n.productionText(
                          'worker.scanner.unavailable',
                        ),
                      ),
                    )
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
                        return ReliableMobileScanner(
                          session: session,
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
                          decoration: InputDecoration(
                            labelText: manualLabel,
                            border: const OutlineInputBorder(),
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
                  context.l10n.productionText('worker.scanner.guide'),
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
