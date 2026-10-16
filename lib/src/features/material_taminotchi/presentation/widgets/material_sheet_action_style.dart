import 'package:flutter/material.dart';

const materialSheetActionGap = 8.0;

const materialSheetActionStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
  ),
);
