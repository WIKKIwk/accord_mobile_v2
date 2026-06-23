import 'package:flutter/material.dart';

import '../buttons/app_action_button_styles.dart';

Future<String?> showAppTextInputDialog({
  required BuildContext context,
  required String title,
  String? initialText,
  String? hintText,
  TextInputType? keyboardType,
  double cardRadius = 18,
  double fieldRadius = 14,
  double buttonRadius = 14,
  String cancelLabel = 'Bekor qilish',
  String saveLabel = 'Saqlash',
}) async {
  final controller = TextEditingController(text: initialText);
  try {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(fieldRadius),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: appOutlinedActionButtonStyle(
                        borderRadius: buttonRadius,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: appFilledActionButtonStyle(
                        borderRadius: buttonRadius,
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      child: Text(saveLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
