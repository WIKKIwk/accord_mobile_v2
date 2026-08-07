import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddons_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminPaddon _paddon({int itemCount = 2}) {
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
        'apparatus': 'Rezka 1',
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
        'apparatus': 'Rezka 1',
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
          'apparatus': 'Rezka 1',
        }),
    ],
    availableItems: snapshot.availableItems,
  );
}

void _setSession() {
  AppSession.instance.token = 'token';
  AppSession.instance.profile = const SessionProfile(
    role: UserRole.aparatchi,
    displayName: 'Rezka operatori',
    legalName: '',
    ref: 'worker-1',
    phone: '',
    avatarUrl: '',
    capabilities: ['apparatus.queue.read'],
    assignedApparatus: ['Rezka 1'],
  );
}

Widget _app(Widget home) {
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
  );
}

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('paddon snapshot hides WIPs already in the paddon', () {
    final snapshot = AdminPaddonSnapshot.fromJson({
      'paddon': {'code': '00001'},
      'items': [
        {'batch_id': 'assigned-wip'},
      ],
      'available_items': [
        {'batch_id': 'assigned-wip'},
        {'batch_id': 'free-wip'},
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
    expect(find.text('Rezka yonidagi 2-qator'), findsOneWidget);
    expect(find.text('2 ta WIP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('paddon-card-00001')),
      findsOneWidget,
    );
  });

  testWidgets('paddon detail switches between add and remove modes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _setSession();

    await tester.pumpWidget(
      _app(
        AparatchiPaddonDetailScreen(
          code: '00001',
          loader: () async => _snapshot(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order: order-001'), findsOneWidget);
    expect(find.text('EPC: 40011234567890ABCDEF'), findsOneWidget);
    expect(find.text('1 metr rulon'), findsNothing);
    expect(find.text('Paddon ichidagi WIP lar'), findsOneWidget);
    expect(find.text('Bo‘sh rulon'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('paddon-edit-mode-action')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Paddonga qo‘shish mumkin bo‘lgan WIP lar'),
      findsOneWidget,
    );
    expect(find.text('Order: order-002'), findsOneWidget);
    expect(find.text('EPC: 40019876543210FEDCBA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('paddon-available-wip-card-free-wip-001')),
      findsOneWidget,
    );
    expect(
      find.byIcon(Icons.remove_circle_outline_rounded),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('paddon-add-wip-scan')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('paddon-edit-mode-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Olib tashlash'), findsOneWidget);
    expect(find.text('Paddon ichidagi WIP lar'), findsOneWidget);
    expect(find.text('Order: order-002'), findsNothing);
    expect(
      find.byKey(const ValueKey('paddon-wip-card-wip-001')),
      findsOneWidget,
    );
  });

  testWidgets('opening available WIPs scrolls them into view', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _setSession();

    await tester.pumpWidget(
      _app(
        AparatchiPaddonDetailScreen(
          code: '00001',
          loader: () async => _snapshotWithAssignedWips(18),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('paddon-edit-mode-action')),
    );
    await tester.pumpAndSettle();

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
          AparatchiPaddonDetailScreen(
            code: '00001',
            loader: () async {
              loadCount += 1;
              return initial;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('paddon-edit-mode-action')),
      );
      await tester.pumpAndSettle();

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
      expect(find.text('Qo‘shish (1)'), findsOneWidget);
    },
  );
}
