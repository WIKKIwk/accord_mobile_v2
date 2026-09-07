import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_factory_map_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
// The public JavascriptChannel callback is typed by model_viewer_plus's
// existing WebView dependency; this test creates that callback payload only.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter/webview_flutter.dart' show JavaScriptMessage;

void main() {
  testWidgets('focus handshake and restore state do not replace the 3D model',
      (tester) async {
    late ModelViewer viewer;
    String? tapped;
    String? focused;
    String selected = 'node:7';
    bool suspended = false;
    Future<void> build() => tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(builder: (context) {
            // Inspect the public configuration without starting a platform WebView.
            viewer = AdminFactoryMapViewer(
              focusedObjectId: selected,
              interactionEnabled: selected.isEmpty,
              renderSuspended: suspended,
              resetRevision: 2,
              stockState: const {
                'fresh': true,
                'piles': [
                  {
                    'stateId': 'state-1',
                    'count': 2,
                    'rollIds': ['roll-1', 'roll-2']
                  }
                ]
              },
              liveState: const {
                'fresh': true,
                'machines': [
                  {'objectId': 'node:7', 'state': 'paused'}
                ]
              },
              onObjectTap: (selection) => tapped = selection.objectId,
              onFocusComplete: (id) => focused = id,
            ).build(context) as ModelViewer;
            return const SizedBox();
          }),
        ));
    await build();
    await tester.pumpAndSettle();
    final state = jsonDecode(viewer.customRendererState!) as Map;
    expect(viewer.lockPageViewport, isTrue);
    expect(viewer.disableZoom, isFalse,
        reason: 'only page zoom is locked, not the model camera');
    expect(state['focusedObjectId'], 'node:7');
    expect(state['enabled'], isFalse);
    expect(state['renderSuspended'], isFalse,
        reason: 'camera focus must finish before suspending for the sheet');
    expect(state['resetRevision'], 2);
    expect(state['live']['machines'][0]['state'], 'paused');
    expect(state['stock']['piles'][0]['count'], 2);
    expect(state['stock']['fresh'], isTrue);
    final channel = viewer.javascriptChannels!.single;
    channel.onMessageReceived(const JavaScriptMessage(
        message: '{"type":"object_tap","objectId":"node:7"}'));
    expect(tapped, 'node:7');
    expect(focused, isNull);
    channel.onMessageReceived(const JavaScriptMessage(
        message: '{"type":"focus_complete","objectId":"node:7"}'));
    expect(focused, 'node:7');
    channel.onMessageReceived(const JavaScriptMessage(message: 'invalid'));
    channel.onMessageReceived(const JavaScriptMessage(
        message: '{"type":"unrelated","objectId":"node:99"}'));
    expect(tapped, 'node:7');
    expect(focused, 'node:7');
    final modelSource = viewer.src;
    suspended = true;
    await build();
    expect(jsonDecode(viewer.customRendererState!)['renderSuspended'], isTrue);
    expect(viewer.src, modelSource);
    suspended = false;
    selected = '';
    await build();
    expect(jsonDecode(viewer.customRendererState!)['focusedObjectId'], '');
    expect(jsonDecode(viewer.customRendererState!)['enabled'], isTrue);
    expect(jsonDecode(viewer.customRendererState!)['renderSuspended'], isFalse);
    expect(viewer.src, modelSource);
    expect(viewer.customHtml, contains('mountFactoryMap()'));
  });
}
