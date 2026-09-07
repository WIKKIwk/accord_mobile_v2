import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:model_viewer_plus/src/html_builder.dart';
import 'package:model_viewer_plus/src/locked_viewport.dart';
// The vendored model viewer owns this existing platform dependency.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter/webview_flutter.dart';

class RecordingWebView extends Fake implements WebViewController {
  final calls = <Object>[];
  @override
  Future<void> enableZoom(bool enabled) async => calls.add(enabled);
  @override
  Future<void> setOverScrollMode(WebViewOverScrollMode mode) async =>
      calls.add(mode);
}

void main() {
  test('locked native viewport disables page zoom and rubber-band scrolling',
      () async {
    final controller = RecordingWebView();
    await configureModelViewerViewport(controller, locked: true);
    expect(controller.calls, [false, WebViewOverScrollMode.never]);
  });

  test('other model viewers retain native defaults', () async {
    final controller = RecordingWebView();
    await configureModelViewerViewport(controller, locked: false);
    expect(controller.calls, isEmpty);
    expect(const ModelViewer(src: 'model.glb').lockPageViewport, isFalse);
  });

  test(
      'initial native HTML locks both shrink and magnify, without changing other viewers',
      () {
    final template = File('third_party/model_viewer_plus/assets/template.html')
        .readAsStringSync();
    final locked = HTMLBuilder.build(
        src: '/model',
        htmlTemplate: template,
        customHtml: '<canvas></canvas>',
        lockPageViewport: true);
    expect(
        locked, contains('minimum-scale=1, maximum-scale=1, user-scalable=no'));
    expect(locked, contains('overflow:hidden'));
    expect(locked, contains('overscroll-behavior:none'));
    expect(locked, contains('<canvas></canvas>'));
    final normal = HTMLBuilder.build(
        src: '/model', htmlTemplate: template, customHtml: '<canvas></canvas>');
    expect(normal, isNot(contains('user-scalable=no')));
    expect(normal, isNot(contains('overscroll-behavior:none')));
  });
}
