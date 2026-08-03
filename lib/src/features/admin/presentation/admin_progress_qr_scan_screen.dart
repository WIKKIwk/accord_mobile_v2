import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/production_map_models.dart';
import 'admin_progress_qr_scan_pdf.dart';

class AdminProgressQrScanScreen extends StatefulWidget {
  const AdminProgressQrScanScreen({super.key});

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
  AdminRawMaterialLookup? _rawMaterialReport;
  String? _errorText;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    if (_scannerSupported) {
      _controller = MobileScannerController(
        autoStart: false,
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
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
    if (_processing || _report != null || _rawMaterialReport != null) {
      return;
    }
    final qrPayload = _extractQrPayload(_firstBarcodeValue(capture));
    if (qrPayload.isEmpty) {
      setState(() => _statusText = 'QR bo‘sh yoki noto‘g‘ri');
      return;
    }
    await _lookupQrPayload(qrPayload);
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
    await _lookupQrPayload(_extractQrPayload(value));
  }

  void _scanAgain() {
    setState(() {
      _report = null;
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
    final rawMaterialReport = _rawMaterialReport;
    final scannerMode =
        report == null && rawMaterialReport == null && _scannerSupported;
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
    final order = report.order;
    final current = report.currentBatch ?? report.scannedBatch;
    final currentQueueState = _currentQueueState(
      report.queueStates,
      report.scannedBatch.orderId,
      current.currentApparatus.trim().isNotEmpty
          ? current.currentApparatus
          : current.apparatus,
    );
    final currentBatchState = _progressQrBatchDisplayState(
      batch: current,
      queueState: currentQueueState,
    );
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
                  order?.title.trim().isNotEmpty == true
                      ? order!.title
                      : report.scannedBatch.labelItemName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (order?.orderNumber.trim().isNotEmpty == true)
                      'Zakaz ${order!.orderNumber}',
                    current.apparatus,
                    progressQrHumanStatusLabel(
                      workStatus: current.statusDetail.workStatus,
                      flowStatus: current.statusDetail.flowStatus,
                      wipStatus: current.wipStatus,
                    ),
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
        _OrderStatusSection(status: report.orderStatus),
        if (report.openedBy != null)
          _OpenedBySection(openedBy: report.openedBy!),
        if (report.queueStates.isNotEmpty)
          _QueueStatesSection(queueStates: report.queueStates),
        _SummarySection(
          report: report,
          current: current,
          queueState: currentBatchState,
        ),
        _ResultSection(batch: current, queueState: currentBatchState),
        if (report.activeSessions.isNotEmpty)
          _ActiveWorkSection(sessions: report.activeSessions),
        if (report.runSessions.isNotEmpty)
          _ParticipantsSection(sessions: report.runSessions),
        if (report.progressBatches.isNotEmpty)
          _ProgressBatchesSection(
            batches: report.progressBatches,
            currentBatchId: current.batchId,
          ),
        _TimelineSection(logs: report.logs),
        _TechnicalQrSection(report: report, current: current),
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
        _TimelineSection(logs: report.logs),
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

class _OrderDetailsSection extends StatelessWidget {
  const _OrderDetailsSection({required this.order});

  final ProductionMapDefinition? order;

  @override
  Widget build(BuildContext context) {
    final order = this.order;
    if (order == null) {
      return const SizedBox.shrink();
    }
    final nodes = order.nodes
        .map(
          (node) => [
            node.title,
            if (node.kind.trim().isNotEmpty) node.kind,
            if (node.roleCode.trim().isNotEmpty) node.roleCode,
            if (node.itemCode.trim().isNotEmpty) 'item=${node.itemCode}',
            if (node.qtyFormula.trim().isNotEmpty) 'qty=${node.qtyFormula}',
            if (node.fromLocation.trim().isNotEmpty)
              'from=${node.fromLocation}',
            if (node.toLocation.trim().isNotEmpty) 'to=${node.toLocation}',
            if (node.alternativeGroupLabel.trim().isNotEmpty)
              'alternative=${node.alternativeGroupLabel}',
            if (node.formula != null &&
                node.formula!.expression.trim().isNotEmpty)
              'formula=${node.formula!.expression}',
          ].where((value) => value.trim().isNotEmpty).join(' • '),
        )
        .where((value) => value.trim().isNotEmpty)
        .join('\n');
    final edges = order.edges
        .map(
          (edge) => [
            '${edge.from} -> ${edge.to}',
            if (edge.branch.trim().isNotEmpty) 'branch=${edge.branch}',
          ].join(' • '),
        )
        .where((value) => value.trim().isNotEmpty)
        .join('\n');
    return _InfoSection(
      title: 'Buyurtma tafsilotlari',
      children: [
        _InfoRow(label: 'Order ID', value: order.id),
        _InfoRow(label: 'Order raqami', value: order.orderNumber),
        _InfoRow(label: 'Order code', value: order.code),
        _InfoRow(label: 'Product code', value: order.productCode),
        _InfoRow(label: 'Mahsulot', value: order.title),
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
          label: 'Order og‘irligi, kg',
          value: order.orderKg == null ? '' : _displayNumber(order.orderKg!),
        ),
        _InfoRow(
          label: 'Asosiy uzunlik',
          value:
              order.baseLength == null ? '' : _displayNumber(order.baseLength!),
        ),
        _InfoRow(label: 'Map node soni', value: '${order.nodes.length}'),
        _InfoRow(label: 'Map edge soni', value: '${order.edges.length}'),
        if (nodes.isNotEmpty) _InfoRow(label: 'Map node’lari', value: nodes),
        if (edges.isNotEmpty)
          _InfoRow(label: 'Map bog‘lanishlari', value: edges),
      ],
    );
  }
}

class _OpenedBySection extends StatelessWidget {
  const _OpenedBySection({required this.openedBy});

  final AdminProgressQrOpenedBy openedBy;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'QR kim tomonidan ochilgan',
      children: [
        _InfoRow(label: 'Actor role', value: openedBy.actorRole),
        _InfoRow(label: 'Actor ref', value: openedBy.actorRef),
        _InfoRow(label: 'Actor name', value: openedBy.actorDisplayName),
        _InfoRow(
          label: 'Ochilgan vaqt',
          value: openedBy.openedAtUnix > 0
              ? formatUnixSecondsLocalDateTime(openedBy.openedAtUnix)
              : '',
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

class _OrderStatusSection extends StatelessWidget {
  const _OrderStatusSection({required this.status});

  final AdminProductionOrderStatusDetail status;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Buyurtmaning to‘liq holati',
      children: [
        _InfoRow(label: 'Order holati', value: status.orderStatus),
        _InfoRow(label: 'Ish holati', value: status.workStatus),
        _InfoRow(label: 'Flow holati', value: status.flowStatus),
        _InfoRow(label: 'Stock holati', value: status.stockStatus),
        _InfoRow(label: 'Jami WIP', value: '${status.totalWipCount}'),
        _InfoRow(label: 'Waiting WIP', value: '${status.waitingWipCount}'),
        _InfoRow(label: 'In-use WIP', value: '${status.inUseWipCount}'),
        _InfoRow(label: 'Processed WIP', value: '${status.processedWipCount}'),
        _InfoRow(
          label: 'Keyingi bosqichni kutayotgan WIP',
          value: '${status.waitingNextStageCount}',
        ),
        _InfoRow(
          label: 'Keyingi bosqich ishlatgan WIP',
          value: '${status.consumedByNextStageCount}',
        ),
        _InfoRow(label: 'Erkin WIP', value: '${status.freeWipCount}'),
        _InfoRow(
          label: 'Omborga qabul qilingan WIP',
          value: '${status.acceptedWipCount}',
        ),
        _InfoRow(
          label: 'Faol sessiyalar',
          value: '${status.activeSessionCount}',
        ),
        _InfoRow(
          label: 'Pauzadagi sessiyalar',
          value: '${status.pausedSessionCount}',
        ),
        _InfoRow(
          label: 'Tugagan navbat ishlari',
          value: '${status.completedQueueCount}',
        ),
        _InfoRow(
          label: 'Muammo bilan tugagan ishlar',
          value: '${status.completedWithIssueCount}',
        ),
      ],
    );
  }
}

class _ProgressBatchesSection extends StatelessWidget {
  const _ProgressBatchesSection({
    required this.batches,
    required this.currentBatchId,
  });

  final List<AdminProgressBatch> batches;
  final String currentBatchId;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Barcha progress batchlari (${batches.length})',
      children: [
        for (var index = 0; index < batches.length; index++)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              '${index + 1}. ${batches[index].apparatus.trim().isEmpty ? 'Aparat ko‘rsatilmagan' : batches[index].apparatus}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                if (batches[index].batchId.trim().isNotEmpty)
                  batches[index].batchId,
                if (batches[index].status.trim().isNotEmpty)
                  batches[index].status,
                if (batches[index].batchId.trim() == currentBatchId.trim())
                  'joriy',
              ].join(' • '),
            ),
            children: _progressBatchDetailWidgets(batches[index]),
          ),
      ],
    );
  }
}

List<Widget> _progressBatchDetailWidgets(AdminProgressBatch batch) {
  return [
    _InfoRow(label: 'Batch ID', value: batch.batchId),
    _InfoRow(label: 'Session ID', value: batch.sessionId),
    _InfoRow(label: 'QR payload', value: batch.qrPayload),
    _InfoRow(label: 'Order ID', value: batch.orderId),
    _InfoRow(label: 'Aparat', value: batch.apparatus),
    _InfoRow(label: 'Current apparatus', value: batch.currentApparatus),
    _InfoRow(label: 'Current apparatus key', value: batch.currentApparatusKey),
    _InfoRow(label: 'Current location', value: batch.currentLocation),
    _InfoRow(label: 'Next apparatus', value: batch.nextApparatus),
    _InfoRow(label: 'Action', value: batch.action),
    _InfoRow(label: 'Batch status', value: batch.status),
    _InfoRow(label: 'Work status', value: batch.statusDetail.workStatus),
    _InfoRow(label: 'WIP status', value: batch.wipStatus),
    _InfoRow(label: 'Flow status', value: batch.statusDetail.flowStatus),
    _InfoRow(label: 'Stock status', value: batch.statusDetail.stockStatus),
    _InfoRow(
        label: 'Produced quantity', value: _displayNumber(batch.producedQty)),
    _InfoRow(label: 'UOM', value: batch.uom),
    _InfoRow(label: 'Label item code', value: batch.labelItemCode),
    _InfoRow(label: 'Label item name', value: batch.labelItemName),
    _InfoRow(label: 'Executor', value: batch.executorName),
    _InfoRow(label: 'Worker role', value: batch.workerRole),
    _InfoRow(label: 'Worker ref', value: batch.workerRef),
    _InfoRow(label: 'Worker name', value: batch.workerDisplayName),
    _InfoRow(
      label: 'Started at',
      value: batch.startedAtUnix > 0
          ? formatUnixSecondsLocalDateTime(batch.startedAtUnix)
          : '',
    ),
    _InfoRow(
      label: 'Completed at',
      value: batch.completedAtUnix > 0
          ? formatUnixSecondsLocalDateTime(batch.completedAtUnix)
          : '',
    ),
    _InfoRow(label: 'Parent batch ID', value: batch.parentBatchId),
    _InfoRow(label: 'Used by session', value: batch.usedBySessionId),
    _InfoRow(label: 'Used by apparatus', value: batch.usedByApparatus),
    _InfoRow(label: 'Processed by session', value: batch.processedBySessionId),
    _InfoRow(
      label: 'Processed by apparatus',
      value: batch.processedByApparatus,
    ),
    _InfoRow(
        label: 'Return ink, kg',
        value: _optionalDisplayNumber(batch.returnInkKg)),
    _InfoRow(
      label: 'Lamination print leftover, rolls',
      value: _optionalDisplayNumber(batch.laminationPrintLeftoverRolls),
    ),
    _InfoRow(
      label: 'Lamination film leftover, rolls',
      value: _optionalDisplayNumber(batch.laminationFilmLeftoverRolls),
    ),
    _InfoRow(
      label: 'Rezka bosma waste, kg',
      value: _optionalDisplayNumber(batch.rezkaBosmaWaste),
    ),
    _InfoRow(
      label: 'Rezka lamination waste, kg',
      value: _optionalDisplayNumber(batch.rezkaLaminationWaste),
    ),
    _InfoRow(
      label: 'Rezka edge waste, kg',
      value: _optionalDisplayNumber(batch.rezkaEdgeWaste),
    ),
    _InfoRow(
        label: 'Total waste, kg',
        value: _optionalDisplayNumber(batch.totalWaste)),
    _InfoRow(
      label: 'Finished goods, kg',
      value: _optionalDisplayNumber(batch.finishedGoodsKg),
    ),
    _InfoRow(
      label: 'Finished goods, meter',
      value: _optionalDisplayNumber(batch.finishedGoodsMeter),
    ),
    _InfoRow(label: 'Description', value: batch.description),
    if (batch.payloadJson.isNotEmpty)
      _JsonPayloadBlock(title: 'Payload JSON', value: batch.payloadJson),
  ];
}

class _JsonPayloadBlock extends StatelessWidget {
  const _JsonPayloadBlock({required this.title, required this.value});

  final String title;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(value);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            pretty,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.report,
    required this.current,
    required this.queueState,
  });

  final AdminProgressQrReport report;
  final AdminProgressBatch current;
  final String queueState;

  @override
  Widget build(BuildContext context) {
    final order = report.order;
    final quantity = _quantityText(current);
    final startedBy = report.openedBy?.actorDisplayName.trim() ?? '';
    final startedAt = report.openedBy == null
        ? ''
        : formatUnixSecondsLocalDateTime(report.openedBy!.openedAtUnix);
    final state = queueState.isEmpty ? current.status : queueState;
    final productStatus = progressQrHumanStatusLabel(
      workStatus: current.statusDetail.workStatus.isNotEmpty
          ? current.statusDetail.workStatus
          : state,
      flowStatus: current.statusDetail.flowStatus,
      wipStatus: current.wipStatus,
    );
    final title = order?.title.trim().isNotEmpty == true
        ? order!.title.trim()
        : current.labelItemName.trim();
    final orderNumber = order?.orderNumber.trim() ?? '';
    final sentences = <String>[
      if (orderNumber.isNotEmpty && title.isNotEmpty)
        'Zakaz $orderNumber bo‘yicha $title mahsuloti tekshirildi.',
      if (orderNumber.isEmpty && title.isNotEmpty)
        '$title mahsuloti tekshirildi.',
      if (report.isStale)
        'Scan qilingan QR eski bosqichga tegishli. Quyida mahsulotning hozirgi holati ko‘rsatilgan.',
      if (productStatus.isNotEmpty)
        'Yarim tayyor mahsulot holati: ${productStatus.toLowerCase()}.',
      _apparatusStateSentence(current.apparatus, state),
      if (quantity.isNotEmpty) '$quantity mahsulot qayd qilingan.',
      _nextApparatusSentence(current.nextApparatus),
      if (startedBy.isNotEmpty && startedAt.isNotEmpty)
        'Order oqimi $startedBy tomonidan $startedAt da ochilgan.',
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: 'Qisqa xulosa',
      children: [
        Text(
          sentences.join(' '),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.batch, required this.queueState});

  final AdminProgressBatch batch;
  final String queueState;

  @override
  Widget build(BuildContext context) {
    final state = queueState.isEmpty ? batch.status : queueState;
    final productStatus = progressQrHumanStatusLabel(
      workStatus: batch.statusDetail.workStatus.isNotEmpty
          ? batch.statusDetail.workStatus
          : state,
      flowStatus: batch.statusDetail.flowStatus,
      wipStatus: batch.wipStatus,
    );
    final lines = [
      if (productStatus.isNotEmpty)
        'Yarim tayyor mahsulot holati: $productStatus.',
      _apparatusStateSentence(batch.apparatus, state),
      if (batch.executorName.trim().isNotEmpty)
        'Bajargan ishchi: ${batch.executorName.trim()}.',
      if (_quantityText(batch).trim().isNotEmpty)
        'Qayd qilingan miqdor: ${_quantityText(batch)}.',
      ..._metricSentences(batch),
      _nextApparatusSentence(batch.nextApparatus),
      if (batch.description.trim().isNotEmpty)
        'Izoh: ${batch.description.trim()}',
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: 'Mahsulot natijasi',
      children: [
        for (final line in lines) _SentenceLine(text: line),
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

class _ActiveWorkSection extends StatelessWidget {
  const _ActiveWorkSection({required this.sessions});

  final List<AdminWorkerRunSession> sessions;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Hozirgi ish joyi',
      children: [
        for (final session in sessions)
          _SentenceLine(
            text: [
              _apparatusStateSentence(session.apparatus, session.status),
              if (session.workerDisplayName.trim().isNotEmpty)
                '${session.workerDisplayName.trim()} shu ish joyida javobgar.',
            ].where((item) => item.trim().isNotEmpty).join(' '),
          ),
      ],
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({required this.sessions});

  final List<AdminWorkerRunSession> sessions;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: 'Kimlar ishlagan',
      children: [
        for (var index = 0; index < sessions.length; index++)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              sessions[index].workerDisplayName.trim().isNotEmpty
                  ? sessions[index].workerDisplayName
                  : 'Ijrochi ko‘rsatilmagan',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                sessions[index].apparatus,
                _workerSessionStatusSentence(sessions[index].status),
              ].where((item) => item.trim().isNotEmpty).join(' • '),
            ),
            children: [
              _InfoRow(label: 'Session ID', value: sessions[index].sessionId),
              _InfoRow(label: 'Order ID', value: sessions[index].orderId),
              _InfoRow(label: 'Aparat', value: sessions[index].apparatus),
              _InfoRow(label: 'Status', value: sessions[index].status),
              _InfoRow(label: 'Worker role', value: sessions[index].workerRole),
              _InfoRow(label: 'Worker ref', value: sessions[index].workerRef),
              _InfoRow(
                label: 'Worker name',
                value: sessions[index].workerDisplayName,
              ),
              _InfoRow(
                label: 'Started at',
                value: sessions[index].startedAtUnix > 0
                    ? formatUnixSecondsLocalDateTime(
                        sessions[index].startedAtUnix,
                      )
                    : '',
              ),
              _InfoRow(
                label: 'Updated at',
                value: sessions[index].updatedAtUnix > 0
                    ? formatUnixSecondsLocalDateTime(
                        sessions[index].updatedAtUnix,
                      )
                    : '',
              ),
              if (sessions[index].payloadJson.isNotEmpty)
                _JsonPayloadBlock(
                  title: 'Payload JSON',
                  value: sessions[index].payloadJson,
                ),
            ],
          ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.logs});

  final List<AdminProductionOrderLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }
    return _InfoSection(
      title: 'Ish ketma-ketligi',
      children: [
        for (var index = 0; index < logs.length; index++)
          _TimelineStep(index: index + 1, log: logs[index]),
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
                _LogDetails(log: log),
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

class _LogDetails extends StatelessWidget {
  const _LogDetails({required this.log});

  final AdminProductionOrderLogEntry log;

  @override
  Widget build(BuildContext context) {
    final transfer = log.transfer;
    final freeze = log.freeze;
    final hasDetails = log.eventId.trim().isNotEmpty ||
        log.fromState.trim().isNotEmpty ||
        log.toState.trim().isNotEmpty ||
        log.actorRole.trim().isNotEmpty ||
        log.actorRef.trim().isNotEmpty ||
        transfer != null ||
        freeze != null;
    if (!hasDetails) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: 'Hodisa tafsiloti',
            value: [
              if (log.fromState.trim().isNotEmpty ||
                  log.toState.trim().isNotEmpty)
                'Holat: ${log.fromState} -> ${log.toState}',
              if (log.eventId.trim().isNotEmpty) 'Event ID: ${log.eventId}',
              if (log.actorRole.trim().isNotEmpty)
                'Actor role: ${log.actorRole}',
              if (log.actorRef.trim().isNotEmpty) 'Actor ref: ${log.actorRef}',
              if (log.actorDisplayName.trim().isNotEmpty)
                'Actor name: ${log.actorDisplayName}',
            ].join('\n'),
          ),
          if (transfer != null)
            _InfoRow(
              label: 'Apparat almashishi',
              value: [
                if (transfer.transferId.trim().isNotEmpty)
                  'Transfer ID: ${transfer.transferId}',
                '${transfer.fromApparatus} -> ${transfer.toApparatus}',
                if (transfer.reason.trim().isNotEmpty)
                  'Sabab: ${transfer.reason}',
                if (transfer.sessionId.trim().isNotEmpty)
                  'Session ID: ${transfer.sessionId}',
                if (transfer.progressBatchId.trim().isNotEmpty)
                  'Progress batch: ${transfer.progressBatchId}',
                if (transfer.materialBarcodes.isNotEmpty)
                  'Material barcode’lari: ${transfer.materialBarcodes.join(', ')}',
              ].where((line) => line.trim().isNotEmpty).join('\n'),
            ),
          if (freeze != null)
            _InfoRow(
              label: 'Muzlatish hodisasi',
              value: [
                if (freeze.requestId.trim().isNotEmpty)
                  'Request ID: ${freeze.requestId}',
                if (freeze.status.trim().isNotEmpty) 'Status: ${freeze.status}',
                if (freeze.targetSessionId.trim().isNotEmpty)
                  'Target session: ${freeze.targetSessionId}',
                if (freeze.targetApparatus.trim().isNotEmpty)
                  'Target apparatus: ${freeze.targetApparatus}',
                if (freeze.targetWorkerRole.trim().isNotEmpty)
                  'Target worker role: ${freeze.targetWorkerRole}',
                if (freeze.targetWorkerRef.trim().isNotEmpty)
                  'Target worker ref: ${freeze.targetWorkerRef}',
                if (freeze.targetWorkerDisplayName.trim().isNotEmpty)
                  'Target worker name: ${freeze.targetWorkerDisplayName}',
                if (freeze.requestedAtUnix > 0)
                  'Requested at: ${formatUnixSecondsLocalDateTime(freeze.requestedAtUnix)}',
                if (freeze.transitionedAtUnix > 0)
                  'Transitioned at: ${formatUnixSecondsLocalDateTime(freeze.transitionedAtUnix)}',
              ].join('\n'),
            ),
        ],
      ),
    );
  }
}

class _TechnicalQrSection extends StatelessWidget {
  const _TechnicalQrSection({required this.report, required this.current});

  final AdminProgressQrReport report;
  final AdminProgressBatch current;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: const Text(
          'Texnik QR ma’lumot',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _InfoRow(
            label: 'Scan qilingan QR',
            value: report.scannedBatch.qrPayload,
          ),
          _InfoRow(label: 'Hozirgi QR', value: current.qrPayload),
          _InfoRow(label: 'Scan batch', value: report.scannedBatch.batchId),
          _InfoRow(label: 'Hozirgi batch', value: current.batchId),
          _InfoRow(
            label: 'Scan session',
            value: report.scannedBatch.sessionId,
          ),
          _InfoRow(label: 'Hozirgi session', value: current.sessionId),
          _InfoRow(
            label: 'Scan apparatus',
            value: report.scannedBatch.apparatus,
          ),
          _InfoRow(label: 'Hozirgi apparatus', value: current.apparatus),
          _InfoRow(
            label: 'Scan WIP status',
            value: report.scannedBatch.wipStatus,
          ),
          _InfoRow(label: 'Hozirgi WIP status', value: current.wipStatus),
          _InfoRow(
            label: 'Mahsulot holati',
            value: progressQrTechnicalProductStatusLabel(
              workStatus: report.scannedBatch.statusDetail.workStatus,
              flowStatus: report.scannedBatch.statusDetail.flowStatus,
              wipStatus: report.scannedBatch.wipStatus,
            ),
          ),
          if (report.scannedBatch.payloadJson.isNotEmpty)
            _JsonPayloadBlock(
              title: 'Scan batch payload JSON',
              value: report.scannedBatch.payloadJson,
            ),
          if (current.payloadJson.isNotEmpty &&
              current.batchId.trim() != report.scannedBatch.batchId.trim())
            _JsonPayloadBlock(
              title: 'Hozirgi batch payload JSON',
              value: current.payloadJson,
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
    'resume' => 'Davom etdi',
    'complete' => 'Tugadi',
    'pending' => 'Kutilmoqda',
    'in_progress' => 'Jarayonda',
    'paused' => 'Pauzada',
    'completed' => 'Tugagan',
    'waiting' => 'Keyingi ishni kutmoqda',
    'in_use' => 'Ish jarayonida',
    'processed' => 'Keyingi bosqichda ishlatilgan',
    'free_wip' || 'finished_pending_acceptance' => 'Erkin WIP',
    'accepted_to_stock' => 'Omborga qabul qilingan',
    'waiting_next_stage' => 'Keyingi bosqichni kutmoqda',
    'consumed_by_next_stage' => 'Keyingi bosqichda ishlatilgan',
    _ => value,
  };
}

String _stateDescription(String value) {
  return switch (value.trim()) {
    'start' => 'ish boshlangan',
    'pause' => 'ish pauzaga olingan',
    'resume' => 'ish davom ettirilgan',
    'complete' || 'completed' => 'ish tugagan',
    'pending' || 'waiting' => 'ish boshlanishini kutyapti',
    'in_progress' => 'ish jarayonda',
    'paused' => 'ish vaqtincha pauzada',
    'stopped' || 'cancelled' => 'ish to‘xtatilgan',
    'in_use' => 'ish jarayonida',
    'processed' => 'keyingi bosqichda ishlatilgan',
    'free_wip' || 'finished_pending_acceptance' => 'erkin WIP holatida',
    'accepted_to_stock' => 'omborga qabul qilingan',
    'waiting_next_stage' => 'keyingi bosqichni kutmoqda',
    'consumed_by_next_stage' => 'keyingi bosqichda ishlatilgan',
    _ => _stateLabel(value).toLowerCase(),
  };
}

String _apparatusStateSentence(String apparatus, String state) {
  final name = apparatus.trim();
  if (name.isEmpty) {
    return _stateDescription(state);
  }
  return switch (state.trim()) {
    'complete' || 'completed' => '$name aparatidagi ish tugagan.',
    'pending' ||
    'waiting' =>
      'Mahsulot $name aparatida navbat kutyapti, ish hali boshlanmagan.',
    'in_progress' ||
    'start' ||
    'resume' =>
      'Mahsulot hozir $name aparatida ishlanyapti.',
    'paused' || 'pause' => '$name aparatidagi ish vaqtincha pauzada.',
    'stopped' || 'cancelled' => '$name aparatidagi ish to‘xtatilgan.',
    _ => 'Mahsulot $name aparatida. Holati: ${_stateDescription(state)}.',
  };
}

String _progressQrBatchDisplayState({
  required AdminProgressBatch batch,
  required String queueState,
}) {
  final serverWorkStatus = batch.statusDetail.workStatus.trim();
  if (serverWorkStatus.isNotEmpty) {
    return serverWorkStatus;
  }
  return progressQrBatchDisplayState(
    batchStatus: batch.status,
    queueState: queueState,
  );
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
        ? 'Ishlab chiqarish bosqichi tugagan, erkin WIP holatida'
        : 'Erkin WIP holatida';
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
  return 'Yarim tayyor mahsulot holati: $status';
}

String _nextApparatusSentence(String apparatus) {
  final name = apparatus.trim();
  if (name.isEmpty) {
    return '';
  }
  return 'Keyingi ish joyi: mahsulot $name aparatiga olib boriladi. ${_apparatusPurposeSentence(name)}';
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

List<String> _metricSentences(AdminProgressBatch batch) {
  return [
    if (batch.returnInkKg != null)
      '${_formatMetric(batch.returnInkKg, 'kg')} kraska qaytgan.',
    if (batch.totalWaste != null)
      '${_formatMetric(batch.totalWaste, 'kg')} jami chiqindi chiqqan.',
    if (batch.finishedGoodsKg != null)
      'Tayyor mahsulot og‘irligi: ${_formatMetric(batch.finishedGoodsKg, 'kg')}.',
    if (batch.finishedGoodsMeter != null)
      'Tayyor mahsulot uzunligi: ${_formatMetric(batch.finishedGoodsMeter, 'm')}.',
    if (batch.laminationPrintLeftoverRolls != null)
      'Laminatsiyadan qaytgan bosma rulon: ${_formatMetric(batch.laminationPrintLeftoverRolls, 'rulon')}.',
    if (batch.laminationFilmLeftoverRolls != null)
      'Laminatsiyadan qaytgan plyonka rulon: ${_formatMetric(batch.laminationFilmLeftoverRolls, 'rulon')}.',
    if (batch.rezkaBosmaWaste != null)
      '${_formatMetric(batch.rezkaBosmaWaste, 'kg')} rezka bosma chiqindisi chiqqan.',
    if (batch.rezkaLaminationWaste != null)
      '${_formatMetric(batch.rezkaLaminationWaste, 'kg')} rezka laminatsiya chiqindisi chiqqan.',
    if (batch.rezkaEdgeWaste != null)
      '${_formatMetric(batch.rezkaEdgeWaste, 'kg')} rezka chet chiqindisi chiqqan.',
  ];
}

String _formatMetric(double? value, String unit) {
  if (value == null) {
    return '';
  }
  return formatQuantityWithUnit(value, unit, trimTrailingZeros: true);
}

String _workerSessionStatusSentence(String status) {
  return switch (status.trim()) {
    'complete' || 'completed' => 'Bu ish tugagan',
    'in_progress' || 'start' || 'resume' => 'Ish jarayonda',
    'paused' || 'pause' => 'Ish vaqtincha pauzada',
    'pending' || 'waiting' => 'Ish boshlanishini kutyapti',
    _ => 'Holati: ${_stateDescription(status)}',
  };
}

@visibleForTesting
String progressQrTimelineTitle(String action) {
  return switch (action.trim()) {
    'start' => 'Bosqichdagi ish boshlandi',
    'pause' => 'Bosqichdagi ish vaqtincha to‘xtatildi',
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

String _quantityText(AdminProgressBatch batch) {
  return formatQuantityWithUnit(
    batch.producedQty,
    batch.uom,
    trimTrailingZeros: true,
  );
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

String _optionalDisplayNumber(num? value) {
  return value == null ? '' : _displayNumber(value);
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
