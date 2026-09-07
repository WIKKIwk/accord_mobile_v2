import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:flutter/material.dart';

// The same FAB animation, style and open state used by the other roles.
final ValueNotifier<bool> werkaCreateHubMenuOpen = adminCreateHubMenuOpen;

void showWerkaCreateHubSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  final l10n = context.l10n;
  AdminFabMenuAction action(String title, IconData icon, String route) =>
      AdminFabMenuAction(
          title: title, icon: icon, onTap: () => navigator.pushNamed(route));
  showAdminCreateHubSheet(context, actions: [
    action('Paddon kirimi', Icons.qr_code_scanner_rounded,
        AppRoutes.werkaPaddonReceive),
    action(l10n.unannouncedTitle, Icons.inventory_2_outlined,
        AppRoutes.werkaUnannouncedSupplier),
    action(l10n.customerIssueTitle, Icons.send_outlined,
        AppRoutes.werkaCustomerIssueCustomer),
    action(l10n.batchDispatchTitle, Icons.playlist_add_check_rounded,
        AppRoutes.werkaBatchDispatch),
    action(
        'Stock QR', Icons.qr_code_2_rounded, AppRoutes.werkaStockEntryQrScan),
    action('Tarozi / printer', Icons.scale_outlined, AppRoutes.gscaleMode),
  ]);
}
