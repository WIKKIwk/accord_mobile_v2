import 'package:accord_mobile_v2/src/features/chat/presentation/chat_media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final contentUri = Uri.parse('https://example.com/chat-media.jpg');
  const headers = <String, String>{};

  testWidgets('image viewer exposes zoom and rotate controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatImageViewerScreen(
          uri: contentUri,
          headers: headers,
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Rasmni aylantirish'), findsOneWidget);
    expect(find.byTooltip('Orqaga'), findsOneWidget);
    final rotateButton = find.ancestor(
      of: find.byIcon(Icons.rotate_right_rounded),
      matching: find.byType(IconButton),
    );
    expect(rotateButton, findsOneWidget);
    expect(tester.widget<IconButton>(rotateButton).color, Colors.white);

    await tester.tap(find.byTooltip('Rasmni aylantirish'));
    await tester.pump();
  });
}
