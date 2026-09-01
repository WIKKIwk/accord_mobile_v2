import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker production text follows the selected locale', () {
    final uzbek = AppLocalizations(const Locale('uz'));
    final english = AppLocalizations(const Locale('en'));
    final russian = AppLocalizations(const Locale('ru'));

    expect(uzbek.productionText('worker.action.start'), 'Boshlash');
    expect(english.productionText('worker.action.start'), 'Start');
    expect(russian.productionText('worker.action.start'), 'Начать');
    expect(uzbek.productionText('worker.action.merge'), 'Merge');
    expect(
      uzbek.productionText(
        'worker.merge_state.current',
        values: const {'batch': 'wip-b'},
      ),
      'Joriy WIP: wip-b',
    );
    expect(
      uzbek.productionErrorMessage('merge_input_same'),
      'Bu WIP hozir ishlatilmoqda. Boshqa WIPni scan qiling',
    );
    expect(
      english.productionText('worker.action.complete'),
      'Complete job',
    );
    expect(
      english.productionText(
        'worker.queue.apparatus_count',
        values: {'count': 2},
      ),
      '2 machines',
    );
    expect(
      english.productionText('worker.qr.report.product_passport'),
      'Product passport',
    );
  });
}
