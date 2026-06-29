import '../../../app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';

class AdminFactoryMapScreen extends StatelessWidget {
  const AdminFactoryMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;

    return AdminShell(
      title: 'Zavod kartasi',
      selectedRouteName: AppRoutes.adminFactoryMap,
      activeTab: AdminDockTab.home,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: ListView(
          padding: EdgeInsets.fromLTRB(4, 8, 4, bottomPadding),
          children: [
            Container(
              height: MediaQuery.sizeOf(context).height * 0.72,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: const ModelViewer(
                src: 'assets/models/zavod6-phone.glb',
                alt: 'Zavod 3D kartasi',
                cameraControls: true,
                autoRotate: false,
                disableZoom: false,
                interactionPrompt: InteractionPrompt.none,
                loading: Loading.eager,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
