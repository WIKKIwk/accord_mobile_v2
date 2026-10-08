import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

const apparatus = 'apparatus:default:bosma_9';

Map<String, dynamic> control(String status, {String? trial}) => {
      'state': status,
      'allowed_actions': trial == 'passed' ? ['start'] : [],
      'previous_stage_ready': true,
      'complete_requires_full_report': true,
      'interaction': {
        'mode': trial == 'passed' ? 'fresh_start' : 'fresh_start_blocked',
        'start_materials_mode': 'hidden',
        'material_scan_required': false,
        'assigned_materials_display_only': true,
        'material_intake_allowed': false,
        'previous_wip_mode': 'not_required',
        'qolip_mode': 'not_required',
        'blocking_reason_code': 'print_preflight_active',
      },
      if (trial != null)
        'print_preflight': {
          'hold_id': 'hold',
          'idempotency_key': 'hold',
          'order_id': 'order',
          'apparatus': apparatus,
          'status': trial,
        },
    };

AdminApparatusQueueSnapshot snapshot() => AdminApparatusQueueSnapshot(
      epoch: 'epoch',
      revision: 10,
      sequences: const {
        apparatus: ['order']
      },
      visibleOrderIds: const {
        apparatus: ['order']
      },
      queueStates: const {
        apparatus: {'order': 'pending'}
      },
      queuePolicies: const {},
      orderControls: const {},
      queueActionControls: {
        apparatus: {
          'order': AdminApparatusQueueOrderActionControl.fromJson(
              control('pending')),
        }
      },
    );

AdminProductionMapLiveStateDelta delta(Map<String, dynamic> patch,
        {String epoch = 'epoch', int base = 10}) =>
    AdminProductionMapLiveStateDelta.fromJson({
      'epoch': epoch,
      'base_rev': base,
      'rev': base + 1,
      'patch': patch,
    });

Map<String, dynamic> field(Object value) => {
      'upsert': {'order': value},
      'remove': <String>[]
    };
Map<String, dynamic> nested(Object value) => {
      'scopes': {apparatus: field(value)},
      'remove': <String>[]
    };

void main() {
  test('1000 consecutive deltas preserve state and reject every gap and restart atomically', () {
    var current = snapshot();
    final original = current;
    for (var index = 0; index < 1000; index++) {
      final status = index % 3 == 0 ? 'pending' : 'print_preflight';
      final trial = index % 3 == 0 ? null : index % 3 == 1 ? 'running' : 'passed';
      final patch = {
        'queue_states': nested(status),
        'queue_action_controls': nested(control(status, trial: trial)),
        'stage_states': {
          'scopes': {'order': {'upsert': {apparatus: status}, 'remove': <String>[]}},
          'remove': <String>[],
        },
        'order_customers': field('Customer $index'),
      };
      final revision = current.revision!;
      final before = current;
      expect(() => delta(patch, base: revision - 1).applyTo(before),
          throwsA(isA<MobileApiException>()));
      expect(() => delta(patch, base: revision, epoch: 'restart-$index').applyTo(before),
          throwsA(isA<MobileApiException>()));
      current = delta(patch, base: revision).applyTo(before);
      expect(current.revision, revision + 1);
      expect(before.revision, revision);
      expect(current.queueStates[apparatus]!['order'], status);
      expect(current.stageStates['order']![apparatus], status);
      expect(current.orderCustomers['order'], 'Customer $index');
      expect(current.queueActionControls[apparatus]!['order']!.serverContractSignature,
          AdminApparatusQueueOrderActionControl.fromJson(control(status, trial: trial)).serverContractSignature);
      expect(current.sequences[apparatus], ['order']);
      expect(current.visibleOrderIds[apparatus], ['order']);
      expect(identical(current.maps, original.maps), isTrue);
    }
    expect(original.revision, 10);
    expect(original.queueStates[apparatus]!['order'], 'pending');
  });

  test('malformed optional colour controls preserve the committed hold', () {
    final response = AdminPrintPreflightResponse.fromJson({
      'hold': {
        'hold_id': 'hold', 'idempotency_key': 'hold', 'order_id': 'order',
        'apparatus': apparatus, 'status': 'passed',
      },
      'control_state': {'rev': 11, 'control': {}},
    });
    expect(response.hold.holdId, 'hold');
    expect(response.hold.status, 'passed');
    expect(response.controlState, isNull);
  });
  test('same revision from another worker scope cannot be applied', () {
    final changedScope = AdminProductionMapLiveStateDelta.fromJson({
      'epoch': 'epoch',
      'base_rev': 10,
      'rev': 11,
      'scope': 'other',
      'patch': {},
    });
    expect(() => changedScope.applyTo(snapshot()),
        throwsA(isA<MobileApiException>()));
  });

  test('HTTP snapshot parsing matches inline and background model conversion',
      () async {
    final source = jsonEncode({
      'ok': true,
      'epoch': 'epoch',
      'rev': 10,
      'scope': 'worker-scope',
      'maps': [],
      'sequences': {
        apparatus: ['order']
      },
      'visible_order_ids': {
        apparatus: ['order']
      },
      'queue_states': {
        apparatus: {'order': 'pending'}
      },
      'stage_states': {},
      'queue_policies': [],
      'order_controls': {},
      'order_statuses': {},
      'frozen_orders_by_apparatus': {},
      'order_customers': {},
      'queue_action_controls': {
        apparatus: {'order': control('pending')}
      },
    });
    final inline = await decodeProductionMapQueueSnapshotPayload(source,
        backgroundThresholdCodeUnits: source.length + 1);
    final background = await decodeProductionMapQueueSnapshotPayload(source,
        backgroundThresholdCodeUnits: 0);
    expect(background.revision, inline.revision);
    expect(background.scope, 'worker-scope');
    expect(background.sequences, inline.sequences);
    expect(background.queueActionControls[apparatus]!['order']!.contractValid,
        isTrue);
  });

  test('colour delta installs state and authoritative controls atomically', () {
    final before = snapshot();
    final next = delta({
      'queue_states': nested('print_preflight'),
      'queue_action_controls':
          nested(control('print_preflight', trial: 'running')),
    }).applyTo(before);
    expect(next.queueStates[apparatus]!['order'], 'print_preflight');
    expect(
        next.queueActionControls[apparatus]!['order']!.printPreflight!
            .isRunning,
        isTrue);
    expect(
        next.queueActionControls[apparatus]!['order']!.allowedActions, isEmpty);
    expect(identical(next.maps, before.maps), isTrue);
    expect(before.queueStates[apparatus]!['order'], 'pending');
    expect(next.revision, 11);
  });

  test('passed colour carries server-owned start permission', () {
    final next = delta({
      'queue_states': nested('print_preflight'),
      'queue_action_controls':
          nested(control('print_preflight', trial: 'passed')),
    }).applyTo(snapshot());
    expect(
        next.queueActionControls[apparatus]!['order']!.allows('start'), isTrue);
  });

  test('cursor gap and server restart require resync', () {
    expect(() => delta({}, base: 9).applyTo(snapshot()),
        throwsA(isA<MobileApiException>()));
    expect(() => delta({}, epoch: 'restart').applyTo(snapshot()),
        throwsA(isA<MobileApiException>()));
  });

  test('contradictory queue state cannot install permissive controls', () {
    expect(
        () =>
            delta({'queue_states': nested('in_progress')}).applyTo(snapshot()),
        throwsA(isA<MobileApiException>()));
  });

  test('unknown state and protocol fields fail closed', () {
    expect(() => delta({'queue_states': nested('unknown')}).applyTo(snapshot()),
        throwsA(isA<MobileApiException>()));
    expect(
        () => delta({'unknown_field': {}}), throwsA(isA<MobileApiException>()));
  });

  test('removed permissions are removed rather than merged back', () {
    final next = delta({
      'queue_action_controls': {
        'scopes': {
          apparatus: {
            'upsert': {},
            'remove': ['order']
          }
        },
        'remove': [],
      }
    }).applyTo(snapshot());
    expect(next.queueActionControls[apparatus], isEmpty);
    expect(snapshot().queueActionControls[apparatus], isNotEmpty);
  });

  test('legacy colour response remains usable without control state', () {
    final response = AdminPrintPreflightResponse.fromJson({
      'hold': {
        'hold_id': 'hold',
        'idempotency_key': 'hold',
        'order_id': 'order',
        'apparatus': apparatus,
        'status': 'passed',
      }
    });
    expect(response.hold.isPassed, isTrue);
    expect(response.controlState, isNull);
  });
}
