part of 'admin_production_map_orders_screen.dart';

typedef _ProgressPrinterOption = ProgressPrinterOption;

Future<_ProgressPrinterOption?> _pickProgressPrinter(
  BuildContext context,
  Future<String?> Function(BuildContext context)? progressDriverUrlPicker,
) {
  return pickProgressPrinter(
    context,
    driverUrlPicker: progressDriverUrlPicker,
  );
}
