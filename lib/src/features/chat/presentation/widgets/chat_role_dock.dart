import '../../../../core/session/state/app_session.dart';
import '../../../admin/presentation/widgets/admin_dock.dart';
import '../../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../../customer/presentation/widgets/customer_dock.dart';
import '../../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../../qolip/presentation/widgets/qolip_dock.dart';
import '../../../boyoqchi/presentation/widgets/boyoqchi_dock.dart';
import '../../../shared/models/app_models.dart';
import '../../../supplier/presentation/widgets/supplier_dock.dart';
import '../../../werka/presentation/widgets/werka_dock.dart';
import '../../../../core/widgets/navigation/app_navigation_bar.dart';
import 'package:flutter/material.dart';

/// Keeps the role-specific navigation visible on the conversation list and
/// provides the shared dock container for the conversation composer.
class ChatRoleDock extends StatelessWidget {
  const ChatRoleDock({super.key, this.messageComposer});

  static const double messageComposerHeight = 76;

  final Widget? messageComposer;

  @override
  Widget build(BuildContext context) {
    if (messageComposer != null) {
      return AppNavigationBar(
        height: messageComposerHeight,
        destinations: const [],
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        content: messageComposer,
      );
    }

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
      UserRole.boyoqchi => const BoyoqchiDock(activeTab: null),
      UserRole.materialTaminotchi => const MaterialTaminotchiDock(
          activeTab: null,
        ),
      null => const SizedBox.shrink(),
    };
  }
}
