import 'package:flutter/material.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session_read_scope.dart';
import '../../admin/presentation/progress_printer_picker.dart';

/// Printing never changes package membership, lock or archive state.
class QolipPaddonPrintButton extends StatefulWidget {
  const QolipPaddonPrintButton({super.key, required this.code});
  final String code;
  @override
  State<QolipPaddonPrintButton> createState() => _PrintState();
}

class _PrintState extends State<QolipPaddonPrintButton> {
  bool _busy = false;
  Future<void> _print() async {
    if (_busy) return;
    final scope = currentSessionReadScope();
    setState(() => _busy = true);
    try {
      final printer = await pickProgressPrinter(context);
      if (printer == null || !mounted || scope != currentSessionReadScope()) {
        return;
      }
      final job = await MobileApi.instance.qolipPrintPaddonQr(
        code: widget.code,
        driverUrl: printer.driverUrl,
        printer: printer.printer,
        printMode: printer.printMode,
        transport: printer.transport,
      );
      if (!mounted || scope != currentSessionReadScope()) return;
      if (printer.transport.isLocal) {
        final result = await PrintService.printRps(job,
            printerProfile: printer.offlinePrinter,
            bluetoothPrinter: printer.bluetoothPrinter,
            transport: printer.transport);
        if (!result.ok) throw StateError('Printer rejected label');
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
  Widget build(BuildContext context) => IconButton(
        tooltip: context.l10n.productionText('worker.paddon.print'),
        onPressed: _busy ? null : _print,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.print_outlined),
      );
}
