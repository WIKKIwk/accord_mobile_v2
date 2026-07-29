import 'package:accord_mobile_v2/src/core/widgets/printing/bluetooth_printer_list.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const discoveryChannel = EventChannel('accord/bluetooth_printer/discovery');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(discoveryChannel, null);
  });

  testWidgets('shows iOS printers before discovery completes', (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MockStreamHandlerEventSink? events;

    try {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        discoveryChannel,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            events = sink;
          },
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BluetoothPrinterList(onSelected: _ignoreSelection),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      events!.success(<String, Object?>{
        'type': 'printer',
        'name': 'XP-P323B',
        'address': 'ios-printer-1',
      });
      await tester.pump();

      expect(find.text('XP-P323B'), findsOneWidget);
      expect(find.text('ios-printer-1'), findsOneWidget);

      events!.success(<String, Object?>{'type': 'complete'});
      await tester.pump();
      expect(find.text('XP-P323B'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('starts a fresh iOS discovery after the picker is reopened',
      (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final eventSinks = <MockStreamHandlerEventSink>[];

    try {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        discoveryChannel,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            eventSinks.add(sink);
          },
        ),
      );

      Future<void> openPicker() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BluetoothPrinterList(
                key: UniqueKey(),
                onSelected: _ignoreSelection,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await openPicker();
      expect(eventSinks, hasLength(1));
      eventSinks.first.success(<String, Object?>{
        'type': 'printer',
        'name': 'XP-P323B',
        'address': 'ios-printer-1',
      });
      await tester.pump();
      expect(find.text('ios-printer-1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await openPicker();

      expect(eventSinks, hasLength(2));
      eventSinks.last.success(<String, Object?>{
        'type': 'printer',
        'name': 'XP-P323B',
        'address': 'ios-printer-1',
      });
      await tester.pump();
      expect(find.text('ios-printer-1'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

void _ignoreSelection(BluetoothPrinterProfile printer) {}
