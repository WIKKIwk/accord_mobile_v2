import 'package:accord_mobile_v2/src/features/boyoqchi/models/returned_paint_models.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/presentation/widgets/returned_paint_sheet.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/state/returned_paint_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    ReturnedPaintDraftStore.instance.resetMemoryForTest();
  });

  test('returned paint draft restores values, Pantones, tab and image',
      () async {
    const scope = 'worker:worker-1:order-1:7 ta rangli bosma';
    const image = ReturnedPaintImage(
      imageId: 'image-1',
      imageName: 'qoldiq.jpg',
      imageMime: 'image/jpeg',
      imageSizeBytes: 100,
      imageUrl: '/image-1',
    );
    final draft = await ReturnedPaintDraftStore.instance.load(scope: scope);

    draft.setValue('rasxot:Oq', 0, '12.5', 9);
    draft.addPantoneField('rasxot:Oq');
    draft.setValue('rasxot:Oq', 9, '3', 10);
    draft.selectedUsageIndex = 1;
    draft.setImage(image);
    await ReturnedPaintDraftStore.instance.flush(scope);
    ReturnedPaintDraftStore.instance.resetMemoryForTest();

    final restored = await ReturnedPaintDraftStore.instance.load(scope: scope);

    expect(restored.valuesFor('rasxot:Oq', 10)[0], '12.5');
    expect(restored.valuesFor('rasxot:Oq', 10)[9], '3');
    expect(
        restored.fieldLabelsFor('rasxot:Oq', const ['Mix']).last, 'Pantone 1');
    expect(restored.selectedUsageIndex, 1);
    expect(restored.image?.imageId, 'image-1');
  });

  test('returned paint draft rejects malformed or over-precision values',
      () async {
    final draft = await ReturnedPaintDraftStore.instance.load(
      scope: 'worker:worker-1:order-invalid:7 ta rangli bosma',
    );

    draft.setValue('rasxot:Oq', 0, '.', 9);
    expect(returnedPaintDraftHasInvalidValues(draft), isTrue);

    draft.setValue('rasxot:Oq', 0, '1.25', 9);
    expect(returnedPaintDraftHasInvalidValues(draft), isFalse);

    draft.setValue('rasxot:Oq', 0, '1.123456789012', 9);
    expect(returnedPaintDraftHasInvalidValues(draft), isTrue);
  });
}
