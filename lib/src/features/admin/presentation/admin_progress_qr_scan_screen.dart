import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/production_map_models.dart';
import 'admin_progress_qr_passport.dart';
import 'admin_progress_qr_scan_pdf.dart';

class AdminProgressQrScanArgs {
  const AdminProgressQrScanArgs({this.scanOnly = false});

  final bool scanOnly;
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
  String _statusText = 'Progress QR kodni ramkaga keltiring';
  AdminProgressQrReport? _report;
  AdminPaddonSnapshot? _paddonReport;
  AdminRawMaterialLookup? _rawMaterialReport;
  String? _errorText;
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
        _errorText = null;
        _statusText = 'Progress QR kodni ramkaga keltiring';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _errorText = 'Kamera ochilmadi';
        _statusText = 'Kamera ochilmadi';
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
      setState(() => _statusText = 'QR bo‘sh yoki noto‘g‘ri');
      return;
    }
    await _handleQrPayload(qrPayload);
  }

  Future<void> _handleQrPayload(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (normalized.isEmpty) {
      if (mounted) {
        setState(() => _statusText = 'QR bo‘sh yoki noto‘g‘ri');
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
      setState(() => _statusText = 'QR bo‘sh yoki noto‘g‘ri');
      return;
    }
    setState(() {
      _processing = true;
      _statusText = 'Order flow yig‘ilmoqda...';
      _errorText = null;
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
        _statusText = 'Report tayyor';
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
            _statusText = 'Paddon report tayyor';
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
            _statusText = 'Homashyo report tayyor';
          });
          return;
        } catch (_) {
          // Show the original QR error below.
        }
      }
      if (!mounted) {
        return;
      }
      final message = _messageForError(error);
      setState(() {
        _processing = false;
        _errorText = message;
        _statusText = message;
      });
      await _startScanner();
    }
  }

  Future<void> _showManualQrDialog() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('QR ni qo‘lda kiritish'),
          content: TextField(
            controller: _manualQrController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'QR payload',
              hintText: '4001...',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_manualQrController.text),
              child: const Text('Tekshirish'),
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
      _errorText = null;
      _statusText = 'Progress QR kodni ramkaga keltiring';
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
          ? AdminProgressQrScanPdf.buildProgress(report)
          : AdminProgressQrScanPdf.buildRawMaterial(rawMaterialReport!);
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
          const SnackBar(
              content: Text('PDF tayyorlash yoki ulashishda xatolik')),
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

  String _messageForError(Object error) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'progress_batch_not_found' => 'Progress QR topilmadi',
        'progress_batch_not_accepted' => 'Bu QR order oqimiga mos emas',
        _ => error.message.isEmpty ? 'QR report olinmadi' : error.message,
      };
    }
    return 'QR report olinmadi';
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
        title: 'QR scan',
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
                            statusText: _statusText,
                            processing: _processing,
                            errorText: _errorText,
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
                message: 'Kamera ochilmadi. Ruxsatlarni tekshiring.',
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
                  label: const Text('QR ni qo‘lda kiritish'),
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
    final passport = buildProgressQrPassport(report);
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
                            ? 'Bu eski QR. Hozirgi holat quyida.'
                            : 'QR hozirgi oqimga mos.',
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
                      'Zakaz ${passport.orderNumber}',
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
          label: const Text('Yana scan qilish'),
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
                        'Bu homashyo QR.',
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
                    _rawMaterialStatusLabel(report.status),
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
          title: 'Homashyo haqida',
          children: [
            Text(
              _rawMaterialSummary(report, queueState),
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
          label: const Text('Yana scan qilish'),
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
                        'Paddon QR',
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
                  '${report.items.length} ta WIP shu package ichida',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (paddon.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Joylashuv: ${paddon.location}'),
                ],
                if (paddon.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Izoh: ${paddon.note}'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoSection(
          title: 'Paddon ichidagi WIP lar (${report.items.length})',
          children: report.items.isEmpty
              ? const [
                  _SentenceLine(text: 'Bu package ichida hozircha WIP yo‘q.'),
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
          label: const Text('Yana scan qilish'),
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
    );
    final location = [
      batch.currentLocation.trim(),
      batch.currentApparatus.trim().isNotEmpty
          ? batch.currentApparatus.trim()
          : batch.apparatus.trim(),
    ].where((item) => item.isNotEmpty).join(' • ');
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. ${title.isEmpty ? 'WIP' : title}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Order', value: batch.orderId),
            _InfoRow(label: 'EPC / QR', value: batch.qrPayload),
            _InfoRow(label: 'Batch ID', value: batch.batchId),
            _InfoRow(
                label: 'Holati', value: status.isEmpty ? batch.status : status),
            _InfoRow(label: 'Joylashuv', value: location),
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
        label: Text(isBusy ? 'PDF tayyorlanmoqda...' : 'PDF ulashish'),
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
      title: 'Buyurtma rejasi',
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
      title: 'Ishlab chiqarish bosqichlari',
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
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Hozirgi'),
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
      title: 'Tahrirlar',
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
                    label: 'Tahrir qilgan',
                    value: corrections[index].editor,
                  ),
                  _InfoRow(label: 'Vaqt', value: corrections[index].time),
                  _InfoRow(label: 'Sabab', value: corrections[index].reason),
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
      title: 'Muammolar va o‘zgarishlar',
      children: [
        for (final issue in issues) ...[
          _InfoRow(label: issue.title, value: issue.description),
          if (issue.time.isNotEmpty) _InfoRow(label: 'Vaqt', value: issue.time),
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
      title: 'Mahsulot va buyurtma',
      children: [
        _InfoRow(label: 'Buyurtma raqami', value: order.orderNumber),
        _InfoRow(label: 'Mahsulot', value: order.title),
        _InfoRow(label: 'Mahsulot kodi', value: order.productCode),
        _InfoRow(label: 'Mijoz', value: order.customerName),
        _InfoRow(
          label: 'Rulon soni',
          value:
              order.rollCount == null ? '' : _displayNumber(order.rollCount!),
        ),
        _InfoRow(
          label: 'Eni, mm',
          value: order.widthMm == null ? '' : _displayNumber(order.widthMm!),
        ),
        _InfoRow(
          label: 'Rejadagi og‘irlik, kg',
          value: order.orderKg == null ? '' : _displayNumber(order.orderKg!),
        ),
        _InfoRow(
          label: 'Rejadagi uzunlik',
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
      title: 'Aparat navbatlarining holati',
      children: [
        for (final apparatus in queueStates.entries)
          for (final order in apparatus.value.entries)
            _InfoRow(
              label: '${apparatus.key} • ${order.key}',
              value: order.value,
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
      '$materialName ${_quantityTextFromParts(report.qty, report.uom)} miqdorda qayd qilingan.',
      if (report.itemGroup.trim().isNotEmpty)
        'Bu homashyo ${report.itemGroup.trim()} guruhiga kiradi.',
      if (report.warehouse.trim().isNotEmpty)
        'Hozirgi ombor: ${report.warehouse.trim()}.',
      _rawMaterialStatusSentence(report.status),
      if (queueState.trim().isNotEmpty)
        'Ulangan order hozir ${_stateDescription(queueState)}.',
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: 'Homashyo holati',
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
      return const _InfoSection(
        title: 'Qayerga ishlatiladi',
        children: [
          _SentenceLine(
            text:
                'Bu homashyo hali hech qaysi orderga ulanmagan. Uni scan qilgan odam hozircha faqat ombordagi homashyo ma’lumotini ko‘radi.',
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
        'Bu homashyo Zakaz $number bo‘yicha $title orderiga ulangan.',
      if (number.isEmpty) 'Bu homashyo $title orderiga ulangan.',
      'Homashyo ${assignment.apparatus} aparatida ishlatilishi kerak.',
      _apparatusPurposeSentence(assignment.apparatus),
      if (queueState.trim().isNotEmpty)
        'Orderning shu aparatdagi holati: ${_stateDescription(queueState)}.',
      if (assignment.assignedByName.trim().isNotEmpty)
        '${assignment.assignedByName.trim()} bu homashyoni orderga ulagan.',
      if (assignment.assignedAt.trim().isNotEmpty)
        'Ulangan vaqt: ${assignment.assignedAt.trim()}.',
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: 'Qayerga ishlatiladi',
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
  AdminProgressBatchCorrectionRecord correction,
) {
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
        label: _passportFieldLabel(field),
        before: _passportCorrectionValue(
          field,
          before,
          correction.oldValues,
        ),
        after: _passportCorrectionValue(
          field,
          after,
          correction.newValues,
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

String _passportFieldLabel(String field) {
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

String _passportCorrectionValue(
  String field,
  Object? value,
  Map<String, dynamic> values,
) {
  if (value == null || value.toString().trim().isEmpty) {
    return 'kiritilmagan';
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
      title: 'Mahsulot tarixi',
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
                  progressQrTimelineTitle(log.action),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _logSentence(log, time),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (log.transfer != null &&
                    log.transfer!.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                      'O‘tkazish sababi: ${_humanReason(log.transfer!.reason)}'),
                ],
                if (log.completedWithIssue &&
                    log.issueNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Izoh: ${log.issueNote.trim()}',
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
        : 'Mas’ul xodim';
    final time = correction.createdAtUnix > 0
        ? formatUnixSecondsLocalDateTime(correction.createdAtUnix)
        : '';
    final changes = progressQrCorrectionChanges(correction);
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
                  'Ma’lumot tahrirlandi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '$actor ma’lumotni tahrirladi.',
                    if (time.isNotEmpty) 'Vaqt: $time.',
                    if (correction.reason.trim().isNotEmpty)
                      'Sabab: ${correction.reason.trim()}.',
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
        title: const Text(
          'Texnik homashyo ma’lumot',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _InfoRow(label: 'QR / barcode', value: report.barcode),
          _InfoRow(label: 'Ombor', value: report.warehouse),
          _InfoRow(label: 'Item code', value: report.itemCode),
          _InfoRow(label: 'Item nomi', value: report.itemName),
          _InfoRow(label: 'Item group', value: report.itemGroup),
          _InfoRow(
            label: 'Miqdor',
            value: _quantityTextFromParts(report.qty, report.uom),
          ),
          _InfoRow(label: 'Holat', value: report.status),
          _InfoRow(label: 'Receipt', value: report.sourceReceiptId),
          _InfoRow(label: 'Reserved order', value: report.reservedOrderId),
          if (report.assignment != null) ...[
            _InfoRow(
              label: 'Assigned order',
              value: report.assignment!.orderId,
            ),
            _InfoRow(
              label: 'Assigned apparatus',
              value: report.assignment!.apparatus,
            ),
            _InfoRow(
              label: 'Assigned by ref',
              value: report.assignment!.assignedByRef,
            ),
            _InfoRow(
              label: 'Assigned by name',
              value: report.assignment!.assignedByName,
            ),
            _InfoRow(
              label: 'Assigned at',
              value: report.assignment!.assignedAt,
            ),
            _InfoRow(
              label: 'Stock status',
              value: report.assignment!.stockStatus,
            ),
            _InfoRow(
              label: 'Stock warehouse',
              value: report.assignment!.stockWarehouse,
            ),
            _InfoRow(
              label: 'Stock quantity',
              value: _displayNumber(report.assignment!.stockQty),
            ),
            _InfoRow(
              label: 'Received quantity',
              value: _displayNumber(report.assignment!.receivedQty),
            ),
            _InfoRow(
              label: 'Consumed quantity',
              value: _displayNumber(report.assignment!.consumedQty),
            ),
            _InfoRow(
              label: 'Remaining quantity',
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
              label: const Text('Qayta urinish'),
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
            const Text(
              'Bu qurilmada kamera orqali QR scan qo‘llab-quvvatlanmaydi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onManualEntry,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('QR ni qo‘lda kiritish'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onBack,
              child: const Text('Orqaga'),
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(String value) {
  return switch (value.trim()) {
    'start' => 'Boshlandi',
    'pause' => 'Pauza',
    'detach_roll' => 'Rulon yechildi',
    'resume' => 'Davom etdi',
    'complete' => 'Tugadi',
    'pending' => 'Kutilmoqda',
    'in_progress' => 'Jarayonda',
    'paused' => 'Pauzada',
    'roll_detached' => 'Rulon yechilgan',
    'completed' => 'Tugagan',
    'waiting' => 'Keyingi ishni kutmoqda',
    'in_use' => 'Ish jarayonida',
    'processed' => 'Keyingi bosqichda ishlatilgan',
    'free_wip' ||
    'finished_pending_acceptance' =>
      'Omborga topshirishni kutmoqda',
    'accepted_to_stock' => 'Omborga qabul qilingan',
    'waiting_next_stage' => 'Keyingi bosqichni kutmoqda',
    'consumed_by_next_stage' => 'Keyingi bosqichda ishlatilgan',
    'active' => 'Jarayonda',
    _ => value,
  };
}

String _stateDescription(String value) {
  return switch (value.trim()) {
    'start' => 'ish boshlangan',
    'pause' => 'ish pauzaga olingan',
    'detach_roll' => 'rulon yechilgan',
    'resume' => 'ish davom ettirilgan',
    'complete' || 'completed' => 'ish tugagan',
    'pending' || 'waiting' => 'ish boshlanishini kutyapti',
    'in_progress' => 'ish jarayonda',
    'paused' => 'ish vaqtincha pauzada',
    'roll_detached' => 'rulon apparatdan yechilgan',
    'stopped' || 'cancelled' => 'ish to‘xtatilgan',
    'in_use' => 'ish jarayonida',
    'processed' => 'keyingi bosqichda ishlatilgan',
    'free_wip' ||
    'finished_pending_acceptance' =>
      'omborga topshirishni kutmoqda',
    'accepted_to_stock' => 'omborga qabul qilingan',
    'waiting_next_stage' => 'keyingi bosqichni kutmoqda',
    'consumed_by_next_stage' => 'keyingi bosqichda ishlatilgan',
    _ => _stateLabel(value).toLowerCase(),
  };
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
}) {
  final work = workStatus.trim();
  final flow = flowStatus.trim();
  final product = wipStatus.trim();
  if (flow == 'free_wip' || flow == 'finished_pending_acceptance') {
    return work == 'completed'
        ? 'Ishlab chiqarish tugagan, omborga topshirishni kutmoqda'
        : 'Omborga topshirishni kutmoqda';
  }
  if (flow == 'accepted_to_stock') {
    return 'Omborga qabul qilingan';
  }
  if (flow == 'waiting_next_stage') {
    return 'Keyingi bosqichni kutmoqda';
  }
  if (flow == 'consumed_by_next_stage') {
    return 'Keyingi bosqichda ishlatilgan';
  }
  if (flow == 'in_progress') {
    return 'Ish jarayonida';
  }
  if (work.isNotEmpty) {
    return switch (work) {
      'completed' || 'complete' => 'Ishi tugagan',
      'paused' || 'pause' => 'Ishi vaqtincha to‘xtatilgan',
      'roll_detached' || 'detach_roll' => 'Ruloni yechilgan',
      'in_progress' || 'start' || 'resume' => 'Ish jarayonida',
      'pending' || 'waiting' => 'Ish boshlanishini kutmoqda',
      _ => _stateLabel(work),
    };
  }
  return switch (product) {
    'waiting' => 'Keyingi ishni kutmoqda',
    'in_use' => 'Ish jarayonida',
    'processed' => 'Keyingi bosqichda ishlatilgan',
    _ => _stateLabel(product),
  };
}

@visibleForTesting
String progressQrTechnicalProductStatusLabel({
  required String workStatus,
  required String flowStatus,
  required String wipStatus,
}) {
  final flow = flowStatus.trim();
  final status = switch (flow) {
    'free_wip' || 'finished_pending_acceptance' => 'erkin WIP holatida',
    'accepted_to_stock' => 'omborga qabul qilingan',
    'waiting_next_stage' => 'keyingi bosqichni kutmoqda',
    'consumed_by_next_stage' => 'keyingi bosqichda ishlatilgan',
    _ => progressQrHumanStatusLabel(
        workStatus: workStatus,
        flowStatus: flowStatus,
        wipStatus: wipStatus,
      ).toLowerCase(),
  };
  if (status.trim().isEmpty) {
    return '';
  }
  final productKind = switch (flow) {
    'free_wip' ||
    'finished_pending_acceptance' ||
    'accepted_to_stock' =>
      'Tayyor mahsulot',
    _ => 'Yarim tayyor mahsulot',
  };
  return '$productKind holati: $status';
}

String _apparatusPurposeSentence(String apparatus) {
  final lower = apparatus.trim().toLowerCase();
  if (lower.contains('lamin')) {
    return 'U yerda mahsulot laminatsiya qilinadi.';
  }
  if (lower.contains('pechat') || lower.contains('bosma')) {
    return 'U yerda mahsulotga pechat/bosma ishi bajariladi.';
  }
  if (lower.contains('rezka') || lower.contains('kes')) {
    return 'U yerda mahsulot kesiladi, ya’ni rezka ishi bajariladi.';
  }
  if (lower.contains('qolip')) {
    return 'U yerda qolip bilan bog‘liq ishlab chiqarish ishi bajariladi.';
  }
  return 'U yerda keyingi ishlab chiqarish ishi bajariladi.';
}

String _humanReason(String value) {
  final reason = value.trim();
  if (reason.isEmpty) {
    return '';
  }
  return switch (reason) {
    'apparatus_issue' => 'Aparatdagi nosozlik',
    'worker_issue' => 'Xodim bilan bog‘liq sabab',
    'material_issue' => 'Homashyo bilan bog‘liq sabab',
    'quality_issue' => 'Sifat bilan bog‘liq sabab',
    'other' => 'Boshqa sabab',
    _ => reason.contains('_')
        ? '${reason.replaceAll('_', ' ')[0].toUpperCase()}${reason.replaceAll('_', ' ').substring(1)}'
        : reason,
  };
}

@visibleForTesting
String progressQrTimelineTitle(String action) {
  return switch (action.trim()) {
    'start' => 'Bosqichdagi ish boshlandi',
    'pause' => 'Bosqichdagi ish vaqtincha to‘xtatildi',
    'detach_roll' => 'Bosqichdagi rulon yechildi',
    'resume' => 'Bosqichdagi ish davom ettirildi',
    'roll_complete' => 'Bitta rulon yakunlandi',
    'complete' => 'Bosqichdagi ish yakunlandi',
    _ => _stateLabel(action),
  };
}

String _logSentence(AdminProductionOrderLogEntry log, String time) {
  final actor = log.actorDisplayName.trim().isNotEmpty
      ? log.actorDisplayName.trim()
      : 'Ijrochi';
  final apparatus = log.apparatus.trim();
  final actionSentence = switch (log.action.trim()) {
    'start' => '$actor $apparatus bosqichida ishni boshladi.',
    'pause' => '$actor $apparatus bosqichidagi ishni vaqtincha to‘xtatdi.',
    'detach_roll' => '$actor $apparatus bosqichidagi rulonni yechdi.',
    'resume' => '$actor $apparatus bosqichidagi ishni davom ettirdi.',
    'roll_complete' =>
      '$actor $apparatus bosqichidagi bitta rulonni yakunladi.',
    'complete' => '$actor $apparatus bosqichidagi ishni yakunladi.',
    _ => '$actor $apparatus bosqichida amal bajardi.',
  };
  return [
    actionSentence,
    if (time.trim().isNotEmpty) 'Vaqt: $time.',
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

String _rawMaterialStatusLabel(String value) {
  return switch (value.trim()) {
    'available' => 'Omborda mavjud',
    'in_use' => 'Ishlatilmoqda',
    'consumed' => 'Ishlatib bo‘lingan',
    'reserved' => 'Band qilingan',
    _ => value,
  };
}

String _rawMaterialStatusSentence(String value) {
  return switch (value.trim()) {
    'available' => 'Bu homashyo omborda mavjud.',
    'in_use' => 'Bu homashyo ishlab chiqarishda ishlatilmoqda.',
    'consumed' => 'Bu homashyo ishlatib bo‘lingan.',
    'reserved' => 'Bu homashyo order uchun band qilingan.',
    _ => value.trim().isEmpty
        ? ''
        : 'Homashyo holati: ${_rawMaterialStatusLabel(value).toLowerCase()}.',
  };
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

String _rawMaterialSummary(AdminRawMaterialLookup report, String queueState) {
  final assignment = report.assignment;
  final order = report.order;
  final materialName = _rawMaterialName(report);
  final quantity = _quantityTextFromParts(report.qty, report.uom);
  if (assignment == null) {
    return [
      '$materialName homashyosi scan qilindi.',
      if (quantity.trim().isNotEmpty) 'Miqdori: $quantity.',
      _rawMaterialStatusSentence(report.status),
      'Bu homashyo hali hech qaysi orderga ulanmagan.',
    ].where((item) => item.trim().isNotEmpty).join(' ');
  }
  final orderTitle = order?.title.trim().isNotEmpty == true
      ? order!.title.trim()
      : assignment.orderId.trim();
  final orderNumber = order?.orderNumber.trim() ?? '';
  return [
    '$materialName homashyosi scan qilindi.',
    if (quantity.trim().isNotEmpty) 'Miqdori: $quantity.',
    if (orderNumber.isNotEmpty)
      'Bu homashyo Zakaz $orderNumber bo‘yicha $orderTitle orderiga ulangan.',
    if (orderNumber.isEmpty) 'Bu homashyo $orderTitle orderiga ulangan.',
    'Homashyo ${assignment.apparatus} aparatida ishlatiladi.',
    _apparatusPurposeSentence(assignment.apparatus),
    if (queueState.trim().isNotEmpty)
      'Orderning shu aparatdagi holati: ${_stateDescription(queueState)}.',
    if (assignment.assignedByName.trim().isNotEmpty)
      '${assignment.assignedByName.trim()} tomonidan ulangan.',
  ].join(' ');
}
