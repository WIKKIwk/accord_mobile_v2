import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/production_map_models.dart';
import 'admin_progress_qr_passport.dart';
import 'admin_progress_qr_scan_pdf.dart';

class AdminProgressQrScanArgs {
  const AdminProgressQrScanArgs({this.scanOnly = false});

  final bool scanOnly;
}

enum _QrScanStatus {
  prompt,
  cameraFailed,
  invalidQr,
  loading,
  reportReady,
  paddonReady,
  materialReady,
  error,
}

class AdminProgressQrScanScreen extends StatefulWidget {
  const AdminProgressQrScanScreen({
    super.key,
    this.scanOnly = false,
  });

  final bool scanOnly;

  @override
  State<AdminProgressQrScanScreen> createState() =>
      _AdminProgressQrScanScreenState();
}

class _AdminProgressQrScanScreenState extends State<AdminProgressQrScanScreen> {
  final bool _scannerSupported = _supportsLiveScanner;
  final _manualQrController = TextEditingController();
  MobileScannerController? _controller;
  bool _processing = false;
  _QrScanStatus _scanStatus = _QrScanStatus.prompt;
  String? _scanErrorCode;
  AdminProgressQrReport? _report;
  AdminPaddonSnapshot? _paddonReport;
  AdminRawMaterialLookup? _rawMaterialReport;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    if (_scannerSupported) {
      _controller = MobileScannerController(
        autoStart: true,
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _manualQrController.dispose();
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  static bool get _supportsLiveScanner {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String _statusText(AppLocalizations l10n) {
    return switch (_scanStatus) {
      _QrScanStatus.prompt => l10n.productionText(
          'worker.scanner.progress_prompt',
        ),
      _QrScanStatus.cameraFailed => l10n.productionText(
          'worker.scanner.camera_failed',
        ),
      _QrScanStatus.invalidQr => l10n.productionText(
          'worker.scanner.invalid_qr',
        ),
      _QrScanStatus.loading => l10n.productionText('worker.scanner.lookup'),
      _QrScanStatus.reportReady => l10n.productionText(
          'worker.scanner.report_ready',
        ),
      _QrScanStatus.paddonReady => l10n.productionText(
          'worker.scanner.paddon_ready',
        ),
      _QrScanStatus.materialReady => l10n.productionText(
          'worker.scanner.material_ready',
        ),
      _QrScanStatus.error => _errorText(l10n),
    };
  }

  String _errorText(AppLocalizations l10n) {
    final code = _scanErrorCode;
    if (code == 'progress_batch_not_found' ||
        code == 'progress_batch_not_accepted') {
      return l10n.productionErrorMessage(
        code!,
        fallback: l10n.productionText('worker.scanner.report_failed'),
      );
    }
    return l10n.productionText('worker.scanner.report_failed');
  }

  Future<void> _startScanner() async {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    try {
      await controller.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _scanErrorCode = null;
        _scanStatus = _QrScanStatus.prompt;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _scanErrorCode = 'camera_failed';
        _scanStatus = _QrScanStatus.cameraFailed;
      });
    }
  }

  Future<void> _stopScanner() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.stop();
    } catch (_) {
      // Camera stop is best-effort.
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing ||
        _report != null ||
        _paddonReport != null ||
        _rawMaterialReport != null) {
      return;
    }
    final qrPayload = _extractQrPayload(_firstBarcodeValue(capture));
    if (qrPayload.isEmpty) {
      setState(() => _scanStatus = _QrScanStatus.invalidQr);
      return;
    }
    await _handleQrPayload(qrPayload);
  }

  Future<void> _handleQrPayload(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (normalized.isEmpty) {
      if (mounted) {
        setState(() => _scanStatus = _QrScanStatus.invalidQr);
      }
      return;
    }
    if (widget.scanOnly) {
      if (mounted) {
        setState(() => _processing = true);
      }
      await _stopScanner();
      if (mounted) {
        Navigator.of(context).pop(normalized);
      }
      return;
    }
    await _lookupQrPayload(normalized);
  }

  Future<void> _lookupQrPayload(String qrPayload) async {
    if (_processing) {
      return;
    }
    final normalized = qrPayload.trim();
    if (normalized.isEmpty) {
      setState(() => _scanStatus = _QrScanStatus.invalidQr);
      return;
    }
    setState(() {
      _processing = true;
      _scanStatus = _QrScanStatus.loading;
      _scanErrorCode = null;
    });
    await _stopScanner();
    try {
      final report = await MobileApi.instance.adminProgressQrReport(normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _processing = false;
        _scanStatus = _QrScanStatus.reportReady;
      });
    } catch (error) {
      if (_shouldTryPaddonLookup(normalized)) {
        try {
          final paddonReport = await MobileApi.instance.adminPaddonQrReport(
            normalized,
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _paddonReport = paddonReport;
            _processing = false;
            _scanStatus = _QrScanStatus.paddonReady;
          });
          return;
        } catch (_) {
          // This five-digit QR may still belong to another flow.
        }
      }
      if (_shouldTryRawMaterialLookup(error)) {
        try {
          final rawReport = await MobileApi.instance.adminRawMaterialLookup(
            barcode: normalized,
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _rawMaterialReport = rawReport;
            _processing = false;
            _scanStatus = _QrScanStatus.materialReady;
          });
          return;
        } catch (_) {
          // Show the original QR error below.
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _scanStatus = _QrScanStatus.error;
        _scanErrorCode = error is MobileApiException ? error.code : null;
      });
      await _startScanner();
    }
  }

  Future<void> _showManualQrDialog() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.l10n.productionText('worker.scanner.manual.title'),
          ),
          content: TextField(
            controller: _manualQrController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.productionText(
                'worker.scanner.manual.payload',
              ),
              hintText: '4001...',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.productionText('worker.action.cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_manualQrController.text),
              child: Text(
                context.l10n.productionText('worker.scanner.manual.verify'),
              ),
            ),
          ],
        );
      },
    );
    if (value == null || !mounted) {
      return;
    }
    await _handleQrPayload(_extractQrPayload(value));
  }

  void _scanAgain() {
    setState(() {
      _report = null;
      _paddonReport = null;
      _rawMaterialReport = null;
      _scanErrorCode = null;
      _scanStatus = _QrScanStatus.prompt;
    });
    unawaited(_startScanner());
  }

  Future<void> _shareCurrentReport() async {
    if (_sharing) {
      return;
    }
    final report = _report;
    final rawMaterialReport = _rawMaterialReport;
    if (report == null && rawMaterialReport == null) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final bytes = report != null
          ? AdminProgressQrScanPdf.buildProgress(
              report,
              l10n: context.l10n,
            )
          : AdminProgressQrScanPdf.buildRawMaterial(
              rawMaterialReport!,
              l10n: context.l10n,
            );
      final filename = report != null
          ? _qrPdfFilename(
              'admin-qr-report',
              report.order?.orderNumber.isNotEmpty == true
                  ? report.order!.orderNumber
                  : report.scannedBatch.batchId,
            )
          : _qrPdfFilename(
              'admin-material-report',
              rawMaterialReport!.barcode,
            );
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          title: filename,
          subject: filename,
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: 'application/pdf',
            ),
          ],
          fileNameOverrides: [filename],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.productionText('worker.scanner.pdf_error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  bool _shouldTryRawMaterialLookup(Object error) {
    if (error is! MobileApiException) {
      return false;
    }
    return error.code == 'progress_batch_not_found' ||
        error.code == 'progress_batch_not_accepted';
  }

  bool _shouldTryPaddonLookup(String qrPayload) {
    return RegExp(r'^\d{5}$').hasMatch(qrPayload.trim());
  }

  String _extractQrPayload(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.pathSegments.isNotEmpty) {
      final queryPayload = (uri.queryParameters['qr_payload'] ??
              uri.queryParameters['progress_qr'] ??
              uri.queryParameters['epc'] ??
              '')
          .trim();
      if (queryPayload.isNotEmpty) {
        return queryPayload;
      }
      return uri.pathSegments.last.trim();
    }
    return trimmed;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final report = _report;
    final paddonReport = _paddonReport;
    final rawMaterialReport = _rawMaterialReport;
    final scannerMode = report == null &&
        paddonReport == null &&
        rawMaterialReport == null &&
        _scannerSupported;
    final backgroundColor =
        scannerMode ? Colors.black : scheme.surfaceContainerLow;
    final appBarTheme = theme.appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: scannerMode ? Colors.white : scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
    return Theme(
      data: theme.copyWith(appBarTheme: appBarTheme),
      child: AppShell(
        title: context.l10n.productionText('worker.action.scan'),
        subtitle: '',
        nativeTopBar: true,
        backgroundColor: backgroundColor,
        contentPadding: EdgeInsets.zero,
        child: report != null
            ? _QrReportView(
                report: report,
                onScanAgain: _scanAgain,
                onShare: _shareCurrentReport,
                sharing: _sharing,
              )
            : paddonReport != null
                ? _PaddonQrReportView(
                    report: paddonReport,
                    onScanAgain: _scanAgain,
                  )
                : rawMaterialReport != null
                    ? _RawMaterialReportView(
                        report: rawMaterialReport,
                        onScanAgain: _scanAgain,
                        onShare: _shareCurrentReport,
                        sharing: _sharing,
                      )
                    : scannerMode
                        ? _ScannerView(
                            controller: _controller,
                            statusText: _statusText(context.l10n),
                            processing: _processing,
                            errorText: _scanStatus == _QrScanStatus.error ||
                                    _scanStatus == _QrScanStatus.cameraFailed
                                ? _statusText(context.l10n)
                                : null,
                            onDetect: _handleDetect,
                            onRetry: _startScanner,
                            onManualEntry: _showManualQrDialog,
                          )
                        : _UnsupportedScannerView(
                            onBack: Navigator.of(context).pop,
                            onManualEntry: _showManualQrDialog,
                          ),
      ),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({
    required this.controller,
    required this.statusText,
    required this.processing,
    required this.errorText,
    required this.onDetect,
    required this.onRetry,
    required this.onManualEntry,
  });

  final MobileScannerController? controller;
  final String statusText;
  final bool processing;
  final String? errorText;
  final void Function(BarcodeCapture capture) onDetect;
  final Future<void> Function() onRetry;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: controller,
            fit: BoxFit.cover,
            useAppLifecycleState: true,
            onDetect: onDetect,
            errorBuilder: (context, error) {
              return _ScannerErrorView(
                message: context.l10n.productionText(
                  'worker.scanner.camera_permission',
                ),
                onRetry: onRetry,
              );
            },
            placeholderBuilder: (context) {
              return const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.42),
                  ],
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 92, 18, 24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 286,
                      height: 286,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.90),
                          width: 2.6,
                        ),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white.withValues(alpha: 0.86),
                              size: 44,
                            ),
                          ),
                          PositionedDirectional(
                            top: 12,
                            end: 12,
                            child: _TorchButton(controller: controller),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _ScanStatusPill(
                  text: errorText ?? statusText,
                  isBusy: processing,
                  isError: errorText != null,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: processing ? null : onManualEntry,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: Text(
                    context.l10n.productionText('worker.scanner.manual.title'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QrReportView extends StatelessWidget {
  const _QrReportView({
    required this.report,
    required this.onScanAgain,
    required this.onShare,
    required this.sharing,
  });

  final AdminProgressQrReport report;
  final VoidCallback onScanAgain;
  final VoidCallback onShare;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passport = buildProgressQrPassport(report, l10n: context.l10n);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Card.filled(
          color:
              report.isStale ? scheme.errorContainer : scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      report.isStale
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: report.isStale
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.isStale
                            ? context.l10n.productionText(
                                'worker.qr.report.stale',
                              )
                            : context.l10n.productionText(
                                'worker.qr.report.current',
                              ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: report.isStale
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  passport.productName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (passport.orderNumber.isNotEmpty)
                      '${context.l10n.productionText('worker.qr.report.order')} ${passport.orderNumber}',
                    passport.status,
                  ].where((item) => item.trim().isNotEmpty).join(' • '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ReportShareButton(onPressed: onShare, isBusy: sharing),
        const SizedBox(height: 12),
        if (passport.plan.isNotEmpty)
          _PassportPlanSection(lines: passport.plan),
        if (passport.stages.isNotEmpty)
          _PassportStagesSection(stages: passport.stages),
        if (passport.corrections.isNotEmpty)
          _PassportCorrectionsSection(corrections: passport.corrections),
        if (passport.issues.isNotEmpty)
          _PassportIssuesSection(issues: passport.issues),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(
            context.l10n.productionText('worker.scanner.scan_again'),
          ),
        ),
      ],
    );
  }
}

class _RawMaterialReportView extends StatelessWidget {
  const _RawMaterialReportView({
    required this.report,
    required this.onScanAgain,
    required this.onShare,
    required this.sharing,
  });

  final AdminRawMaterialLookup report;
  final VoidCallback onScanAgain;
  final VoidCallback onShare;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assignment = report.assignment;
    final order = report.order;
    final queueState = assignment == null
        ? ''
        : _currentQueueState(
            report.queueStates,
            assignment.orderId,
            assignment.apparatus,
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Card.filled(
          color: scheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.productionText(
                          'worker.qr.report.material_title',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.itemName.trim().isNotEmpty
                      ? report.itemName
                      : report.itemCode,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    report.itemGroup,
                    _quantityTextFromParts(report.qty, report.uom),
                    _rawMaterialStatusLabel(report.status, context.l10n),
                  ].where((item) => item.trim().isNotEmpty).join(' • '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ReportShareButton(onPressed: onShare, isBusy: sharing),
        const SizedBox(height: 12),
        _OrderDetailsSection(order: order),
        if (report.queueStates.isNotEmpty)
          _QueueStatesSection(queueStates: report.queueStates),
        _InfoSection(
          title: context.l10n.productionText('worker.qr.report.material_about'),
          children: [
            Text(
              _rawMaterialSummary(report, queueState, context.l10n),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ),
        _RawMaterialStatusSection(report: report, queueState: queueState),
        _RawMaterialAssignmentSection(
          assignment: assignment,
          orderTitle: order?.title ?? '',
          orderNumber: order?.orderNumber ?? '',
          queueState: queueState,
        ),
        _TimelineSection(logs: report.logs, corrections: const []),
        _TechnicalRawMaterialSection(report: report),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(
            context.l10n.productionText('worker.scanner.scan_again'),
          ),
        ),
      ],
    );
  }
}

class _PaddonQrReportView extends StatelessWidget {
  const _PaddonQrReportView({
    required this.report,
    required this.onScanAgain,
  });

  final AdminPaddonSnapshot report;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paddon = report.paddon;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Card.filled(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.productionText(
                          'worker.qr.report.paddon_title',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  paddon.code,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.productionText(
                    'worker.qr.report.paddon_count',
                    values: {'count': report.items.length},
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (paddon.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${context.l10n.productionText('worker.qr.report.location')}: ${paddon.location}',
                  ),
                ],
                if (paddon.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${context.l10n.productionText('worker.qr.report.note')}: ${paddon.note}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoSection(
          title: context.l10n.productionText(
            'worker.qr.report.paddon_wips',
            values: {'count': report.items.length},
          ),
          children: report.items.isEmpty
              ? [
                  _SentenceLine(
                    text: context.l10n.productionText(
                      'worker.qr.report.paddon_empty',
                    ),
                  ),
                ]
              : [
                  for (var index = 0; index < report.items.length; index++)
                    _PaddonScannedWipCard(
                      index: index + 1,
                      batch: report.items[index],
                    ),
                ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(
            context.l10n.productionText('worker.scanner.scan_again'),
          ),
        ),
      ],
    );
  }
}

class _PaddonScannedWipCard extends StatelessWidget {
  const _PaddonScannedWipCard({
    required this.index,
    required this.batch,
  });

  final int index;
  final AdminProgressBatch batch;

  @override
  Widget build(BuildContext context) {
    final title = batch.labelItemName.trim().isNotEmpty
        ? batch.labelItemName.trim()
        : batch.labelItemCode.trim().isNotEmpty
            ? batch.labelItemCode.trim()
            : batch.batchId.trim();
    final status = progressQrHumanStatusLabel(
      workStatus: batch.statusDetail.workStatus,
      flowStatus: batch.statusDetail.flowStatus,
      wipStatus: batch.wipStatus,
      l10n: context.l10n,
    );
    final location = [
      batch.currentLocation.trim(),
      batch.currentApparatus.trim().isNotEmpty
          ? context.l10n.productionApparatusName(batch.currentApparatus)
          : context.l10n.productionApparatusName(batch.apparatus),
    ].where((item) => item.isNotEmpty).join(' • ');
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. ${title.isEmpty ? context.l10n.productionText('worker.daily.wip') : title}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: context.l10n.productionText('worker.qr.report.order'),
              value: batch.orderId,
            ),
            _InfoRow(
              label: context.l10n.productionText('worker.qr.report.epc'),
              value: batch.qrPayload,
            ),
            _InfoRow(
              label: context.l10n.productionText('worker.qr.report.batch_id'),
              value: batch.batchId,
            ),
            _InfoRow(
              label: context.l10n.productionText('worker.qr.report.status'),
              value: status.isEmpty ? batch.status : status,
            ),
            _InfoRow(
              label: context.l10n.productionText('worker.qr.report.location'),
              value: location,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportShareButton extends StatelessWidget {
  const _ReportShareButton({required this.onPressed, required this.isBusy});

  final VoidCallback onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FilledButton.tonalIcon(
        onPressed: isBusy ? null : onPressed,
        icon: isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ios_share_rounded),
        label: Text(
          isBusy
              ? context.l10n.productionText('worker.scanner.pdf_preparing')
              : context.l10n.productionText('worker.scanner.share_pdf'),
        ),
      ),
    );
  }
}

class _PassportPlanSection extends StatelessWidget {
  const _PassportPlanSection({required this.lines});

  final List<ProgressQrPassportLine> lines;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.share_plan'),
      children: [
        for (final line in lines)
          _InfoRow(label: line.label, value: line.value),
      ],
    );
  }
}

class _PassportStagesSection extends StatelessWidget {
  const _PassportStagesSection({required this.stages});

  final List<ProgressQrPassportStage> stages;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.stages'),
      children: [
        for (var index = 0; index < stages.length; index++)
          _PassportStageCard(index: index + 1, stage: stages[index]),
      ],
    );
  }
}

class _PassportStageCard extends StatelessWidget {
  const _PassportStageCard({required this.index, required this.stage});

  final int index;
  final ProgressQrPassportStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      color: stage.isCurrent ? scheme.primaryContainer.withAlpha(90) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text('$index'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stage.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (stage.isCurrent)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      context.l10n.productionText(
                        'worker.qr.report.current_label',
                      ),
                    ),
                  ),
              ],
            ),
            if (stage.status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                stage.status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (stage.lines.isNotEmpty) const SizedBox(height: 10),
            for (final line in stage.lines)
              _InfoRow(label: line.label, value: line.value),
          ],
        ),
      ),
    );
  }
}

class _PassportCorrectionsSection extends StatelessWidget {
  const _PassportCorrectionsSection({required this.corrections});

  final List<ProgressQrPassportCorrection> corrections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.corrections'),
      children: [
        for (var index = 0; index < corrections.length; index++)
          Card.outlined(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${corrections[index].stage}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: context.l10n.productionText(
                      'worker.qr.report.editor',
                    ),
                    value: corrections[index].editor,
                  ),
                  _InfoRow(
                    label: context.l10n.productionText('worker.qr.report.time'),
                    value: corrections[index].time,
                  ),
                  _InfoRow(
                    label: context.l10n.productionText(
                      'worker.qr.report.reason',
                    ),
                    value: corrections[index].reason,
                  ),
                  for (final change in corrections[index].changes)
                    _InfoRow(
                      label: change.label,
                      value: '${change.before} → ${change.after}',
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PassportIssuesSection extends StatelessWidget {
  const _PassportIssuesSection({required this.issues});

  final List<ProgressQrPassportIssue> issues;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.issues'),
      children: [
        for (final issue in issues) ...[
          _InfoRow(label: issue.title, value: issue.description),
          if (issue.time.isNotEmpty)
            _InfoRow(
              label: context.l10n.productionText('worker.qr.report.time'),
              value: issue.time,
            ),
        ],
      ],
    );
  }
}

class _OrderDetailsSection extends StatelessWidget {
  const _OrderDetailsSection({required this.order});

  final ProductionMapDefinition? order;

  @override
  Widget build(BuildContext context) {
    final order = this.order;
    if (order == null) {
      return const SizedBox.shrink();
    }
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.product_order'),
      children: [
        _InfoRow(
          label: context.l10n.productionText('worker.qr.report.order_number'),
          value: order.orderNumber,
        ),
        _InfoRow(
          label: context.l10n.productionText('worker.qr.report.product'),
          value: order.title,
        ),
        _InfoRow(
          label: context.l10n.productionText('worker.qr.report.product_code'),
          value: order.productCode,
        ),
        _InfoRow(
          label: context.l10n.productionText('worker.qr.report.customer'),
          value: order.customerName,
        ),
        _InfoRow(
          label: context.l10n.productionText('worker.qr.report.roll_count'),
          value:
              order.rollCount == null ? '' : _displayNumber(order.rollCount!),
        ),
        _InfoRow(
          label: context.l10n.productionText('worker.qr.report.width'),
          value: order.widthMm == null ? '' : _displayNumber(order.widthMm!),
        ),
        _InfoRow(
          label: context.l10n.productionText(
            'worker.qr.report.planned_weight',
          ),
          value: order.orderKg == null ? '' : _displayNumber(order.orderKg!),
        ),
        _InfoRow(
          label: context.l10n.productionText(
            'worker.qr.report.planned_length',
          ),
          value:
              order.baseLength == null ? '' : _displayNumber(order.baseLength!),
        ),
      ],
    );
  }
}

class _QueueStatesSection extends StatelessWidget {
  const _QueueStatesSection({required this.queueStates});

  final Map<String, Map<String, String>> queueStates;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.queue_status'),
      children: [
        for (final apparatus in queueStates.entries)
          for (final order in apparatus.value.entries)
            _InfoRow(
              label:
                  '${context.l10n.productionApparatusName(apparatus.key)} • ${order.key}',
              value: _stateLabel(order.value, l10n: context.l10n),
            ),
      ],
    );
  }
}

class _RawMaterialStatusSection extends StatelessWidget {
  const _RawMaterialStatusSection({
    required this.report,
    required this.queueState,
  });

  final AdminRawMaterialLookup report;
  final String queueState;

  @override
  Widget build(BuildContext context) {
    final materialName = _rawMaterialName(report);
    final lines = [
      context.l10n.productionText(
        'worker.qr.material.recorded',
        values: {
          'name': materialName,
          'quantity': _quantityTextFromParts(report.qty, report.uom),
        },
      ),
      if (report.itemGroup.trim().isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.group',
          values: {'group': report.itemGroup.trim()},
        ),
      if (report.warehouse.trim().isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.warehouse',
          values: {'warehouse': report.warehouse.trim()},
        ),
      _rawMaterialStatusSentence(report.status, context.l10n),
      if (queueState.trim().isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.queue_state',
          values: {
            'state': _stateDescription(queueState, l10n: context.l10n),
          },
        ),
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.material_status'),
      children: [
        for (final line in lines) _SentenceLine(text: line),
      ],
    );
  }
}

class _RawMaterialAssignmentSection extends StatelessWidget {
  const _RawMaterialAssignmentSection({
    required this.assignment,
    required this.orderTitle,
    required this.orderNumber,
    required this.queueState,
  });

  final AdminRawMaterialAssignment? assignment;
  final String orderTitle;
  final String orderNumber;
  final String queueState;

  @override
  Widget build(BuildContext context) {
    final assignment = this.assignment;
    if (assignment == null) {
      return _InfoSection(
        title: context.l10n.productionText('worker.qr.report.where_used'),
        children: [
          _SentenceLine(
            text: context.l10n.productionText('worker.qr.material.unassigned'),
          ),
        ],
      );
    }
    final title = orderTitle.trim().isNotEmpty
        ? orderTitle.trim()
        : assignment.orderId.trim();
    final number = orderNumber.trim();
    final lines = [
      if (number.isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.assigned_order_number',
          values: {'number': number, 'order': title},
        ),
      if (number.isEmpty)
        context.l10n.productionText(
          'worker.qr.material.assigned_order',
          values: {'order': title},
        ),
      context.l10n.productionText(
        'worker.qr.material.assigned_apparatus',
        values: {
          'apparatus':
              context.l10n.productionApparatusName(assignment.apparatus),
        },
      ),
      _apparatusPurposeSentence(assignment.apparatus, context.l10n),
      if (queueState.trim().isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.queue_state',
          values: {
            'state': _stateDescription(queueState, l10n: context.l10n),
          },
        ),
      if (assignment.assignedByName.trim().isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.assigned_by',
          values: {'name': assignment.assignedByName.trim()},
        ),
      if (assignment.assignedAt.trim().isNotEmpty)
        context.l10n.productionText(
          'worker.qr.material.assigned_at',
          values: {'time': assignment.assignedAt.trim()},
        ),
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.where_used'),
      children: [
        for (final line in lines) _SentenceLine(text: line),
      ],
    );
  }
}

class ProgressQrPassportChange {
  const ProgressQrPassportChange({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;
}

@visibleForTesting
List<ProgressQrPassportChange> progressQrCorrectionChanges(
  AdminProgressBatchCorrectionRecord correction, {
  AppLocalizations? l10n,
}) {
  const fields = <String>[
    'produced_qty',
    'uom',
    'diameter',
    'return_ink_kg',
    'lamination_print_leftover_rolls',
    'lamination_film_leftover_rolls',
    'rezka_bosma_waste',
    'rezka_lamination_waste',
    'rezka_edge_waste',
    'total_waste',
    'finished_goods_kg',
    'bobina_kg',
    'finished_goods_meter',
    'description',
  ];
  final changes = <ProgressQrPassportChange>[];
  for (final field in fields) {
    final before = correction.oldValues[field];
    final after = correction.newValues[field];
    if (_passportValuesEqual(before, after)) {
      continue;
    }
    changes.add(
      ProgressQrPassportChange(
        label: _passportFieldLabel(field, l10n: l10n),
        before: _passportCorrectionValue(
          field,
          before,
          correction.oldValues,
          l10n: l10n,
        ),
        after: _passportCorrectionValue(
          field,
          after,
          correction.newValues,
          l10n: l10n,
        ),
      ),
    );
  }
  return changes;
}

bool _passportValuesEqual(Object? before, Object? after) {
  if (before is num && after is num) {
    return before.toDouble() == after.toDouble();
  }
  return before?.toString().trim() == after?.toString().trim();
}

String _passportFieldLabel(String field, {AppLocalizations? l10n}) {
  final key = switch (field) {
    'produced_qty' => 'worker.qr.passport.produced_quantity',
    'uom' => 'worker.qr.passport.unit',
    'diameter' => 'worker.qr.passport.diameter',
    'return_ink_kg' => 'worker.qr.passport.returned_ink',
    'lamination_print_leftover_rolls' =>
      'worker.qr.passport.returned_print_rolls',
    'lamination_film_leftover_rolls' =>
      'worker.qr.passport.returned_film_rolls',
    'rezka_bosma_waste' => 'worker.qr.passport.print_waste',
    'rezka_lamination_waste' => 'worker.qr.passport.lamination_waste',
    'rezka_edge_waste' => 'worker.qr.passport.edge_waste',
    'total_waste' => 'worker.progress.qty.waste',
    'finished_goods_kg' => 'worker.qr.passport.finished_weight',
    'bobina_kg' => 'worker.qr.passport.bobbin_weight',
    'finished_goods_meter' => 'worker.qr.passport.finished_length',
    'description' => 'worker.wip.info.note',
    _ => null,
  };
  if (key == null) {
    return field;
  }
  return l10n?.productionText(key) ?? _passportFieldLabelFallback(field);
}

String _passportCorrectionValue(
  String field,
  Object? value,
  Map<String, dynamic> values, {
  AppLocalizations? l10n,
}) {
  if (value == null || value.toString().trim().isEmpty) {
    return l10n?.productionText('worker.qr.report.not_entered') ??
        'kiritilmagan';
  }
  if (value is num) {
    final unit = switch (field) {
      'produced_qty' => values['uom']?.toString().trim() ?? '',
      'lamination_print_leftover_rolls' ||
      'lamination_film_leftover_rolls' =>
        'rulon',
      'finished_goods_meter' => 'm',
      'diameter' => 'mm',
      'return_ink_kg' ||
      'rezka_bosma_waste' ||
      'rezka_lamination_waste' ||
      'rezka_edge_waste' ||
      'total_waste' ||
      'finished_goods_kg' ||
      'bobina_kg' =>
        'kg',
      _ => '',
    };
    return formatQuantityWithUnit(
      value.toDouble(),
      unit,
      trimTrailingZeros: true,
    );
  }
  return value.toString().trim();
}

String _passportFieldLabelFallback(String field) {
  return switch (field) {
    'produced_qty' => 'Ishlab chiqarilgan miqdor',
    'uom' => 'O‘lchov birligi',
    'diameter' => 'Diametr',
    'return_ink_kg' => 'Qaytgan bo‘yoq',
    'lamination_print_leftover_rolls' => 'Qaytgan bosma rulon',
    'lamination_film_leftover_rolls' => 'Qaytgan plyonka rulon',
    'rezka_bosma_waste' => 'Rezka bosma chiqindisi',
    'rezka_lamination_waste' => 'Rezka laminatsiya chiqindisi',
    'rezka_edge_waste' => 'Rezka chet chiqindisi',
    'total_waste' => 'Jami chiqindi',
    'finished_goods_kg' => 'Tayyor mahsulot og‘irligi',
    'bobina_kg' => 'Bobina og‘irligi',
    'finished_goods_meter' => 'Tayyor mahsulot uzunligi',
    'description' => 'Izoh',
    _ => field,
  };
}

class _PassportTimelineEntry {
  _PassportTimelineEntry.log(AdminProductionOrderLogEntry value)
      : log = value,
        correction = null,
        createdAtUnix = value.createdAtUnix;

  _PassportTimelineEntry.correction(AdminProgressBatchCorrectionRecord value)
      : log = null,
        correction = value,
        createdAtUnix = value.createdAtUnix;

  final AdminProductionOrderLogEntry? log;
  final AdminProgressBatchCorrectionRecord? correction;
  final int createdAtUnix;
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.logs,
    this.corrections = const [],
  });

  final List<AdminProductionOrderLogEntry> logs;
  final List<AdminProgressBatchCorrectionRecord> corrections;

  @override
  Widget build(BuildContext context) {
    final entries = <_PassportTimelineEntry>[
      for (final log in logs) _PassportTimelineEntry.log(log),
      for (final correction in corrections)
        _PassportTimelineEntry.correction(correction),
    ]..sort((left, right) {
        final byTime = left.createdAtUnix.compareTo(right.createdAtUnix);
        if (byTime != 0) {
          return byTime;
        }
        return left.log != null ? -1 : 1;
      });
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return _InfoSection(
      title: context.l10n.productionText('worker.qr.report.history'),
      children: [
        for (var index = 0; index < entries.length; index++)
          if (entries[index].log != null)
            _TimelineStep(index: index + 1, log: entries[index].log!)
          else
            _CorrectionTimelineStep(
              index: index + 1,
              correction: entries[index].correction!,
            ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.index, required this.log});

  final int index;
  final AdminProductionOrderLogEntry log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time = log.createdAtUnix > 0
        ? formatUnixSecondsLocalDateTime(log.createdAtUnix)
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
              '$index',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progressQrTimelineTitle(log.action, l10n: context.l10n),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _logSentence(log, time, context.l10n),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (log.transfer != null &&
                    log.transfer!.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.productionText('worker.qr.report.transfer_reason')}: ${_humanReason(log.transfer!.reason, context.l10n)}',
                  ),
                ],
                if (log.completedWithIssue &&
                    log.issueNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.productionText('worker.qr.report.completed_note')}: ${log.issueNote.trim()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionTimelineStep extends StatelessWidget {
  const _CorrectionTimelineStep({
    required this.index,
    required this.correction,
  });

  final int index;
  final AdminProgressBatchCorrectionRecord correction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = correction.actorDisplayName.trim().isNotEmpty
        ? correction.actorDisplayName.trim()
        : context.l10n.productionText('worker.wip.info.worker');
    final time = correction.createdAtUnix > 0
        ? formatUnixSecondsLocalDateTime(correction.createdAtUnix)
        : '';
    final changes = progressQrCorrectionChanges(correction, l10n: context.l10n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            child: Text(
              '$index',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.productionText('worker.qr.report.corrections'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '$actor ${context.l10n.productionText('worker.qr.report.corrections').toLowerCase()}.',
                    if (time.isNotEmpty)
                      '${context.l10n.productionText('worker.qr.report.time')}: $time.',
                    if (correction.reason.trim().isNotEmpty)
                      '${context.l10n.productionText('worker.qr.report.reason')}: ${correction.reason.trim()}.',
                  ].join(' '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (changes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final change in changes)
                    Text(
                      '${change.label}: ${change.before} → ${change.after}',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalRawMaterialSection extends StatelessWidget {
  const _TechnicalRawMaterialSection({required this.report});

  final AdminRawMaterialLookup report;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          context.l10n.productionText('worker.qr.report.technical'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.barcode'),
            value: report.barcode,
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.warehouse'),
            value: report.warehouse,
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.item_code'),
            value: report.itemCode,
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.item_name'),
            value: report.itemName,
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.item_group'),
            value: report.itemGroup,
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.wip.info.quantity'),
            value: _quantityTextFromParts(report.qty, report.uom),
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.status'),
            value: _rawMaterialStatusLabel(report.status, context.l10n),
          ),
          _InfoRow(
            label: context.l10n.productionText('worker.qr.report.receipt'),
            value: report.sourceReceiptId,
          ),
          _InfoRow(
            label: context.l10n.productionText(
              'worker.qr.report.reserved_order',
            ),
            value: report.reservedOrderId,
          ),
          if (report.assignment != null) ...[
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.assigned_order',
              ),
              value: report.assignment!.orderId,
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.assigned_machine',
              ),
              value: context.l10n.productionApparatusName(
                report.assignment!.apparatus,
              ),
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.assigned_by_ref',
              ),
              value: report.assignment!.assignedByRef,
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.assigned_by_name',
              ),
              value: report.assignment!.assignedByName,
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.assigned_at',
              ),
              value: report.assignment!.assignedAt,
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.stock_status',
              ),
              value: report.assignment!.stockStatus,
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.stock_warehouse',
              ),
              value: report.assignment!.stockWarehouse,
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.stock_quantity',
              ),
              value: _displayNumber(report.assignment!.stockQty),
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.received_quantity',
              ),
              value: _displayNumber(report.assignment!.receivedQty),
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.consumed_quantity',
              ),
              value: _displayNumber(report.assignment!.consumedQty),
            ),
            _InfoRow(
              label: context.l10n.productionText(
                'worker.qr.report.remaining_quantity',
              ),
              value: _displayNumber(report.assignment!.remainingQty),
            ),
          ],
        ],
      ),
    );
  }
}

class _SentenceLine extends StatelessWidget {
  const _SentenceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(
              Icons.circle,
              size: 7,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _qrPdfFilename(String prefix, String identifier) {
  final normalized = identifier
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${normalized.isEmpty ? prefix : '$prefix-$normalized'}.pdf';
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  Future<void> _toggleTorch() async {
    try {
      await controller.toggleTorch();
    } catch (_) {
      // Torch is device-specific.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, child) {
        if (!state.isInitialized ||
            !state.isRunning ||
            state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final enabled = state.torchState == TorchState.on;
        return IconButton.filledTonal(
          onPressed: _toggleTorch,
          icon:
              Icon(enabled ? Icons.flash_on_rounded : Icons.flash_off_rounded),
        );
      },
    );
  }
}

class _ScanStatusPill extends StatelessWidget {
  const _ScanStatusPill({
    required this.text,
    required this.isBusy,
    required this.isError,
  });

  final String text;
  final bool isBusy;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Colors.white.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(
                isError ? Icons.error_outline_rounded : Icons.qr_code_rounded,
                color: isError ? null : Colors.white,
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isError ? null : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                context.l10n.productionText('worker.action.retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedScannerView extends StatelessWidget {
  const _UnsupportedScannerView({
    required this.onBack,
    required this.onManualEntry,
  });

  final VoidCallback onBack;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              context.l10n.productionText('worker.scanner.unsupported'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onManualEntry,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: Text(
                context.l10n.productionText('worker.scanner.manual.title'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onBack,
              child: Text(
                context.l10n.productionText('worker.scanner.back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(String value, {AppLocalizations? l10n}) {
  final normalized = value.trim();
  final translation = switch (normalized) {
    'start' => ('worker.qr.status.started', 'Boshlandi'),
    'pause' => ('worker.action.pause', 'Pauza'),
    'detach_roll' => ('worker.qr.status.roll_removed', 'Rulon yechildi'),
    'resume' => ('worker.qr.status.resumed', 'Davom etdi'),
    'complete' => ('worker.qr.status.finished', 'Tugadi'),
    'pending' => ('worker.qr.status.waiting_start', 'Kutilmoqda'),
    'in_progress' || 'active' => ('worker.qr.status.in_progress', 'Jarayonda'),
    'paused' => ('worker.qr.status.paused', 'Pauzada'),
    'roll_detached' => ('worker.qr.status.roll_removed', 'Rulon yechilgan'),
    'completed' => ('worker.qr.status.completed', 'Tugagan'),
    'waiting' => ('worker.qr.status.waiting_work', 'Keyingi ishni kutmoqda'),
    'in_use' => ('worker.qr.status.in_progress', 'Ish jarayonida'),
    'processed' || 'consumed_by_next_stage' => (
        'worker.qr.status.used',
        'Keyingi bosqichda ishlatilgan'
      ),
    'free_wip' || 'finished_pending_acceptance' => (
        'worker.qr.status.waiting_stock',
        'Omborga topshirishni kutmoqda'
      ),
    'accepted_to_stock' => (
        'worker.qr.status.accepted_stock',
        'Omborga qabul qilingan'
      ),
    'waiting_next_stage' => (
        'worker.qr.status.waiting_next',
        'Keyingi bosqichni kutmoqda'
      ),
    _ => null,
  };
  if (translation == null) {
    return value;
  }
  return l10n?.productionText(translation.$1) ?? translation.$2;
}

String _stateDescription(String value, {AppLocalizations? l10n}) {
  final normalized = value.trim();
  final translation = switch (normalized) {
    'start' => ('worker.qr.state.started', 'ish boshlangan'),
    'pause' => ('worker.qr.state.paused', 'ish pauzaga olingan'),
    'detach_roll' || 'roll_detached' => (
        'worker.qr.state.roll_removed',
        'rulon yechilgan'
      ),
    'resume' => ('worker.qr.state.resumed', 'ish davom ettirilgan'),
    'complete' || 'completed' => ('worker.qr.state.completed', 'ish tugagan'),
    'pending' || 'waiting' => (
        'worker.qr.state.waiting_start',
        'ish boshlanishini kutyapti'
      ),
    'in_progress' || 'in_use' || 'active' => (
        'worker.qr.state.in_progress',
        'ish jarayonda'
      ),
    'paused' => ('worker.qr.state.paused', 'ish vaqtincha pauzada'),
    'stopped' || 'cancelled' => ('worker.qr.state.stopped', 'ish to‘xtatilgan'),
    'processed' || 'consumed_by_next_stage' => (
        'worker.qr.state.used_next',
        'keyingi bosqichda ishlatilgan'
      ),
    'free_wip' || 'finished_pending_acceptance' => (
        'worker.qr.state.waiting_stock',
        'omborga topshirishni kutmoqda'
      ),
    'accepted_to_stock' => (
        'worker.qr.status.accepted_stock',
        'omborga qabul qilingan'
      ),
    'waiting_next_stage' => (
        'worker.qr.state.waiting_next',
        'keyingi bosqichni kutmoqda'
      ),
    _ => null,
  };
  if (translation == null) {
    return _stateLabel(value, l10n: l10n).toLowerCase();
  }
  return l10n?.productionText(translation.$1) ?? translation.$2;
}

@visibleForTesting
String progressQrBatchDisplayState({
  required String batchStatus,
  required String queueState,
}) {
  final normalizedBatchStatus = batchStatus.trim();
  if (normalizedBatchStatus.isNotEmpty) {
    return normalizedBatchStatus;
  }
  return queueState;
}

@visibleForTesting
String progressQrHumanStatusLabel({
  required String workStatus,
  required String flowStatus,
  required String wipStatus,
  AppLocalizations? l10n,
}) {
  final work = workStatus.trim();
  final flow = flowStatus.trim();
  final product = wipStatus.trim();
  if (flow == 'free_wip' || flow == 'finished_pending_acceptance') {
    return work == 'completed'
        ? _qrText(
            l10n,
            'worker.qr.status.completed_pending_stock',
            'Ishlab chiqarish tugagan, omborga topshirishni kutmoqda',
          )
        : _qrText(
            l10n,
            'worker.qr.status.waiting_stock',
            'Omborga topshirishni kutmoqda',
          );
  }
  if (flow == 'accepted_to_stock') {
    return _qrText(
      l10n,
      'worker.qr.status.accepted_stock',
      'Omborga qabul qilingan',
    );
  }
  if (flow == 'waiting_next_stage') {
    return _qrText(
      l10n,
      'worker.qr.status.waiting_next',
      'Keyingi bosqichni kutmoqda',
    );
  }
  if (flow == 'consumed_by_next_stage') {
    return _qrText(
      l10n,
      'worker.qr.status.consumed_next',
      'Keyingi bosqichda ishlatilgan',
    );
  }
  if (flow == 'in_progress') {
    return _qrText(l10n, 'worker.qr.status.in_progress', 'Ish jarayonida');
  }
  if (work.isNotEmpty) {
    return switch (work) {
      'completed' ||
      'complete' =>
        _qrText(l10n, 'worker.qr.status.completed', 'Ishi tugagan'),
      'paused' ||
      'pause' =>
        _qrText(l10n, 'worker.qr.status.paused', 'Ishi vaqtincha to‘xtatilgan'),
      'roll_detached' ||
      'detach_roll' =>
        _qrText(l10n, 'worker.qr.status.roll_removed', 'Ruloni yechilgan'),
      'in_progress' ||
      'start' ||
      'resume' =>
        _qrText(l10n, 'worker.qr.status.in_progress', 'Ish jarayonida'),
      'pending' || 'waiting' => _qrText(
          l10n, 'worker.qr.status.waiting_start', 'Ish boshlanishini kutmoqda'),
      _ => _stateLabel(work, l10n: l10n),
    };
  }
  return switch (product) {
    'waiting' => _qrText(
        l10n,
        'worker.qr.status.waiting_work',
        'Keyingi ishni kutmoqda',
      ),
    'in_use' => _qrText(l10n, 'worker.qr.status.in_progress', 'Ish jarayonida'),
    'processed' => _qrText(
        l10n,
        'worker.qr.status.used',
        'Keyingi bosqichda ishlatilgan',
      ),
    _ => _stateLabel(product, l10n: l10n),
  };
}

@visibleForTesting
String progressQrTechnicalProductStatusLabel({
  required String workStatus,
  required String flowStatus,
  required String wipStatus,
  AppLocalizations? l10n,
}) {
  final flow = flowStatus.trim();
  final status = switch (flow) {
    'free_wip' || 'finished_pending_acceptance' => _lowercaseFirst(
        _qrText(l10n, 'worker.qr.status.free_wip', 'erkin WIP holatida'),
      ),
    'accepted_to_stock' => _lowercaseFirst(
        _qrText(
          l10n,
          'worker.qr.status.accepted_stock',
          'omborga qabul qilingan',
        ),
      ),
    'waiting_next_stage' => _lowercaseFirst(
        _qrText(
          l10n,
          'worker.qr.status.waiting_next',
          'keyingi bosqichni kutmoqda',
        ),
      ),
    'consumed_by_next_stage' => _lowercaseFirst(
        _qrText(
          l10n,
          'worker.qr.status.consumed_next',
          'keyingi bosqichda ishlatilgan',
        ),
      ),
    _ => progressQrHumanStatusLabel(
        workStatus: workStatus,
        flowStatus: flowStatus,
        wipStatus: wipStatus,
        l10n: l10n,
      ),
  };
  if (status.trim().isEmpty) {
    return '';
  }
  final productKind = switch (flow) {
    'free_wip' ||
    'finished_pending_acceptance' ||
    'accepted_to_stock' =>
      _qrText(l10n, 'worker.qr.status.product_ready', 'Tayyor mahsulot'),
    _ => _qrText(
        l10n,
        'worker.qr.status.semi_finished',
        'Yarim tayyor mahsulot',
      ),
  };
  return _qrText(
    l10n,
    'worker.qr.status.label',
    '$productKind holati: $status',
    values: {'kind': productKind, 'status': status},
  );
}

String _apparatusPurposeSentence(String apparatus, [AppLocalizations? l10n]) {
  final lower = apparatus.trim().toLowerCase();
  if (lower.contains('lamin')) {
    return _qrText(
      l10n,
      'worker.qr.apparatus.purpose.lamination',
      'U yerda mahsulot laminatsiya qilinadi.',
    );
  }
  if (lower.contains('pechat') || lower.contains('bosma')) {
    return _qrText(
      l10n,
      'worker.qr.apparatus.purpose.printing',
      'U yerda mahsulotga pechat/bosma ishi bajariladi.',
    );
  }
  if (lower.contains('rezka') || lower.contains('kes')) {
    return _qrText(
      l10n,
      'worker.qr.apparatus.purpose.cutting',
      'U yerda mahsulot kesiladi, ya’ni rezka ishi bajariladi.',
    );
  }
  if (lower.contains('qolip')) {
    return _qrText(
      l10n,
      'worker.qr.apparatus.purpose.mold',
      'U yerda qolip bilan bog‘liq ishlab chiqarish ishi bajariladi.',
    );
  }
  return _qrText(
    l10n,
    'worker.qr.apparatus.purpose.next',
    'U yerda keyingi ishlab chiqarish ishi bajariladi.',
  );
}

String _humanReason(String value, [AppLocalizations? l10n]) {
  final reason = value.trim();
  if (reason.isEmpty) {
    return '';
  }
  return switch (reason) {
    'apparatus_issue' => _qrText(
        l10n,
        'worker.qr.reason.apparatus_issue',
        'Aparatdagi nosozlik',
      ),
    'worker_issue' => _qrText(
        l10n,
        'worker.qr.reason.worker_issue',
        'Xodim bilan bog‘liq sabab',
      ),
    'material_issue' => _qrText(
        l10n,
        'worker.qr.reason.material_issue',
        'Homashyo bilan bog‘liq sabab',
      ),
    'quality_issue' => _qrText(
        l10n,
        'worker.qr.reason.quality_issue',
        'Sifat bilan bog‘liq sabab',
      ),
    'other' => _qrText(l10n, 'worker.qr.reason.other', 'Boshqa sabab'),
    _ => reason.contains('_')
        ? '${reason.replaceAll('_', ' ')[0].toUpperCase()}${reason.replaceAll('_', ' ').substring(1)}'
        : reason,
  };
}

@visibleForTesting
String progressQrTimelineTitle(
  String action, {
  AppLocalizations? l10n,
}) {
  final normalized = action.trim();
  final translation = switch (normalized) {
    'start' => ('worker.qr.timeline.start', 'Bosqichdagi ish boshlandi'),
    'pause' => (
        'worker.qr.timeline.pause',
        'Bosqichdagi ish vaqtincha to‘xtatildi',
      ),
    'detach_roll' => (
        'worker.qr.timeline.detach_roll',
        'Bosqichdagi rulon yechildi'
      ),
    'resume' => (
        'worker.qr.timeline.resume',
        'Bosqichdagi ish davom ettirildi'
      ),
    'roll_complete' => (
        'worker.qr.timeline.roll_complete',
        'Bitta rulon yakunlandi'
      ),
    'complete' => ('worker.qr.timeline.complete', 'Bosqichdagi ish yakunlandi'),
    _ => null,
  };
  if (translation == null) {
    return _stateLabel(action, l10n: l10n);
  }
  return l10n?.productionText(translation.$1) ?? translation.$2;
}

String _logSentence(AdminProductionOrderLogEntry log, String time,
    [AppLocalizations? l10n]) {
  final actor = log.actorDisplayName.trim().isNotEmpty
      ? log.actorDisplayName.trim()
      : _qrText(l10n, 'worker.qr.report.editor', 'Ijrochi');
  final apparatus =
      l10n?.productionApparatusName(log.apparatus) ?? log.apparatus.trim();
  final actionKey = switch (log.action.trim()) {
    'start' => 'worker.qr.timeline.action.start',
    'pause' => 'worker.qr.timeline.action.pause',
    'detach_roll' => 'worker.qr.timeline.action.detach_roll',
    'resume' => 'worker.qr.timeline.action.resume',
    'roll_complete' => 'worker.qr.timeline.action.roll_complete',
    'complete' => 'worker.qr.timeline.action.complete',
    _ => 'worker.qr.timeline.action.generic',
  };
  final actionSentence = _qrText(
    l10n,
    actionKey,
    _logSentenceFallback(log.action, actor, apparatus),
    values: {'actor': actor, 'apparatus': apparatus},
  );
  return [
    actionSentence,
    if (time.trim().isNotEmpty)
      _qrText(
        l10n,
        'worker.qr.timeline.time',
        'Vaqt: $time.',
        values: {'time': time},
      ),
  ].join(' ');
}

String _currentQueueState(
  Map<String, Map<String, String>> queueStates,
  String orderId,
  String apparatus,
) {
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) {
    return '';
  }
  final normalizedApparatus = apparatus.trim().toLowerCase();
  if (normalizedApparatus.isNotEmpty) {
    for (final entry in queueStates.entries) {
      if (entry.key.trim().toLowerCase() != normalizedApparatus) {
        continue;
      }
      final value = entry.value[normalizedOrderId]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
  }
  for (final states in queueStates.values) {
    final value = states[normalizedOrderId]?.trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _quantityTextFromParts(double qty, String uom) {
  return formatQuantityWithUnit(
    qty,
    uom,
    trimTrailingZeros: true,
  );
}

String _displayNumber(num value) {
  final asDouble = value.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return asDouble.toInt().toString();
  }
  return asDouble.toString();
}

String _rawMaterialStatusLabel(String value, [AppLocalizations? l10n]) {
  final key = switch (value.trim()) {
    'available' => 'worker.qr.material.status_available',
    'in_use' => 'worker.qr.material.status_in_use',
    'consumed' => 'worker.qr.material.status_consumed',
    'reserved' => 'worker.qr.material.status_reserved',
    _ => null,
  };
  if (key == null) {
    return value;
  }
  return _qrText(l10n, key, _rawMaterialStatusLabelFallback(value));
}

String _rawMaterialStatusSentence(String value, [AppLocalizations? l10n]) {
  final key = switch (value.trim()) {
    'available' => 'worker.qr.material.status_available',
    'in_use' => 'worker.qr.material.status_in_use',
    'consumed' => 'worker.qr.material.status_consumed',
    'reserved' => 'worker.qr.material.status_reserved',
    _ => null,
  };
  if (value.trim().isEmpty) {
    return '';
  }
  if (key != null) {
    return _qrText(
      l10n,
      key,
      _rawMaterialStatusSentenceFallback(value),
    );
  }
  return _qrText(
    l10n,
    'worker.qr.material.status_generic',
    'Homashyo holati: ${_rawMaterialStatusLabel(value).toLowerCase()}.',
    values: {
      'status': _rawMaterialStatusLabel(value, l10n).toLowerCase(),
    },
  );
}

String _rawMaterialName(AdminRawMaterialLookup report) {
  if (report.itemName.trim().isNotEmpty) {
    return report.itemName.trim();
  }
  if (report.itemCode.trim().isNotEmpty) {
    return report.itemCode.trim();
  }
  return 'Homashyo';
}

String _rawMaterialSummary(
  AdminRawMaterialLookup report,
  String queueState,
  AppLocalizations? l10n,
) {
  final assignment = report.assignment;
  final order = report.order;
  final materialName = _rawMaterialName(report);
  final quantity = _quantityTextFromParts(report.qty, report.uom);
  if (assignment == null) {
    return [
      _qrText(
        l10n,
        'worker.qr.material.scanned',
        '$materialName homashyosi scan qilindi.',
        values: {'name': materialName},
      ),
      if (quantity.trim().isNotEmpty)
        _qrText(
          l10n,
          'worker.qr.material.quantity',
          'Miqdori: $quantity.',
          values: {'quantity': quantity},
        ),
      _rawMaterialStatusSentence(report.status, l10n),
      _qrText(
        l10n,
        'worker.qr.material.unassigned',
        'Bu homashyo hali hech qaysi orderga ulanmagan.',
      ),
    ].where((item) => item.trim().isNotEmpty).join(' ');
  }
  final orderTitle = order?.title.trim().isNotEmpty == true
      ? order!.title.trim()
      : assignment.orderId.trim();
  final orderNumber = order?.orderNumber.trim() ?? '';
  return [
    _qrText(
      l10n,
      'worker.qr.material.scanned',
      '$materialName homashyosi scan qilindi.',
      values: {'name': materialName},
    ),
    if (quantity.trim().isNotEmpty)
      _qrText(
        l10n,
        'worker.qr.material.quantity',
        'Miqdori: $quantity.',
        values: {'quantity': quantity},
      ),
    if (orderNumber.isNotEmpty)
      _qrText(
        l10n,
        'worker.qr.material.assigned_order_number',
        'Bu homashyo Zakaz $orderNumber bo‘yicha $orderTitle orderiga ulangan.',
        values: {'number': orderNumber, 'order': orderTitle},
      ),
    if (orderNumber.isEmpty)
      _qrText(
        l10n,
        'worker.qr.material.assigned_order',
        'Bu homashyo $orderTitle orderiga ulangan.',
        values: {'order': orderTitle},
      ),
    _qrText(
      l10n,
      'worker.qr.material.assigned_apparatus',
      'Homashyo ${assignment.apparatus} aparatida ishlatiladi.',
      values: {'apparatus': assignment.apparatus},
    ),
    _apparatusPurposeSentence(assignment.apparatus, l10n),
    if (queueState.trim().isNotEmpty)
      _qrText(
        l10n,
        'worker.qr.material.queue_state',
        'Orderning shu aparatdagi holati: ${_stateDescription(queueState)}.',
        values: {'state': _stateDescription(queueState, l10n: l10n)},
      ),
    if (assignment.assignedByName.trim().isNotEmpty)
      _qrText(
        l10n,
        'worker.qr.material.assigned_by',
        '${assignment.assignedByName.trim()} tomonidan ulangan.',
        values: {'name': assignment.assignedByName.trim()},
      ),
  ].join(' ');
}

String _qrText(
  AppLocalizations? l10n,
  String key,
  String fallback, {
  Map<String, Object?> values = const {},
}) {
  return l10n?.productionText(key, values: values) ?? fallback;
}

String _lowercaseFirst(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toLowerCase()}${value.substring(1)}';
}

String _logSentenceFallback(String action, String actor, String apparatus) {
  return switch (action.trim()) {
    'start' => '$actor $apparatus bosqichida ishni boshladi.',
    'pause' => '$actor $apparatus bosqichidagi ishni vaqtincha to‘xtatdi.',
    'detach_roll' => '$actor $apparatus bosqichidagi rulonni yechdi.',
    'resume' => '$actor $apparatus bosqichidagi ishni davom ettirdi.',
    'roll_complete' =>
      '$actor $apparatus bosqichidagi bitta rulonni yakunladi.',
    'complete' => '$actor $apparatus bosqichidagi ishni yakunladi.',
    _ => '$actor $apparatus bosqichida amal bajardi.',
  };
}

String _rawMaterialStatusLabelFallback(String value) {
  return switch (value.trim()) {
    'available' => 'Omborda mavjud',
    'in_use' => 'Ishlatilmoqda',
    'consumed' => 'Ishlatib bo‘lingan',
    'reserved' => 'Band qilingan',
    _ => value,
  };
}

String _rawMaterialStatusSentenceFallback(String value) {
  return switch (value.trim()) {
    'available' => 'Bu homashyo omborda mavjud.',
    'in_use' => 'Bu homashyo ishlab chiqarishda ishlatilmoqda.',
    'consumed' => 'Bu homashyo ishlatib bo‘lingan.',
    'reserved' => 'Bu homashyo order uchun band qilingan.',
    _ =>
      'Homashyo holati: ${_rawMaterialStatusLabelFallback(value).toLowerCase()}.',
  };
}
