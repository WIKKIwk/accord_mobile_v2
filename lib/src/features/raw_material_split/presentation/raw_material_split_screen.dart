import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../gscale/gscale_mobile_app.dart';
import '../models/raw_material_split_models.dart';
import '../models/raw_material_split_width_plan.dart';
import 'raw_material_split_navigation.dart';
import 'raw_material_split_print.dart';

class RawMaterialSplitScreen extends StatefulWidget {
  const RawMaterialSplitScreen({super.key});
  @override
  State<RawMaterialSplitScreen> createState() => _RawMaterialSplitScreenState();
}

class _OutputDraft {
  final gross = TextEditingController();
  final bobina = TextEditingController();
  final width = TextEditingController();
  bool get isEmpty =>
      [width, gross, bobina].every((c) => c.text.trim().isEmpty);
  BigInt get net {
    final value = rawSplitQuantity(gross.text) -
        rawSplitQuantity(bobina.text, allowZero: true);
    if (value <= BigInt.zero) {
      throw const FormatException(
          'Rulon og‘irligi babina kg dan katta bo‘lsin');
    }
    return value;
  }

  String get netLabel {
    try {
      return 'Netto: ${rawSplitDisplay(rawSplitDecimal(net))} kg';
    } catch (_) {
      return 'Netto: —';
    }
  }

  void dispose() {
    gross.dispose();
    bobina.dispose();
    width.dispose();
  }
}

class _RawMaterialSplitScreenState extends State<RawMaterialSplitScreen> {
  final _barcode = TextEditingController();
  final _waste = TextEditingController();
  final _outputs = <_OutputDraft>[];
  RawSplitRoll? _source;
  RawSplitSnapshot? _snapshot;
  RawSplitResult? _saved;
  Map<String, dynamic>? _pending;
  PrintDeviceSelection? _printer;
  String _wifiPrinter = 'godex';
  String? _error;
  bool _busy = false;
  late final String _scope;
  bool get _locked => _busy || _pending != null;
  @override
  void initState() {
    super.initState();
    _scope = MobileApi.instance.rawSplitScope();
    _reload();
  }

  @override
  void dispose() {
    _barcode.dispose();
    _waste.dispose();
    for (final o in _outputs) {
      o.dispose();
    }
    super.dispose();
  }

  void _checkScope() {
    if (!mounted || MobileApi.instance.rawSplitScope() != _scope) {
      throw StateError('Akkaunt o‘zgargan');
    }
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pending = await MobileApi.instance.rawSplitPending();
      _checkScope();
      setState(() => _pending = pending);
      final snapshot = await MobileApi.instance.rawSplitSnapshot();
      _checkScope();
      setState(() => _snapshot = snapshot);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sourceLookup({bool scan = false}) async {
    if (_locked) return;
    if (scan) {
      final barcode = await showRawMaterialScanDialog(context);
      if (!mounted || barcode == null) return;
      _barcode.text = barcode;
    }
    final barcode = rawMaterialBarcodeFromQr(_barcode.text);
    if (barcode.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _source = null;
      _saved = null;
    });
    try {
      final source = await MobileApi.instance.rawSplitSource(barcode);
      _checkScope();
      setState(() {
        _source = source;
        for (final o in _outputs) {
          o.dispose();
        }
        _outputs
          ..clear()
          ..add(_OutputDraft());
        _waste.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _payload() {
    final source = _source!;
    _widthPlan.validateForSave();
    if (_waste.text.trim().isEmpty) {
      throw const FormatException('Atxot kg ni kiriting (0 dan katta)');
    }
    final waste = rawSplitQuantity(_waste.text, allowZero: true);
    if (waste == BigInt.zero) {
      throw const FormatException('Atxot 0 dan katta bo‘lishi kerak');
    }
    var sum = waste;
    final outputs = <Map<String, String>>[];
    for (final o in _outputs) {
      if (o.gross.text.trim().isEmpty || o.bobina.text.trim().isEmpty) {
        throw const FormatException(
            'Har bir rulonning og‘irligi va babina kg ini kiriting');
      }
      final kg = o.net;
      final width = rawSplitQuantity(o.width.text);
      if (width > rawSplitQuantity(source.widthMm)) {
        throw const FormatException('Chiqish eni asl rulondan katta');
      }
      sum += kg;
      outputs.add({
        'kg': rawSplitDecimal(kg),
        'width_mm': rawSplitDecimal(width),
        'gross_kg': rawSplitDecimal(rawSplitQuantity(o.gross.text)),
        'bobina_kg':
            rawSplitDecimal(rawSplitQuantity(o.bobina.text, allowZero: true)),
      });
    }
    if (sum != rawSplitQuantity(source.kg)) {
      throw const FormatException(
          'Rulonlar + chiqindi asl kg ga aniq teng bo‘lsin');
    }
    return {
      'request_id': newRawSplitRequestId(),
      'source_barcode': source.barcode,
      'expected_revision': source.revision!,
      'expected_kg': source.kg,
      'expected_width_mm': source.widthMm,
      'expected_micron': source.micron,
      'waste_kg': rawSplitDecimal(waste),
      'outputs': outputs
    };
  }

  Future<bool> _selectPrinter() async {
    final selection = await showPrintDevicePicker(context);
    if (!mounted || selection == null) return false;
    setState(() => _printer = selection);
    return true;
  }

  Future<void> _save({bool retry = false}) async {
    if (_busy || (!retry && _locked)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = retry ? _pending! : _payload();
      if (_printer == null && !await _selectPrinter()) return;
      _checkScope();
      final result = await MobileApi.instance.rawSplitSave(payload);
      _checkScope();
      // Stock is already committed. Print failures only expose reprint.
      setState(() {
        _saved = result;
        _source = null;
        _pending = null;
        _barcode.clear();
      });
      await _print(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            _saved != null ? 'Omborga saqlandi. Chop etish: $e' : e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _reload();
      }
    }
  }

  Future<void> _print(RawSplitResult result) async {
    final printer = _printer!;
    for (final output in result.outputs) {
      _checkScope();
      if (printer.transport.isLocal) {
        final response = await PrintService.printRps(
            rawMaterialSplitPrintRequest(output),
            printerProfile: printer.offlinePrinter,
            bluetoothPrinter: printer.bluetoothPrinter,
            transport: printer.transport);
        if (!response.ok || response.status != 'done') {
          throw StateError('Printer natijani tasdiqlamadi');
        }
      } else {
        await MobileApi.instance.rawSplitPrint(
            splitId: result.id,
            barcode: output.barcode,
            driverUrl: driverUrlForRs(printer.server!),
            printer: _wifiPrinter,
            printMode: 'label');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chop etildi')));
    }
  }

  String get _balance {
    try {
      final sum = _outputs.fold(BigInt.zero, (a, o) => a + o.net);
      final waste = rawSplitQuantity(_waste.text);
      final delta = rawSplitQuantity(_source!.kg) - sum - waste;
      return 'Chiqish: ${rawSplitDisplay(rawSplitDecimal(sum))} kg · Chiqindi: ${rawSplitDisplay(rawSplitDecimal(waste))} kg'
          '\n${delta == BigInt.zero ? 'Hisob teng ✓' : delta.isNegative ? 'Asl kg dan oshib ketdi' : 'Kiritilmagan: ${rawSplitDisplay(rawSplitDecimal(delta))} kg'}';
    } catch (_) {
      return 'Og‘irlik, babina va 0 dan katta atxot kg ni kiriting.';
    }
  }

  RawSplitWidthPlan get _widthPlan => RawSplitWidthPlan(
      _source!.widthMm, _outputs.map((o) => o.width.text).toList());

  void _confirmWidth() {
    if (_locked || _source == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _error = null;
      final plan = _widthPlan;
      // Never discard entered weights or widths when another row is edited.
      if (plan.valid && plan.remaining < rawSplitMinimumWidth) {
        final empty = _outputs.where((o) => o.isEmpty).toList();
        for (final output in empty) {
          if (_outputs.length <= 1) break;
          _outputs.remove(output);
          output.dispose();
        }
      }
    });
  }

  void _addRoll() {
    if (_locked || _source == null || !_widthPlan.canAdd) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _error = null;
      _outputs.add(_OutputDraft());
    });
  }

  Widget _addRollButton() {
    final decoration = Theme.of(context).inputDecorationTheme;
    final border = decoration.enabledBorder ?? decoration.border;
    return FilledButton(
        onPressed: _locked ? null : _addRoll,
        style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: border is OutlineInputBorder
                    ? border.borderRadius
                    : BorderRadius.circular(16))),
        child: const Text('+ rulon'));
  }

  Widget _widthSummary() {
    final plan = _widthPlan;
    final remaining = plan.remaining;
    final text = !plan.valid ||
            _outputs.every((o) => o.width.text.trim().isEmpty)
        ? 'Ko‘pi bilan ${plan.maxRolls} ta rulon · eng kam eni 355 mm'
        : remaining == BigInt.zero
            ? 'En to‘liq taqsimlandi'
            : remaining < rawSplitMinimumWidth
                ? 'Qolgan ${rawSplitDisplay(rawSplitDecimal(remaining))} mm — atxot'
                : 'Qolgan ${rawSplitDisplay(rawSplitDecimal(remaining))} mm — yana rulon kiriting';
    return Text(text);
  }

  String? get _wasteWidthLabel {
    if (_source == null) return null;
    final plan = _widthPlan;
    if (!plan.valid || !plan.complete) return null;
    final remaining = plan.remaining;
    return remaining >= rawSplitMinimumWidth
        ? 'Yana rulon kerak: ${rawSplitDisplay(rawSplitDecimal(remaining))} mm'
        : 'Atxotga ketadi: ${rawSplitDisplay(rawSplitDecimal(remaining))} mm';
  }

  Widget _number(TextEditingController c, String label,
      {VoidCallback? onDone, String? error}) {
    final inputTheme = Theme.of(context).inputDecorationTheme;
    final errorBorder = inputTheme.errorBorder ??
        OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error));
    return TextField(
        key: ObjectKey(c),
        controller: c,
        enabled: !_locked,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
            labelText: label,
            enabledBorder: error == null ? null : errorBorder,
            focusedBorder: error == null
                ? null
                : inputTheme.focusedErrorBorder ?? errorBorder),
        onSubmitted: onDone == null ? null : (_) => onDone(),
        onChanged: (_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Rezka',
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
        contentPadding: EdgeInsets.zero,
        appBarBottomLoading: _busy,
        drawer: const RawMaterialSplitDrawer(),
        bottom: const RawMaterialSplitDock(),
        actions: [
          IconButton(
              tooltip: 'Rezka tarixi',
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context)
                      .pushNamed(AppRoutes.rawMaterialSplitHistory),
              icon: const Icon(Icons.history_rounded)),
          IconButton(
              tooltip: 'Printer tanlash',
              onPressed: _busy ? null : _selectPrinter,
              icon: DevicePickerIcon(attention: _printer == null))
        ],
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            children: [
              if (_error != null) ...[
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
              ],
              if (_pending != null) ...[
                const Text('Oldingi saqlash natijasini tekshiring.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _busy ? null : () => _save(retry: true),
                    child: const Text('Tekshirish va chop etish')),
                const SizedBox(height: 24),
              ],
              Text(
                  _snapshot == null
                      ? 'Omborlar yuklanmoqda'
                      : _snapshot!.warehouses.isEmpty
                          ? 'Ombor biriktirilmagan'
                          : 'Ombor: ${_snapshot!.warehouses.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(
                  controller: _barcode,
                  enabled: !_locked,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                      labelText: 'Rulon QR / shtrix-kodi',
                      suffixIcon: IconButton(
                          tooltip: 'Rulonni topish',
                          onPressed: _locked ? null : () => _sourceLookup(),
                          icon: const Icon(Icons.arrow_forward_rounded))),
                  onSubmitted: (_) => _sourceLookup()),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _locked ? null : () => _sourceLookup(scan: true),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Skanerlash')),
              if (_printer != null) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.print_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Printer: ${_printer!.transport.apiValue}',
                          style: Theme.of(context).textTheme.bodySmall)),
                  if (!_printer!.transport.isLocal)
                    DropdownButton<String>(
                        value: _wifiPrinter,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _wifiPrinter = v!),
                        items: const [
                          DropdownMenuItem(
                              value: 'godex', child: Text('GoDEX')),
                          DropdownMenuItem(value: 'zebra', child: Text('Zebra'))
                        ]),
                ]),
              ],
              if (_source != null) ...[
                const Divider(height: 32),
                Text(_source!.itemName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                    '${rawSplitDisplay(_source!.kg)} kg · ${rawSplitDisplay(_source!.widthMm)} mm · ${rawSplitDisplay(_source!.micron)} mkm'),
                Text('Ombor: ${_source!.warehouse}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                _widthSummary(),
                const SizedBox(height: 8),
                for (var i = 0; i < _outputs.length; i++) ...[
                  Row(children: [
                    Expanded(
                        child: Text('${i + 1}-rulon',
                            style: Theme.of(context).textTheme.titleSmall)),
                    IconButton(
                        tooltip: 'Rulonni olib tashlash',
                        onPressed: _locked || _outputs.length <= 1
                            ? null
                            : () {
                                setState(() {
                                  _outputs.removeAt(i).dispose();
                                });
                              },
                        icon: const Icon(Icons.close))
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _number(_outputs[i].width, 'Eni (mm)',
                            onDone: _confirmWidth,
                            error: _widthPlan.errors[i])),
                    const SizedBox(width: 12),
                    Expanded(child: _number(_outputs[i].gross, 'Og‘irlik (kg)'))
                  ]),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child:
                                  _number(_outputs[i].bobina, 'Babina (kg)')),
                          const SizedBox(width: 12),
                          Expanded(
                              child:
                                  i == _outputs.length - 1 && _widthPlan.canAdd
                                      ? _addRollButton()
                                      : Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(_outputs[i].netLabel,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall))),
                        ]),
                  ),
                  if (i == _outputs.length - 1 && _widthPlan.canAdd) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Expanded(child: SizedBox.shrink()),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_outputs[i].netLabel,
                              style: Theme.of(context).textTheme.bodySmall)),
                    ]),
                  ],
                  const SizedBox(height: 20),
                ],
                const Divider(height: 32),
                _number(_waste, 'Atxot (kg) *'),
                const SizedBox(height: 16),
                for (var i = 0; i < _outputs.length; i++)
                  if (_widthPlan.errors[i] != null) ...[
                    Text('${i + 1}-rulon: ${_widthPlan.errors[i]}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 8),
                  ],
                Text(_balance),
                const SizedBox(height: 20),
                if (_wasteWidthLabel != null) ...[
                  Align(
                      alignment: Alignment.center,
                      child: Text(_wasteWidthLabel!,
                          style: Theme.of(context).textTheme.bodySmall)),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                    onPressed: _locked ? null : () => _save(),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Saqlash va chop etish')),
              ],
            ]),
      );
}
