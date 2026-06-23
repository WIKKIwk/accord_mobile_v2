import 'package:flutter/material.dart';

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
