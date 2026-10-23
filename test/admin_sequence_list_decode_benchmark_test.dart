import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

const _selected = 'apparatus:default:bench_0';
final _machines = [
  for (var i = 0; i < 8; i++) 'apparatus:default:bench_$i',
];

Map<String, Object?> _control(int stage) => {
      'state': 'pending',
      'allowed_actions': ['start'],
      'previous_stage': 'Oldingi bosqich',
      'previous_stage_ready': true,
      'stage_node_id': 'machine-$stage',
      'complete_requires_full_report': false,
      'stage_work': {
        'completed': false,
        'local_completed': false,
        'upstream_closed': false,
        'astatka_available': false,
        'astatka_required': false,
        'report_session_id': '',
        'upstream_title': ''
      },
      'last_worked_at_unix': 0,
      'rezka_output_report': null,
      'interaction': {
        'mode': 'fresh_start',
        'start_materials_mode': 'scan_required',
        'material_scan_required': true,
        'assigned_materials_display_only': true,
        'material_intake_allowed': false,
        'previous_wip_mode': 'not_required',
        'opening_wip_mode': 'not_required',
        'qolip_mode': 'scan_required'
      },
    };

Map<String, Object?> _policy(String apparatus) => {
      'apparatus_id': apparatus,
      'apparatus': 'Bosma apparati',
      'policy': 'strict_sequence',
      'locked': false,
      'reason': '',
    };

Map<String, Object?> _order(String id, int row) => {
      'map': {
        'id': id,
        'code': '${1000 + row}',
        'order_number': '${1000 + row}',
        'product_code': 'FILM-${1000 + row}',
        'title': 'Bosma plyonka buyurtmasi ${1000 + row}',
        'customer_name': 'Xaridor korxonasi ${row % 5}',
        'image_id': 'photo-$id',
        'roll_count': 8,
        'width_mm': 1250,
        'print_val_size_mm': 1300,
        'order_kg': 2500 + row,
        'base_length': 12000 + row,
        'nodes': [
          for (var node = 0; node < 16; node++)
            {
              'id':
                  node >= 4 && node < 12 ? 'machine-${node - 4}' : 'node-$node',
              'kind': node == 0
                  ? 'start'
                  : node == 15
                      ? 'end'
                      : node >= 4 && node < 12
                          ? 'apparatus'
                          : 'material',
              'title': node == 15
                  ? 'Tayyor mahsulot $row'
                  : 'Texnologik bosqich $node',
              'apparatus_id': node >= 4 && node < 12 ? _machines[node - 4] : '',
              'formula': null,
              'role_code': 'operator',
              'item_code': 'FILM-$node',
              'qty_formula': 'order_kg * (1 + waste_percent / 100)',
              'from_location': 'Warehouse A',
              'to_location': 'Production B',
              'x': node * 160.0,
              'y': 120.0 + (node % 3) * 80,
            },
        ],
        'edges': [
          for (var node = 0; node < 15; node++)
            {
              'from':
                  node >= 4 && node < 12 ? 'machine-${node - 4}' : 'node-$node',
              'to': node + 1 >= 4 && node + 1 < 12
                  ? 'machine-${node + 1 - 4}'
                  : 'node-${node + 1}',
            },
        ],
      },
      'program': {
        'map_id': id,
        'product_code': 'FILM-${1000 + row}',
        'operations': [
          for (var node = 1; node < 15; node++)
            {
              'order': node,
              'node_id':
                  node >= 4 && node < 12 ? 'machine-${node - 4}' : 'node-$node',
              'op_code': 'production_execute',
              'args': {
                'item_code': 'FILM-$node',
                'qty': 'order_kg * 1.05',
                'from_location': 'Warehouse A',
                'to_location': 'Production B'
              },
            }
        ],
      },
    };

(Map<String, Object?>, Map<String, Object?>) _fixtures() {
  final ids = [for (var row = 0; row < 20; row++) 'zakaz-${1000 + row}'];
  final shared = <String, Object?>{
    'ok': true,
    'epoch': 'benchmark-server',
    'rev': 41,
    'scope': 'benchmark-scope',
    'version': 'page-v41',
    'offset': 0,
    'total': 20,
    'next_cursor': null,
    'order_ids': ids,
    'sequence_positions': {
      for (var row = 0; row < ids.length; row++) ids[row]: row + 1
    },
  };
  final full = <String, Object?>{
    ...shared,
    'maps': [for (var row = 0; row < ids.length; row++) _order(ids[row], row)],
    'sequence_versions': {for (final machine in _machines) machine: 's41'},
    'sequence_revisions': {for (final machine in _machines) machine: 41},
    'sequences': {for (final machine in _machines) machine: ids},
    'visible_order_ids': {for (final machine in _machines) machine: ids},
    'queue_states': {
      for (final machine in _machines)
        machine: {for (final id in ids) id: 'pending'}
    },
    'queue_action_controls': {
      for (var machine = 0; machine < _machines.length; machine++)
        _machines[machine]: {for (final id in ids) id: _control(machine)}
    },
    'queue_policies': [for (final machine in _machines) _policy(machine)],
    'stage_states': {
      for (final id in ids)
        id: {
          for (var stage = 0; stage < 8; stage++) 'machine-$stage': 'pending'
        }
    },
    'order_statuses': {
      for (final id in ids)
        id: {
          'lifecycle_status': 'open',
          'order_status': 'pending',
          'work_status': 'pending',
          'flow_status': 'pending',
          'stock_status': 'pending',
          'completed_with_issue_count': 0
        }
    },
    'order_controls': {},
    'stage_order_controls': [],
    'order_customers': {
      for (var row = 0; row < ids.length; row++)
        ids[row]: 'Xaridor korxonasi ${row % 5}'
    },
    'frozen_orders_by_apparatus': {},
    'pending_orders': [],
    'calculation_templates': {},
  };
  final summary = <String, Object?>{
    ...shared,
    'projection': adminSequenceListProjection,
    'sequence_versions': {_selected: 's41'},
    'sequence_revisions': {_selected: 41},
    'queue_policies': [_policy(_selected)],
    'rows': {
      for (var row = 0; row < ids.length; row++)
        ids[row]: {
          'id': ids[row],
          'code': '${1000 + row}',
          'title': 'Bosma plyonka buyurtmasi ${1000 + row}',
          'customer_name': 'Xaridor korxonasi ${row % 5}',
          'image_id': 'photo-${ids[row]}',
          'queue_state': 'pending',
          'display_state': 'pending',
          'can_reorder': true,
          'frozen': false,
        }
    },
  };
  return (full, summary);
}

int _percentile(List<int> samples, double fraction) =>
    samples[((samples.length - 1) * fraction).round()];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('benchmark: equal twenty-row full and compact page decode', () async {
    final (fullWire, summaryWire) = _fixtures();
    final fullSource = jsonEncode(fullWire);
    final summarySource = jsonEncode(summaryWire);
    Future<AdminProductionOrderPage> decode(String source) =>
        AdminProductionOrderPage.fromPayload(source,
            // Compare codec CPU only; neither path starts/copies into an isolate.
            backgroundThresholdCodeUnits: source.length + 1);

    final full = await decode(fullSource);
    final summary = await decode(summarySource);
    expect(full.orderIds, summary.orderIds);
    for (final order in full.snapshot!.maps) {
      final row = summary.sequenceRows[order.map.id]!;
      expect(row.code, order.map.code);
      expect(row.title, order.map.title);
      expect(row.customerName, order.map.customerName);
      expect(row.queueState, full.snapshot!.queueStates[_selected]![row.id]);
    }
    expect(summary.snapshot, isNull);

    for (var warmup = 0; warmup < 30; warmup++) {
      await decode(fullSource);
      await decode(summarySource);
    }
    final fullTimes = <int>[];
    final summaryTimes = <int>[];
    Future<void> sample(String source, List<int> times) async {
      final watch = Stopwatch()..start();
      final page = await decode(source);
      watch.stop();
      times.add(watch.elapsedMicroseconds);
      expect(page.length, 20);
    }

    // Alternate ordering to reduce warmup/GC and scheduler bias between paths.
    for (var iteration = 0; iteration < 150; iteration++) {
      if (iteration.isEven) {
        await sample(fullSource, fullTimes);
        await sample(summarySource, summaryTimes);
      } else {
        await sample(summarySource, summaryTimes);
        await sample(fullSource, fullTimes);
      }
    }
    fullTimes.sort();
    summaryTimes.sort();
    final fullBytes = utf8.encode(fullSource).length;
    final summaryBytes = utf8.encode(summarySource).length;
    // Fixture and decoding correctness are assertions; elapsed timings are
    // reported, not a flaky cross-machine performance pass/fail threshold.
    expect(summaryBytes, lessThan(fullBytes));
    // ignore: avoid_print
    print(
        'admin_sequence_decode_benchmark environment=desktop_flutter_test_JIT '
        'rows=20 nodes=320 operations=280 machine_controls=160 samples=150 '
        'warmups=30 isolates=false full_raw_utf8_bytes=$fullBytes '
        'compact_raw_utf8_bytes=$summaryBytes '
        'raw_reduction_pct=${((1 - summaryBytes / fullBytes) * 100).toStringAsFixed(2)} '
        'full_median_us=${_percentile(fullTimes, .5)} '
        'full_p95_us=${_percentile(fullTimes, .95)} '
        'compact_median_us=${_percentile(summaryTimes, .5)} '
        'compact_p95_us=${_percentile(summaryTimes, .95)}');
  });
}
