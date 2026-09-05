import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_mapping.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

AdminApparatus _apparatus(String name, String objectId) {
  return AdminApparatus(name: name, factoryMapObjectId: objectId);
}

void main() {
  test('resolves the exact instanced map object without grouping siblings', () {
    final first = _apparatus('Birinchi aparat', 'node:73:instance:0');
    final second = _apparatus('Ikkinchi aparat', 'node:73:instance:1');

    expect(
      resolveFactoryMapApparatus([first, second], 'node:73:instance:1'),
      same(second),
    );
    expect(
      resolveFactoryMapApparatus([first, second], 'node:73:instance:2'),
      isNull,
    );
  });

  test('does not reuse a legacy node binding for a new instance tap', () {
    final legacy = _apparatus('Legacy aparat', 'node:73');

    expect(
      resolveFactoryMapApparatus([legacy], 'node:73:instance:0'),
      isNull,
    );
    expect(
      hasLegacyFactoryMapBinding([legacy], 'node:73:instance:0'),
      isTrue,
    );
  });

  test('ignores malformed instance ids without a legacy object id', () {
    final unassigned = _apparatus('Unassigned aparat', '');

    expect(
      hasLegacyFactoryMapBinding([unassigned], ':instance:0'),
      isFalse,
    );
  });

  test('preserves the structured API error message for the map notice', () {
    const error = MobileApiException(
      code: 'aasx_integrity_failed',
      message: 'Aparat AASX ma’lumotlari tekshirilmadi (HTTP 500)',
      statusCode: 500,
    );

    expect(
      factoryMapLoadErrorMessage(error, 'Aparatlar yuklanmadi'),
      'Aparat AASX ma’lumotlari tekshirilmadi (HTTP 500)',
    );
  });

  test('canonicalFactoryMapObjectId maps only the verified arrow', () {
    expect(
      canonicalFactoryMapObjectId('node:33:instance:0'),
      'node:39:instance:0',
    );
    expect(
      canonicalFactoryMapObjectId('node:33'),
      'node:39',
    );
    // Roof, fins, plates, signs and machine panels stay separate objects.
    expect(
      canonicalFactoryMapObjectId('node:32:instance:0'),
      'node:32:instance:0',
    );
    expect(
      canonicalFactoryMapObjectId('node:34:instance:2'),
      'node:34:instance:2',
    );
    expect(
      canonicalFactoryMapObjectId('node:38:instance:0'),
      'node:38:instance:0',
    );
    expect(
      canonicalFactoryMapObjectId('node:90:instance:4'),
      'node:90:instance:4',
    );
    expect(
      canonicalFactoryMapObjectId('node:91:instance:0'),
      'node:91:instance:0',
    );
    expect(
      canonicalFactoryMapObjectId('node:36:instance:1'),
      'node:36:instance:1',
    );
    expect(
      canonicalFactoryMapObjectId('node:37'),
      'node:37',
    );
    expect(
      canonicalFactoryMapObjectId('node:39:instance:1'),
      'node:39:instance:1',
    );
    expect(
      canonicalFactoryMapObjectId('node:73:instance:0'),
      'node:73:instance:0',
    );
    expect(canonicalFactoryMapObjectId(''), '');
  });

  test('resolves apparatus when tapping overhead arrow instead of machine body', () {
    final apparatus = _apparatus('Pechat aparati', 'node:39:instance:0');

    // Tapping the arrow above instance 0 resolves to the apparatus
    expect(
      resolveFactoryMapApparatus([apparatus], 'node:33:instance:0'),
      same(apparatus),
    );

    // Tapping the arrow backing above instance 0 does NOT resolve: the fin
    // is a separate object, not the verified arrow.
    expect(
      resolveFactoryMapApparatus([apparatus], 'node:34:instance:0'),
      isNull,
    );

    // Tapping the arrow above instance 1 does NOT resolve to instance 0 apparatus
    expect(
      resolveFactoryMapApparatus([apparatus], 'node:33:instance:1'),
      isNull,
    );
  });

  test('resolves apparatus when machine body is tapped for legacy arrow binding', () {
    final apparatus = _apparatus('Legacy strelka boglangan aparat', 'node:33:instance:2');

    // Tapping the machine body resolves to the apparatus bound with the arrow ID
    expect(
      resolveFactoryMapApparatus([apparatus], 'node:39:instance:2'),
      same(apparatus),
    );

    // Tapping the arrow itself still resolves
    expect(
      resolveFactoryMapApparatus([apparatus], 'node:33:instance:2'),
      same(apparatus),
    );
  });

  test('unboundFactoryMapApparatus offers only active unattached items', () {
    final free = _apparatus('Bosh aparat', '');
    final blank = _apparatus('Probel', '   ');
    final bound = _apparatus('Ulangan aparat', 'node:19:instance:0');
    final retired =
        _apparatus('Eski aparat', '').copyWith(lifecycleState: 'retired');

    final result = unboundFactoryMapApparatus([bound, free, blank, retired]);

    expect(
      result.map((item) => item.name),
      ['Bosh aparat', 'Probel'],
    );
  });
}
