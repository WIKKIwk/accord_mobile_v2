import 'dart:convert';

import 'package:erpnext_stock_mobile/src/core/session/session.dart';
import 'package:erpnext_stock_mobile/src/features/admin/state/calculate_order_store.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() {
    AppSession.instance.profile = null;
  });

  test('upserts calculate orders for the current profile without kg', () async {
    final store = CalculateOrderTemplateStore();
    await store.load();

    await store.upsert(_template(name: 'CPP 600', widthMm: 530));
    await store.upsert(_template(name: 'CPP 600', widthMm: 630));

    expect(store.templates, hasLength(1));
    expect(store.templates.single.name, 'CPP 600');
    expect(store.templates.single.widthMm, 630);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('admin_calculate_orders_v1')!;
    expect(raw, isNot(contains('"kg"')));
    expect(jsonDecode(raw), isA<Map<String, dynamic>>());
  });

  test('keeps calculate orders isolated per profile', () async {
    final store = CalculateOrderTemplateStore();
    await store.load();
    await store.upsert(_template(name: 'Admin order'));

    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Second',
      legalName: 'Second',
      ref: 'ADMIN-002',
      phone: '',
      avatarUrl: '',
    );
    await store.load(force: true);

    expect(store.templates, isEmpty);
  });
}

CalculateOrderTemplate _template({
  required String name,
  double widthMm = 530,
}) {
  return CalculateOrderTemplate(
    id: '',
    name: name,
    savedAt: DateTime.utc(2026, 6, 8, 11),
    orderNumber: 'ORD-1',
    customer: 'Mijoz',
    product: 'cpp / 20 mikron / 600',
    status: 'Ready',
    materialDisplay: 'pet 12 / pe oq 30',
    color: 'oq',
    widthMm: widthMm,
    wastePercent: 3,
    rollCount: 7,
    firstLayerMaterial: 'pet',
    firstLayerMicron: '12',
    secondLayerMaterial: 'pe oq',
    secondLayerMicron: '30',
    thirdLayerMaterial: '',
    thirdLayerMicron: '',
    note: 'test',
  );
}
