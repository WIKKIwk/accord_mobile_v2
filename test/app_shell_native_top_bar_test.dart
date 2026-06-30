import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/shared_header_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppShell native top bar mode uses AppBar only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const AppShell(
          title: 'Werka',
          subtitle: '',
          nativeTopBar: true,
          child: SizedBox.expand(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(SharedHeaderTitle), findsNothing);
    expect(find.text('Werka'), findsOneWidget);
  });

  testWidgets('AppShell can hide profile action while search is focused', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: AppShell(
          title: '',
          subtitle: '',
          nativeTopBar: true,
          profileActionListenable: focusNode,
          showProfileActionResolver: () => !focusNode.hasFocus,
          titleWidget: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(color: Colors.black),
            cursorColor: Colors.black,
            backgroundCursorColor: Colors.white,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(AppShellProfileAction), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('app-shell-profile-action-slot')),
          )
          .width,
      58,
    );

    await tester.showKeyboard(find.byType(EditableText));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 90));
    final midAnimationWidth = tester
        .getSize(
          find.byKey(const ValueKey('app-shell-profile-action-slot')),
        )
        .width;
    expect(midAnimationWidth, greaterThan(0));
    expect(midAnimationWidth, lessThan(58));

    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('app-shell-profile-action-slot')),
          )
          .width,
      0,
    );
  });

  testWidgets('AppShell opens drawer from left edge drag', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const AppShell(
          title: 'Werka',
          subtitle: '',
          drawer: SizedBox(
            width: 280,
            child: ColoredBox(
              color: Colors.white,
              child: Text('Drawer content'),
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Drawer content', skipOffstage: false), findsOneWidget);

    await tester.dragFrom(const Offset(4, 320), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(find.text('Drawer content'), findsOneWidget);
  });
}
