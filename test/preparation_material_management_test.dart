import 'dart:convert';
import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/spring_bottom_sheet.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionProfile profile(UserRole role) => SessionProfile(
    role: role,
    displayName: 'Master',
    legalName: '',
    ref: 'prep-1',
    phone: '',
    avatarUrl: '',
    capabilities: const ['preparation.access']);

Widget app({Widget home = const PreparationMaterialsScreen()}) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

final ownMaterials = {
  'materials': [
    {
      'item_code': 'PREP-1',
      'name': 'Kley',
      'warehouses': ['Own']
    },
    {
      'item_code': 'PREP-2',
      'name': 'Un',
      'warehouses': ['Own']
    },
  ]
};

Future<void> actions(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('preparation-material-PREP-1')));
  await tester.pumpAndSettle();
  expect(
      find.descendant(
          of: find.byType(AppActionSheet<String>),
          matching: find.byType(M3SegmentFilledSurface)),
      findsNWidgets(3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = profile(UserRole.tayyorlovMasteri);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'Tayyorlov home opens own-material page, excludes shared catalog, searches',
      (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(app(home: const PreparationScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Homashyolar'));
      await tester.pumpAndSettle();
      expect(find.text('Kley'), findsOneWidget);
      expect(find.text('Shared catalog item'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'un');
      await tester.pumpAndSettle();
      expect(find.text('Un'), findsOneWidget);
      expect(find.text('Kley'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              if (request.url.path.endsWith('/snapshot')) {
                return response({
                  'warehouses': ['Own'],
                  'assigned_warehouses': ['Own'],
                  'material_warehouses': ['Own'],
                  'materials': [
                    {
                      'item_code': 'SHARED',
                      'name': 'Shared catalog item',
                      'can_receive': false
                    }
                  ],
                  'orders': [],
                  'history': []
                });
              }
              expect(request.url.path, '/v1/mobile/preparation/materials');
              return response(ownMaterials);
            }));
  });

  for (final duplicate in [false, true]) {
    testWidgets('rename prefilled own material, duplicate=$duplicate',
        (tester) async {
      var saves = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await actions(tester);
        await tester.tap(find.text('Nomini o‘zgartirish'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField))
                .controller!
                .text,
            'Kley');
        await tester.enterText(find.byType(TextFormField), 'New glue');
        await tester.tap(find.text('Saqlash'));
        await tester.pumpAndSettle();
        expect(saves, 1);
        expect(find.text(duplicate ? 'Kley' : 'New glue'), findsOneWidget);
        expect(
            find.text(duplicate
                ? 'Sizda bunday nomli homashyo mavjud. Boshqa nom kiriting'
                : 'Homashyo nomi o‘zgartirildi'),
            findsOneWidget);
        expect(find.textContaining('dhsjkl'), findsNothing);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.method == 'GET') return response(ownMaterials);
                saves++;
                expect(request.method, 'PATCH');
                expect(jsonDecode(request.body),
                    {'item_code': 'PREP-1', 'name': 'New glue'});
                return duplicate
                    ? response({
                        'code': 'preparation_material_name_taken',
                        'error': 'dhsjkl'
                      }, 409)
                    : response({'item_code': 'PREP-1', 'name': 'New glue'});
              }));
    });
  }

  for (final blocked in [false, true]) {
    testWidgets(
        'delete requires confirmation and removes only on success, blocked=$blocked',
        (tester) async {
      var deletes = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await actions(tester);
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        expect(deletes, 0);
        expect(find.text('Homashyoni o‘chirish'), findsOneWidget);
        await tester.tap(find.text('Bekor qilish'));
        await tester.pumpAndSettle();
        expect(deletes, 0);
        await actions(tester);
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        expect(deletes, 1);
        expect(find.byKey(const ValueKey('preparation-material-PREP-1')),
            blocked ? findsOneWidget : findsNothing);
        expect(find.text('Un'), findsOneWidget);
        expect(
            find.text(blocked
                ? 'Homashyo ishlatilgan: qoldiq, kirim, formula yoki boshqa bog‘langan yozuvlar bor. Uni o‘chirib bo‘lmaydi'
                : 'Homashyo o‘chirildi'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.method == 'GET') return response(ownMaterials);
                deletes++;
                expect(request.method, 'DELETE');
                expect(request.url.queryParameters, {'item_code': 'PREP-1'});
                return blocked
                    ? response({'code': 'preparation_material_in_use'}, 409)
                    : response({'item_code': 'PREP-1', 'deleted': true});
              }));
    });
  }

  testWidgets('failed list is readable and retry shows an empty state',
      (tester) async {
    var loads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.textContaining('dhsjkl'), findsNothing);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(find.text('Hali homashyo yaratmagansiz.'), findsOneWidget);
    },
        () => MockClient((_) async => ++loads == 1
            ? http.Response('dhsjkl', 500)
            : response({'materials': []})));
  });

  testWidgets(
      'no refresh or duplicate back button; pull keeps default animation mounted',
      (tester) async {
    var loads = 0;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(
          find.descendant(
              of: find.byType(AdminCatalogSearchField),
              matching: find.byIcon(Icons.arrow_back_rounded)),
          findsOneWidget);
      final refresh = tester.element(find.byType(AppRefreshIndicator));
      await tester.drag(find.byType(ListView).first, const Offset(0, 180));
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads, 2);
      expect(tester.element(find.byType(AppRefreshIndicator)), same(refresh));
      expect(find.text('Kley'), findsOneWidget);
      pending.complete(response({'materials': []}));
      await tester.pumpAndSettle();
      expect(find.text('Hali homashyo yaratmagansiz.'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(loads, 3);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async {
              loads++;
              return loads == 1 ? response(ownMaterials) : pending.future;
            }));
  });

  for (final blocked in [false, true]) {
    testWidgets(
        'three-dot warehouse editing uses exclusive choices, blocked=$blocked',
        (tester) async {
      tester.view.physicalSize = const Size(320, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Homashyo amallari').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Omborga biriktirish'));
        await tester.pumpAndSettle();
        expect(find.text('Other'), findsNothing);
        expect(find.text('Shared'), findsNothing);
        final own = find.widgetWithText(CheckboxListTile, 'Own');
        expect(tester.widget<CheckboxListTile>(own).value, isTrue);
        await tester.tap(own);
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Second'));
        await tester.pump();
        await tester.tap(find.text('Saqlash'));
        await tester.pumpAndSettle();
        expect(saves, 1);
        final card = find.byKey(const ValueKey('preparation-material-PREP-1'));
        expect(
            find.descendant(
                of: card, matching: find.text(blocked ? 'Own' : 'Second')),
            findsOneWidget);
        expect(
            find.text(blocked
                ? 'Bu omborda homashyo qoldig‘i, kutilayotgan kirim yoki faol ko‘chirish bor. Avval ularni yakunlang'
                : 'Ombor biriktirish yangilandi'),
            findsOneWidget);
        expect(find.textContaining('dhsjkl'), findsNothing);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/snapshot')) {
                  return response({
                    'warehouses': ['Own', 'Second', 'Other', 'Shared'],
                    'material_warehouses': ['Own', 'Second'],
                    'materials': [],
                    'orders': [],
                    'history': [],
                  });
                }
                if (request.method == 'GET') return response(ownMaterials);
                saves++;
                expect(request.method, 'PATCH');
                expect(request.url.path,
                    '/v1/mobile/preparation/materials/warehouses');
                expect(jsonDecode(request.body), {
                  'item_code': 'PREP-1',
                  'warehouses': ['Second']
                });
                return blocked
                    ? response({
                        'code': 'preparation_material_warehouse_in_use',
                        'error': 'dhsjkl'
                      }, 409)
                    : response({
                        'item_code': 'PREP-1',
                        'name': 'Kley',
                        'warehouses': ['Second']
                      });
              }));
    });
  }

  testWidgets(
      'warehouse sheet cancellation does not save; can unlink an unused material',
      (tester) async {
    var saves = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final cancel in [true, false]) {
        await actions(tester);
        await tester.tap(find.text('Omborga biriktirish'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Own'));
        await tester.pump();
        if (cancel) {
          Navigator.of(tester.element(find.byType(CheckboxListTile))).pop();
        } else {
          await tester.tap(find.text('Saqlash'));
        }
        await tester.pumpAndSettle();
        expect(saves, cancel ? 0 : 1);
      }
      expect(find.text('Ombor biriktirilmagan'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/snapshot')) {
                return response({
                  'material_warehouses': ['Own'],
                  'materials': [],
                  'orders': [],
                  'history': [],
                });
              }
              if (request.method == 'GET') return response(ownMaterials);
              saves++;
              expect(jsonDecode(request.body),
                  {'item_code': 'PREP-1', 'warehouses': []});
              return response(
                  {'item_code': 'PREP-1', 'name': 'Kley', 'warehouses': []});
            }));
  });

  for (final role in [UserRole.materialTaminotchi, UserRole.homashyoRezkachi]) {
    test('other role cannot list or mutate Tayyorlov materials: $role',
        () async {
      AppSession.instance.profile = profile(role);
      await http.runWithClient(() async {
        await expectLater(MobileApi.instance.preparationOwnedMaterials(),
            throwsA(isA<MobileApiException>()));
        await expectLater(
            MobileApi.instance
                .preparationRenameMaterial(itemCode: 'PREP-1', name: 'No'),
            throwsA(isA<MobileApiException>()));
        await expectLater(
            MobileApi.instance.preparationDeleteMaterial('PREP-1'),
            throwsA(isA<MobileApiException>()));
        await expectLater(
            MobileApi.instance.preparationSetMaterialWarehouses(
                itemCode: 'PREP-1', warehouses: ['Own']),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient(
              (_) async => throw StateError('Unauthorized request was sent')));
    });
  }
}
