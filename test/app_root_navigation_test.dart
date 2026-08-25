import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('root navigation never overlaps pop with a new push', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    var target = '/users';

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/home',
        navigatorObservers: [
          AppRootNavigation.navigatorObserver,
          observer,
        ],
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) {
              return TextButton(
                key: const ValueKey('root-navigation-trigger'),
                onPressed: () =>
                    AppRootNavigation.replaceRootRoute(context, target),
                child: Text(settings.name!),
              );
            },
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    observer.events.clear();

    await tester.tap(find.byKey(const ValueKey('root-navigation-trigger')));
    await tester.pumpAndSettle();
    expect(observer.events, ['push:/users']);
    observer.events.clear();

    target = '/activity';
    await tester.tap(find.byKey(const ValueKey('root-navigation-trigger')));
    await tester.pumpAndSettle();
    expect(observer.events, ['push:/activity']);
    observer.events.clear();

    target = '/users';
    await tester.tap(find.byKey(const ValueKey('root-navigation-trigger')));
    await tester.pumpAndSettle();
    expect(observer.events, ['pop:/activity']);
  });

  testWidgets('root navigation clears the active field focus', (tester) async {
    final fieldFocusNode = FocusNode();
    addTearDown(fieldFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/home',
        navigatorObservers: [AppRootNavigation.navigatorObserver],
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    Focus(
                      key: const ValueKey('root-navigation-field'),
                      focusNode: fieldFocusNode,
                      child: const SizedBox(height: 48, width: 200),
                    ),
                    TextButton(
                      key: const ValueKey('root-navigation-focus-trigger'),
                      onPressed: () =>
                          AppRootNavigation.replaceRootRoute(context, '/next'),
                      child: const Text('Next'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    fieldFocusNode.requestFocus();
    await tester.pump();
    expect(fieldFocusNode.hasFocus, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('root-navigation-focus-trigger')),
    );
    await tester.pump();

    expect(fieldFocusNode.hasFocus, isFalse);
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String> events = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    events.add('push:${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    events.add('pop:${route.settings.name}');
  }
}
