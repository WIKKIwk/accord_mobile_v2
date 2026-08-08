import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_order_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const orderIds = ['active', 'paused', 'finished', 'queued'];
  const states = {
    'active': 'in_progress',
    'paused': 'paused',
    'finished': 'completed',
  };

  test('jarayonda filter only keeps active and paused orders', () {
    expect(
      filterFactoryMapOrderIds(
        orderIds: orderIds,
        states: states,
        filter: FactoryMapOrderFilter.inProgress,
      ),
      ['active', 'paused'],
    );
  });

  test('tugagan filter only keeps completed orders', () {
    expect(
      filterFactoryMapOrderIds(
        orderIds: orderIds,
        states: states,
        filter: FactoryMapOrderFilter.completed,
      ),
      ['finished'],
    );
  });

  test('barchasi filter preserves the source order', () {
    expect(
      filterFactoryMapOrderIds(
        orderIds: orderIds,
        states: states,
        filter: FactoryMapOrderFilter.all,
      ),
      orderIds,
    );
  });
}
