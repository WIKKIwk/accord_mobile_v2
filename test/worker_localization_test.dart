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
      english.productionApparatusName('7 ta rangli bosma'),
      '7-color printing',
    );
    expect(
      english.productionText('worker.qr.report.product_passport'),
      'Product passport',
    );
  });
}
