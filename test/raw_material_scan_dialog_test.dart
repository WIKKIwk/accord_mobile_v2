import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('raw material scanner shows a target grid guide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RawMaterialScannerGuide(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('raw-material-scanner-grid')), findsOne);
    expect(find.text('QR kodni shu to‘r ichiga olib keling'), findsOneWidget);
  });
}
