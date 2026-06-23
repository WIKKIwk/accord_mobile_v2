import 'package:flutter/material.dart';

InputDecoration appSurfaceInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? suffixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool alignLabelWithHint = false,
  EdgeInsetsGeometry? contentPadding,
  double borderRadius = 12,
}) {
  final scheme = Theme.of(context).colorScheme;

  OutlineInputBorder outline({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide:
          BorderSide(color: color ?? scheme.outlineVariant, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: contentPadding,
    filled: true,
    fillColor: scheme.surface,
    border: outline(),
    enabledBorder: outline(),
    focusedBorder: outline(color: scheme.primary, width: 1.2),
    errorBorder: outline(color: scheme.error),
    focusedErrorBorder: outline(color: scheme.error, width: 1.2),
  );
}

InputDecoration appSoftInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? suffixText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  double borderRadius = 18,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final fillColor = theme.brightness == Brightness.light
      ? scheme.surfaceBright
      : scheme.surfaceContainerHighest;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: scheme.primary, width: 1.6),
    ),
  );
}
