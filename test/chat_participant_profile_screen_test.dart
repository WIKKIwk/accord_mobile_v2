import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/chat_participant_profile_screen.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_role_dock.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_profile_avatar.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat participant profile uses the full profile surface', (
    tester,
  ) async {
    const participant = ChatPrincipal(
      principalId: 'principal-admin',
      role: UserRole.admin,
      ref: 'admin',
      displayName: 'Admin',
      avatarUrl: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatParticipantProfileScreen(participant: participant),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Admin'), findsWidgets);
    expect(find.text('Admin profili'), findsOneWidget);
    expect(find.text('Telefon kiritilmagan'), findsOneWidget);
    expect(find.byType(AdminProfileAvatar), findsOneWidget);
    expect(find.byType(ChatRoleDock), findsOneWidget);

    await tester.tap(find.byType(AdminProfileAvatar));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
