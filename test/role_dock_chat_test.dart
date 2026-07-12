import 'package:accord_mobile_v2/src/core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every role dock includes the shared Chat destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RoleDock(
            selectedIndex: 0,
            selectionVisible: true,
            destinations: [
              RoleDockDestination(
                id: 'home',
                label: 'Uy',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                active: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
  });
}
