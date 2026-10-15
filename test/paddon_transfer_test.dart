import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/transfer/two_pane_transfer.dart';
import 'package:accord_mobile_v2/src/core/widgets/transfer/transfer_list.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_transfer_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddons_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionProfile _profile(String ref) => SessionProfile(
      role: UserRole.aparatchi,
      ref: ref,
      displayName: 'Rezka',
      legalName: '',
      phone: '',
      avatarUrl: '',
      assignedApparatus: const ['apparatus:default:asset-010'],
      capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
    );

class _Server {
  final members = <String, List<String>>{
    '00001': ['roll-1', 'roll-busy'],
    '00002': [],
    '00003': []
  };
  int writes = 0;
  int reads = 0;
  bool rejectTransfer = false;
  bool lockSourceOnRead = false;
  bool forgedReply = false;
  bool loseReply = false;
  bool freeMovement = false;
  String operation = 'cut';
  Map<String, dynamic>? lastRequest;

  Map<String, dynamic> paddon(String code) => {
        'id': 'paddon-$code',
        'code': code,
        'item_count': members[code]!.length,
        'created_by_ref': 'worker-1',
        if (code == '00003' || (code == '00001' && lockSourceOnRead))
          'locked_at_unix': 2,
      };

  late final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/admin/apparatus')) {
      return http.Response(
          jsonEncode([
            {
              'apparatus_id': 'apparatus:default:asset-010',
              'display': {'display_name': 'Rezka'},
              'source_revision': 1,
              'source_aasx_sha256':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'execution_profile': {
                'operation': operation,
                'technology': 'slitting'
              },
            }
          ]),
          200);
    }
    if (path.endsWith('/paddons')) {
      return http.Response(
          jsonEncode(
              {'ok': true, 'paddons': members.keys.map(paddon).toList()}),
          200);
    }
    if (path.endsWith('/qr/report')) {
      reads++;
      final code = request.url.queryParameters['code']!;
      return http.Response(
          jsonEncode({
            'ok': true,
            'paddon': paddon(code),
            'can_manage_items': true,
            'free_movement_enabled': freeMovement,
            'items': members[code]!
                .map((id) => {
                      'batch_id': id,
                      'apparatus': 'apparatus:default:asset-010',
                      'label_item_code': 'ITEM',
                      'label_item_name': id,
                      'wip_status': id == 'roll-busy' ? 'in_use' : 'waiting',
                      'produced_qty': 15,
                      'uom': 'kg',
                    })
                .toList(),
          }),
          200);
    }
    if (path.endsWith('/items/transfer')) {
      writes++;
      lastRequest = jsonDecode(request.body) as Map<String, dynamic>;
      if (rejectTransfer) {
        return http.Response('{"error":"paddon_locked"}', 409);
      }
      final from = lastRequest!['source_code'] as String;
      final to = lastRequest!['target_code'] as String;
      final ids = (lastRequest!['progress_batch_ids'] as List).cast<String>();
      members[from]!.removeWhere(ids.contains);
      members[to]!.addAll(ids);
      if (loseReply) throw TimeoutException('Transfer response lost');
      return http.Response(
          jsonEncode({
            'ok': true,
            ...lastRequest!,
            if (forgedReply) 'target_code': '00003',
          }),
          200);
    }
    return http.Response('{}', 404);
  });
}

Widget _app({Widget home = const AparatchiPaddonTransferScreen()}) =>
    MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: home,
    );

void main() {
  late _Server server;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile('worker-1');
    server = _Server();
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  for (final operation in ['cut', 'print']) {
    testWidgets(
        'paddon list offers transfer only for a cutting worker: $operation',
        (tester) async {
      server.operation = operation;
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(home: const AparatchiPaddonsScreen()));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
        await tester.pumpAndSettle();
        final action = find.byKey(
            const ValueKey('admin-hub-custom-Paddonlar aro WIP ko‘chirish'));
        expect(action, operation == 'cut' ? findsOneWidget : findsNothing);
        if (operation == 'cut') {
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.byType(AparatchiPaddonTransferScreen), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => server.client);
    });
  }

  test(
      'transfer API validates the confirmed source, destination and selected WIPs',
      () async {
    await http.runWithClient(() async {
      await MobileApi.instance.transferPaddonItems(
          sourceCode: ' 00001 ',
          targetCode: '00002',
          progressBatchIds: [' roll-1 ', 'roll-1']);
      expect(server.lastRequest, {
        'source_code': '00001',
        'target_code': '00002',
        'progress_batch_ids': ['roll-1']
      });
      expect(server.writes, 1);
      server.forgedReply = true;
      await expectLater(
          MobileApi.instance.transferPaddonItems(
              sourceCode: '00002',
              targetCode: '00001',
              progressBatchIds: ['roll-1']),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'paddon_transfer')));
    }, () => server.client);
  });

  test('invalid selections do not send a transfer request', () async {
    await http.runWithClient(() async {
      for (final args in [
        ('00001', '00001', ['roll-1']),
        ('00001', '00002', <String>[]),
        ('00001', '00002', [' '])
      ]) {
        await expectLater(
            MobileApi.instance.transferPaddonItems(
                sourceCode: args.$1,
                targetCode: args.$2,
                progressBatchIds: args.$3),
            throwsA(isA<MobileApiException>()));
      }
      expect(server.writes, 0);
    }, () => server.client);
  });

  testWidgets(
      'reuses transfer panes and rows, confirms, then refreshes both paddons',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(TwoPaneTransfer), findsOneWidget);
      expect(find.byType(TransferListRow), findsNWidgets(2));
      final busy = tester.widget<TransferListRow>(find.descendant(
          of: find.byKey(const ValueKey('paddon-transfer-wip-roll-busy')),
          matching: find.byType(TransferListRow)));
      expect(busy.disabled, isTrue);
      await tester
          .tap(find.byKey(const ValueKey('paddon-transfer-wip-roll-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-selected')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(server.writes, 0);
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-confirm')));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(server.members['00001'], ['roll-busy']);
      expect(server.members['00002'], ['roll-1']);
      expect(server.reads, greaterThanOrEqualTo(4));
      final destination =
          find.byKey(const ValueKey('paddon-transfer-list-00002'));
      expect(
          find.descendant(
              of: destination,
              matching:
                  find.byKey(const ValueKey('paddon-transfer-wip-roll-1'))),
          findsOneWidget);
      // Move back using the shared drag/drop component.
      final handle = find.descendant(
          of: find.byKey(const ValueKey('paddon-transfer-wip-roll-1')),
          matching: find.byIcon(Icons.drag_handle_rounded));
      final origin = find.byKey(const ValueKey('paddon-transfer-list-00001'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(origin));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-confirm')));
      await tester.pumpAndSettle();
      expect(server.members['00002'], isEmpty);
      expect(server.lastRequest!['source_code'], '00002');
      expect(server.lastRequest!['target_code'], '00001');
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets(
      'a pallet locked after selection is rejected and both sides are reloaded',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-transfer-wip-roll-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-selected')));
      await tester.pump(const Duration(milliseconds: 500));
      server.rejectTransfer = true;
      server.lockSourceOnRead = true;
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-confirm')));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(server.members['00001'], contains('roll-1'));
      expect(server.members['00002'], isEmpty);
      expect(
          find.byKey(const ValueKey('paddon-transfer-selected')), findsNothing);
      expect(server.reads, greaterThan(2));
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets(
      'locked detail cannot be edited even if the server advertises free movement',
      (tester) async {
    server.lockSourceOnRead = true;
    server.freeMovement = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // The list filters locked pallets, so only the unlocked empty destination remains.
      expect(find.byType(TransferListRow), findsNothing);
      expect(server.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets('cancelling confirmation preserves selection and sends no write',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-transfer-wip-roll-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-selected')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      expect(find.byKey(const ValueKey('paddon-transfer-selected')),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets(
      'a lost response reloads committed membership without replaying the transfer',
      (tester) async {
    server.loseReply = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-transfer-wip-roll-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-selected')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-confirm')));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(server.members['00002'], ['roll-1']);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('paddon-transfer-list-00002')),
              matching:
                  find.byKey(const ValueKey('paddon-transfer-wip-roll-1'))),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('paddon-transfer-selected')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets(
      'switching accounts while confirming cannot submit the old selection',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('paddon-transfer-wip-roll-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-selected')));
      await tester.pump(const Duration(milliseconds: 500));
      AppSession.instance.profile = _profile('worker-2');
      AppSession.instance.revision.value++;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-transfer-confirm')));
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });
}
