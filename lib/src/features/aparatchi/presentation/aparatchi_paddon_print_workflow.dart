part of 'aparatchi_paddon_detail_screen.dart';

extension _PaddonPrintWorkflow on _AparatchiPaddonDetailScreenState {
  Future<void> _unlockPaddon() async {
    if (_busy || _printingQr || widget.busy || _qrScanMode) return;
    final scope = currentSessionReadScope();
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: context.l10n.productionText('worker.paddon.unlock.title'),
      message: context.l10n.productionText('worker.paddon.unlock.body',
          values: {'code': widget.code}),
      cancelLabel: context.l10n.no,
      confirmLabel: context.l10n.yes,
      confirmButtonKey: const ValueKey('paddon-unlock-confirm'),
      cancelButtonKey: const ValueKey('paddon-unlock-cancel'),
    );
    if (confirmed != true || !mounted || scope != currentSessionReadScope()) return;
    final applied = await _runMutation(
      () => MobileApi.instance.unlockPaddon(widget.code),
      confirmsApplied: (snapshot) => !snapshot.paddon.isLocked,
      fallbackMessage: context.l10n.productionText('worker.paddon.unlock.failed'),
      expectedReadScope: scope,
    );
    if (!applied || !mounted || scope != currentSessionReadScope()) return;
    _exitSelection();
    ActiveRezkaPaddonStore.notifyChanged();
    _showMessage(context.l10n.productionText('worker.paddon.unlock.success'));
  }

  Future<void> _printPaddonQr() async {
    if (_busy || _printingQr) return;
    final scope = currentSessionReadScope();
    _setPrintingQr(true);
    var printed = false;
    var confirmed = false;
    try {
      final printer = await pickProgressPrinter(context);
      if (printer == null || !mounted || scope != currentSessionReadScope()) {
        return;
      }
      final result = await MobileApi.instance.adminPaddonPrintQr(
        code: widget.code,
        driverUrl: printer.driverUrl,
        printer: printer.printer,
        printMode: printer.printMode,
        printTransport: printer.transport,
      );
      if (!result.ok) throw StateError('Print request failed');
      if (scope != currentSessionReadScope()) return;
      if (printer.transport.isLocal) {
        final job = result.printJob;
        if (job == null) throw StateError('Missing print data');
        final response = await PrintService.printRps(job,
            printerProfile: printer.offlinePrinter,
            bluetoothPrinter: printer.bluetoothPrinter,
            transport: printer.transport);
        if (!response.ok) throw StateError('Printer rejected the label');
      }
      printed = true;
      if (scope != currentSessionReadScope()) return;
      if (result.canCloseAfterPrint &&
          !result.paddon.isLocked &&
          widget.manageItems) {
        // USB/Bluetooth confirmation happens only after the local printer succeeds.
        final completion =
            await MobileApi.instance.confirmPaddonPrint(widget.code);
        confirmed = true;
        ActiveRezkaPaddonStore.notifyChanged();
        if (!mounted || scope != currentSessionReadScope()) return;
        await _retry();
        if (!mounted || scope != currentSessionReadScope()) return;
        _setPrintingQr(false);
        if (!completion.newlyLocked) return;
        final create = await showM3ConfirmDialog(
          context: context,
          title: context.l10n.productionText('worker.paddon.next.title'),
          message: context.l10n.productionText('worker.paddon.next.body',
              values: {'code': widget.code}),
          cancelLabel: context.l10n.no,
          confirmLabel: context.l10n.yes,
          confirmButtonKey: const ValueKey('paddon-next-confirm'),
          cancelButtonKey: const ValueKey('paddon-next-cancel'),
        );
        if (create != true || !mounted || scope != currentSessionReadScope()) {
          return;
        }
        var apparatus = completion.apparatus;
        apparatus ??= await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
                  title: Text(context.l10n
                      .productionText('worker.paddon.next.apparatus')),
                  children: [
                    for (final option in completion.apparatusOptions.entries)
                      SimpleDialogOption(
                          onPressed: () =>
                              Navigator.of(context).pop(option.key),
                          child: Text(option.value)),
                  ],
                ));
        if (apparatus == null ||
            !mounted ||
            scope != currentSessionReadScope()) {
          return;
        }
        _setPrintingQr(true);
        final next = await MobileApi.instance.createActivePaddonSuccessor(
            code: widget.code, apparatus: apparatus);
        ActiveRezkaPaddonStore.notifyChanged();
        if (mounted && scope == currentSessionReadScope()) {
          _showMessage(context.l10n.productionText('worker.paddon.next.created',
              values: {'code': next.code}));
        }
      } else if (mounted) {
        _showMessage(context.l10n.productionText('worker.paddon.printed',
            values: {'qr': result.qrPayload}));
      }
    } catch (error) {
      if (mounted && scope == currentSessionReadScope()) {
        final key = confirmed
            ? 'worker.paddon.create_failed'
            : printed
                ? 'worker.paddon.print_confirm_failed'
                : 'worker.paddon.print_failed';
        _showMessage(error is MobileApiException
            ? context.l10n.productionErrorMessage(error.code,
                fallback: context.l10n.productionText(key))
            : context.l10n.productionText(key));
      }
    } finally {
      if (mounted) _setPrintingQr(false);
    }
  }
}
