import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('route guard stays open before a session is loaded', () {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;

    expect(AppRouter.canOpenRoute(AppRoutes.werkaArchive), isTrue);
  });

  test('route access follows session capabilities', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Scale operator',
      legalName: '',
      ref: 'werka',
      phone: '',
      avatarUrl: '',
      capabilities: ['gscale.print', 'rps.batch.manage'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.gscaleMode), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.werkaHome), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.adminRoles), isFalse);
  });

  test('admin role route only opens with role capability', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.supplier,
      displayName: 'Role manager',
      legalName: '',
      ref: 'SUP-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['role.capability.read'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.adminRoles), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminSettings), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.supplierHome), isFalse);
  });

  test('production map route opens with production map capability', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Production mapper',
      legalName: '',
      ref: 'werka',
      phone: '',
      avatarUrl: '',
      capabilities: ['production.map.manage'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.adminProductionMapTest), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminQueuePolicies), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminRoles), isFalse);
  });

  test('raw material admin routes follow raw material capabilities', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Raw material manager',
      legalName: '',
      ref: 'werka',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.rule.manage'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.adminRawMaterialRules), isTrue);
    expect(AppSession.instance.homeRoute, AppRoutes.adminHome);
    expect(
      AppRouter.canOpenRoute(AppRoutes.adminRawMaterialAssignments),
      isFalse,
    );

    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Raw material assigner',
      legalName: '',
      ref: 'werka',
      phone: '',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.adminRawMaterialRules), isFalse);
    expect(
      AppRouter.canOpenRoute(AppRoutes.adminRawMaterialAssignments),
      isTrue,
    );
  });

  test('production map route stays open for admin access', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.adminProductionMapTest), isTrue);
  });

  test('apparatus queue route opens read-only with queue capability', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Apparatchi',
      legalName: '',
      ref: 'werka',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );

    expect(AppSession.instance.homeRoute, AppRoutes.apparatusQueue);
    expect(AppRouter.canOpenRoute(AppRoutes.apparatusQueue), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminProductionMapOrders), isFalse);
    expect(AppRouter.canOpenRoute(AppRoutes.adminProductionMapTest), isFalse);
  });

  test('rezka split route opens with rezka capability', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.werka,
      displayName: 'Rezka operator',
      legalName: '',
      ref: 'rezka',
      phone: '',
      avatarUrl: '',
      capabilities: ['rezka.split.manage'],
    );

    expect(AppRouter.canOpenRoute(AppRoutes.rezkaSplit), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminRoles), isFalse);
  });
}
