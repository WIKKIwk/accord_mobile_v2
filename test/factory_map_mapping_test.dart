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
}
