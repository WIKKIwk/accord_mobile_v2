import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../gscale/gscale_mobile_app.dart';
import '../models/raw_material_split_models.dart';
import 'raw_material_split_navigation.dart';
import 'raw_material_split_result_view.dart';
import 'raw_material_split_print.dart';

class RawMaterialSplitHistoryScreen extends StatefulWidget {
  const RawMaterialSplitHistoryScreen({super.key});

  @override
  State<RawMaterialSplitHistoryScreen> createState() =>
      _RawMaterialSplitHistoryScreenState();
}

class _RawMaterialSplitHistoryScreenState
    extends State<RawMaterialSplitHistoryScreen> {
  RawSplitSnapshot? _snapshot;
  PrintDeviceSelection? _printer;
  String _wifiPrinter = 'godex';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await MobileApi.instance.rawSplitSnapshot();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectPrinter() async {
    final selection = await showPrintDevicePicker(context);
    if (!mounted || selection == null) return;
    setState(() => _printer = selection);
  }

  Future<void> _reprint(RawSplitResult result, {RawSplitRoll? only}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_printer == null) {
        await _selectPrinter();
        if (_printer == null) return;
      }
      final printer = _printer!;
      for (final output in only == null ? result.outputs : [only]) {
        if (!mounted) return;
        if (printer.transport.isLocal) {
          final response = await PrintService.printRps(
            rawMaterialSplitPrintRequest(output),
            printerProfile: printer.offlinePrinter,
            bluetoothPrinter: printer.bluetoothPrinter,
            transport: printer.transport,
          );
          if (!response.ok || response.status != 'done') {
            throw StateError('Printer natijani tasdiqlamadi');
          }
        } else {
          await MobileApi.instance.rawSplitPrint(
            splitId: result.id,
            barcode: output.barcode,
            driverUrl: driverUrlForRs(printer.server!),
            printer: _wifiPrinter,
            printMode: 'label',
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Chop etildi')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ombordagi hisob o‘zgarmadi. Chop etish: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.rawMaterialSplit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _snapshot?.history ?? const <RawSplitResult>[];
    final issues = _snapshot?.issues ?? const <RawSplitIssue>[];
    return AppShell(
      leading: IconButton(
        tooltip: 'Orqaga',
        onPressed: _goBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: 'Rezka tarixi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: const RawMaterialSplitDrawer(history: true),
      contentPadding: EdgeInsets.zero,
      appBarBottomLoading: _busy,
      actions: [
        IconButton(
          tooltip: 'Printer tanlash',
          onPressed: _busy ? null : _selectPrinter,
          icon: DevicePickerIcon(attention: _printer == null),
        ),
      ],
      bottom: const RawMaterialSplitDock(),
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            if (_snapshot == null && _busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (history.isEmpty && issues.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Hali bo‘lish tarixi yo‘q.'),
              )
            else ...[
              if (_printer != null) ...[
                Row(
                  children: [
                    const Icon(Icons.print_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Printer: ${_printer!.transport.apiValue}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (!_printer!.transport.isLocal)
                      DropdownButton<String>(
                        value: _wifiPrinter,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                  () => _wifiPrinter = value!,
                                ),
                        items: const [
                          DropdownMenuItem(
                              value: 'godex', child: Text('GoDEX')),
                          DropdownMenuItem(
                              value: 'zebra', child: Text('Zebra')),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 32),
              ],
              for (final result in history)
                RawMaterialSplitResultView(
                  result: result,
                  busy: _busy,
                  onReprint: (output) => _reprint(result, only: output),
                  onReprintAll: () => _reprint(result),
                ),
            ],
            if (issues.isNotEmpty) ...[
              const Divider(height: 32),
              Text('Muammolar', style: Theme.of(context).textTheme.titleMedium),
              for (final issue in issues)
                Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(issue.source.itemName),
                    subtitle: Text(issue.check.message),
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('QR: ${issue.source.barcode}'),
                      Text(
                          'Asl: ${rawSplitDisplay(issue.source.kg)} kg · Atxot: ${issue.enteredWaste.isEmpty ? 'kiritilmagan' : issue.enteredWaste} kg'),
                      for (var i = 0; i < issue.outputs.length; i++)
                        Text(
                            '${i + 1}-rulon: ${rawSplitDisplay(issue.outputs[i]['width_mm'] as String)} mm · '
                            'Og‘irlik: ${rawSplitDisplay(issue.outputs[i]['gross_kg'] as String)} kg · '
                            'Babina: ${rawSplitDisplay(issue.outputs[i]['bobina_kg'] as String)} kg · '
                            'Netto: ${rawSplitDisplay(issue.outputs[i]['kg'] as String)} kg'),
                      const SizedBox(height: 8),
                      Text('Sabab: ${issue.note}'),
                      Text('${issue.actorName} · ${issue.createdAt.toLocal()}',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(history.any((result) => result.issueId == issue.id)
                          ? 'Muammo bo‘yicha rulonlar saqlangan.'
                          : 'Muammo sababi qayd etilgan.'),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
