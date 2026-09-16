import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_audio_playback_controller.dart';
import 'package:accord_mobile_v2/src/features/material_link/models/material_link_request.dart';
import 'package:accord_mobile_v2/src/features/material_link/presentation/material_link_request_card.dart';
import 'package:accord_mobile_v2/src/features/material_link/presentation/material_link_request_panel.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> fixture({String status = 'pending', int revision = 1}) => {
      'request_id': 'link-1',
      'status': status,
      'event_sequence': revision,
      'order_id': 'order-1',
      'order_number': '001',
      'apparatus_id': 'apparatus:test:film',
      'apparatus_name': 'Machine',
      'requester_ref': 'worker',
      'requester_display_name': 'Worker',
      'mover_ref': 'mover',
      'mover_display_name': 'Mover',
      'expires_at_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800,
      'reason': status == 'stale' ? 'Rulon boshqa orderga ulangan' : '',
      'candidates': [
        for (final code in ['R1', 'R2', 'R3'])
          {
            'barcode': code,
            'item_name': 'Film',
            'qty': 15.0,
            'uom': 'kg',
            'location_name': 'State',
          }
      ],
      'selected_barcodes': status == 'approved' ? ['R2'] : <String>[],
    };

SessionProfile profile(UserRole role, String ref) => SessionProfile(
      role: role,
      ref: ref,
      displayName: ref,
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: const ['raw_material.assign', 'apparatus.queue.manage'],
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = profile(UserRole.admin, 'admin');
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('chat card metadata and terminal status survive serialization', () {
    final message = ChatMessage.fromJson({
      'message_id': 'm1',
      'sender_role': 'aparatchi',
      'type': 'material_link_request',
      'metadata': fixture(status: 'stale', revision: 2),
    });
    expect(message.previewText, 'Homashyo ulash so‘rovi');
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.materialLinkRequest?.pending, isFalse);
    expect(
        restored.materialLinkRequest?.reason, 'Rulon boshqa orderga ulangan');
  });

  test('approval sends only explicit selected barcode and bearer token',
      () async {
    await http.runWithClient(() async {
      final result = await MobileApi.instance.decideMaterialLinkRequest(
          requestId: 'link-1', action: 'approve', barcodes: ['R2']);
      expect(result.selectedBarcodes, ['R2']);
    },
        () => MockClient((request) async {
              expect(request.headers['authorization'], 'Bearer token');
              expect(request.url.path, '/v1/mobile/material-link-requests');
              expect(jsonDecode(request.body), {
                'request_id': 'link-1',
                'action': 'approve',
                'barcodes': ['R2']
              });
              return http.Response(
                  jsonEncode(
                      {'request': fixture(status: 'approved', revision: 2)}),
                  200);
            }));
  });

  testWidgets(
      'structured chat card submits selection and handles an external assignment',
      (tester) async {
    final playback = ChatAudioPlaybackController();
    addTearDown(playback.dispose);
    var posted = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ChatMessageBubble(
        mine: false,
        playback: playback,
        message: ChatMessage.fromJson({
          'message_id': 'm1',
          'sender_role': 'aparatchi',
          'type': 'material_link_request',
          'metadata': fixture(),
        }),
      ))));
      expect(find.byType(MaterialLinkRequestCard), findsOneWidget);
      await tester.tap(find.text('Ha, ulash'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialLinkRollPicker), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('material-link-roll-R2')));
      await tester.pump();
      await tester.tap(find.text('Tanlanganlarni ulash (1)'));
      await tester.pumpAndSettle();
      expect(posted, 1);
      expect(find.text('Ha, ulash'), findsNothing);
      expect(find.text('Tasdiq kutilmoqda'), findsNothing);
      expect(find.text('Rulon boshqa orderga ulangan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                posted++;
                expect(jsonDecode(request.body)['barcodes'], ['R2']);
                return http.Response(
                    jsonEncode(
                        {'request': fixture(status: 'stale', revision: 2)}),
                    200);
              }
              expect(request.url.queryParameters['request_id'], 'link-1');
              return http.Response(jsonEncode({'request': fixture()}), 200);
            }));
  });

  test('empty approval is rejected without issuing a network request',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.decideMaterialLinkRequest(
              requestId: 'link-1', action: 'approve'),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((_) async {
              fail('empty selection must not be sent');
            }));
  });

  for (final entry in [
    (role: UserRole.admin, ref: 'admin', canDecide: true),
    (role: UserRole.materialTaminotchi, ref: 'mover', canDecide: true),
    (role: UserRole.materialTaminotchi, ref: 'unrelated', canDecide: false),
    (role: UserRole.aparatchi, ref: 'worker', canDecide: false),
  ]) {
    testWidgets('card actions limited to ${entry.role.name}/${entry.ref}',
        (tester) async {
      AppSession.instance.profile = profile(entry.role, entry.ref);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MaterialLinkRequestCard(
        request: MaterialLinkRequest.fromJson(fixture()),
      ))));
      expect(find.text('Ha, ulash'),
          entry.canDecide ? findsOneWidget : findsNothing);
      expect(
          find.text('Yo‘q'), entry.canDecide ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('roll picker starts empty and returns only selected roll',
      (tester) async {
    List<String>? picked;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    picked = await showModalBottomSheet<List<String>>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => MaterialLinkRollPicker(
                              rolls:
                                  MaterialLinkRequest.fromJson(fixture()).rolls,
                            ));
                  },
                )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Tanlanganlarni ulash (0)'))
            .onPressed,
        isNull);
    for (final tile
        in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
      expect(tile.value, isFalse);
    }
    await tester.tap(find.byKey(const ValueKey('material-link-roll-R2')));
    await tester.pump();
    await tester.tap(find.text('Tanlanganlarni ulash (1)'));
    await tester.pumpAndSettle();
    expect(picked, ['R2']);
  });

  testWidgets(
      'shared card update closes actions; delayed pending cannot reopen',
      (tester) async {
    Widget card(Map<String, dynamic> json) => MaterialApp(
        home: Scaffold(
            body: MaterialLinkRequestCard(
                key: const ValueKey('shared-card'),
                request: MaterialLinkRequest.fromJson(json))));
    await tester.pumpWidget(card(fixture()));
    expect(find.text('Ha, ulash'), findsOneWidget);
    await tester.pumpWidget(card(fixture(status: 'cancelled', revision: 2)));
    expect(find.text('Bekor qilingan'), findsOneWidget);
    expect(find.text('Ha, ulash'), findsNothing);
    await tester.pumpWidget(card(fixture()));
    expect(find.text('Bekor qilingan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final terminal in ['cancelled', 'stale', 'expired', 'approved']) {
    testWidgets(
        'worker leaves pending after $terminal and refreshes changed materials',
        (tester) async {
      AppSession.instance.profile = profile(UserRole.aparatchi, 'worker');
      var status = 'pending';
      var linked = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MaterialLinkRequestPanel(
          orderId: 'order-1',
          apparatusId: 'apparatus:test:film',
          onMaterialsLinked: () {
            linked++;
          },
        ))));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<OutlinedButton>(find.byType(OutlinedButton))
                .onPressed,
            isNull);
        status = terminal;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('Tasdiq kutilmoqda'), findsNothing);
        expect(find.text('Ulash uchun so‘rov'), findsOneWidget);
        expect(
            tester
                .widget<OutlinedButton>(find.byType(OutlinedButton))
                .onPressed,
            isNotNull);
        expect(linked, ['approved', 'stale'].contains(terminal) ? 1 : 0);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(linked, ['approved', 'stale'].contains(terminal) ? 1 : 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({
                'available_count': 2,
                'requests': [
                  fixture(status: status, revision: status == 'pending' ? 1 : 2)
                ],
              }),
              200)));
    });
  }

  testWidgets(
      'stale with no remaining rolls does not offer another doomed request',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MaterialLinkRequestPanel(
        orderId: 'order-1',
        apparatusId: 'apparatus:test:film',
        onMaterialsLinked: () {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Ulash uchun so‘rov'), findsNothing);
      expect(find.text('Tasdiq kutilmoqda'), findsNothing);
      expect(
          find.text('Hozir bu orderga ulash mumkin bo‘lgan bo‘sh rulon yo‘q'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'available_count': 0,
              'requests': [fixture(status: 'stale', revision: 2)],
            }),
            200)));
  });
}
