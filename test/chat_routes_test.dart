import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  for (final role in UserRole.values) {
    test('${role.name} can open every chat route', () {
      AppSession.instance.token = 'token';
      AppSession.instance.profile = SessionProfile(
        role: role,
        displayName: role.name,
        legalName: role.name,
        ref: '${role.name}_1',
        phone: '',
        avatarUrl: '',
      );

      expect(AppRouter.canOpenRoute(AppRoutes.chat), isTrue);
      expect(AppRouter.canOpenRoute(AppRoutes.chatDirectory), isTrue);
      expect(AppRouter.canOpenRoute(AppRoutes.chatDetail), isTrue);
    });
  }
}
