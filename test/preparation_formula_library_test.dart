import 'dart:async';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/state/preparation_formula_library_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preparation_material_management_test.dart' as fixtures;

Map<String, dynamic> _set(String id, String title) => {
      'set_id': 'set-$id',
      'name': title,
      'product_code': id,
      'product_title': title,
      'order_codes': ['order-$id'],
      'formulas': [],
      'sort_at': 1,
    };

Map<String, dynamic> _recipe(String id, String title) => {
      'id': 'recipe-$id',
      'name': title,
      'product_code': id,
      'product_title': 'Product $id',
      'material_id': 'material',
      'material_name': 'Material',
      'order_codes': ['order-$id'],
      'sort_at': 1,
    };

Map<String, dynamic> _cursor(int revision) => {
      'epoch': 'test-epoch',
      'revision': revision,
    };

void main() {
  testWidgets(
      'both tabs reuse one snapshot and apply live patches across reconnects',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    final session = AppSession.instance;
    session.token = 'token';
    session.profile = fixtures.profile(UserRole.tayyorlovMasteri);
    addTearDown(() {
      session.token = null;
      session.profile = null;
      session.revision.value++;
    });

    var reads = 0;
    final sockets = <StreamController<Map<String, dynamic>>>[];
    final cursors = <(String, int)>[];
    final library =
        PreparationFormulaLibraryStore(connectLive: (epoch, revision) {
      cursors.add((epoch, revision));
      final socket = StreamController<Map<String, dynamic>>();
      sockets.add(socket);
      return socket.stream;
    });
    addTearDown(library.dispose);

    await http.runWithClient(() async {
      Future<void> tab(String name) async {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }

      Widget page() => fixtures.app(
            home: PreparationFormulaOrdersScreen(library: library),
          );

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(cursors, [('test-epoch', 1)]);
      sockets.single.add({'type': 'checkpoint', 'cursor': _cursor(1)});
      await tester.pumpAndSettle();
      expect(find.text('Product A'), findsOneWidget);
      await tab('Saqlangan formulalar');
      expect(find.text('Recipe A'), findsOneWidget);
      await tab('Mahsulot bo‘yicha');
      await tab('Saqlangan formulalar');
      expect(reads, 1);

      sockets.single.add({
        'type': 'delta',
        'base_revision': 1,
        'cursor': _cursor(2),
        'products': ['A'],
        'sets': [_set('A', 'Updated product')],
        'formulas': [_recipe('A', 'Updated recipe')],
      });
      await tester.pumpAndSettle();
      expect(library.recipesFor('A').single.name, 'Updated recipe');
      expect(find.text('Updated recipe'), findsOneWidget);
      expect(find.text('Recipe B'), findsOneWidget);
      await tab('Mahsulot bo‘yicha');
      expect(find.text('Updated product'), findsOneWidget);
      expect(find.text('Product B'), findsOneWidget);

      unawaited(sockets.first.close());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(cursors, [('test-epoch', 1), ('test-epoch', 2)]);
      expect(find.text('Updated product'), findsOneWidget);
      sockets.last.add({
        'type': 'delta',
        'base_revision': 2,
        'cursor': _cursor(3),
        'products': ['A'],
        'sets': [],
        'formulas': [],
      });
      await tester.pumpAndSettle();
      expect(find.text('Updated product'), findsNothing);
      await tab('Saqlangan formulalar');
      expect(find.text('Updated recipe'), findsNothing);
      expect(find.text('Recipe B'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(cursors.last, ('test-epoch', 3));
      expect(find.text('Product B'), findsOneWidget);
      expect(reads, 1);
      await tester.tap(find.text('Product B'));
      await tester.pumpAndSettle();
      expect(find.text('Recipe B'), findsOneWidget);
      Navigator.of(tester.element(find.text('Recipe B'))).pop();
      await tester.pumpAndSettle();
      expect(reads, 1);

      session.token = null;
      session.profile = null;
      session.revision.value++;
      await tester.pump();
      expect(find.text('Product B'), findsNothing);
      expect(library.recipes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              expect(request.url.path, '/v1/mobile/preparation/formula-sets');
              expect(request.url.queryParameters['library'], 'true');
              reads++;
              return fixtures.response({
                'cursor': _cursor(1),
                'sets': [_set('A', 'Product A'), _set('B', 'Product B')],
                'formulas': [
                  _recipe('A', 'Recipe A'),
                  _recipe('B', 'Recipe B')
                ],
              });
            }));
  });
}
