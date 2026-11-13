import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'metalayzer_navigation.dart';

class MetalayzerScreen extends StatefulWidget {
  const MetalayzerScreen({super.key});

  @override
  State<MetalayzerScreen> createState() => _MetalayzerScreenState();
}

class _MetalayzerScreenState extends State<MetalayzerScreen> {
  final _barcode = TextEditingController();
  MetalayzerMaterial? _material;
  String? _error;
  bool _busy = false;
  late final String _scope;

  @override
  void initState() {
    super.initState();
    _scope = MobileApi.instance.metalayzerScope();
  }

  @override
  void dispose() {
    _barcode.dispose();
    super.dispose();
  }

  void _checkScope() {
    if (MobileApi.instance.metalayzerScope() != _scope) {
      throw StateError('Akkaunt o‘zgargan');
    }
  }

  Future<void> _lookup({bool scan = false}) async {
    if (_busy) return;
    if (scan) {
      setState(() => _busy = true);
      String? code;
      try {
        code = await showRawMaterialScanDialog(context,
            title: 'Xomashyoni skan qiling');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted || code == null) return;
      _barcode.text = code;
    }
    final barcode = rawMaterialBarcodeFromQr(_barcode.text);
    if (barcode.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _material = null;
    });
    try {
      _checkScope();
      final material = await MobileApi.instance.metalayzerMaterial(barcode);
      _checkScope();
      if (mounted) setState(() => _material = material);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final material = _material;
    if (_busy || material == null || material.isMetalayzer) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _checkScope();
      final result =
          await MobileApi.instance.metalayzerComplete(material.barcode);
      _checkScope();
      if (mounted) setState(() => _material = result);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is MobileApiException
      ? error.message
      : error
          .toString()
          .replaceFirst(RegExp(r'^(Bad state|FormatException): '), '');

  @override
  Widget build(BuildContext context) {
    final material = _material;
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      title: 'Metalayzer',
      subtitle: '',
      nativeTopBar: true,
      appBarBottomLoading: _busy,
      drawer: const MetalayzerDrawer(),
      bottom: const MetalayzerDock(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _lookup(scan: true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Xomashyoni skan qilish'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barcode,
            enabled: !_busy,
            decoration: const InputDecoration(
                labelText: 'Xomashyo QR kodi', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {
              _material = null;
              _error = null;
            }),
            onSubmitted: (_) => _lookup(),
          ),
          TextButton(
              onPressed: _busy ? null : _lookup,
              child: const Text('Tekshirish')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          if (material != null) ...[
            AppSegmentSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          material.itemName.isEmpty
                              ? material.itemCode
                              : material.itemName,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(material.barcode),
                      Text(material.warehouse),
                      Text('${material.qty} ${material.uom}'),
                      const SizedBox(height: 12),
                      Text(
                          material.isMetalayzer
                              ? 'Metalayzer bo‘ldi'
                              : 'Metalayzer bo‘lmagan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary)),
                    ]),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || material.isMetalayzer ? null : _complete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Metalayzer bo‘ldi'),
            ),
          ],
        ],
      ),
    );
  }
}
