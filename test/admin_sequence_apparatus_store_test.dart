import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdminSequenceApparatusStore.instance.clearCache();
  });

  const app1 = AdminApparatus(
    id: 'canonical:apparatus:01',
    name: '8 ta rangli bosma aparat',
  );
  const app2 = AdminApparatus(
    id: 'canonical:apparatus:02',
    name: '9 ta rangli bosma aparat',
  );
  const list = [app1, app2];

  test('saves and restores selected apparatus by id', () async {
    final store = AdminSequenceApparatusStore.instance;

    await store.saveApparatus(app2);
    expect(store.cachedApparatusId, 'canonical:apparatus:02');
    expect(store.cachedApparatusName, '9 ta rangli bosma aparat');

    final resolved = store.resolveApparatus(list);
    expect(resolved?.id, 'canonical:apparatus:02');
    expect(resolved?.name, '9 ta rangli bosma aparat');

    // Simulate clearing cache as if app reopened
    store.clearCache();
    expect(store.cachedApparatusId, isNull);

    // Restore from SharedPreferences
    await store.loadSavedApparatusId();
    expect(store.cachedApparatusId, 'canonical:apparatus:02');

    final resolvedAfterReload = store.resolveApparatus(list);
    expect(resolvedAfterReload?.id, 'canonical:apparatus:02');
    expect(resolvedAfterReload?.name, '9 ta rangli bosma aparat');
  });

  test('fallback to matching by name if id changed', () async {
    final store = AdminSequenceApparatusStore.instance;

    await store.saveApparatus(app2);
    store.clearCache();

    // Imagine the backend migrated apparatus IDs but names remained the same
    const migratedApp2 = AdminApparatus(
      id: 'canonical:apparatus:new_02',
      name: '9 ta rangli bosma aparat',
    );
    final migratedList = [app1, migratedApp2];

    await store.loadSavedApparatusId();
    final resolved = store.resolveApparatus(migratedList);
    expect(resolved?.id, 'canonical:apparatus:new_02');
    expect(resolved?.name, '9 ta rangli bosma aparat');
  });
}
