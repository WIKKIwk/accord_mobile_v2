import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _closeKey = ValueKey('close-sheet');

Future<GlobalKey> _openSheet(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size viewport = const Size(320, 600),
}) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final anchorKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Center(
        child: SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SizedBox(
                      height: 450,
                      child: ColoredBox(
                        key: anchorKey,
                        color: Theme.of(context).colorScheme.surface,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            key: _closeKey,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              dismissAdminTopNotice();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
  return anchorKey;
}

void _showNotice(GlobalKey anchorKey, {bool success = true}) {
  showAdminTopNotice(
    anchorKey.currentContext!,
    success ? 'Amal bajarildi' : 'Amal bajarilmadi',
    anchorKey: anchorKey,
    tone: success ? AdminTopNoticeTone.success : AdminTopNoticeTone.error,
  );
}

void main() {
  tearDown(dismissAdminTopNotice);

  for (final brightness in Brightness.values) {
    for (final success in [true, false]) {
      testWidgets('sheet notice stays below close button: $brightness/$success',
          (tester) async {
        final anchorKey = await _openSheet(tester, brightness: brightness);
        _showNotice(anchorKey, success: success);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));

        final sheetRect = tester.getRect(find.byKey(anchorKey));
        final enteringRect = tester.getRect(find.byType(MaterialBanner));
        expect(enteringRect.bottom, greaterThan(sheetRect.bottom));
        await tester.pump(const Duration(milliseconds: 110));

        final banner = find.byType(MaterialBanner);
        final noticeRect = tester.getRect(banner);
        expect(noticeRect.left, sheetRect.left);
        expect(noticeRect.right, sheetRect.right);
        expect(noticeRect.bottom, sheetRect.bottom);
        expect(noticeRect.top,
            greaterThan(tester.getRect(find.byKey(_closeKey)).bottom));
        final widget = tester.widget<MaterialBanner>(banner);
        expect(widget.backgroundColor,
            success ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6));
        expect(widget.contentTextStyle?.color,
            success ? const Color(0xFF173A24) : const Color(0xFF5F1412));

        await tester.tap(find.byKey(_closeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(anchorKey), findsNothing);
        expect(banner, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('sheet notice slides down after five seconds', (tester) async {
    final anchorKey = await _openSheet(tester);
    _showNotice(anchorKey);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final banner = find.byType(MaterialBanner);
    final visibleRect = tester.getRect(banner);

    await tester.pump(const Duration(milliseconds: 4779));
    expect(tester.getRect(banner), visibleRect);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 110));
    expect(banner, findsOneWidget);
    expect(tester.getRect(banner).top, greaterThan(visibleRect.top));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacing or dismissing an exiting notice leaves no overlay',
      (tester) async {
    final anchorKey = await _openSheet(tester);
    _showNotice(anchorKey);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 110));

    _showNotice(anchorKey, success: false);
    await tester.pumpAndSettle();
    expect(find.text('Amal bajarildi'), findsNothing);
    expect(find.text('Amal bajarilmadi'), findsOneWidget);
    dismissAdminTopNotice();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(MaterialBanner), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet notice moves above the keyboard and returns to the bottom',
      (tester) async {
    final anchorKey = await _openSheet(tester);
    _showNotice(anchorKey);
    await tester.pumpAndSettle();
    final banner = find.byType(MaterialBanner);
    final sheetRect = tester.getRect(find.byKey(anchorKey));

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(banner).bottom, 560);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(banner).bottom, sheetRect.bottom);
    dismissAdminTopNotice();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom notice keeps text above the home indicator',
      (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final anchorKey = await _openSheet(tester, viewport: const Size(400, 800));
    _showNotice(anchorKey);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(MaterialBanner)).bottom, 800);
    expect(tester.getRect(find.text('Amal bajarildi')).bottom,
        lessThanOrEqualTo(776));
    dismissAdminTopNotice();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unanchored notices still use the scaffold top banner',
      (tester) async {
    final bodyKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SizedBox(key: bodyKey))),
    );
    showAdminTopNotice(
      bodyKey.currentContext!,
      'Saqlandi',
      tone: AdminTopNoticeTone.success,
    );
    await tester.pumpAndSettle();
    final banner = find.byType(MaterialBanner);
    expect(tester.getRect(banner).top, 0);
    expect(find.ancestor(of: banner, matching: find.byType(Scaffold)),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
