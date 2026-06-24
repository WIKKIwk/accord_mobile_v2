import 'package:flutter/material.dart';

import '../buttons/app_action_button_styles.dart';

class AppDialogActionRow extends StatelessWidget {
  const AppDialogActionRow({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.buttonRadius = 14,
    this.gap = 12,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final double buttonRadius;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: appOutlinedActionButtonStyle(borderRadius: buttonRadius),
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: FilledButton(
            style: appFilledActionButtonStyle(borderRadius: buttonRadius),
            onPressed: onConfirm,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
