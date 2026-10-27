import 'package:accord_mobile_v2/src/core/api/qolip/qolip_rework_request_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rework IDs remain unique and fit the backend request ID contract', () {
    final ids = <String>{};
    final format = RegExp(r'^qolip-rework-[0-9]+-[0-9a-f]{32}$');
    for (var index = 0; index < 10000; index++) {
      final id = newQolipReworkRequestId();
      expect(format.hasMatch(id), isTrue, reason: 'Unexpected request ID: $id');
      expect(id.length, lessThanOrEqualTo(128));
      expect(ids.add(id), isTrue, reason: 'Duplicate request ID: $id');
    }
    expect(ids, hasLength(10000));
  });
}
