import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';

class QolipCellQrScanScreen extends _QolipQrScanScreen {
  const QolipCellQrScanScreen({super.key})
      : super._(mode: _QolipQrScanMode.cell);
}

class QolipRawQrScanScreen extends _QolipQrScanScreen {
  const QolipRawQrScanScreen({super.key}) : super._(mode: _QolipQrScanMode.raw);
}

enum _QolipQrScanMode { cell, raw }

class _QolipQrScanScreen extends StatefulWidget {
  const _QolipQrScanScreen._({super.key, required this.mode});

  final _QolipQrScanMode mode;

  @override
  State<_QolipQrScanScreen> createState() => _QolipQrScanScreenState();
}

class _QolipQrScanScreenState extends State<_QolipQrScanScreen> {
  final bool _scannerSupported = _supportsLiveScanner;
  MobileScannerController? _controller;
  bool _processing = false;
  late String _statusText = _initialStatusText;

  String get _initialStatusText {
    return widget.mode == _QolipQrScanMode.cell
        ? 'Yachayka QR kodini ramkaga keltiring'
        : 'Qolip QR kodini ramkaga keltiring';
  }

  String get _checkingStatusText {
    return widget.mode == _QolipQrScanMode.cell
        ? 'Yachayka tekshirilmoqda...'
        : 'Qolip QR o‘qilmoqda...';
  }

  String get _title {
    return widget.mode == _QolipQrScanMode.cell
        ? 'Yachayka scan'
        : 'Qolip scan';
  }

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
        _statusText = _initialStatusText;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
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
      // Best-effort stop.
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) {
      return;
    }
    final qr = _firstBarcodeValue(capture);
    if (qr.isEmpty) {
      return;
    }

    setState(() {
      _processing = true;
      _statusText = _checkingStatusText;
    });
    await _stopScanner();

    try {
      if (widget.mode == _QolipQrScanMode.raw) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop<String>(qr);
        return;
      }
      final cell = await MobileApi.instance.qolipCellQrLookup(qr);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<QolipCellQr>(cell);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _messageForError(error);
      setState(() {
        _processing = false;
        _statusText = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _startScanner();
    }
  }

  String _messageForError(Object error) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'cell_qr_not_found' ||
        'qolip_cell_qr_not_found' =>
          'Bu QR yachayka uchun topilmadi.',
        'qr_required' || 'qolip_cell_qr_required' => 'Yachayka QR bo‘sh.',
        _ => error.message.trim().isEmpty
            ? 'Yachayka QR tekshirishda xatolik.'
            : error.message,
      };
    }
    return 'Yachayka QR tekshirishda xatolik.';
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
    final backgroundColor =
        _scannerSupported ? Colors.black : scheme.surfaceContainerLow;
    final appBarTheme = theme.appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: _scannerSupported ? Colors.white : scheme.onSurface,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        color: _scannerSupported ? Colors.white : scheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );

    return Theme(
      data: theme.copyWith(appBarTheme: appBarTheme),
      child: AppShell(
        title: _title,
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: _scannerSupported ? Colors.white : scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
        backgroundColor: backgroundColor,
        contentPadding: EdgeInsets.zero,
        child: _scannerSupported
            ? Stack(
                children: [
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      useAppLifecycleState: true,
                      onDetect: _handleDetect,
                      errorBuilder: (context, error) {
                        return _ScannerErrorView(
                          message:
                              'Kamera ochilmadi. Ruxsatlarni tekshirib qayta urinib ko‘ring.',
                          onRetry: _startScanner,
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
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.06),
                              Colors.black.withValues(alpha: 0.34),
                            ],
                            stops: const [0.0, 0.52, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 68),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double frameWidth =
                                    (constraints.maxWidth * 0.78).clamp(
                                  220.0,
                                  320.0,
                                );
                                final double frameHeight =
                                    (constraints.maxHeight * 0.42).clamp(
                                  220.0,
                                  340.0,
                                );
                                return Center(
                                  child: Container(
                                    width: frameWidth,
                                    height: frameHeight,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                        width: 2.5,
                                      ),
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withValues(
                                                alpha: 0.78,
                                              ),
                                            ),
                                          ),
                                        ),
                                        PositionedDirectional(
                                          top: 12,
                                          end: 12,
                                          child: _TorchButton(
                                            controller: _controller!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ScanStatusPill(
                            text: _statusText,
                            isBusy: _processing,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _UnsupportedScannerView(
                onBack: () => Navigator.of(context).maybePop(),
              ),
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
      // Torch availability is device-specific; the button is best-effort.
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
        return Tooltip(
          message: enabled ? 'Flash o‘chirish' : 'Flash yoqish',
          child: Material(
            color: enabled
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.black.withValues(alpha: 0.42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _toggleTorch,
              child: SizedBox.square(
                dimension: 46,
                child: Icon(
                  enabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: enabled ? Colors.black : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScanStatusPill extends StatelessWidget {
  const _ScanStatusPill({required this.text, required this.isBusy});

  final String text;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Card.filled(
        key: ValueKey<String>(text),
        margin: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _ScannerFallbackPanel(
      icon: Icons.videocam_off_rounded,
      title: 'Scanner ishlamadi',
      message: message,
      actionLabel: 'Qayta urinish',
      onAction: onRetry,
    );
  }
}

class _UnsupportedScannerView extends StatelessWidget {
  const _UnsupportedScannerView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _ScannerFallbackPanel(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Scanner mavjud emas',
      message: 'Bu qurilmada yachayka QR scanner qo‘llab-quvvatlanmadi.',
      actionLabel: 'Orqaga',
      onAction: onBack,
    );
  }
}

class _ScannerFallbackPanel extends StatelessWidget {
  const _ScannerFallbackPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
