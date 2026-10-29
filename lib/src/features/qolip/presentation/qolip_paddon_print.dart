import 'package:flutter/material.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session_read_scope.dart';
import '../../admin/presentation/progress_printer_picker.dart';

/// Returns false when printer selection or the originating session is cancelled.
Future<bool> printQolipPaddonQr(BuildContext context,
    {required String code, required String scope}) async {
  if (!context.mounted || scope != currentSessionReadScope()) return false;
  final printer = await pickProgressPrinter(context);
  if (printer == null ||
      !context.mounted ||
      scope != currentSessionReadScope()) {
    return false;
  }
  final job = await MobileApi.instance.qolipPrintPaddonQr(
    code: code,
    driverUrl: printer.driverUrl,
    printer: printer.printer,
    printMode: printer.printMode,
    transport: printer.transport,
  );
  if (!context.mounted || scope != currentSessionReadScope()) return false;
  if (printer.transport.isLocal) {
    final result = await PrintService.printRps(job,
        printerProfile: printer.offlinePrinter,
        bluetoothPrinter: printer.bluetoothPrinter,
        transport: printer.transport);
    if (!result.ok) throw StateError('Printer rejected label');
  }
  return context.mounted && scope == currentSessionReadScope();
}

/// Printing never changes package membership, lock or archive state.
class QolipPaddonPrintButton extends StatefulWidget {
  const QolipPaddonPrintButton({
    super.key,
    required this.code,
    this.filled = false,
    this.enabled = true,
  });
  final String code;
  final bool filled;
  final bool enabled;
  @override
  State<QolipPaddonPrintButton> createState() => _PrintState();
}

class _PrintState extends State<QolipPaddonPrintButton> {
  bool _busy = false;
  Future<void> _print() async {
    if (_busy || !widget.enabled) return;
    final scope = currentSessionReadScope();
    setState(() => _busy = true);
    try {
      if (!await printQolipPaddonQr(context, code: widget.code, scope: scope)) {
        return;
      }
      if (mounted && scope == currentSessionReadScope()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.productionText('worker.paddon.printed',
                values: {'qr': widget.code}))));
      }
    } catch (_) {
      if (mounted && scope == currentSessionReadScope()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                context.l10n.productionText('worker.paddon.print_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox.square(
            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.qr_code_2_rounded, size: 18);
    if (widget.filled) {
      return FilledButton.icon(
        key: const ValueKey('qolip-paddon-print-qr'),
        onPressed: _busy || !widget.enabled ? null : _print,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: icon,
        label: Text(context.l10n.productionText('worker.paddon.print.short')),
      );
    }
    return IconButton(
      tooltip: context.l10n.productionText('worker.paddon.print'),
      onPressed: _busy || !widget.enabled ? null : _print,
      icon: icon,
    );
  }
}
