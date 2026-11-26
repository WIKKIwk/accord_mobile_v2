import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/forms/app_input_decoration.dart';
import '../../gscale/gscale_mobile_app.dart';
import 'waste_bin_details.dart';
import 'waste_warehouses_screen.dart';

class WasteMeasurement {
  const WasteMeasurement(
      this.grossKg, this.source, this.note, this.warehouseId);

  final double grossKg;
  final String source, note, warehouseId;
}

class WasteWeighDialog extends StatefulWidget {
  const WasteWeighDialog({
    super.key,
    required this.bin,
    required this.warehouses,
  });

  final WasteBin bin;
  final List<WasteWarehouse> warehouses;

  @override
  State<WasteWeighDialog> createState() => _WasteWeighDialogState();
}

class _WasteWeighDialogState extends State<WasteWeighDialog> {
  final _gross = TextEditingController();
  final _note = TextEditingController();
  final _client = http.Client();
  DiscoveredServer? _scale;
  String? _scaleError;
  bool _reading = false;
  String _source = 'manual';
  late String? _warehouseId =
      widget.warehouses.length == 1 ? widget.warehouses.single.id : null;

  @override
  void dispose() {
    _client.close();
    _gross.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickScale() async {
    final selected = await showModalBottomSheet<DiscoveredServer>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _WasteScalePicker(),
    );
    if (!mounted || selected == null) return;
    setState(() => _scale = selected);
    await _readScale();
  }

  Future<void> _readScale() async {
    final scale = _scale;
    if (scale == null || _reading) return;
    setState(() {
      _reading = true;
      _scaleError = null;
      _gross.clear();
    });
    try {
      final response = await _client
          .get(Uri.parse(
            '${scale.endpoint.baseUrl}/v1/mobile/monitor/state',
          ))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) throw const FormatException();
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final state = payload['state'] as Map<String, dynamic>;
      final reading = state['scale'] as Map<String, dynamic>;
      final kg = wasteKgInput(reading['weight']?.toString() ?? '');
      final error = reading['error'];
      if (reading['stable'] != true ||
          reading['unit']?.toString().trim().toLowerCase() != 'kg' ||
          kg == null ||
          (error is String && error.trim().isNotEmpty)) {
        throw const FormatException();
      }
      if (!mounted) return;
      setState(() {
        _gross.text = kg.toString();
        _source = 'gscale';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _scaleError =
            'Tarozi barqaror kg qiymatini bermadi. Qayta o‘qing yoki qo‘lda kiriting.');
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = widget.bin.cycle!.expectedKg;
    final gross = wasteKgInput(_gross.text);
    final tare = widget.bin.tareKg;
    final net = gross == null || gross < tare ? null : gross - tare;
    final delta =
        net == null ? null : ((net - expected) * 1000000).round() / 1000000;
    final difference = delta != null && delta.abs() > widget.bin.toleranceKg;
    final valid = !_reading &&
        _warehouseId != null &&
        net != null &&
        (!difference || _note.text.trim().isNotEmpty);

    return AlertDialog(
      title: Text('${widget.bin.code} qutisini tortish'),
      scrollable: true,
      insetPadding: m3DialogInsetPadding,
      constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
      content: SizedBox(
        width: m3DialogMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WasteWarehouseField(
              warehouses: widget.warehouses,
              selectedId: _warehouseId,
              onChanged: (id) => setState(() => _warehouseId = id),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _reading ? null : _pickScale,
                  style: appOutlinedActionButtonStyle(),
                  icon: const Icon(Icons.scale_outlined),
                  label: Text(_scale == null ? 'GScale' : 'Tarozini tanlash'),
                ),
                if (_scale != null)
                  TextButton(
                    onPressed: _reading ? null : _readScale,
                    child: const Text('Vaznni qayta o‘qish'),
                  ),
              ],
            ),
            if (_reading) const LinearProgressIndicator(),
            if (_scaleError != null) ...[
              const SizedBox(height: 8),
              Text(_scaleError!),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _gross,
              enabled: !_reading,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: appSurfaceInputDecoration(
                context,
                labelText: 'Quti bilan vazn (kg)',
              ).copyWith(
                helperText: _source == 'gscale' ? 'GScale' : 'Qo‘lda kiritish',
                errorText: gross != null && gross < tare
                    ? 'Vazn bo‘sh quti vaznidan kichik'
                    : null,
              ),
              onChanged: (_) => setState(() {
                _source = 'manual';
                _scaleError = null;
              }),
            ),
            const SizedBox(height: 12),
            if (net != null && delta != null)
              WasteWeightComparison(
                expected: expected,
                gross: gross!,
                tare: tare,
                net: net,
                difference: delta,
                outsideTolerance: difference,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Qayd etilgan: ${wasteKgLabel(expected)}'),
                subtitle: Text('Bo‘sh quti: ${wasteKgLabel(tare)}'),
              ),
            if (difference) ...[
              const SizedBox(height: 12),
              Text(
                  'Tafovut ${wasteKgLabel(widget.bin.toleranceKg)} chegaradan oshdi. '
                  'Vaznni qayta tekshiring va sababini kiriting.'),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: appSurfaceInputDecoration(
                context,
                labelText: difference ? 'Tafovut sababi *' : 'Izoh',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: appOutlinedActionButtonStyle(),
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          style: appFilledActionButtonStyle(),
          onPressed: valid
              ? () => Navigator.pop(
                    context,
                    WasteMeasurement(
                      gross!,
                      _source,
                      _note.text.trim(),
                      _warehouseId!,
                    ),
                  )
              : null,
          child: const Text('Qabul qilish'),
        ),
      ],
    );
  }
}

class _WasteScalePicker extends StatefulWidget {
  const _WasteScalePicker();

  @override
  State<_WasteScalePicker> createState() => _WasteScalePickerState();
}

class _WasteScalePickerState extends State<_WasteScalePicker> {
  final _client = http.Client();
  late final Future<DiscoveryResult> _servers = discoverServers(_client);

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _manual() async {
    final server = await showModalBottomSheet<DiscoveredServer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ManualServerSheet(client: _client),
    );
    if (mounted && server != null) Navigator.pop(context, server);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: FutureBuilder<DiscoveryResult>(
          future: _servers,
          builder: (context, snapshot) => ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('GScale tarozisini tanlang')),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.data?.servers.isNotEmpty != true)
                const ListTile(title: Text('Tarozi topilmadi')),
              for (final server
                  in snapshot.data?.servers ?? <DiscoveredServer>[])
                ListTile(
                  title: Text(printTargetLabel(server)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, server),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Tarozi manzilini kiritish'),
                onTap: _manual,
              ),
            ],
          ),
        ),
      );
}
