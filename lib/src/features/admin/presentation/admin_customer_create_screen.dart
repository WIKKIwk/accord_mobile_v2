import '../../../core/api/mobile_api.dart';
import 'admin_suppliers_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_party_create_scaffold.dart';
import 'package:flutter/material.dart';

class AdminCustomerCreateScreen extends StatelessWidget {
  const AdminCustomerCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPartyCreateScaffold(
      title: 'Customer qo‘shish',
      nameLabel: 'Customer name',
      phoneLabel: 'Customer phone',
      submitLabel: 'Customer qo‘shish',
      savingLabel: 'Qo‘shilmoqda...',
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
