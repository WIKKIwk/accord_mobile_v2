import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import 'admin_suppliers_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_party_create_scaffold.dart';
import 'package:flutter/material.dart';

class AdminSupplierCreateScreen extends StatelessWidget {
  const AdminSupplierCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPartyCreateScaffold(
      title: context.l10n.adminText('user.add_supplier'),
      nameLabel: context.l10n.adminText('user.name'),
      phoneLabel: context.l10n.adminText('user.phone'),
      submitLabel: context.l10n.adminText('user.add_supplier'),
      savingLabel: context.l10n.adminText('user.saving'),
      activeTab: AdminDockTab.user,
      onCreate: (name, phone) {
        return MobileApi.instance.adminCreateSupplier(
          name: name,
          phone: phone,
        );
      },
      onCreated: () {
        AdminSuppliersScreen.invalidateCache();
      },
    );
  }
}
