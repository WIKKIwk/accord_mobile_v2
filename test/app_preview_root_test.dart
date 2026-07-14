import 'package:accord_mobile_v2/main.dart' as app;
import 'package:accord_mobile_v2/src/app/app.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview uses a fixed device frame without DevicePreview layout', () {
    final root = app.buildAppRoot(previewEnabled: true);

    expect(root, isA<MaterialApp>());
    final materialApp = root as MaterialApp;
    final background = materialApp.home! as ColoredBox;
    final safeArea = background.child! as SafeArea;
    final padding = safeArea.child as Padding;
    final fittedBox = padding.child! as FittedBox;
    final frame = fittedBox.child! as DeviceFrame;

    expect(frame.device, Devices.ios.iPhone13);
    expect(frame.screen, isA<ErpnextStockMobileApp>());
  });

  test('normal app root keeps the preview wrapper without tooltip override',
      () {
    final root = app.buildAppRoot(previewEnabled: false);

    expect(root, isA<DevicePreview>());
  });
}
