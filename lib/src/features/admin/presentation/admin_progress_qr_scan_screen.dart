import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/scanner/reliable_mobile_scanner.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import '../models/production_map_models.dart';
import 'admin_progress_qr_passport.dart';
import 'admin_progress_qr_scan_pdf.dart';

part 'admin_progress_qr_scan_screen__AdminProgressQrScanScreenState_methods_01.dart';
part 'admin_progress_qr_scan_screen_models_part_01.dart';
part 'admin_progress_qr_scan_screen_widgets_part_02.dart';
part 'admin_progress_qr_scan_screen_declarations_part_03.dart';
part 'admin_progress_qr_scan_screen_declarations_part_04.dart';
part 'admin_progress_qr_scan_screen_declarations_part_05.dart';
part 'admin_progress_qr_scan_screen_helpers_part_06.dart';

class _AdminProgressQrScanScreenState extends State<AdminProgressQrScanScreen> {
  final bool _scannerSupported = _supportsLiveScanner;
  final _manualQrController = TextEditingController();
  ReliableScannerSession? _scannerSession;
  bool _processing = false;
  _QrScanStatus _scanStatus = _QrScanStatus.prompt;
  String? _scanErrorCode;
  AdminProgressQrReport? _report;
  AdminPaddonSnapshot? _paddonReport;
  AdminRawMaterialLookup? _rawMaterialReport;
  List<AdminApparatus> _apparatusCatalog = const [];
  bool _sharing = false;

  Map<String, String> get _apparatusNamesById =>
      canonicalApparatusNamesById(_apparatusCatalog);

  @override
  void initState() {
    super.initState();
    unawaited(_loadApparatusCatalog());
    if (_scannerSupported) {
      _scannerSession = ReliableScannerSession(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _manualQrController.dispose();
    final session = _scannerSession;
    if (session != null) {
      unawaited(session.dispose());
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
                apparatusNamesById: _apparatusNamesById,
                onScanAgain: _scanAgain,
                onShare: _shareCurrentReport,
                sharing: _sharing,
              )
            : paddonReport != null
                ? _PaddonQrReportView(
                    report: paddonReport,
                    apparatusNamesById: _apparatusNamesById,
                    onScanAgain: _scanAgain,
                  )
                : rawMaterialReport != null
                    ? _RawMaterialReportView(
                        report: rawMaterialReport,
                        apparatusNamesById: _apparatusNamesById,
                        onScanAgain: _scanAgain,
                        onShare: _shareCurrentReport,
                        sharing: _sharing,
                      )
                    : scannerMode
                        ? _ScannerView(
                            session: _scannerSession,
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
