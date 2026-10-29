import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../shared/models/app_models.dart';
import 'qolip_home_screen.dart'
    show
        QolipPrinterOption,
        qolipPrinterChoiceForDriver,
        showQolipPrinterPicker;
import 'qolip_mileage_sheet.dart';

Future<void> showQolipCodeDetailsSheet(
  BuildContext context, {
  required QolipProduct product,
  required Future<void> Function()? onPayloadTap,
  required Future<String?> Function()? onReprint,
  List<RpsQrDetail> additionalDetails = const [],
  Widget Function(BuildContext context)? afterDetails,
  Widget Function(Widget child)? wrap,
  bool loadMileage = true,
}) async {
  final code = product.qolipCode.trim();
  if (code.isEmpty) return;
  final l10n = context.l10n;
  final itemName = product.name.trim().isEmpty ? code : product.name.trim();
  Future<QolipMileage>? mileageFuture;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (sheetContext) {
      final child = Builder(builder: (context) {
        return FutureBuilder<QolipMileage>(
          future: loadMileage
              ? (mileageFuture ??= MobileApi.instance.qolipMileage(code))
              : null,
          builder: (context, snapshot) {
            final mileage = snapshot.data;
            return RpsQrReprintSheet(
              title: l10n.qolipText('products.qr_title'),
              payload: code,
              onPayloadTap: onPayloadTap,
              payloadTapTooltip: l10n.adminText('action.copy'),
              payloadTapKey: ValueKey('qolip-code-qr-payload-$code'),
              itemName: itemName,
              previewKey: ValueKey('qolip-code-qr-preview-$code'),
              reprintButtonKey: ValueKey('qolip-code-qr-reprint-$code'),
              details: [
                if (product.code.trim().isNotEmpty)
                  RpsQrDetail(
                      l10n.qolipText('products.product_code'), product.code),
                if (product.qolipSize > 0)
                  RpsQrDetail(
                      l10n.qolipText('products.size'), '${product.qolipSize}'),
                if (product.customerNames.isNotEmpty)
                  RpsQrDetail(l10n.qolipText('products.customer'),
                      product.customerNames.join(', ')),
                ...additionalDetails,
                if (mileage != null &&
                    mileage.trackingEnabled &&
                    mileage.currentMeter != null)
                  RpsQrDetail(
                    l10n.qolipReworkText('distance'),
                    l10n.qolipReworkText('cycle', values: {
                      'meter': qolipMileageMeter(mileage.currentMeter!)
                    }),
                  ),
              ],
              afterDetails: afterDetails?.call(sheetContext),
              onReprint: onReprint,
              errorMessage: (error) => qolipErrorMessage(
                error,
                fallback: l10n.qolipText('products.qr_failed'),
                l10n: l10n,
              ),
            );
          },
        );
      });
      return wrap?.call(child) ?? child;
    },
  );
}

Future<String?> reprintQolipCodeQr(
  BuildContext context,
  QolipProduct product, {
  required String scope,
}) async {
  if (!context.mounted || scope != currentSessionReadScope()) {
    throw const RpsQrReprintCancelled();
  }
  final option = await showQolipPrinterPicker(context);
  if (!context.mounted ||
      option == null ||
      scope != currentSessionReadScope()) {
    throw const RpsQrReprintCancelled();
  }
  await printQolipCodeQrWithOption(product, option, scope: scope);
  return null;
}

Future<void> printQolipCodeQrWithOption(
  QolipProduct product,
  QolipPrinterOption option, {
  String? scope,
}) async {
  if (scope != null && scope != currentSessionReadScope()) {
    throw const RpsQrReprintCancelled();
  }
  final printer = option.transport.isLocal
      ? option.transport.isBluetooth
          ? option.bluetoothPrinter!.printer
          : option.offlinePrinter!.printer
      : qolipPrinterChoiceForDriver(
          kind: option.printerKind,
          label: option.printerLabel,
        );
  final result = await MobileApi.instance.qolipPrintCodeQr(
    qolipCode: product.qolipCode.trim(),
    driverUrl: option.driverUrl,
    printer: printer,
    printMode: option.transport.isLocal
        ? option.transport.isBluetooth
            ? option.bluetoothPrinter!.printMode
            : option.offlinePrinter!.printMode
        : printer == 'godex'
            ? 'label'
            : 'rfid',
    customerName: product.customerNames.join(', '),
    qolipColor: product.qolipColor,
    printTransport: option.transport,
  );
  if (scope != null && scope != currentSessionReadScope()) {
    throw const RpsQrReprintCancelled();
  }
  if (option.transport.isLocal) {
    await PrintService.printRps(
      result.printJob,
      printerProfile: option.offlinePrinter,
      bluetoothPrinter: option.bluetoothPrinter,
      transport: option.transport,
    );
  }
}
