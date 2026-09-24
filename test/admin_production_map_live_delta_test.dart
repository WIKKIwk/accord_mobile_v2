import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminProductionMapLiveDelta model tests', () {
    test('parses delta packet with move operation', () {
      final json = {
        'ok': true,
        'type': 'delta',
        'epoch': 'epoch_123',
        'apparatus': 'APP-01',
        'base_revision': 5,
        'revision': 6,
        'ops': [
          {
            'type': 'move',
            'id': 'ORD-42',
            'before_id': 'ORD-50',
            'after_id': 'ORD-30',
          }
        ],
        'version': 'v6_hash',
      };

      final delta = AdminProductionMapLiveDelta.fromJson(json);
      expect(delta.epoch, 'epoch_123');
      expect(delta.apparatus, 'APP-01');
      expect(delta.baseRevision, 5);
      expect(delta.revision, 6);
      expect(delta.version, 'v6_hash');
      expect(delta.ops.length, 1);

      final op = delta.ops.first;
      expect(op.type, 'move');
      expect(op.id, 'ORD-42');
      expect(op.beforeId, 'ORD-50');
      expect(op.afterId, 'ORD-30');
    });

    test('parses delta with canonical_apparatus_id fallback from replay API', () {
      final json = {
        'canonical_apparatus_id': 'APP-02',
        'base_revision': '10',
        'revision': '11',
        'event_type': 'delta',
        'ops': [
          {
            'type': 'move',
            'id': 'ORD-99',
            'after_id': null,
          }
        ],
      };

      final delta = AdminProductionMapLiveDelta.fromJson(json);
      expect(delta.apparatus, 'APP-02');
      expect(delta.baseRevision, 10);
      expect(delta.revision, 11);
      expect(delta.ops.length, 1);
      expect(delta.ops.first.id, 'ORD-99');
      expect(delta.ops.first.afterId, isNull);
    });
  });

  group('Delta queue reordering reducer algorithm', () {
    List<String> applyMove(List<String> list, AdminProductionMapDeltaOp op) {
      final result = List<String>.from(list);
      result.remove(op.id);
      if (op.afterId != null && op.afterId!.isNotEmpty) {
        final idx = result.indexOf(op.afterId!);
        if (idx != -1) {
          result.insert(idx + 1, op.id);
        } else {
          result.add(op.id);
        }
      } else if (op.beforeId != null && op.beforeId!.isNotEmpty) {
        final idx = result.indexOf(op.beforeId!);
        if (idx != -1) {
          result.insert(idx, op.id);
        } else {
          result.insert(0, op.id);
        }
      } else {
        result.insert(0, op.id);
      }
      return result;
    }

    test('move order to head when after_id and before_id are null', () {
      final initial = ['ORD-1', 'ORD-2', 'ORD-3', 'ORD-4'];
      final op = const AdminProductionMapDeltaOp(
        type: 'move',
        id: 'ORD-3',
      );
      final updated = applyMove(initial, op);
      expect(updated, ['ORD-3', 'ORD-1', 'ORD-2', 'ORD-4']);
    });

    test('move order after specified order', () {
      final initial = ['ORD-1', 'ORD-2', 'ORD-3', 'ORD-4'];
      final op = const AdminProductionMapDeltaOp(
        type: 'move',
        id: 'ORD-1',
        afterId: 'ORD-3',
      );
      final updated = applyMove(initial, op);
      expect(updated, ['ORD-2', 'ORD-3', 'ORD-1', 'ORD-4']);
    });

    test('move order before specified order', () {
      final initial = ['ORD-1', 'ORD-2', 'ORD-3', 'ORD-4'];
      final op = const AdminProductionMapDeltaOp(
        type: 'move',
        id: 'ORD-4',
        beforeId: 'ORD-2',
      );
      final updated = applyMove(initial, op);
      expect(updated, ['ORD-1', 'ORD-4', 'ORD-2', 'ORD-3']);
    });

    test('sequence of multiple move operations matches serial reducer', () {
      var queue = ['A', 'B', 'C', 'D', 'E'];

      // Move D after A -> [A, D, B, C, E]
      queue = applyMove(queue, const AdminProductionMapDeltaOp(type: 'move', id: 'D', afterId: 'A'));
      expect(queue, ['A', 'D', 'B', 'C', 'E']);

      // Move E to head -> [E, A, D, B, C]
      queue = applyMove(queue, const AdminProductionMapDeltaOp(type: 'move', id: 'E'));
      expect(queue, ['E', 'A', 'D', 'B', 'C']);

      // Move B after E -> [E, B, A, D, C]
      queue = applyMove(queue, const AdminProductionMapDeltaOp(type: 'move', id: 'B', afterId: 'E'));
      expect(queue, ['E', 'B', 'A', 'D', 'C']);
    });
  });
}
