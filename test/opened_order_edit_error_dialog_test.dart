import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/opened_order_edit_error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network failures explain uncertainty without claiming the save failed',
      () {
    expect(openedOrderEditErrorReason(TimeoutException('private')),
        contains('saqlanganini tekshiring'));
    expect(openedOrderEditErrorReason(http.ClientException('private')),
        contains('aloqa'));
    expect(openedOrderEditErrorReason(const FormatException('private')),
        contains('format'));
  });

  const legacyError = MobileApiException(
    code: 'order_edit',
    statusCode: 409,
    message: 'So‘ralgan amal bajarilmadi: Buyurtmaning asl Calculate '
        'ma’lumotlari saqlanmagan: tahrirlash mumkin emas (HTTP 409)',
  );

  test('legacy snapshot error explains missing data without blaming the user',
      () {
    final reason = openedOrderEditErrorReason(legacyError);
    expect(reason, contains('dastlabki Calculate hisob-kitobi'));
    expect(reason, contains('mos yagona shablon aniqlanmadi'));
    expect(reason, contains('hozir kiritgan ma’lumotlaringizdagi xato emas'));
    expect(reason, contains('administratorga buyurtma raqamini yuboring'));
    expect(reason, isNot(contains('HTTP')));
    expect(reason, isNot(contains('So‘ralgan amal bajarilmadi')));
  });

  for (final reason in [
    'Buyurtmaga xomashyo biriktirilgan. Xomashyo tarixini tekshiring.',
    'Buyurtmada opening WIP ochilgan. Bekor qilingan bo‘lsa ham bloklanadi.',
    'Buyurtmada ish sessiyasi ochilgan. Ish tarixini tekshiring.',
    'Buyurtma apparat navbatida birinchi. Barcha navbatlarni tekshiring.',
    'Kadr soni Rezka bo‘linishiga mos emas. Avvalgi qiymatni kiriting.',
    'Buyurtma o‘zgargan. Sahifani qayta oching.',
  ]) {
    test('server business reason is preserved: $reason', () {
      expect(
        openedOrderEditErrorReason(MobileApiException(
          code: reason,
          message: 'So‘ralgan amal bajarilmadi: $reason (HTTP 409)',
          statusCode: 409,
        )),
        reason,
      );
    });
  }

  test('permission and server failures are not described as user mistakes', () {
    for (final entry in {
      401: 'qayta kiring',
      403: 'huquqi yo‘q',
      500: 'xato emas'
    }.entries) {
      expect(
        openedOrderEditErrorReason(MobileApiException(
          code: 'error',
          message: 'error',
          statusCode: entry.key,
        )),
        contains(entry.value),
      );
    }
    expect(openedOrderEditErrorReason(Exception('private details')),
        isNot(contains('private details')));
  });

  for (final saving in [false, true]) {
    testWidgets('edit failure stays readable until dismissed (saving=$saving)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showOpenedOrderEditErrorDialog(
                        context,
                        error: legacyError,
                        orderNumber: '0016',
                        saving: saving,
                      ),
                      child: const Text('Edit'),
                    ))),
      ));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Buyurtma №0016'), findsOneWidget);
      expect(find.text('Sabab'), findsOneWidget);
      expect(
          find.text(openedOrderEditErrorReason(legacyError)), findsOneWidget);
      expect(
          find.text(saving
              ? 'Saqlash tasdiqlanmadi'
              : 'Buyurtmani tahrirlash ochilmadi'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Tushunarli'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
