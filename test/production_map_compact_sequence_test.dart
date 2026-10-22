import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

const apparatus = 'apparatus:default:press';

// Independent BigInt reference verifies the portable two-limb production
// implementation against Rust's wrapping u64, including UTF-8 boundaries.
String fingerprint(List<String> ids) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final id in ids) {
    for (final byte in [...utf8.encode(id), 0xff]) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

AdminApparatusQueueSnapshot snapshot(List<String> ids) =>
    AdminApparatusQueueSnapshot(
      epoch: 'epoch',
      revision: 10,
      scope: 'scope',
      sequences: {apparatus: ids},
      visibleOrderIds: {apparatus: ids},
      queueStates: const {},
      queuePolicies: const {},
      orderControls: const {},
    );

Map<String, Object> edit(
        List<String> before, List<String> after, List<Object> ops) =>
    {
      'base_len': before.length,
      'base_hash': fingerprint(before),
      'len': after.length,
      'hash': fingerprint(after),
      'ops': ops,
    };

Map<String, Object> field(Map<String, Object> edit) => {
      'upsert': <String, Object>{},
      'remove': <String>[],
      'edit': {apparatus: edit},
    };

AdminProductionMapLiveStateDelta delta(Map<String, dynamic> patch,
        {String protocol = 'state_delta_v2'}) =>
    AdminProductionMapLiveStateDelta.fromJson({
      'epoch': 'epoch',
      'scope': 'scope',
      'base_rev': 10,
      'rev': 11,
      'protocol': protocol,
      'patch': patch,
    });

void main() {
  test('10000-ID move copies immutable ranges and preserves the old snapshot',
      () {
    final ids =
        List.generate(10000, (i) => 'order-${i.toString().padLeft(6, '0')}');
    final after = [...ids];
    after.insert(1, after.removeAt(9998));
    final operation = edit(ids, after, [
      [0, 0, 1],
      [0, 9998, 1],
      [0, 1, 9997],
      [0, 9999, 1],
    ]);
    final before = snapshot(ids);
    final next = delta({
      'sequences': field(operation),
      'visible_order_ids': field(operation)
    }).applyTo(before);
    expect(next.sequences[apparatus], after);
    expect(next.visibleOrderIds[apparatus], after);
    expect(next.revision, 11);
    expect(identical(before.sequences[apparatus], ids), isTrue);
    expect(before.sequences[apparatus]![1], 'order-000001');
    expect(before.revision, 10);
    expect(jsonEncode(operation).length, lessThan(200));
  });

  test('mixed reorder, removal and Unicode insertion matches Rust fingerprint',
      () {
    final ids = ['order-000000', 'ўзбек-😀'];
    expect(fingerprint(ids), '054688fb8e618984');
    final after = ['ўзбек-😀', 'yangi-😀'];
    final next = delta({
      'sequences': field(edit(ids, after, [
        [0, 1, 1],
        [
          1,
          ['yangi-😀']
        ],
      ]))
    }).applyTo(snapshot(ids));
    expect(next.sequences[apparatus], after);
  });

  test('legacy replacements and compact no-op preserve v1 compatibility', () {
    final before = snapshot(['a', 'b']);
    final legacy = delta({
      'sequences': {
        'upsert': {
          apparatus: ['b', 'a']
        },
        'remove': [],
      }
    }, protocol: 'state_delta_v1')
        .applyTo(before);
    expect(legacy.sequences[apparatus], ['b', 'a']);
    final unchanged = delta({}).applyTo(before);
    expect(identical(unchanged.sequences, before.sequences), isTrue);
    expect(unchanged.revision, 11);
    expect(
        () => delta({
              'sequences': field(edit([
                'a',
                'b'
              ], [
                'b',
                'a'
              ], [
                [0, 1, 1],
                [0, 0, 1],
              ]))
            }, protocol: 'state_delta_v1')
                .applyTo(before),
        throwsA(isA<MobileApiException>()));
  });

  final corruptions = <String, void Function(Map<String, Object>)>{
    'base length': (v) => v['base_len'] = 3,
    'base hash': (v) => v['base_hash'] = '0000000000000000',
    'result length': (v) => v['len'] = 3,
    'result hash': (v) => v['hash'] = '0000000000000000',
    'negative range': (v) => v['ops'] = [
          [0, -1, 2]
        ],
    'range overflow': (v) => v['ops'] = [
          [0, 1, 2]
        ],
    'zero range': (v) => v['ops'] = [
          [0, 0, 0]
        ],
    'duplicate identity': (v) => v['ops'] = [
          [0, 0, 1],
          [0, 0, 1]
        ],
    'unknown opcode': (v) => v['ops'] = [
          [2, 0, 2]
        ],
    'fractional range': (v) => v['ops'] = [
          [0, 0, 2.0]
        ],
    'empty insertion': (v) => v['ops'] = [
          [1, []]
        ],
    'empty ID': (v) => v['ops'] = [
          [
            1,
            ['', 'a']
          ]
        ],
  };
  for (final entry in corruptions.entries) {
    test('rejects ${entry.key} without partially mutating any field', () {
      final before = snapshot(['a', 'b']);
      final malformed = edit([
        'a',
        'b'
      ], [
        'b',
        'a'
      ], [
        [0, 1, 1],
        [0, 0, 1],
      ]);
      entry.value(malformed);
      expect(
          () => delta({
                'order_customers': {
                  'upsert': {'a': 'changed'},
                  'remove': []
                },
                'sequences': field(malformed),
              }).applyTo(before),
          throwsA(isA<MobileApiException>()));
      expect(before.orderCustomers, isEmpty);
      expect(before.sequences[apparatus], ['a', 'b']);
      expect(before.revision, 10);
    });
  }

  test('missing or same-length wrong baseline requires resync', () {
    final operation = field(edit([
      'a',
      'b'
    ], [
      'b',
      'a'
    ], [
      [0, 1, 1],
      [0, 0, 1],
    ]));
    final missing = const AdminApparatusQueueSnapshot(
      epoch: 'epoch',
      scope: 'scope',
      revision: 10,
      sequences: {},
      visibleOrderIds: {},
      queueStates: {},
      queuePolicies: {},
      orderControls: {},
    );
    expect(() => delta({'sequences': operation}).applyTo(missing),
        throwsA(isA<MobileApiException>()));
    expect(() => delta({'sequences': operation}).applyTo(snapshot(['b', 'a'])),
        throwsA(isA<MobileApiException>()));
  });

  test('overlapping remove, replace and edit fail closed', () {
    final operation = field(edit([
      'a',
      'b'
    ], [
      'b',
      'a'
    ], [
      [0, 1, 1],
      [0, 0, 1],
    ]));
    for (final bad in [
      {
        ...operation,
        'remove': [apparatus]
      },
      {
        ...operation,
        'upsert': {
          apparatus: ['a']
        }
      },
    ]) {
      expect(() => delta({'sequences': bad}).applyTo(snapshot(['a', 'b'])),
          throwsA(isA<MobileApiException>()));
    }
  });
}
