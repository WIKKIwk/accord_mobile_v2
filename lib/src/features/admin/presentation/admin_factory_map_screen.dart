import '../../../app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'admin_factory_map_mapbox.dart';
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
              child: const _FactoryMapSwitcher(
                fallback: ModelViewer(
                  src: 'assets/models/zavod6-phone.glb',
                  alt: 'Zavod 3D kartasi',
                  customHtml: '''
                  <style>
                    html, body { background: #202426; }
                    #factory-map-canvas {
                      width: 100%;
                      height: 100%;
                      display: block;
                      touch-action: none;
                    }
                    #factory-map-status {
                      position: fixed;
                      inset: 0;
                      display: grid;
                      place-items: center;
                      color: #f4f4f4;
                      font: 14px sans-serif;
                    }
                  </style>
                  <script>
                    function showFactoryMapError(event) {
                      var status = document.getElementById('factory-map-status');
                      if (status) {
                        status.textContent = 'Zavod modeli yuklanmadi';
                        status.title = event && (event.message || event.reason || event.type) || 'Unknown renderer error';
                        status.hidden = false;
                        status.style.display = 'grid';
                      }
                    }
                    window.addEventListener('error', showFactoryMapError, true);
                    window.addEventListener('unhandledrejection', showFactoryMapError);
                  </script>
                  <canvas id="factory-map-canvas" data-model-src="__MODEL_SRC__"></canvas>
                  <div id="factory-map-status">Zavod modeli yuklanmoqda...</div>
                  <script type="module" src="./factory-map-renderer.js"></script>
                ''',
                  cameraControls: true,
                  cameraTarget: '0m 0m 0m',
                  cameraOrbit: '45deg 65deg 150m',
                  minCameraOrbit: 'auto auto 5m',
                  maxCameraOrbit: 'auto auto 250m',
                  fieldOfView: '35deg',
                  autoRotate: false,
                  disableZoom: false,
                  interactionPrompt: InteractionPrompt.none,
                  loading: Loading.eager,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactoryMapSwitcher extends StatelessWidget {
  const _FactoryMapSwitcher({required this.fallback});

  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    const enabled = bool.fromEnvironment('MAPBOX_FACTORY_MAP');
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    if (enabled && token.trim().isNotEmpty) {
      return const MapboxFactoryMapViewport();
    }
    return fallback;
  }
}
