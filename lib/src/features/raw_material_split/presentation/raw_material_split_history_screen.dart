import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../gscale/gscale_mobile_app.dart';
import '../models/raw_material_split_models.dart';
import 'raw_material_split_navigation.dart';
import 'raw_material_split_print.dart';
import 'raw_material_split_result_view.dart';

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

  Future<void> _showResultDetails(RawSplitResult result) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => RawSplitDetailsSheet(
        result: result,
        printerLabel: _printer?.transport.apiValue,
        showWifiSelector:
            _printer != null && !_printer!.transport.isLocal,
        wifiPrinter: _wifiPrinter,
        onReprint: (output) => _reprint(result, only: output),
        onReprintAll: () => _reprint(result),
        onSelectPrinter: () async {
          Navigator.of(sheetContext).pop();
          await _selectPrinter();
        },
        onWifiChanged: (value) => setState(() => _wifiPrinter = value),
      ),
    );
  }

  Future<void> _showIssueDetails(
    RawSplitIssue issue,
    bool hasResult,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => RawSplitIssueDetailsSheet(
        issue: issue,
        hasResult: hasResult,
      ),
    );
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
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
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
      preferNativeTitle: true,
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
      child: AppRefreshIndicator(
        onRefresh: _reload,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RawSplitHistoryMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Tarix yuklanmadi',
                  subtitle: _error,
                  onTap: _busy ? null : _reload,
                ),
              )
            else if (_snapshot == null && _busy)
              const RawSplitHistoryLoading()
            else if (history.isEmpty && issues.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: RawSplitHistoryMessage(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Hali bo‘lish tarixi yo‘q.',
                ),
              )
            else ...[
              if (_printer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: RawSplitHistoryMessage(
                    icon: Icons.print_outlined,
                    title: 'Printer: ${_printer!.transport.apiValue}',
                    subtitle: _printer!.transport.isLocal
                        ? null
                        : 'Wi-Fi printer: $_wifiPrinter',
                  ),
                ),
              if (history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: M3SegmentSpacedColumn(
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < history.length; i++)
                        RawSplitHistoryCard(
                          slot: M3SegmentedListGeometry
                              .standaloneListSlotForIndex(i, history.length),
                          result: history[i],
                          onTap: () => _showResultDetails(history[i]),
                        ),
                    ],
                  ),
                ),
            ],
            if (issues.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Muammolar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: M3SegmentSpacedColumn(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < issues.length; i++)
                      RawSplitIssueCard(
                        slot: M3SegmentedListGeometry
                            .standaloneListSlotForIndex(i, issues.length),
                        issue: issues[i],
                        hasResult: history.any(
                          (result) => result.issueId == issues[i].id,
                        ),
                        onTap: () => _showIssueDetails(
                          issues[i],
                          history.any(
                            (result) => result.issueId == issues[i].id,
                          ),
                        ),
                      ),
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
