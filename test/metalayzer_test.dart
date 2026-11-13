import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/app_info_row.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/app_status_chip.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/role_dock.dart';
import 'package:accord_mobile_v2/src/features/metalayzer/presentation/metalayzer_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _material = {
  'barcode': 'RAW-1',
  'item_code': 'FILM',
  'item_name': 'Film 1000/20',
  'warehouse': 'Xomashyo',
  'qty': 100,
  'uom': 'kg',
  'is_metalayzer': false,
};
http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Widget _screen({Brightness brightness = Brightness.light, double scale = 1}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const MetalayzerScreen(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'metalayzer',
      'ref': 'metal-1',
      'capabilities': ['metalayzer.access'],
      'assigned_warehouses': ['Xomashyo'],
    });
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('role can only open its workspace even with unrelated capabilities', () {
    expect(AppRouter.canOpenRoute(AppRoutes.metalayzer), isTrue);
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
      capabilities: ['metalayzer.access', 'admin.access', 'raw_material.split'],
    );
    expect(AppRouter.canOpenRoute(AppRoutes.adminHome), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.rawMaterialSplit), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.profile), isTrue);
  });

  test('API reads and marks only barcode, then reads persisted true', () async {
    var marked = false;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      if (request.method == 'POST') {
        expect(request.url.path, '/v1/mobile/metalayzer/complete');
        expect(jsonDecode(request.body), {'barcode': 'RAW-1'});
        marked = true;
      } else {
        expect(request.url.path, '/v1/mobile/metalayzer/material');
        expect(request.url.queryParameters, {'barcode': 'RAW-1'});
      }
      return _json({..._material, 'is_metalayzer': marked});
    });
    await http.runWithClient(() async {
      final api = MobileApi.instance;
      expect((await api.metalayzerMaterial('RAW-1')).isMetalayzer, isFalse);
      expect((await api.metalayzerComplete('RAW-1')).isMetalayzer, isTrue);
      expect((await api.metalayzerMaterial('RAW-1')).isMetalayzer, isTrue);
    }, () => client);
    expect(
        AdminRawMaterialLookup.fromJson({..._material, 'is_metalayzer': true})
            .isMetalayzer,
        isTrue);
    final asset =
        InventoryAsset.fromJson({..._material, 'is_metalayzer': true});
    expect(asset.copyWith(status: 'in_use').isMetalayzer, isTrue);
  });

  test('rejects stale-account replies, wrong barcode and false completion',
      () async {
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.metalayzerComplete('RAW-1'),
          throwsFormatException);
    }, () => MockClient((_) async => _json(_material)));
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.metalayzerMaterial('OTHER'),
          throwsFormatException);
    }, () => MockClient((_) async => _json(_material)));
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.metalayzerMaterial('RAW-1'), throwsStateError);
    },
        () => MockClient((_) async {
              AppSession.instance.profile =
                  AppSession.instance.profile!.copyWith(ref: 'metal-2');
              return _json(_material);
            }));
  });

  test(
      'API rejects another role, missing capability and demo sessions before HTTP',
      () async {
    var requests = 0;
    await http.runWithClient(() async {
      final session = AppSession.instance;
      final allowed = session.profile!;
      for (final profile in [
        allowed.copyWith(role: UserRole.admin),
        allowed.copyWith(capabilities: []),
      ]) {
        session.profile = profile;
        await expectLater(
            MobileApi.instance.metalayzerComplete('RAW-1'), throwsStateError);
      }
      session.profile = allowed;
      session.token = 'test-mode-token';
      await expectLater(
          MobileApi.instance.metalayzerComplete('RAW-1'), throwsStateError);
    },
        () => MockClient((_) async {
              requests++;
              return _json({..._material, 'is_metalayzer': true});
            }));
    expect(requests, 0);
  });

  testWidgets('failed mark keeps false and allows an explicit retry',
      (tester) async {
    var writes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MetalayzerScreen(),
      ));
      await tester.enterText(find.byType(TextField), 'RAW-1');
      await tester.tap(find.byTooltip('Tekshirish'));
      await tester.pumpAndSettle();
      final mark = find.widgetWithText(FilledButton, 'Metalayzer bo‘ldi');
      await tester.scrollUntilVisible(mark, 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Belgilash hozir ishlamadi'), findsOneWidget);
      expect(find.text('Metalayzer bo‘lmagan'), findsOneWidget);
      expect(tester.widget<FilledButton>(mark).onPressed, isNotNull);
      await tester.scrollUntilVisible(mark, 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(writes, 2);
      expect(find.text('Belgilash hozir ishlamadi'), findsNothing);
      expect(find.text('Metalayzer bo‘lmagan'), findsNothing);
      expect(tester.widget<FilledButton>(mark).onPressed, isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes++;
                return writes == 1
                    ? _json({'error': 'Belgilash hozir ishlamadi'}, 503)
                    : _json({..._material, 'is_metalayzer': true});
              }
              return _json(_material);
            }));
  });

  testWidgets('scan lookup then one confirmed mark with no quantity entry',
      (tester) async {
    final completion = Completer<http.Response>();
    var writes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MetalayzerScreen(),
      ));
      await tester.enterText(find.byType(TextField), 'RAW-1');
      await tester.tap(find.byTooltip('Tekshirish'));
      await tester.pumpAndSettle();
      expect(find.text('Metalayzer bo‘lmagan'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Metalayzer bo‘ldi'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Metalayzer bo‘ldi'));
      expect(writes, 1);
      completion.complete(_json({..._material, 'is_metalayzer': true}));
      await tester.pumpAndSettle();
      expect(find.text('Metalayzer bo‘lmagan'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Metalayzer bo‘ldi'))
              .onPressed,
          isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes++;
                return completion.future;
              }
              return _json(_material);
            }));
  });

  testWidgets('empty input validates locally and search dismisses keyboard',
      (tester) async {
    var reads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen());
      await tester.tap(find.byTooltip('Tekshirish'));
      await tester.pumpAndSettle();
      expect(find.text('Xomashyo QR kodini kiriting'), findsOneWidget);
      expect(reads, 0);
      await tester.enterText(find.byType(TextField), 'RAW-1');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(AppInfoRow), findsNWidgets(3));
      expect(find.text('100 kg'), findsOneWidget);
    },
        () => MockClient((_) async {
              reads++;
              return _json(_material);
            }));
  });

  testWidgets('network errors show readable feedback and allow another lookup',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen());
      await tester.enterText(find.byType(TextField), 'RAW-1');
      await tester.tap(find.byTooltip('Tekshirish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Serverga ulanib bo‘lmadi'), findsOneWidget);
      expect(find.textContaining('Failed host lookup'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    },
        () => MockClient((_) async =>
            throw http.ClientException('Failed host lookup: private-host')));
  });

  testWidgets('account changes clear old material and discard late replies',
      (tester) async {
    final pending = Completer<http.Response>();
    var reads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen());
      await tester.enterText(find.byType(TextField), 'RAW-1');
      await tester.tap(find.byTooltip('Tekshirish'));
      await tester.pump();
      AppSession.instance.profile =
          AppSession.instance.profile!.copyWith(ref: 'metal-2');
      AppSession.instance.revision.value++;
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      await tester.enterText(find.byType(TextField), 'RAW-2');
      await tester.tap(find.byTooltip('Tekshirish'));
      await tester.pumpAndSettle();
      expect(find.text('New roll'), findsOneWidget);
      pending.complete(_json(_material));
      await tester.pumpAndSettle();
      expect(find.text('New roll'), findsOneWidget);
      expect(find.text('Film 1000/20'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async {
              reads++;
              return reads == 1
                  ? pending.future
                  : _json({
                      ..._material,
                      'barcode': 'RAW-2',
                      'item_name': 'New roll'
                    });
            }));
  });

  testWidgets('shared components fit phone and tablet with large text',
      (tester) async {
    final output = Platform.environment['METALAYZER_SCREENSHOT_DIR'];
    if (output != null) {
      final font = FontLoader('Google Sans')
        ..addFont(
            rootBundle.load('assets/fonts/google_sans/GoogleSans-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const scenarios = [
      ('phone', Size(390, 844), Brightness.light, 1.0),
      ('compact', Size(320, 640), Brightness.light, 1.5),
      ('tablet', Size(834, 1112), Brightness.dark, 1.6),
    ];
    final boundaryKey = GlobalKey();
    await http.runWithClient(() async {
      for (final (name, size, brightness, scale) in scenarios) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(RepaintBoundary(
            key: boundaryKey,
            child: _screen(brightness: brightness, scale: scale)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'RAW-1');
        await tester.tap(find.byTooltip('Tekshirish'));
        await tester.pumpAndSettle();
        final action = find.widgetWithText(FilledButton, 'Metalayzer bo‘ldi');
        await tester.scrollUntilVisible(action, 100,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.byType(AppStatusChip), findsOneWidget);
        expect(tester.getBottomLeft(action).dy,
            lessThanOrEqualTo(tester.getTopLeft(find.byType(RoleDock)).dy));
        expect(tester.takeException(), isNull);
        if (output != null) {
          await tester.runAsync(() async {
            final boundary = boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(output).create(recursive: true);
            await File('$output/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    },
        () => MockClient((_) async => _json({
              ..._material,
              'item_name': 'BOPP shaffof rulon — uzun mahsulot nomi 1000/20',
              'barcode': 'RAW-1'
            })));
  });
}
