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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return ListView(
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (!_started)
          const ListTile(
            leading: Icon(Icons.bluetooth_rounded),
            title: Text('XP-P323B'),
            subtitle: Text('Bluetooth printer tanlanmoqda...'),
          ),
        if (!_loading && _printers.isEmpty)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            tileColor: scheme.surfaceContainerHighest,
            leading: const Icon(Icons.bluetooth_searching_rounded),
            title: const Text('XP-P323B topilmadi'),
            subtitle: Text(
              _error.isEmpty
                  ? isIOS
                      ? 'Printerni yoqing va shu oynada Bluetooth orqali qidiring.'
                      : 'Printerni Android Bluetooth sozlamalarida avval pair qiling.'
                  : _error,
            ),
            trailing: IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Qayta tekshirish',
            ),
          ),
        for (final printer in _printers)
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            tileColor: scheme.surfaceContainerHighest,
            leading: const Icon(Icons.bluetooth_rounded),
            title: Text(printer.displayName),
            subtitle: Text(printer.address),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => widget.onSelected(printer),
          ),
      ],
    );
  }
}
