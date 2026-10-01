import 'dart:io';
import 'dart:ui' as ui;
import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 test('render captured native pallet TSPL and verify unchanged geometry', () async {
  final dir=Directory('/Users/wikki/Desktop/Accord_project/accord_mobile_v2/.codex/paddon-bluetooth-label');
  final font=FontLoader('PreviewMono')..addFont(File('/System/Library/Fonts/Menlo.ttc').readAsBytes().then((b)=>ByteData.sublistView(b)));
  await font.load();
  final textPattern=RegExp(r'^TEXT (\d+),(\d+),"([^"]+)",0,1,1,"([^"]*)"');
  final qrPattern=RegExp(r'^QRCODE (\d+),(\d+),H,(\d+),A,0,.*"([^"]+)"');
  List<String> lines(String file)=>File('${dir.path}/$file').readAsLinesSync();
  for(final platform in ['android','ios']) {
   for(final sample in ['known','unknown','empty','partial','legacy']) {
    final before=lines('$platform-before-$sample.tspl');
    final after=lines('$platform-after-$sample.tspl');
    final beforeNonText=before.where((l)=>!l.startsWith('TEXT ')).toList();
    expect(after.where((l)=>!l.startsWith('TEXT ')).toList(), beforeNonText);
    expect(after.where((l)=>l.startsWith('TEXT ')).length,5);
    final qr=after.map(qrPattern.firstMatch).whereType<RegExpMatch>().single;
    expect([qr[1],qr[2],qr[3],qr[4]],['140','156','8','00001']);
    final nativeText=after.map(textPattern.firstMatch).whereType<RegExpMatch>().toList();
    expect(nativeText.take(4).map((m)=>m[2]).toList(),['6','32','58','84']);
    expect(nativeText.last[2],'352');
    for(final m in nativeText.take(4)) {
     final small=m[3]=='1';
     final charWidth=small?8:16; // Conservative XP-P323B glyph estimate.
     final fontHeight=small?12:20;
     expect(int.parse(m[1]!)+m[4]!.length*charWidth,lessThanOrEqualTo(424));
     // Leave four QR modules of white space as well as preserving its origin.
     expect(int.parse(m[2]!)+fontHeight,lessThanOrEqualTo(156-4*8));
    }
   }
  }
  Future<ui.Image> render(String filename) async {
   final recorder=ui.PictureRecorder();
   final canvas=Canvas(recorder)..drawColor(Colors.white,BlendMode.src);
   for(final line in lines(filename)) {
    final text=textPattern.firstMatch(line);
    if(text!=null) {
     final height=text[3]=='1'?12.0:20.0;
     final painter=TextPainter(text:TextSpan(text:text[4],style:TextStyle(fontFamily:'PreviewMono',fontSize:height,height:1,color:Colors.black)),textDirection:TextDirection.ltr)..layout();
     painter.paint(canvas,Offset(double.parse(text[1]!),double.parse(text[2]!)));
     painter.dispose();
    }
    final qr=qrPattern.firstMatch(line);
    if(qr!=null) {
     final rect=Rect.fromLTWH(double.parse(qr[1]!),double.parse(qr[2]!),168,168);
     final bars=Barcode.qrCode(typeNumber:1,errorCorrectLevel:BarcodeQRCorrectionLevel.high).make(qr[4]!,width:168,height:168,drawText:false);
     for(final bar in bars.whereType<BarcodeBar>()) {
      if(bar.black) canvas.drawRect(Rect.fromLTWH(rect.left+bar.left,rect.top+bar.top,bar.width,bar.height),Paint()..color=Colors.black);
     }
    }
   }
   return recorder.endRecording().toImage(448,480);
  }
  for(final scenario in ['before-known','after-known','after-unknown','after-empty']) {
   final image=await render('android-$scenario.tspl');
   final png=await image.toByteData(format:ui.ImageByteFormat.png);
   File('${dir.path}/$scenario.png').writeAsBytesSync(png!.buffer.asUint8List());
   image.dispose();
  }
  final recorder=ui.PictureRecorder();
  final canvas=Canvas(recorder)..drawColor(Colors.white,BlendMode.src);
  for(final entry in [(0,'before-known','Before'),(1,'after-known','Known weights'),(2,'after-unknown','Unknown weights')]) {
   final painter=TextPainter(text:TextSpan(text:entry.$3,style:const TextStyle(fontFamily:'PreviewMono',color:Colors.black,fontSize:18)),textDirection:TextDirection.ltr)..layout();
   painter.paint(canvas,Offset(entry.$1*472+10,10));
   final image=await render('android-${entry.$2}.tspl');
   canvas.drawImage(image,Offset(entry.$1*472+10,44),Paint());
   canvas.drawRect(Rect.fromLTWH(entry.$1*472+10,44,448,480),Paint()..color=Colors.grey..style=PaintingStyle.stroke);
  }
  final comparison=await recorder.endRecording().toImage(1416,536);
  final png=await comparison.toByteData(format:ui.ImageByteFormat.png);
  File('${dir.path}/comparison.png').writeAsBytesSync(png!.buffer.asUint8List());
 });
}
