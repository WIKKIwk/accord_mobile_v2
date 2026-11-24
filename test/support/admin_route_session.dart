import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void signInToAdminRoutes() {
  final session = AppSession.instance;
  final previousToken = session.token;
  final previousProfile = session.profile;
  session.token = 'admin-route-test';
  session.profile = const SessionProfile(
    role: UserRole.admin,
    displayName: 'Admin',
    legalName: '',
    ref: 'admin-route-test',
    phone: '',
    avatarUrl: '',
    capabilities: [
      'admin.access',
      'admin.activity.read',
      'catalog.item.create',
      'catalog.item.bulk_move',
      'party.supplier.read',
      'party.supplier.manage',
    ],
  );
  addTearDown(() {
    session.token = previousToken;
    session.profile = previousProfile;
  });
}
