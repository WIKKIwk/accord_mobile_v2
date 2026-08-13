import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Qolip role uses complete production English copy', () {
    final english = AppLocalizations(const Locale('en'));

    expect(english.qolipText('nav.blocks'), 'Storage blocks');
    expect(english.qolipText('nav.ledger'), 'Mold checkout ledger');
    expect(
      english.qolipText(
        'home.issue_confirm_message',
        values: {'count': 2, 'worker': 'Alex'},
      ),
      'Issue 2 selected molds to Alex? One mold will be issued from each '
      'location.',
    );
    expect(
      english.qolipText(
        'transfer.moved',
        values: {'item': 'M-100', 'block': 'B', 'cell': 'C4'},
      ),
      'M-100 was moved to B / C4',
    );
    expect(english.qolipColorName('#E53935'), 'Red');
    expect(
      english.qolipErrorText(' BLOCK_IN_USE '),
      'This block has molds or outstanding checkouts and cannot be deleted',
    );
  });
}
