import 'dart:async';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  testWidgets('raw material scanner shows a target grid guide', (tester) async {
    await tester.pumpWidget(
      _testApp(
        const RawMaterialScannerGuide(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('raw-material-scanner-grid')), findsOne);
    expect(find.text('QR kodni shu to‘r ichiga olib keling'), findsOneWidget);
  });

  testWidgets('quick scanner leaves automatic zoom disabled', (tester) async {
    await tester.pumpWidget(
      _testApp(
        ProductionQuickScannerPanel(
          statusText: 'Scan',
          onCodeDetected: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    expect(scanner.controller!.autoZoom, isFalse);
  });

  testWidgets('quick scanner keeps continuous autofocus active',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        ProductionQuickScannerPanel(
          statusText: 'Scan',
          onCodeDetected: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    expect(scanner.tapToFocus, isFalse);
  });

  testWidgets('quick scanner vibrates before scan validation completes',
      (tester) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final validation = Completer<void>();
    var scanReceived = false;
    await tester.pumpWidget(
      _testApp(
        ProductionQuickScannerPanel(
          statusText: 'Scan',
          onCodeDetected: (_) {
            scanReceived = true;
            return validation.future;
          },
        ),
      ),
    );
    await tester.pump();
    platformCalls.clear();

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    scanner.onDetect!(
      const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'QR-1')],
      ),
    );
    await tester.pump();

    expect(scanReceived, isTrue);
    expect(validation.isCompleted, isFalse);
    expect(
      platformCalls,
      contains(
        isA<MethodCall>()
            .having(
              (call) => call.method,
              'method',
              'HapticFeedback.vibrate',
            )
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.mediumImpact',
            ),
      ),
    );

    validation.complete();
    await tester.pump();
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
