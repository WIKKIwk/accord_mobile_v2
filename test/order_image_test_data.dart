import 'dart:ui' as ui;
import 'dart:typed_data';

Future<Uint8List> orderImageTestPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xff123456));
  for (var x = 0; x < width; x += 20) {
    canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), 10, 5, (height - 20).toDouble()),
        ui.Paint()..color = const ui.Color(0xfffedcba));
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
