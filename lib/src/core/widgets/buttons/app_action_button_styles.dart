import 'package:flutter/material.dart';

const appPillActionButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(50)),
  shape: WidgetStatePropertyAll(StadiumBorder()),
);

ButtonStyle appFilledActionButtonStyle({double borderRadius = 14}) {
  return FilledButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    minimumSize: const Size(0, 54),
  );
}

ButtonStyle appOutlinedActionButtonStyle({double borderRadius = 14}) {
  return OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    minimumSize: const Size(0, 54),
  );
}
