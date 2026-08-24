import '../../../core/security/state/security_controller.dart';
import '../../../core/localization/app_localizations.dart';
import 'pin_setup_purpose.dart';
import 'widgets/pin_entry_scaffold.dart';
import 'package:flutter/material.dart';

class PinSetupConfirmScreen extends StatefulWidget {
  const PinSetupConfirmScreen({super.key, required this.args});

  final PinSetupConfirmArgs args;

  @override
  State<PinSetupConfirmScreen> createState() => _PinSetupConfirmScreenState();
}

class _PinSetupConfirmScreenState extends State<PinSetupConfirmScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_saving) {
      return;
    }
    final pin = _pinController.text.trim();
    setState(() {
      _error = null;
    });
    if (pin != widget.args.firstPin) {
      setState(() {
        _pinController.clear();
        _error = context.l10n.pinMismatch;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      switch (widget.args.purpose) {
        case PinSetupPurpose.appLock:
          await SecurityController.instance.savePinForCurrentUser(pin);
        case PinSetupPurpose.profileSwitch:
          await SecurityController.instance.saveSwitchPinForCurrentUser(pin);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pinController.clear();
        _error = context.l10n.pinSaveFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PinEntryScaffold(
      title: widget.args.purpose == PinSetupPurpose.profileSwitch
          ? l10n.switchPinRepeatTitle
          : l10n.pinRepeatTitle,
      subtitle: '',
      controller: _pinController,
      actionLabel: l10n.save,
      onAction: _handleConfirm,
      errorText: _error,
      busy: _saving,
    );
  }
}
