import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/spring_bottom_sheet.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/server_endpoint_switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({
    required List<SavedServerEndpoint> endpoints,
    required Future<bool> Function(SavedServerEndpoint endpoint) onSwitch,
    required Future<SavedServerEndpoint> Function(String raw) onSave,
  }) {
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
      home: Scaffold(
        body: ServerEndpointSwitcherSheet(
          endpoints: endpoints,
          activeBaseUrl: 'https://erp-one.example.com',
          onSwitch: onSwitch,
          onSave: onSave,
        ),
      ),
    );
  }

  testWidgets('lists saved servers and adds a new domain', (tester) async {
    final endpoints = <SavedServerEndpoint>[
      SavedServerEndpoint(
        baseUrl: 'https://erp-one.example.com',
        lastUsedAt: DateTime(2026, 9, 17, 10),
      ),
      SavedServerEndpoint(
        baseUrl: 'https://erp-two.example.com',
        lastUsedAt: DateTime(2026, 9, 17, 9),
      ),
    ];
    String? switchedTo;

    await tester.pumpWidget(
      buildApp(
        endpoints: endpoints,
        onSwitch: (endpoint) async {
          switchedTo = endpoint.baseUrl;
          return false;
        },
        onSave: (raw) async {
          return SavedServerEndpoint(
            baseUrl: ServerEndpointStore.normalize(raw)!,
            lastUsedAt: DateTime(2026, 9, 17, 11),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saqlangan serverlar'), findsOneWidget);
    expect(find.text('https://erp-one.example.com'), findsOneWidget);
    expect(find.text('https://erp-two.example.com'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('saved-server-https://erp-two.example.com'),
      ),
    );
    await tester.pump();
    expect(switchedTo, 'https://erp-two.example.com');

    await tester.tap(find.byKey(const ValueKey<String>('add-saved-server')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('server-endpoint-add-input')),
      'erp-three.example.com',
    );
    await tester
        .tap(find.byKey(const ValueKey<String>('server-endpoint-save')));
    await tester.pumpAndSettle();

    expect(find.text('https://erp-three.example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('server-endpoint-list')),
        findsOneWidget);
  });

  testWidgets('done action dismisses the endpoint keyboard focus',
      (tester) async {
    await tester.pumpWidget(
      buildApp(
        endpoints: [
          SavedServerEndpoint(
            baseUrl: 'https://erp-one.example.com',
            lastUsedAt: DateTime(2026, 9, 17, 10),
          ),
        ],
        onSwitch: (_) async => false,
        onSave: (raw) async {
          return SavedServerEndpoint(
            baseUrl: ServerEndpointStore.normalize(raw)!,
            lastUsedAt: DateTime(2026, 9, 17, 11),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('add-saved-server')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('server-endpoint-add-input')),
      'erp-three.example.com',
    );
    final endpointFocusNode = tester
        .widget<EditableText>(
          find.byType(EditableText),
        )
        .focusNode;

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('server-endpoint-list')),
        findsOneWidget);
    expect(endpointFocusNode.hasFocus, isFalse);
  });

  testWidgets('add form stays above the keyboard inset', (tester) async {
    final endpoint = SavedServerEndpoint(
      baseUrl: 'https://erp-one.example.com',
      lastUsedAt: DateTime(2026, 9, 17, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: child!,
          );
        },
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showSpringBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.sizeOf(sheetContext).height * 0.76,
                          ),
                          child: ServerEndpointSwitcherSheet(
                            endpoints: [endpoint],
                            activeBaseUrl: endpoint.baseUrl,
                            onSwitch: (_) async => false,
                            onSave: (raw) async => SavedServerEndpoint(
                              baseUrl: ServerEndpointStore.normalize(raw)!,
                              lastUsedAt: DateTime(2026, 9, 17, 11),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open server switcher'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open server switcher'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('add-saved-server')));
    await tester.pumpAndSettle();

    final input = find.byKey(
      const ValueKey<String>('server-endpoint-add-input'),
    );
    final keyboardTop = tester.binding.renderView.size.height - 260;
    expect(tester.getRect(input).bottom, lessThanOrEqualTo(keyboardTop));
  });
}
