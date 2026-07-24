import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../native_bluetooth_printer.dart';

class BluetoothPrinterList extends StatefulWidget {
  const BluetoothPrinterList({
    required this.onSelected,
    this.activationTabIndex,
    super.key,
  });

  final ValueChanged<BluetoothPrinterProfile> onSelected;
  final int? activationTabIndex;

  @override
  State<BluetoothPrinterList> createState() => _BluetoothPrinterListState();
}

class _BluetoothPrinterListState extends State<BluetoothPrinterList> {
  List<BluetoothPrinterProfile> _printers = const [];
  StreamSubscription<BluetoothPrinterScanEvent>? _discoverySubscription;
  TabController? _tabController;
  bool _started = false;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.activationTabIndex == null) {
      unawaited(_load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (identical(controller, _tabController)) {
      return;
    }
    _tabController?.removeListener(_handleTabChanged);
    _tabController = controller;
    _tabController?.addListener(_handleTabChanged);
    _handleTabChanged();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChanged);
    unawaited(_discoverySubscription?.cancel());
    super.dispose();
  }

  void _handleTabChanged() {
    final activationTabIndex = widget.activationTabIndex;
    if (activationTabIndex != null &&
        _tabController?.index == activationTabIndex &&
        !_started) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final previousSubscription = _discoverySubscription;
    _discoverySubscription = null;
    await previousSubscription?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _started = true;
      _loading = true;
      _error = '';
      _printers = const [];
    });
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _discoverySubscription = NativeBluetoothPrinter.discoverPrinters().listen(
        _handleDiscoveryEvent,
        onError: _handleDiscoveryError,
      );
      return;
    }
    try {
      final printers = await NativeBluetoothPrinter.pairedPrinters();
      if (!mounted) {
        return;
      }
      setState(() {
        _printers = printers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _printers = const [];
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _handleDiscoveryEvent(BluetoothPrinterScanEvent event) {
    if (!mounted) {
      return;
    }
    setState(() {
      final printer = event.printer;
      if (printer != null) {
        final index = _printers.indexWhere(
          (item) => item.address == printer.address,
        );
        if (index < 0) {
          _printers = [..._printers, printer];
        } else {
          final printers = [..._printers];
          printers[index] = printer;
          _printers = printers;
        }
      }
      if (event.completed) {
        _loading = false;
      }
    });
    if (event.completed) {
      final subscription = _discoverySubscription;
      _discoverySubscription = null;
      unawaited(subscription?.cancel());
    }
  }

  void _handleDiscoveryError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }
    setState(() {
      _printers = const [];
      _loading = false;
      _error = error.toString();
    });
  }

  String _userFriendlyError(String rawError) {
    if (rawError.isEmpty) return '';
    if (rawError.contains('MissingPluginException')) {
      return 'Bluetooth printer tizim moduli ushbu muhitda faol emas. Qurilma Bluetooth sozlamalarini tekshiring.';
    }
    if (rawError.toLowerCase().contains('permission')) {
      return 'Bluetooth ruxsatlari taqdim etilmagan. Sozlamalardan ruxsat bering.';
    }
    return 'Bluetooth printerlarni izlashda kutilmagan xatolik yuz berdi.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(),
              ),
            ),
          if (!_started)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.bluetooth_searching_rounded,
                      color: scheme.onSecondaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'XP-P323B',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bluetooth printer tanlanmoqda...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!_loading && _printers.isEmpty)
            _BluetoothEmptyState(
              errorText: _userFriendlyError(_error),
              rawError: _error,
              isIOS: isIOS,
              onRetry: _load,
            ),
          for (final printer in _printers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onSelected(printer),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            color: scheme.onSecondaryContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                printer.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                printer.address,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ],
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

class _BluetoothEmptyState extends StatefulWidget {
  const _BluetoothEmptyState({
    required this.errorText,
    required this.rawError,
    required this.isIOS,
    required this.onRetry,
  });

  final String errorText;
  final String rawError;
  final bool isIOS;
  final VoidCallback onRetry;

  @override
  State<_BluetoothEmptyState> createState() => _BluetoothEmptyStateState();
}

class _BluetoothEmptyStateState extends State<_BluetoothEmptyState> {
  bool _showRawDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final description = widget.errorText.isNotEmpty
        ? widget.errorText
        : widget.isIOS
            ? 'Printerni yoqing va shu oynada Bluetooth orqali qidiring.'
            : 'Printerni Android Bluetooth sozlamalarida avval bog‘lang (pair).';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_disabled_rounded,
              color: scheme.onSecondaryContainer,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bluetooth printer topilmadi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.rawError.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showRawDetails = !_showRawDetails;
                });
              },
              child: Text(
                _showRawDetails ? 'Tafsilotlarni yashirish' : 'Texnik ma’lumot',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (_showRawDetails) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.rawError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text(
              'Qayta qidirish',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
