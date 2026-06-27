import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/widgets/shell/app_shell.dart';

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
            ? _QrReportView(report: report, onScanAgain: _scanAgain)
            : rawMaterialReport != null
                ? _RawMaterialReportView(
                    report: rawMaterialReport,
                    onScanAgain: _scanAgain,
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
  const _QrReportView({required this.report, required this.onScanAgain});

  final AdminProgressQrReport report;
  final VoidCallback onScanAgain;

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
                    _stateLabel(current.status),
                  ].where((item) => item.trim().isNotEmpty).join(' • '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
  });

  final AdminRawMaterialLookup report;
  final VoidCallback onScanAgain;

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
    final lines = [
      _apparatusStateSentence(batch.apparatus, state),
      if (batch.executorName.trim().isNotEmpty)
        '${batch.executorName.trim()} shu aparatdagi ishni bajargan.',
      if (_quantityText(batch).trim().isNotEmpty)
        'Qayd qilingan miqdor: ${_quantityText(batch)}.',
      ..._metricSentences(batch),
      _nextApparatusSentence(batch.nextApparatus),
      if (batch.description.trim().isNotEmpty)
        'Izoh: ${batch.description.trim()}',
    ].where((item) => item.trim().isNotEmpty).toList();
    return _InfoSection(
      title: 'Ish natijasi',
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
        for (final session in sessions)
          _SentenceLine(
            text: [
              if (session.workerDisplayName.trim().isNotEmpty)
                '${session.workerDisplayName.trim()} ${session.apparatus} aparatida ishlagan.',
              if (session.workerDisplayName.trim().isEmpty)
                '${session.apparatus} aparatida ish bajarilgan.',
              '${_workerSessionStatusSentence(session.status)}.',
              if (session.startedAtUnix > 0)
                'Ish vaqti: ${formatUnixSecondsLocalDateTime(session.startedAtUnix)}.',
            ].where((item) => item.trim().isNotEmpty).join(' '),
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
                  _logTitle(log),
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
              label: 'Scan qilingan QR', value: report.scannedBatch.qrPayload),
          _InfoRow(label: 'Hozirgi QR', value: current.qrPayload),
          _InfoRow(label: 'Scan batch', value: report.scannedBatch.batchId),
          _InfoRow(label: 'Hozirgi batch', value: current.batchId),
          _InfoRow(
            label: 'WIP holat',
            value: _stateLabel(report.scannedBatch.wipStatus),
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
          _InfoRow(label: 'Receipt', value: report.sourceReceiptId),
          _InfoRow(label: 'Reserved order', value: report.reservedOrderId),
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
    'waiting' => 'Kutmoqda',
    'in_use' => 'Ishlatilmoqda',
    'processed' => 'Eski QR',
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
    'in_use' => 'ishlatilmoqda',
    'processed' => 'eski QR holatida',
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
      '${_formatMetric(batch.finishedGoodsKg, 'kg')} tayyor mahsulot kg bo‘yicha qayd qilingan.',
    if (batch.finishedGoodsMeter != null)
      '${_formatMetric(batch.finishedGoodsMeter, 'm')} tayyor mahsulot metr bo‘yicha qayd qilingan.',
    if (batch.laminationPrintLeftoverRolls != null)
      '${_formatMetric(batch.laminationPrintLeftoverRolls, 'rulon')} laminatsiyadan qolgan bosma rulon qayd qilingan.',
    if (batch.laminationFilmLeftoverRolls != null)
      '${_formatMetric(batch.laminationFilmLeftoverRolls, 'rulon')} laminatsiyadan qolgan plyonka rulon qayd qilingan.',
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

String _logTitle(AdminProductionOrderLogEntry log) {
  return switch (log.action.trim()) {
    'start' => 'Ish boshlandi',
    'pause' => 'Ish pauzaga olindi',
    'resume' => 'Ish davom ettirildi',
    'complete' => 'Ish tugadi',
    _ => _stateLabel(log.action),
  };
}

String _logSentence(AdminProductionOrderLogEntry log, String time) {
  final actor = log.actorDisplayName.trim().isNotEmpty
      ? log.actorDisplayName.trim()
      : 'Ijrochi';
  final apparatus = log.apparatus.trim();
  final actionSentence = switch (log.action.trim()) {
    'start' => '$actor $apparatus aparatida ishni boshlagan.',
    'pause' => '$actor $apparatus aparatidagi ishni pauzaga olgan.',
    'resume' => '$actor $apparatus aparatidagi ishni davom ettirgan.',
    'complete' => '$actor $apparatus aparatidagi ishni tugatgan.',
    _ => '$actor $apparatus aparatida amal bajargan.',
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
