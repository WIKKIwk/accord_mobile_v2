import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import 'admin_suppliers_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_party_create_scaffold.dart';
import 'package:flutter/material.dart';

class AdminCustomerCreateScreen extends StatelessWidget {
  const AdminCustomerCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPartyCreateScaffold(
      title: context.l10n.adminText('user.add_customer'),
      nameLabel: context.l10n.adminText('user.name'),
      phoneLabel: context.l10n.adminText('user.phone'),
      submitLabel: context.l10n.adminText('user.add_customer'),
      savingLabel: context.l10n.adminText('user.saving'),
      activeTab: AdminDockTab.settings,
      onCreate: (name, phone) {
        return MobileApi.instance.adminCreateCustomer(
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
