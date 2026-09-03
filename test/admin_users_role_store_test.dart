import 'package:accord_mobile_v2/src/features/admin/state/admin_users_role_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdminUsersRoleStore.instance.clearCache();
  });

  test('saves and restores selected role', () async {
    final store = AdminUsersRoleStore.instance;

    await store.saveRole(AdminUserKind.werka);
    expect(store.cachedRole, AdminUserKind.werka);

    store.clearCache();
    expect(store.cachedRole, isNull);

    await store.loadSavedRole();
    expect(store.cachedRole, AdminUserKind.werka);
  });

  test('parses role names case-insensitively', () {
    expect(AdminUsersRoleStore.parseKind('customer'), AdminUserKind.customer);
    expect(AdminUsersRoleStore.parseKind('WERKA'), AdminUserKind.werka);
    expect(AdminUsersRoleStore.parseKind('unknown_role'), isNull);
  });
}
