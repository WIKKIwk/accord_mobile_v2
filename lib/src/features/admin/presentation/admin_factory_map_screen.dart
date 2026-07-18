import '../../../app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';

class AdminFactoryMapScreen extends StatefulWidget {
  const AdminFactoryMapScreen({super.key});

  @override
  State<AdminFactoryMapScreen> createState() => _AdminFactoryMapScreenState();
}

class _AdminFactoryMapScreenState extends State<AdminFactoryMapScreen> {
  Animation<double>? _routeAnimation;
  bool _modelLoadScheduled = false;
  bool _showModel = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    }
    if (animation == null || animation.status == AnimationStatus.completed) {
      _scheduleModelLoad();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    super.dispose();
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleModelLoad();
    }
  }

  void _scheduleModelLoad() {
    if (_modelLoadScheduled) {
      return;
    }
    _modelLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final animation = _routeAnimation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        _modelLoadScheduled = false;
        return;
      }
      setState(() {
        _showModel = true;
      });
    });
  }

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
              child: _showModel
                  ? const ModelViewer(
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
                    )
                  : const _FactoryMapPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactoryMapPlaceholder extends StatelessWidget {
  const _FactoryMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF202426),
      child: Semantics(
        label: 'Zavod 3D kartasi tayyorlanmoqda',
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.factory_outlined, color: Colors.white70, size: 34),
              SizedBox(height: 12),
              Text(
                'Zavod kartasi tayyorlanmoqda…',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
