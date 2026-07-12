import '../../../../core/session/state/app_session.dart';
import '../../../admin/presentation/widgets/admin_dock.dart';
import '../../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../../customer/presentation/widgets/customer_dock.dart';
import '../../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../../qolip/presentation/widgets/qolip_dock.dart';
import '../../../shared/models/app_models.dart';
import '../../../supplier/presentation/widgets/supplier_dock.dart';
import '../../../werka/presentation/widgets/werka_dock.dart';
import 'package:flutter/material.dart';

/// Keeps the role-specific navigation visible on the conversation list.
/// The full conversation detail intentionally remains distraction-free.
class ChatRoleDock extends StatelessWidget {
  const ChatRoleDock({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final role = profile?.accessRole ?? profile?.role;
    return switch (role) {
      UserRole.admin => const AdminDock(
          activeTab: null,
          showPrimaryFab: false,
        ),
      UserRole.werka => const WerkaDock(
          activeTab: null,
          showPrimaryFab: false,
        ),
      UserRole.supplier => const SupplierDock(
          activeTab: null,
          showPrimaryFab: false,
        ),
      UserRole.customer => const CustomerDock(activeTab: null),
      UserRole.aparatchi => const AparatchiDock(activeTab: null),
      UserRole.qolipchi => const QolipDock(activeTab: null),
      UserRole.materialTaminotchi => const MaterialTaminotchiDock(
          activeTab: null,
        ),
      null => const SizedBox.shrink(),
    };
  }
}
