import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/paddon_widgets.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'archive actions are in the FAB menu and empty state is plain text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'archive-fab-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'worker',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Qolip ombori'],
    );
    AppSession.instance.revision.value++;
    addTearDown(() {
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QolipStorageScreen(archive: true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No records found'), findsOneWidget);
      expect(find.byType(PaddonEmptyState), findsNothing);
      expect(find.text('Molds: Archive'), findsNothing);
      expect(find.text('Open pallet QR'), findsNothing);
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      expect(find.text('Molds: Archive'), findsOneWidget);
      expect(find.text('Open pallet QR'), findsOneWidget);
      expect(find.text('Create pallet'), findsNothing);
    },
        () => MockClient((request) async {
              final data = request.url.path.endsWith('/blocks')
                  ? {
                      'ok': true,
                      'warehouses': ['Qolip ombori'],
                      'blocks': []
                    }
                  : {'ok': true, 'entries': [], 'has_more': false};
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
