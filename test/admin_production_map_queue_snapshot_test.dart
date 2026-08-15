import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production map live snapshot parses backend visible order ids', () {
    final snapshot = AdminProductionMapLiveSnapshot.fromJson({
      'ok': true,
      'maps': const [],
      'sequences': const {},
      'visible_order_ids': const {
        '7 ta rangli pechat': ['zakaz-visible-alt'],
        'Laminatsiya 1': ['zakaz-visible-alt'],
      },
      'queue_states': const {},
      'queue_policies': const [],
      'completed_orders': const [],
      'completion_requests': const [],
      'completion_request_decisions': const [],
      'order_controls': const {
        'zakaz-visible-alt': {'state': 'freeze_requested'},
        'zakaz-frozen': {'state': 'frozen'},
      },
      'order_customers': const {
        'zakaz-visible-alt': '555 kukuruz',
      },
      'order_statuses': const {
        'zakaz-visible-alt': {
          'order_status': 'in_progress',
          'active_session_count': 1,
        },
        'zakaz-issue': {
          'order_status': 'completed_with_issue',
          'completed_with_issue_count': 1,
        },
      },
    });

    expect(
      snapshot.visibleOrderIds['7 ta rangli pechat'],
      ['zakaz-visible-alt'],
    );
    expect(snapshot.visibleOrderIds['Laminatsiya 2'], isNull);
    expect(
      snapshot.orderControls['zakaz-visible-alt'],
      AdminOrderControlState.freezeRequested,
    );
    expect(
      snapshot.orderControls['zakaz-frozen'],
      AdminOrderControlState.frozen,
    );
    expect(
      snapshot.orderStatuses['zakaz-visible-alt']?.orderStatus,
      'in_progress',
    );
    expect(
      snapshot.orderStatuses['zakaz-issue']?.completedWithIssueCount,
      1,
    );
    expect(snapshot.orderCustomers['zakaz-visible-alt'], '555 kukuruz');
  });

  test('live snapshot projects frozen control over stale queue data', () {
    final snapshot = AdminProductionMapLiveSnapshot.fromJson({
      'maps': const [],
      'sequences': const {},
      'visible_order_ids': const {
        'Pechat': ['zakaz-frozen'],
      },
      'queue_states': const {
        'Pechat': {'zakaz-frozen': 'paused'},
      },
      'queue_policies': const [],
      'queue_action_controls': const {
        'Pechat': {
          'zakaz-frozen': {
            'state': 'paused',
            'allowed_actions': ['resume'],
          },
        },
      },
      'completed_orders': const [],
      'completion_requests': const [],
      'completion_request_decisions': const [],
      'order_controls': const {
        'zakaz-frozen': {'state': 'frozen'},
      },
      'order_statuses': const {
        'zakaz-frozen': {
          'order_status': 'in_progress',
          'work_status': 'in_progress',
          'flow_status': 'in_progress',
        },
      },
    });

    expect(snapshot.queueStates['Pechat']?['zakaz-frozen'], 'frozen');
    expect(
      snapshot.queueActionControls['Pechat']?['zakaz-frozen']?.state,
      'frozen',
    );
    expect(
      snapshot.queueActionControls['Pechat']?['zakaz-frozen']?.allowedActions,
      isEmpty,
    );
    expect(snapshot.orderStatuses['zakaz-frozen']?.orderStatus, 'frozen');
    expect(snapshot.orderStatuses['zakaz-frozen']?.workStatus, 'frozen');
    expect(snapshot.orderStatuses['zakaz-frozen']?.flowStatus, 'frozen');
  });

  test('production map definition keeps server customer name', () {
    final map = ProductionMapDefinition.fromJson({
      'id': 'zakaz-7657',
      'product_code': 'YASHIL',
      'title': 'yashil',
      'customer_name': '555 kukuruz',
      'nodes': const [],
      'edges': const [],
    });

    expect(map.customerName, '555 kukuruz');
    expect(map.toJson()['customer_name'], '555 kukuruz');
  });

  test('production map live snapshot requires backend visible order ids', () {
    expect(
      () => AdminProductionMapLiveSnapshot.fromJson({
        'ok': true,
        'maps': const [],
        'sequences': const {},
        'queue_states': const {},
        'queue_policies': const [],
        'completed_orders': const [],
        'completion_requests': const [],
        'completion_request_decisions': const [],
      }),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'production_map_visible_order_ids_missing',
        ),
      ),
    );
  });
}
