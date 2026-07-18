import 'package:accord_mobile_v2/src/features/admin/presentation/admin_factory_map_screen.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() {
  testWidgets('factory model is deferred until after the first route frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  transitionDuration: const Duration(seconds: 1),
                  pageBuilder: (_, __, ___) => const AdminFactoryMapScreen(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.byType(AdminFactoryMapScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(ModelViewer, skipOffstage: false), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ModelViewer, skipOffstage: false), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
