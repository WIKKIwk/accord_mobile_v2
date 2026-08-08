import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart' show JavaScriptMessage;

import 'html_builder.dart';
import 'model_viewer_plus.dart';
import 'shim/dart_ui_web_fake.dart'
    if (dart.library.ui_web) 'dart:ui_web'
    as ui_web;
import 'shim/dart_web_fake.dart'
    if (dart.library.js_interop) 'package:web/web.dart'
    as web;
import 'shim/dart_web_fake.dart' if (dart.library.js_interop) 'dart:js_interop';

class ModelViewerState extends State<ModelViewer> {
  bool _isLoading = true;
  web.HTMLHtmlElement? _htmlElement;
  final String _uniqueViewType = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    unawaited(generateModelViewerHtml());
  }

  /// To generate the HTML code for using the model viewer.
  Future<void> generateModelViewerHtml() async {
    final String htmlTemplate = await rootBundle.loadString(
      'packages/model_viewer_plus/assets/template.html',
    );

    final String html = _buildHTML(htmlTemplate);

    ui_web.platformViewRegistry.registerViewFactory(
      'model-viewer-html-$_uniqueViewType',
      (viewId) {
        final element = web.HTMLHtmlElement()
          ..style.border = 'none'
          ..style.height = '100%'
          ..style.width = '100%'
          ..style.setProperty(
            'pointer-events',
            widget.interactionEnabled ? 'auto' : 'none',
          )
          ..innerHTML = html.toJS;
        _htmlElement = element;
        _wireJavascriptChannels(element);
        // Scripts inserted through innerHTML are inert. Recreate them after
        // the platform view is attached so custom HTML can run its scripts.
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 16),
            () => _activateScripts(element),
          ),
        );
        return element;
      },
    );

    setState(() => _isLoading = false);
  }

  @override
  void didUpdateWidget(covariant ModelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionEnabled != widget.interactionEnabled) {
      _setInteractionEnabled(widget.interactionEnabled);
    }
  }

  void _setInteractionEnabled(bool enabled) {
    final element = _htmlElement;
    if (element == null) {
      return;
    }
    element.style.setProperty('pointer-events', enabled ? 'auto' : 'none');
  }

  void _wireJavascriptChannels(web.HTMLHtmlElement element) {
    final channels = widget.javascriptChannels;
    if (channels == null || channels.isEmpty) {
      return;
    }
    element.addEventListener(
      'model-viewer-plus-message',
      ((web.Event _) {
        final bridge = element.querySelector('#factory-map-bridge');
        final channelName =
            bridge?.getAttribute('data-model-viewer-channel') ?? '';
        final message = bridge?.getAttribute('data-model-viewer-message') ?? '';
        if (channelName.isEmpty) {
          return;
        }
        for (final channel in channels) {
          if (channel.name == channelName) {
            channel.onMessageReceived(JavaScriptMessage(message: message));
            return;
          }
        }
      }).toJS,
    );
  }

  void _activateScripts(web.HTMLHtmlElement element) {
    final scripts = element.querySelectorAll('script');
    for (var index = 0; index < scripts.length; index++) {
      final node = scripts.item(index);
      if (node == null) {
        continue;
      }
      final source = node as web.HTMLScriptElement;
      final replacement = web.HTMLScriptElement();
      final type = source.getAttribute('type');
      final src = source.getAttribute('src');
      if (type != null) {
        replacement.type = type;
      }
      if (src != null && src.isNotEmpty) {
        replacement.src = src;
      } else {
        replacement.text = source.textContent ?? '';
      }
      source.replaceWith(replacement);
    }
  }

  @override
  Widget build(final BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading Model Viewer...',
        ),
      );
    } else {
      return HtmlElementView(viewType: 'model-viewer-html-$_uniqueViewType');
    }
  }

  String _buildHTML(final String htmlTemplate) {
    if (widget.src.startsWith('file://')) {
      // Local file URL can't be used in Flutter web.
      debugPrint("file:// URL scheme can't be used in Flutter web.");
      throw ArgumentError("file:// URL scheme can't be used in Flutter web.");
    }

    return HTMLBuilder.build(
      htmlTemplate: htmlTemplate.replaceFirst(
        '<script type="module" src="model-viewer.min.js" defer></script>',
        '',
      ),
      // Attributes
      src: widget.src,
      alt: widget.alt,
      poster: widget.poster,
      loading: widget.loading,
      reveal: widget.reveal,
      withCredentials: widget.withCredentials,
      // AR Attributes
      ar: widget.ar,
      arModes: widget.arModes,
      // arScale: widget.arScale,
      // arPlacement: widget.arPlacement,
      iosSrc: widget.iosSrc,
      xrEnvironment: widget.xrEnvironment,
      // Staing & Cameras Attributes
      cameraControls: widget.cameraControls,
      disablePan: widget.disablePan,
      disableTap: widget.disableTap,
      touchAction: widget.touchAction,
      disableZoom: widget.disableZoom,
      orbitSensitivity: widget.orbitSensitivity,
      autoRotate: widget.autoRotate,
      autoRotateDelay: widget.autoRotateDelay,
      rotationPerSecond: widget.rotationPerSecond,
      interactionPrompt: widget.interactionPrompt,
      interactionPromptStyle: widget.interactionPromptStyle,
      interactionPromptThreshold: widget.interactionPromptThreshold,
      cameraOrbit: widget.cameraOrbit,
      cameraTarget: widget.cameraTarget,
      fieldOfView: widget.fieldOfView,
      maxCameraOrbit: widget.maxCameraOrbit,
      minCameraOrbit: widget.minCameraOrbit,
      maxFieldOfView: widget.maxFieldOfView,
      minFieldOfView: widget.minFieldOfView,
      interpolationDecay: widget.interpolationDecay,
      // Lighting & Env Attributes
      skyboxImage: widget.skyboxImage,
      environmentImage: widget.environmentImage,
      exposure: widget.exposure,
      shadowIntensity: widget.shadowIntensity,
      shadowSoftness: widget.shadowSoftness,
      // Animation Attributes
      animationName: widget.animationName,
      animationCrossfadeDuration: widget.animationCrossfadeDuration,
      autoPlay: widget.autoPlay,
      // Materials & Scene Attributes
      variantName: widget.variantName,
      orientation: widget.orientation,
      scale: widget.scale,

      // CSS Styles
      backgroundColor: widget.backgroundColor,

      // Annotations CSS
      minHotspotOpacity: widget.minHotspotOpacity,
      maxHotspotOpacity: widget.maxHotspotOpacity,

      // Others
      innerModelViewerHtml: widget.innerModelViewerHtml,
      customHtml: widget.customHtml,
      relatedCss: widget.relatedCss,
      relatedJs: widget.relatedJs,
      id: widget.id,
      debugLogging: widget.debugLogging,
    );
  }
}
