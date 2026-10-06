import 'dart:convert';
import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddons_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminPaddon _paddon({int itemCount = 2, double? totalGrossKg = 24.375, double? totalNetKg = 23.125}) {
  return AdminPaddon(
    id: 'paddon-1',
    code: '00001',
    location: 'Rezka yonidagi 2-qator',
    note: 'Bugungi ishlab chiqarish',
    createdByRef: 'worker-1',
    createdByDisplayName: 'Rezka operatori',
    createdAtUnix: 1,
    updatedAtUnix: 2,
    itemCount: itemCount,
    totalGrossKg: totalGrossKg,
    totalNetKg: totalNetKg,
  );
}

AdminPaddonSnapshot _snapshot() {
  return AdminPaddonSnapshot(
    paddon: _paddon(),
    items: [
      AdminProgressBatch.fromJson({
        'batch_id': 'wip-001',
        'order_id': 'order-001',
        'qr_payload': '40011234567890ABCDEF',
        'label_item_name': '1 metr rulon',
        'produced_qty': 1,
        'uom': 'm',
        'apparatus': 'apparatus:default:asset-010',
      }),
    ],
    availableItems: [
      AdminProgressBatch.fromJson({
        'batch_id': 'free-wip-001',
        'order_id': 'order-002',
        'qr_payload': '40019876543210FEDCBA',
        'label_item_name': 'Bo‘sh rulon',
        'produced_qty': 2,
        'uom': 'm',
        'apparatus': 'apparatus:default:asset-010',
      }),
    ],
  );
}

AdminPaddonSnapshot _snapshotWithAssignedWips(int count) {
  final snapshot = _snapshot();
  return AdminPaddonSnapshot(
    paddon: _paddon(itemCount: count),
    items: [
      ...snapshot.items,
      for (var index = 2; index <= count; index++)
        AdminProgressBatch.fromJson({
          'batch_id': 'wip-$index',
          'order_id': 'order-$index',
          'qr_payload': '40011234567890ABC$index',
          'label_item_name': '1 metr rulon',
          'produced_qty': 1,
          'uom': 'm',
          'apparatus': 'apparatus:default:asset-010',
        }),
    ],
    availableItems: snapshot.availableItems,
  );
}

void _setSession({bool canManage = false}) {
  AppSession.instance.token = 'token';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.aparatchi,
    displayName: 'Rezka operatori',
    legalName: '',
    ref: 'worker-1',
    phone: '',
    avatarUrl: '',
    capabilities: [
      'apparatus.queue.read',
      if (canManage) 'apparatus.queue.manage',
    ],
    assignedApparatus: ['apparatus:default:asset-010'],
  );
}

Widget _app(Widget home, {RouteFactory? onGenerateRoute}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
    onGenerateRoute: onGenerateRoute,
  );
}

Future<void> _openPaddonFab(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('app-primary-navigation-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPaddonFabEditAction(WidgetTester tester) async {
  await _openPaddonFab(tester);
  await tester.tap(find.textContaining(RegExp(r'^(Qo‘shish|Olib tashlash)')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('paddon header has 4px inset and add actions live only in FAB',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _setSession();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AparatchiPaddonDetailScreen(
      code: '00001',
      loader: () async => _snapshot(),
      apparatusLoader: () async => const [],
    )));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    final padding = list.padding! as EdgeInsets;
    expect(padding.top, 4);
    expect(padding.left, 4);
    expect(padding.right, 4);
    expect(find.text('Qo‘shish'), findsNothing);
    expect(find.text('WIP QR scan qilib qo‘shish'), findsNothing);
    expect(find.byKey(const ValueKey('paddon-print-qr')), findsOneWidget);

    await _openPaddonFab(tester);
    expect(find.text('Qo‘shish'), findsOneWidget);
    expect(find.text('WIP QR scan qilib qo‘shish'), findsOneWidget);
    expect(find.text('QR scan qilish'), findsNothing);
    expect(find.text('Kunlik ish'), findsNothing);
    expect(find.text('Paddonlar'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('admin-hub-toggle-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('paddon FAB scan adds the returned WIP to the current paddon',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _setSession();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var writes = 0;
    http.Request? submittedRequest;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(AparatchiPaddonDetailScreen(
        code: '00001',
        loader: () async => _snapshot(),
        apparatusLoader: () async => const [],
      )));
      await tester.pumpAndSettle();
      await _openPaddonFab(tester);
      await tester.tap(find.text('WIP QR scan qilib qo‘shish'));
      await tester.pumpAndSettle();
      final scanner = tester.widget<AdminProgressQrScanScreen>(
        find.byType(AdminProgressQrScanScreen),
      );
      expect(scanner.scanOnly, isTrue);
      tester.state<NavigatorState>(find.byType(Navigator).first)
          .pop('40019876543210FEDCBA');
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(submittedRequest!.method, 'POST');
      expect(submittedRequest!.url.path,
          '/v1/mobile/admin/production-maps/paddons/items/add');
      final body = jsonDecode(submittedRequest!.body) as Map<String, dynamic>;
      expect(body['code'], '00001');
      expect(body['qr_payload'], '40019876543210FEDCBA');
      expect(find.byType(AparatchiPaddonDetailScreen), findsOneWidget);
      expect(find.text('Jami brutto: 44.375 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      writes++;
      submittedRequest = request;
      return http.Response(jsonEncode({
        'paddon': {'code': '00001', 'total_gross_kg': 44.375},
        'items': [{'batch_id': 'free-wip-001',
          'apparatus': 'apparatus:default:asset-010',
          'qr_payload': '40019876543210FEDCBA'}],
      }), 200);
    }));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('list avoids catalog and scan reuses detail across same-account reauth', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _setSession();
    var detailReads = 0;
    var catalogReads = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          _app(
            AparatchiPaddonsScreen(loader: () async => [_paddon()]),
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.adminProgressQrScan) {
                return MaterialPageRoute<String>(
                  settings: settings,
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).pop('00001'),
                      child: const Text('Return scanned code'),
                    ),
                  ),
                );
              }
              return AppRouter.onGenerateRoute(settings);
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(catalogReads, 0);
        expect(detailReads, 0);
        await tester.tap(find.byKey(const ValueKey('paddon-scan')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Return scanned code'));
        await tester.pumpAndSettle();
        expect(find.byType(AparatchiPaddonDetailScreen), findsOneWidget);
        expect(detailReads, 1);
        expect(catalogReads, 1); // Detail still needs location names.
        expect(find.text('Fresh scanned snapshot'), findsOneWidget);
        final refresh = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        await refresh.onRefresh();
        await tester.pumpAndSettle();
        expect(
          detailReads,
          2,
        ); // Explicit refresh must read backend truth again.
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/paddons/detail')) {
          detailReads++;
          if (detailReads == 1) {
            await AppSession.instance.setSession(
              token: 'refreshed-token',
              profile: AppSession.instance.profile!,
            );
          }
          return http.Response(
            jsonEncode({
              'paddon': {
                'id': 'paddon-1',
                'code': '00001',
                'note': 'Fresh scanned snapshot',
              },
              'items': [],
              'available_items': [],
            }),
            200,
          );
        }
        expect(request.url.path, '/v1/mobile/admin/apparatus');
        catalogReads++;
        return http.Response('{"items":[]}', 200);
      }),
    );
  });

  test(
    'scan seed is one-shot and rejects different pallet/account/permissions',
    () {
      _setSession();
      final initial = _snapshot();
      final seed = AparatchiPaddonDetailSeed(initial);
      expect(seed.takeForCode('00001'), same(initial));
      expect(seed.takeForCode('00001'), isNull);
      expect(AparatchiPaddonDetailSeed(initial).takeForCode('00002'), isNull);
      final accountSeed = AparatchiPaddonDetailSeed(initial);
      AppSession.instance.profile = null;
      expect(accountSeed.takeForCode('00001'), isNull);
      _setSession();
      final revisionSeed = AparatchiPaddonDetailSeed(initial);
      AppSession.instance.revision.value++;
      expect(revisionSeed.takeForCode('00001'), same(initial));
      final capabilitySeed = AparatchiPaddonDetailSeed(initial);
      AppSession.instance.profile = AppSession.instance.profile!.copyWith(
        capabilities: const [],
      );
      expect(capabilitySeed.takeForCode('00001'), isNull);
      _setSession();
      final assignmentSeed = AparatchiPaddonDetailSeed(initial);
      AppSession.instance.profile = AppSession.instance.profile!.copyWith(
        assignedApparatus: const ['apparatus:another'],
      );
      expect(assignmentSeed.takeForCode('00001'), isNull);
    },
  );

  testWidgets('invalid scan seed falls back to a fresh detail read', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _setSession();
    final seed = AparatchiPaddonDetailSeed(_snapshot());
    _setSession(canManage: true);
    AppSession.instance.revision.value++;
    var reads = 0;
    await tester.pumpWidget(
      _app(
        AparatchiPaddonDetailScreen(
          code: '00001',
          initialSnapshot: seed,
          apparatusLoader: () async => const [],
          loader: () async {
            reads++;
            return _snapshot();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty paddon deletion requires long press and confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _setSession(canManage: true);
    var deleted = false;
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(AparatchiPaddonsScreen(
        loader: () async => deleted ? [] : [_paddon(itemCount: 0)],
      )));
      await tester.pumpAndSettle();

      Future<void> openDeleteDialog() async {
        await tester.longPress(find.byKey(const ValueKey('paddon-card-00001')));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        expect(find.text('Paddonni o‘chirish'), findsOneWidget);
        expect(requests, 0);
      }

      await openDeleteDialog();
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.byKey(const ValueKey('paddon-card-00001')), findsOneWidget);

      await openDeleteDialog();
      await tester.tap(find.byKey(const ValueKey('paddon-delete-confirm')));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.byKey(const ValueKey('paddon-card-00001')), findsNothing);
      expect(find.text('Paddon o‘chirildi'), findsOneWidget);
    }, () => MockClient((request) async {
      requests++;
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/mobile/admin/production-maps/paddons/delete');
      expect(request.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(request.body), {'code': '00001'});
      deleted = true;
      return http.Response('{"ok":true}', 200);
    }));
  });

  for (final count in [0, 2]) {
    testWidgets('paddon with $count rolls remains when server rejects history', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      _setSession(canManage: true);
      var requests = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(AparatchiPaddonsScreen(
          loader: () async => [_paddon(itemCount: count)],
        )));
        await tester.pumpAndSettle();
        await tester.longPress(find.byKey(const ValueKey('paddon-card-00001')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('paddon-delete-confirm')));
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(find.byKey(const ValueKey('paddon-card-00001')), findsOneWidget);
        expect(find.text('Paddon bo‘sh emas yoki unda harakat bo‘lgan. Uni o‘chirib bo‘lmaydi.'), findsOneWidget);
      }, () => MockClient((_) async {
        requests++;
        return http.Response('{"error":"paddon_delete_locked"}', 409);
      }));
    });
  }

  test('paddon snapshot hides WIPs already in the paddon', () {
    final snapshot = AdminPaddonSnapshot.fromJson({
      'paddon': {'code': '00001'},
      'items': [
        {
          'batch_id': 'assigned-wip',
          'apparatus': 'apparatus:default:asset-007',
        },
      ],
      'available_items': [
        {
          'batch_id': 'assigned-wip',
          'apparatus': 'apparatus:default:asset-007',
        },
        {
          'batch_id': 'free-wip',
          'apparatus': 'apparatus:default:asset-007',
        },
      ],
    });

    expect(
      snapshot.availableItems.map((item) => item.batchId),
      ['free-wip'],
    );
  });

  testWidgets('paddon list renders physical location and WIP count', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _setSession();

    await tester.pumpWidget(
      _app(
        AparatchiPaddonsScreen(
          loader: () async => [_paddon()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('00001'), findsOneWidget);
    expect(find.text('2 ta WIP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('paddon-card-00001')),
      findsOneWidget,
    );
  });

  testWidgets('paddon detail switches between add and remove modes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _setSession();

    await tester.pumpWidget(
      _app(
        AparatchiPaddonDetailScreen(apparatusLoader: () async => const [],
          code: '00001',
          loader: () async => _snapshot(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order: order-001'), findsOneWidget);
    expect(
      find.text('EPC: 40011234567890ABCDEF • 1 m'),
      findsOneWidget,
    );
    expect(find.text('1 metr rulon'), findsNothing);
    expect(find.text('Paddon ichidagi WIP lar'), findsOneWidget);
    expect(find.text('Bo‘sh rulon'), findsNothing);
    await _tapPaddonFabEditAction(tester);
    expect(
      find.text('Paddonga qo‘shish mumkin bo‘lgan WIP lar'),
      findsOneWidget,
    );
    expect(find.text('Order: order-002'), findsOneWidget);
    expect(
      find.text('EPC: 40019876543210FEDCBA • 2 m'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('paddon-available-wip-card-free-wip-001')),
      findsOneWidget,
    );
    expect(
      find.byIcon(Icons.remove_circle_outline_rounded),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('paddon-add-wip-scan')), findsNothing);

    await _tapPaddonFabEditAction(tester);
    expect(find.text('Paddon ichidagi WIP lar'), findsOneWidget);
    expect(find.text('Order: order-002'), findsNothing);
    expect(
      find.byKey(const ValueKey('paddon-wip-card-wip-001')),
      findsOneWidget,
    );
    await _openPaddonFab(tester);
    expect(find.text('Olib tashlash'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-hub-toggle-button')));
    await tester.pumpAndSettle();
  });

  testWidgets('opening available WIPs scrolls them into view', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _setSession();

    await tester.pumpWidget(
      _app(
        AparatchiPaddonDetailScreen(apparatusLoader: () async => const [],
          code: '00001',
          loader: () async => _snapshotWithAssignedWips(18),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapPaddonFabEditAction(tester);

    final availableCard = find.byKey(
      const ValueKey('paddon-available-wip-card-free-wip-001'),
    );
    final rect = tester.getRect(availableCard);
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(rect.top, lessThan(viewport.height));
    expect(rect.bottom, greaterThan(0));
  });

  testWidgets(
    'available WIPs use the detail snapshot when the add list opens',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      _setSession();
      var loadCount = 0;
      final initial = _snapshot();

      await tester.pumpWidget(
        _app(
          AparatchiPaddonDetailScreen(apparatusLoader: () async => const [],
            code: '00001',
            loader: () async {
              loadCount += 1;
              return initial;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapPaddonFabEditAction(tester);

      expect(loadCount, 1);
      expect(
        find.text('Paddonga qo‘shish mumkin bo‘lgan WIP lar'),
        findsOneWidget,
      );
      expect(find.text('Order: order-002'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paddon-available-wip-card-free-wip-001')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('paddon-available-wip-card-free-wip-001')),
      );
      await tester.pumpAndSettle();

      expect(loadCount, 1);
      await _openPaddonFab(tester);
      expect(find.text('Qo‘shish (1)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-hub-toggle-button')));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('cutting cards preserve unknown weights', (tester) async {
    SharedPreferences.setMockInitialValues({}); _setSession();
    await tester.pumpWidget(_app(AparatchiPaddonsScreen( loader: () async =>
      [_paddon(totalGrossKg: null, totalNetKg: 0)])));
    await tester.pumpAndSettle();
    // List card is compact: only code + WIP count, no weights.
    expect(find.text('00001'), findsOneWidget);
    expect(find.text('2 ta WIP'), findsOneWidget);
    expect(find.text('Jami brutto: —'), findsNothing);
    expect(find.text('Jami netto: 0 kg'), findsNothing);
  });
  testWidgets('missing EPC never exposes an internal cutting batch ID',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    _setSession();
    const id = 'progress-batch:17894018964434500:apparatus-default-asset-010';
    await tester.pumpWidget(_app(AparatchiPaddonDetailScreen(
      code: '00001',
      apparatusLoader: () async => const [],
      loader: () async => AdminPaddonSnapshot(
        paddon: _paddon(itemCount: 1),
        items: [
          AdminProgressBatch.fromJson({
            'batch_id': id,
            'order_id': 'order-001',
            'apparatus': 'apparatus:default:asset-010',
          })
        ],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Order: order-001'), findsOneWidget);
    expect(find.text('EPC: —'), findsOneWidget);
    expect(find.textContaining('progress-batch:'), findsNothing);
    expect(find.textContaining('…'), findsNothing);
    expect(find.byKey(const ValueKey('paddon-add-wip-scan')), findsNothing);
    expect(find.byKey(const ValueKey('paddon-print-qr')), findsOneWidget);
  });

  for (final catalogUnavailable in [false, true]) {
    testWidgets(
        'cutting pallet locations hide IDs, catalog unavailable: $catalogUnavailable',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      _setSession();
      const paddon = AdminPaddon(
        id: 'paddon-1',
        code: '00001',
        location: '2-qator • apparatus:default:asset-010',
        note: '',
        createdByRef: '',
        createdByDisplayName: '',
        createdAtUnix: 1,
        updatedAtUnix: 1,
        itemCount: 1,
        totalGrossKg: 24.375,
        totalNetKg: 23.125,
      );
      Future<List<AdminApparatus>> catalog() async {
        if (catalogUnavailable) throw StateError('catalog unavailable');
        return const [
          AdminApparatus(
            id: 'apparatus:default:asset-010',
            name: 'Rezka 1',
          )
        ];
      }

      final expectedLocation =
          '2-qator • ${catalogUnavailable ? 'Belgilanmagan' : 'Rezka 1'}';
      for (final screen in [
        AparatchiPaddonsScreen(
            loader: () async => [paddon]),
        AparatchiPaddonDetailScreen(
          code: paddon.code,
          apparatusLoader: catalog,
          loader: () async =>
              const AdminPaddonSnapshot(paddon: paddon, items: []),
        ),
      ]) {
        await tester.pumpWidget(_app(screen));
        await tester.pumpAndSettle();
        final isList = screen is AparatchiPaddonsScreen;
        if (isList) {
          // List card is compact: only code + WIP count.
          expect(find.text('00001'), findsOneWidget);
          expect(find.text('1 ta WIP'), findsOneWidget);
          expect(find.text(expectedLocation), findsNothing);
          expect(find.text('Jami brutto: 24.375 kg'), findsNothing);
          expect(find.text('Jami netto: 23.125 kg'), findsNothing);
        } else {
          expect(find.text(expectedLocation), findsOneWidget);
          expect(find.text('Jami brutto: 24.375 kg'), findsOneWidget);
          expect(find.text('Jami netto: 23.125 kg'), findsOneWidget);
        }
        expect(find.textContaining('apparatus:'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
  for (final responseLost in [false, true]) {
    for (final removing in [false, true]) {
      testWidgets('${removing ? 'remove' : 'add'} refreshes totals, response lost: $responseLost', (tester) async {
        SharedPreferences.setMockInitialValues({}); _setSession();
        await tester.binding.setSurfaceSize(const Size(430, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var writes = 0; var loads = 0;
        final payload = <String, dynamic>{
          'paddon': {'code':'00001', 'item_count': removing ? 0 : 2,
            'total_gross_kg': removing ? 0 : 44.375, 'total_net_kg': removing ? 0 : 42.125},
          'items': [if (!removing) for (final id in ['wip-001','free-wip-001'])
            {'batch_id':id, 'apparatus':'apparatus:default:asset-010'}],
        };
        await http.runWithClient(() async {
          await tester.pumpWidget(_app(AparatchiPaddonDetailScreen(apparatusLoader: () async => const [], code:'00001', loader:() async {
            loads++; return writes == 0 ? _snapshot() : AdminPaddonSnapshot.fromJson(payload);
          })));
          await tester.pumpAndSettle();
          expect(find.text('Jami brutto: 24.375 kg'), findsOneWidget);
          await _tapPaddonFabEditAction(tester);
          if (removing) {
            await _tapPaddonFabEditAction(tester);
          }
          await tester.tap(find.byKey(ValueKey(removing ? 'paddon-wip-card-wip-001' : 'paddon-available-wip-card-free-wip-001')));
          await tester.pumpAndSettle();
          await _tapPaddonFabEditAction(tester);
          if (removing) {
            await tester.tap(find.widgetWithText(FilledButton, 'Olib tashlash'));
            await tester.pumpAndSettle();
          }
          expect(writes,1); expect(loads,responseLost ? 2 : 1);
          await tester.ensureVisible(find.byKey(const ValueKey('paddon-detail-weights')));
          await tester.pumpAndSettle();
          expect(find.text('Jami brutto: ${removing ? '0' : '44.375'} kg'), findsOneWidget);
          expect(find.text('Jami netto: ${removing ? '0' : '42.125'} kg'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, () => MockClient((request) async {
          writes++; expect(request.url.path, '/v1/mobile/admin/production-maps/paddons/items/${removing ? 'remove' : 'add'}-batch');
          if (responseLost) throw TimeoutException('response lost');
          return http.Response(jsonEncode(payload),200);
        }));
      });
    }
  }

}
