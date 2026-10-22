import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_models.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show compute;

const _apparatus = 'apparatus:default:asset-005';
const _order = 'zakaz-cache-ўзбек-😀';

Map<String, dynamic> _wire() => {
      'ok': true,
      'epoch': 'server',
      'scope': 'actor-and-window',
      'rev': 53,
      'worker_show_all_apparatus_tabs': true,
      'maps': [
        {
          'map': {
            'id': _order,
            'title': 'Cache order',
            'product_code': 'P1',
            'code': '  CODE  ',
            'order_number': '  0053  ',
            'customer_name': '  Мижоз 😀  ',
            'image_id': '  image  ',
            'roll_count': 8.5,
            'width_mm': 123.4,
            'print_val_size_mm': 124.0,
            'order_kg': 19.2,
            'base_length': 300.5,
            'nodes': [
              {
                'id': 'work',
                'kind': 'apparatus',
                'apparatus_id': _apparatus,
                'title': '  Work  ',
                'item_code': '  material  ',
                'qty_formula': '  qty * 2  ',
                'from_location': '  old  ',
                'to_location': '  new  ',
                'alternative_group_label': '  Group  ',
                'alternative_assigned_title': '  Alternative  ',
                'x': 12.5,
                'y': -8.5,
                'rezka_kadr_count': 3,
                'rezka_label_length': 4.5,
                'rezka_frame_groups': [1, 2],
              }
            ],
            'edges': [
              {'from': 'start', 'to': 'work', 'branch': '  route  '}
            ],
          },
          'program': {
            'map_id': _order,
            'product_code': 'P1',
            'operations': [
              {
                'order': 1,
                'node_id': 'work',
                'op_code': 'run',
                'args': {'material': '  MAT 😀  ', 'quantity': 'qty * 2'},
              }
            ]
          },
        }
      ],
      'sequences': {
        _apparatus: [_order]
      },
      'sequence_versions': {_apparatus: 'a' * 64},
      'sequence_revisions': {_apparatus: 9},
      'visible_order_ids': {
        _apparatus: [_order]
      },
      'queue_states': {
        _apparatus: {_order: 'in_progress'}
      },
      'stage_states': {
        _order: {'work': 'in_progress'}
      },
      'queue_policies': [
        {
          'apparatus_id': _apparatus,
          'apparatus': 'Press',
          'source_revision': 3,
          'source_aasx_sha256': 'b' * 64,
          'discipline': 'strict_sequence',
          'policy': 'strict_sequence',
          'locked': true,
          'reason': 'pechat_always_strict',
        }
      ],
      'queue_action_controls': {
        _apparatus: {
          _order: {
            'state': 'in_progress',
            'allowed_actions': ['pause'],
            'interaction': {
              'mode': 'freeze_requested',
              'start_materials_mode': 'hidden',
              'material_scan_required': false,
              'assigned_materials_display_only': true,
              'material_intake_allowed': false,
              'previous_wip_mode': 'not_required',
              'qolip_mode': 'not_required',
              'blocking_reason_code': 'order_freeze_requested',
            },
            'previous_stage_ready': false,
            'complete_requires_full_report': false,
            'freeze_request': {
              'request_id': 'freeze-1',
              'status': 'pending',
              'target_session_id': 'session-1',
              'target_apparatus': _apparatus,
              'target_worker_role': 'aparatchi',
              'target_worker_ref': 'worker',
              'target_worker_display_name': 'Worker',
              'requested_at_unix': 1234,
              'transitioned_at_unix': 0,
            },
            'future_server_field': {
              'keep_this': ['exactly', 123]
            },
          }
        }
      },
      'order_controls': {
        _order: {'state': 'freeze_requested', 'early_close': {}}
      },
      'order_customers': {_order: 'Мижоз'},
      'order_statuses': {
        _order: {
          'lifecycle_status': 'in_progress',
          'order_status': 'active',
          'work_status': 'running',
          'flow_status': 'waiting',
          'stock_status': 'ready',
          'completed_with_issue_count': 2,
        }
      },
      'frozen_orders_by_apparatus': {
        _apparatus: [
          {
            'apparatus': _apparatus,
            'order_id': 'old-order',
            'issue_note': 'Сабаб',
            'frozen_at_unix': 1234,
            'frozen_by': 'worker',
          }
        ]
      },
      'completed_orders': [
        {
          'apparatus': _apparatus,
          'order_id': 'finished',
          'completed_at_unix': 5678,
          'status': 'completed_with_issue',
          'issue_note': 'Изоҳ',
        }
      ],
      'completion_requests': [
        {
          'event_id': 'request',
          'apparatus': _apparatus,
          'order_id': _order,
          'order_number': '53',
          'order_title': 'Order',
          'product_code': 'P1',
          'worker_role': 'aparatchi',
          'worker_ref': 'worker',
          'worker_display_name': 'Worker',
          'description': 'Please finish',
          'zero_metric_codes': ['meter'],
          'notice_kind': 'completion_request',
          'decision_required': false,
          'created_at_unix': 1234,
        }
      ],
      'completion_request_decisions': [
        {
          'event_id': 'decision',
          'request_event_id': 'request',
          'decision': 'rejected',
          'apparatus': _apparatus,
          'order_id': _order,
          'order_number': '53',
          'order_title': 'Order',
          'product_code': 'P1',
          'worker_role': 'aparatchi',
          'worker_ref': 'worker',
          'worker_display_name': 'Worker',
          'decided_by_role': 'admin',
          'decided_by_ref': 'admin',
          'decided_by_display_name': 'Admin',
          'description': 'Description',
          'message': 'Try again',
          'created_at_unix': 2345,
        }
      ],
    };

void main() {
  test('large decoded cache converts to exact typed models in a native isolate',
      () async {
    final raw = _wire();
    final saved = (raw['maps'] as List).single as Map<String, dynamic>;
    raw['maps'] = [
      saved,
      for (var i = 1; i < 100; i++)
        {
          'map': <String, dynamic>{
            ...saved['map'] as Map<String, dynamic>,
            'id': 'zakaz-cached-$i'
          },
          'program': <String, dynamic>{
            ...saved['program'] as Map<String, dynamic>,
            'map_id': 'zakaz-cached-$i'
          },
        },
    ];
    final decoded = await compute(decodeCachedProductionMapQueueSnapshot, raw);
    expect(decoded.maps, hasLength(100));
    expect(decoded.maps.last.map.id, 'zakaz-cached-99');
    expect(decoded.maps.last.program.mapId, 'zakaz-cached-99');
    expect(decoded.maps.last.map.customerName, '  Мижоз 😀  ');
    expect(decoded.scope, 'actor-and-window');
    expect(decoded.revision, 53);
    expect(decoded.queueActionControls[_apparatus]![_order]!.contractValid,
        isTrue);
  });

  test('all modeled snapshot fields and unknown action fields roundtrip',
      () async {
    final raw = _wire();
    final before =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(raw));
    final encoded = encodeProductionMapQueueSnapshot(before);
    final after =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(encoded))
            as AdminProductionMapLiveSnapshot;
    expect(encodeProductionMapQueueSnapshot(after), encoded);
    expect(after.sequenceVersions, before.sequenceVersions);
    expect(after.sequenceRevisions, before.sequenceRevisions);
    expect(after.earlyClosingOrderIds, {_order});
    expect(after.workerShowAllApparatusTabs, isTrue);
    expect(after.queuePolicies[_apparatus]!.sourceAasxSha256, 'b' * 64);
    expect(after.orderStatuses[_order]!.stockStatus, 'ready');
    expect(after.orderStatuses[_order]!.completedWithIssueCount, 2);
    expect(
        after.frozenOrdersByApparatus[_apparatus]!.single.issueNote, 'Сабаб');
    expect(after.completedOrders.single.issueNote, 'Изоҳ');
    expect(after.completionRequests.single.zeroMetricCodes, ['meter']);
    expect(after.completionRequests.single.decisionRequired, isFalse);
    expect(after.completionRequestDecisions.single.message, 'Try again');
    expect(
        jsonDecode(after
            .queueActionControls[_apparatus]![_order]!.serverContractSignature),
        (raw['queue_action_controls'] as Map)[_apparatus][_order]);
  });

  test(
      'cached map and compiled program preserve whitespace, geometry and operations',
      () {
    final saved = ProductionMapSaved.fromJson((_wire()['maps'] as List).single);
    final restored =
        ProductionMapSaved.fromJson(encodeCachedProductionMap(saved));
    expect(restored.map.code, saved.map.code);
    expect(restored.map.orderNumber, saved.map.orderNumber);
    expect(restored.map.customerName, saved.map.customerName);
    expect(restored.map.nodes.single.qtyFormula, '  qty * 2  ');
    expect(restored.map.nodes.single.alternativeGroupLabel, '  Group  ');
    expect(restored.map.nodes.single.x, 12.5);
    expect(restored.map.nodes.single.y, -8.5);
    expect(restored.map.nodes.single.rezkaFrameGroups, [1, 2]);
    expect(restored.map.edges.single.branch, '  route  ');
    expect(restored.program.operations.single.args['material'], '  MAT 😀  ');
    expect(
        encodeCachedProductionMap(restored), encodeCachedProductionMap(saved));
  });

  test('delta cursor and independently updated history are saved together',
      () async {
    final before =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(_wire()));
    final after = AdminProductionMapLiveStateDelta.fromJson({
      'epoch': 'server',
      'scope': 'actor-and-window',
      'base_rev': 53,
      'rev': 54,
      'protocol': 'state_delta_v2',
      'patch': {
        'order_customers': {
          'upsert': {_order: 'New customer'},
          'remove': []
        }
      },
    }).applyTo(before);
    final result = await decodeProductionMapQueueSnapshotPayload(jsonEncode(
            encodeProductionMapQueueSnapshot(after,
                completedOrders: const [],
                completionRequests: const [],
                completionRequestDecisions: const [])))
        as AdminProductionMapLiveSnapshot;
    expect(result.revision, 54);
    expect(result.orderCustomers[_order], 'New customer');
    expect(result.completedOrders, isEmpty);
    expect(result.completionRequests, isEmpty);
    expect(result.completionRequestDecisions, isEmpty);
  });

  test(
      'catalog roundtrip preserves capability intervals and every operational flag',
      () {
    final before = AdminApparatus.fromJson({
      'apparatus_id': _apparatus,
      'source_revision': 9,
      'source_aasx_sha256': 'a' * 64,
      'display': {
        'display_name': 'Press',
        'description': 'Description',
        'catalog_order': 7
      },
      'equipment_class_id': 'class',
      'physical_asset_id': 'asset',
      'hierarchy': {
        'enterprise_id': 'e',
        'site_id': 's',
        'area_id': 'a',
        'work_center_id': 'c',
        'work_unit_id': 'u'
      },
      'capabilities': [
        {
          'code': 'print',
          'level': 3,
          'valid_from_unix': 100,
          'valid_to_unix': 200,
          'enabled': false
        }
      ],
      'execution_profile': {
        'operation': 'print',
        'technology': 'gravure',
        'color_station_count': 8,
        'min_web_width_mm': 100,
        'max_web_width_mm': 500,
        'virtual_tasks': 'enabled',
        'capability_compatible_reroute': true
      },
      'training': {
        'enabled': true,
        'queue_enabled': true,
        'material_tracking_enabled': true
      },
      'placement': {'factory_map_object_id': 'map-object'},
      'lifecycle': {'state': 'active'},
      'worker_material_assignment_allowed': true,
    });
    final after = decodeCachedApparatus(encodeCachedApparatus(before));
    expect(encodeCachedApparatus(after), encodeCachedApparatus(before));
    expect(after.capabilityProfiles.single.validFromUnix, 100);
    expect(after.capabilityProfiles.single.validToUnix, 200);
    expect(after.capabilityProfiles.single.enabled, isFalse);
    expect(after.workerMaterialAssignmentAllowed, isTrue);
    expect(after.trainingMaterialTrackingEnabled, isTrue);
  });

  test(
      'malformed cached catalog fails rather than silently dropping authority fields',
      () {
    expect(() => decodeCachedApparatus({'apparatus_id': _apparatus}),
        throwsFormatException);
  });

  test('invalid server action contract cannot be persisted', () {
    const snapshot = AdminApparatusQueueSnapshot(
        sequences: {},
        visibleOrderIds: {},
        queueStates: {},
        queuePolicies: {},
        orderControls: {},
        queueActionControls: {
          _apparatus: {_order: AdminApparatusQueueOrderActionControl()},
        });
    expect(() => encodeProductionMapQueueSnapshot(snapshot),
        throwsA(isA<MobileApiException>()));
  });
}
