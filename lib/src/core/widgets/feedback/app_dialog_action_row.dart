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
    this.vertical = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final double buttonRadius;
  final double gap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final cancelButton = OutlinedButton(
      style: appOutlinedActionButtonStyle(borderRadius: buttonRadius),
      onPressed: onCancel,
      child: Text(cancelLabel),
    );
    final confirmButton = FilledButton(
      style: appFilledActionButtonStyle(borderRadius: buttonRadius),
      onPressed: onConfirm,
      child: Text(confirmLabel),
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          confirmButton,
          SizedBox(height: gap),
          cancelButton,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: cancelButton,
        ),
        SizedBox(width: gap),
        Expanded(
          child: confirmButton,
        ),
      ],
    );
  }
}
