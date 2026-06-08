import 'dart:convert';

import 'package:erpnext_stock_mobile/src/features/admin/state/calculate_order_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and mutates calculate orders through the server client',
      () async {
    final client = _FakeCalculateOrderTemplateClient();
    final store = CalculateOrderTemplateStore(client: client);

    await store.load();
    expect(client.listCalls, 1);
    expect(store.templates, isEmpty);

    await store.upsert(_template(name: 'CPP 600', widthMm: 530));
    await store.upsert(_template(name: 'CPP 600', widthMm: 630));

    expect(client.upsertCalls, 2);
    expect(client.listCalls, 3);
    expect(store.templates, hasLength(1));
    expect(store.templates.single.name, 'CPP 600');
    expect(store.templates.single.widthMm, 630);
    expect(store.templates.single.materialDisplay, isEmpty);
    expect(
        jsonEncode(store.templates.single.toJson()), isNot(contains('"kg"')));

    await store.delete(store.templates.single.id);

    expect(client.deleteCalls, 1);
    expect(store.templates, isEmpty);
  });
}

class _FakeCalculateOrderTemplateClient
    implements CalculateOrderTemplateClient {
  final List<CalculateOrderTemplate> _templates = [];
  int listCalls = 0;
  int upsertCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<CalculateOrderTemplate>> listTemplates() async {
    listCalls++;
    return List<CalculateOrderTemplate>.from(_templates);
  }

  @override
  Future<CalculateOrderTemplate> upsertTemplate(
    CalculateOrderTemplate template,
  ) async {
    upsertCalls++;
    final normalizedName = template.name.trim().toLowerCase();
    final index = _templates.indexWhere(
      (item) => item.name.trim().toLowerCase() == normalizedName,
    );
    final saved = _copyWithServerFields(
      template,
      id: index >= 0 ? _templates[index].id : 'template-$upsertCalls',
    );
    if (index >= 0) {
      _templates[index] = saved;
    } else {
      _templates.add(saved);
    }
    return saved;
  }

  @override
  Future<void> deleteTemplate(String id) async {
    deleteCalls++;
    _templates.removeWhere((template) => template.id == id);
  }
}

CalculateOrderTemplate _copyWithServerFields(
  CalculateOrderTemplate template, {
  required String id,
}) {
  return CalculateOrderTemplate(
    id: id,
    name: template.name,
    savedAt: DateTime.utc(2026, 6, 8, 12),
    orderNumber: template.orderNumber,
    customer: template.customer,
    product: template.product,
    status: template.status,
    materialDisplay: '',
    color: template.color,
    widthMm: template.widthMm,
    wastePercent: template.wastePercent,
    rollCount: template.rollCount,
    firstLayerMaterial: template.firstLayerMaterial,
    firstLayerMicron: template.firstLayerMicron,
    secondLayerMaterial: template.secondLayerMaterial,
    secondLayerMicron: template.secondLayerMicron,
    thirdLayerMaterial: template.thirdLayerMaterial,
    thirdLayerMicron: template.thirdLayerMicron,
    note: template.note,
  );
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
    materialDisplay: '',
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
