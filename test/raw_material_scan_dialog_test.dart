import 'dart:async';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/scanner/reliable_mobile_scanner.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalScannerPlatform = MobileScannerPlatform.instance;
  late _SequencedScannerPlatform scannerPlatform;

  setUpAll(() {
    scannerPlatform = _SequencedScannerPlatform();
    MobileScannerPlatform.instance = scannerPlatform;
  });

  tearDownAll(() {
    MobileScannerPlatform.instance = originalScannerPlatform;
  });

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

  testWidgets('quick scanner delegates lifecycle to the reliable coordinator',
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
    expect(scanner.useAppLifecycleState, isFalse);
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

  testWidgets('quick scanner starts after the previous scanner is disposed',
      (tester) async {
    scannerPlatform.events.clear();
    await tester.pumpWidget(
      _testApp(
        ProductionQuickScannerPanel(
          key: const ValueKey('first-scanner'),
          statusText: 'First',
          onCodeDetected: (_) async {},
        ),
      ),
    );
    await tester.pump();
    final reliableScanner = tester
        .widget<ReliableMobileScanner>(find.byType(ReliableMobileScanner));
    await _pumpUntilScannerSettled(tester, reliableScanner.session);
    await tester.pump();
    expect(reliableScanner.session.phase, ReliableScannerPhase.running);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: scannerPlatform.events.join(', '),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      _testApp(
        ProductionQuickScannerPanel(
          key: const ValueKey('second-scanner'),
          statusText: 'Second',
          onCodeDetected: (_) async {},
        ),
      ),
    );
    await tester.pump();
    final replacementScanner = tester
        .widget<ReliableMobileScanner>(find.byType(ReliableMobileScanner));
    await _pumpUntilScannerSettled(tester, replacementScanner.session);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('second-scanner')), findsOneWidget);
    expect(replacementScanner.session.phase, ReliableScannerPhase.running);
    expect(
      scannerPlatform.events,
      containsAllInOrder(<String>['start', 'stop', 'dispose', 'start']),
    );
  });
}

Future<void> _pumpUntilScannerSettled(
  WidgetTester tester,
  ReliableScannerSession session,
) async {
  var settled = false;
  unawaited(session.settled.then((_) => settled = true));
  for (var index = 0; index < 400 && !settled; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(settled, isTrue, reason: 'Scanner coordinator did not settle.');
}

class _SequencedScannerPlatform extends MobileScannerPlatform {
  final List<String> events = <String>[];

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream =>
      Stream<TorchState>.value(TorchState.unavailable);

  @override
  Stream<double> get zoomScaleStateStream => Stream<double>.value(1);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    events.add('start');
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(200, 200),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }

  @override
  Widget buildCameraView() => const SizedBox.square(dimension: 100);
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
