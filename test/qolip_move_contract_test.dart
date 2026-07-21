import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targetBlock = QolipBlock(name: 'B blok', warehouse: 'Qolip ombor');
  const source = QolipLocationEntry(
    id: 'source',
    block: 'A blok',
    warehouse: 'Qolip ombor',
    itemCode: 'ITEM-1',
    itemName: 'Qolip',
    qolipCode: 'Q-1',
    size: 44,
    quantity: 1,
    rowLetter: 'A',
    columnNumber: 1,
    locationLabel: 'A1',
  );

  test('old backend payload keeps moves inside the source block', () {
    final result = QolipBlocksResult.fromJson({
      'warehouses': ['Qolip ombor'],
      'blocks': [
        {'name': 'A blok', 'warehouse': 'Qolip ombor'},
        {'name': 'B blok', 'warehouse': 'Qolip ombor'},
      ],
    });

    final targets = qolipMoveTargetBlocks(
      blocks: result.blocks,
      source: source,
      supportsCrossBlockMove: result.supportsCrossBlockMove,
    );

    expect(result.supportsCrossBlockMove, isFalse);
    expect(targets.map((block) => block.name), orderedEquals(['A blok']));
  });

  test('new backend enables cross-block targets', () {
    final result = QolipBlocksResult.fromJson({
      'supports_cross_block_move': true,
      'warehouses': ['Qolip ombor'],
      'blocks': [
        {'name': 'A blok', 'warehouse': 'Qolip ombor'},
        {'name': 'B blok', 'warehouse': 'Qolip ombor'},
      ],
    });

    final targets = qolipMoveTargetBlocks(
      blocks: result.blocks,
      source: source,
      supportsCrossBlockMove: result.supportsCrossBlockMove,
    );

    expect(result.supportsCrossBlockMove, isTrue);
    expect(
      targets.map((block) => block.name),
      orderedEquals(['A blok', 'B blok']),
    );
  });

  test('stale backend response cannot be accepted as a cross-block move', () {
    const staleResponse = QolipLocationEntry(
      id: 'stale',
      block: 'A blok',
      warehouse: 'Qolip ombor',
      itemCode: 'ITEM-1',
      itemName: 'Qolip',
      qolipCode: 'Q-1',
      size: 44,
      quantity: 1,
      rowLetter: 'Z',
      columnNumber: 13,
      locationLabel: 'Z13',
    );
    const correctResponse = QolipLocationEntry(
      id: 'correct',
      block: 'B blok',
      warehouse: 'Qolip ombor',
      itemCode: 'ITEM-1',
      itemName: 'Qolip',
      qolipCode: 'Q-1',
      size: 44,
      quantity: 1,
      rowLetter: 'Z',
      columnNumber: 13,
      locationLabel: 'Z13',
    );

    expect(
      qolipMoveReachedTarget(
        moved: staleResponse,
        targetBlock: targetBlock,
        qolipCode: source.qolipCode,
        rowLetter: 'Z',
        columnNumber: 13,
      ),
      isFalse,
    );
    expect(
      qolipMoveReachedTarget(
        moved: correctResponse,
        targetBlock: targetBlock,
        qolipCode: source.qolipCode,
        rowLetter: 'Z',
        columnNumber: 13,
      ),
      isTrue,
    );
  });
}
