import 'package:accord_mobile_v2/main.dart' as app;
import 'package:device_preview/device_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview keeps the DevicePreview device selector and tools', () {
    final root = app.buildAppRoot(previewEnabled: true);

    expect(root, isA<DevicePreview>());
    final preview = root as DevicePreview;

    expect(preview.enabled, isTrue);
    expect(preview.defaultDevice, Devices.ios.iPhone13);
    expect(preview.tools, DevicePreview.defaultTools);
  });

  test('normal app root keeps the preview wrapper without tooltip override',
      () {
    final root = app.buildAppRoot(previewEnabled: false);

    expect(root, isA<DevicePreview>());
  });
}
