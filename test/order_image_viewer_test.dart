import 'dart:math' as math;
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/image_fade.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/order_image_viewer.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/profile_avatar_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_image_test_data.dart';

Widget _app(Widget child) => MaterialApp(
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

Matrix4 _transform(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('order-image-transform')))
    .transform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List landscape;
  late Uint8List portrait;
  setUpAll(() async {
    landscape = await orderImageTestPng(1200, 600);
    portrait = await orderImageTestPng(600, 1200);
  });

  for (final tall in [false, true]) {
    testWidgets('order image fits whole viewport without a crop, tall=$tall',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(OrderImageViewer(
        image: MemoryImage(tall ? portrait : landscape),
      )));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      final viewport = find.byKey(const ValueKey('order-image-viewport'));
      expect(tester.getSize(viewport), const Size(390, 844));
      final image = tester.widget<ImageFade>(
        find.descendant(of: viewport, matching: find.byType(ImageFade)),
      );
      expect(image.fit, BoxFit.contain);
      expect(find.descendant(of: viewport, matching: find.byType(ClipRRect)),
          findsNothing);
      final clip = find.ancestor(of: viewport, matching: find.byType(ClipRect));
      expect(tester.getSize(clip), const Size(390, 844));
      expect(_transform(tester), Matrix4.identity());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wheel zoom keeps its focal point and pan is not clamped',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(_app(OrderImageViewer(image: MemoryImage(landscape))));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final close = find.byKey(const ValueKey('order-image-close'));
    final closeRect = tester.getRect(close);
    const focalPoint = Offset(30, 420);
    const center = Offset(195, 422);
    GestureBinding.instance.handlePointerEvent(const PointerScrollEvent(
      position: focalPoint,
      scrollDelta: Offset(0, -2000),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pump();
    final zoom = _transform(tester).clone();
    expect(zoom.getMaxScaleOnAxis(), greaterThan(8));
    expect(MatrixUtils.transformPoint(zoom, focalPoint - center),
        (focalPoint - center));

    await tester.dragFrom(const Offset(195, 500), const Offset(900, 900));
    await tester.pump();
    expect(_transform(tester).entry(0, 3) - zoom.entry(0, 3), greaterThan(800));
    expect(_transform(tester).entry(1, 3) - zoom.entry(1, 3), greaterThan(800));
    expect(tester.getRect(close), closeRect);
    await tester.tap(find.byKey(const ValueKey('order-image-reset')));
    await tester.pump();
    expect(_transform(tester), Matrix4.identity());

    GestureBinding.instance.handlePointerEvent(const PointerScrollEvent(
      position: center,
      scrollDelta: Offset(0, 2000),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pump();
    expect(_transform(tester).getMaxScaleOnAxis(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotation buttons turn the image and reset restores the view',
      (tester) async {
    await tester
        .pumpWidget(_app(OrderImageViewer(image: MemoryImage(landscape))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-image-rotate-right')));
    await tester.pump();
    expect(_transform(tester).entry(0, 0), closeTo(0, 0.00001));
    expect(_transform(tester).entry(1, 0), closeTo(1, 0.00001));
    await tester.tap(find.byKey(const ValueKey('order-image-rotate-left')));
    await tester.pump();
    expect(_transform(tester).entry(0, 0), closeTo(1, 0.00001));
    expect(_transform(tester).entry(1, 0), closeTo(0, 0.00001));
    await tester.tap(find.byKey(const ValueKey('order-image-rotate-left')));
    await tester.pump();
    expect(_transform(tester).entry(1, 0), closeTo(-1, 0.00001));
    await tester.tap(find.byKey(const ValueKey('order-image-reset')));
    await tester.pump();
    expect(_transform(tester), Matrix4.identity());
    expect(tester.takeException(), isNull);
  });

  testWidgets('two fingers can zoom and freely rotate the image',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(_app(OrderImageViewer(image: MemoryImage(landscape))));
    await tester.pumpAndSettle();
    const center = Offset(195, 422);
    final first =
        await tester.startGesture(center - const Offset(60, 0), pointer: 1);
    final second =
        await tester.startGesture(center + const Offset(60, 0), pointer: 2);
    await first.moveTo(center - const Offset(90, 0));
    await second.moveTo(center + const Offset(90, 0));
    await tester.pump();
    await first.moveTo(center - const Offset(0, 150));
    await second.moveTo(center + const Offset(0, 150));
    await tester.pump();
    final matrix = _transform(tester);
    expect(matrix.getMaxScaleOnAxis(), greaterThan(1.2));
    expect(math.atan2(matrix.entry(1, 0), matrix.entry(0, 0)).abs(),
        greaterThan(0.5));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile avatar keeps its existing preview mode', (tester) async {
    await tester.pumpWidget(_app(ProfileAvatarPreview(
      key: const ValueKey('profile-thumb'),
      displayName: 'Operator',
      avatarImage: MemoryImage(portrait),
      child: const SizedBox(width: 40, height: 40),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-thumb')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(const ValueKey('order-image-viewport')), findsNothing);
    expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .maxScale,
        3);
    expect(tester.takeException(), isNull);
  });
}
