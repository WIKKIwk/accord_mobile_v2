import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../core/localization/app_localizations.dart';

class FactoryMapObjectSelection {
  const FactoryMapObjectSelection({
    required this.objectId,
    required this.label,
  });

  final String objectId;
  final String label;
}

class AdminFactoryMapViewer extends StatelessWidget {
  const AdminFactoryMapViewer({
    super.key,
    this.selectedObjectId = '',
    this.selectionMode = false,
    this.interactionEnabled = true,
    this.onObjectTap,
  });

  final String selectedObjectId;
  final bool selectionMode;
  final bool interactionEnabled;
  final ValueChanged<FactoryMapObjectSelection>? onObjectTap;

  void _handleMessage(String message, String fallbackLabel) {
    try {
      final payload = jsonDecode(message);
      if (payload is! Map || payload['type'] != 'object_tap') {
        return;
      }
      final objectId = payload['objectId']?.toString().trim() ?? '';
      if (objectId.isEmpty) {
        return;
      }
      final label = payload['label']?.toString().trim() ?? '';
      onObjectTap?.call(
        FactoryMapObjectSelection(
          objectId: objectId,
          label: label.isEmpty ? '$fallbackLabel · $objectId' : label,
        ),
      );
    } on FormatException {
      // Ignore malformed messages from custom renderer scripts.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rendererScript = kIsWeb
        ? 'assets/packages/model_viewer_plus/assets/factory-map-renderer.js'
        : './factory-map-renderer.js';
    final escapedSelectedObjectId = htmlEscape.convert(selectedObjectId.trim());

    return ModelViewer(
      src: 'assets/models/zavod6-phone.glb',
      alt: l10n.adminText('factory_map.title'),
      interactionEnabled: interactionEnabled,
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
            var statuses = document.querySelectorAll('[data-factory-map-status]');
            var status = statuses.length ? statuses[statuses.length - 1] : null;
            if (status) {
              status.textContent = '${htmlEscape.convert(l10n.adminText('factory_map.renderer_failed'))}';
              status.title = event && (event.message || event.reason || event.type) || 'Renderer error';
              status.hidden = false;
              status.style.display = 'grid';
            }
          }
          window.addEventListener('error', showFactoryMapError, true);
          window.addEventListener('unhandledrejection', showFactoryMapError);
        </script>
        <canvas
          id="factory-map-canvas"
          data-factory-map-canvas
          data-model-src="__MODEL_SRC__"
          data-selection-mode="$selectionMode"
          data-selected-object-id="$escapedSelectedObjectId"
        ></canvas>
        <div id="factory-map-status" data-factory-map-status>${htmlEscape.convert(l10n.adminText('factory_map.model_loading'))}</div>
        <div
          id="factory-map-bridge"
          data-factory-map-bridge
          data-model-viewer-channel="FactoryMapChannel"
          data-model-viewer-message=""
          hidden
        ></div>
        <script type="module" src="$rendererScript"></script>
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
      javascriptChannels: {
        JavascriptChannel(
          'FactoryMapChannel',
          onMessageReceived: (message) => _handleMessage(
            message.message,
            l10n.adminText('factory_map.object_fallback'),
          ),
        ),
      },
    );
  }
}

Future<FactoryMapObjectSelection?> showAdminFactoryMapObjectPicker(
  BuildContext context, {
  String initialObjectId = '',
}) {
  return showDialog<FactoryMapObjectSelection>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _FactoryMapObjectPicker(
      initialObjectId: initialObjectId,
    ),
  );
}

class _FactoryMapObjectPicker extends StatefulWidget {
  const _FactoryMapObjectPicker({required this.initialObjectId});

  final String initialObjectId;

  @override
  State<_FactoryMapObjectPicker> createState() =>
      _FactoryMapObjectPickerState();
}

class _FactoryMapObjectPickerState extends State<_FactoryMapObjectPicker> {
  FactoryMapObjectSelection? _selection;

  @override
  void initState() {
    super.initState();
    final initialObjectId = widget.initialObjectId.trim();
    if (initialObjectId.isNotEmpty) {
      _selection = FactoryMapObjectSelection(
        objectId: initialObjectId,
        label: initialObjectId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final viewportWidth = size.width.isFinite ? size.width : 520.0;
    final viewportHeight = size.height.isFinite ? size.height : 640.0;
    final dialogWidth = (viewportWidth - 24).clamp(280.0, 920.0).toDouble();
    final dialogHeight = (viewportHeight * 0.86).clamp(420.0, 760.0).toDouble();
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.factory_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.adminText('factory_map.viewer_title'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          l10n.adminText('factory_map.viewer_instruction'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.adminText('factory_map.close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF202426),
                child: AdminFactoryMapViewer(
                  selectedObjectId: widget.initialObjectId,
                  selectionMode: true,
                  onObjectTap: (selection) {
                    setState(() => _selection = selection);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SizedBox(
                width: dialogWidth - 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: dialogWidth - 24),
                      child: Text(
                        _selection?.label ??
                            l10n.adminText('factory_map.viewer_not_selected'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.adminText('action.cancel')),
                          ),
                          FilledButton.icon(
                            onPressed: _selection == null
                                ? null
                                : () => Navigator.of(context).pop(_selection),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              l10n.adminText('factory_map.viewer_select'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
