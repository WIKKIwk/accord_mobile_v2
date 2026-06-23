import '../../../core/api/mobile_api.dart';
import 'admin_suppliers_screen.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_party_create_scaffold.dart';
import 'package:flutter/material.dart';

class AdminSupplierCreateScreen extends StatelessWidget {
  const AdminSupplierCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPartyCreateScaffold(
      title: 'Supplier qo‘shish',
      nameLabel: 'Supplier name',
      phoneLabel: 'Supplier phone',
      submitLabel: 'Supplier qo‘shish',
      savingLabel: 'Qo‘shilmoqda...',
      activeTab: AdminDockTab.suppliers,
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
