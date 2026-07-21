import 'package:accord_mobile_v2/src/features/qolip/qolip_search_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const values = <String>[
    'Kross model',
    'ITEM-001',
    'Q-001',
    'Customer Iskandar',
  ];

  test('matches mixed Latin and Cyrillic text', () {
    expect(qolipSearchMatches('кrоss', values), isTrue);
    expect(qolipSearchMatches('кросс', values), isTrue);
  });

  test('matches inserted spaces and punctuation', () {
    expect(qolipSearchMatches('kr oss', values), isTrue);
    expect(qolipSearchMatches('Q 0-0 1', values), isTrue);
  });

  test('matches insertion, deletion, substitution and transposition typos', () {
    expect(qolipSearchMatches('krosss', values), isTrue);
    expect(qolipSearchMatches('kros', values), isTrue);
    expect(qolipSearchMatches('krass', values), isTrue);
    expect(qolipSearchMatches('korss', values), isTrue);
  });

  test('allows more than one typo only for longer words', () {
    expect(qolipSearchMatches('batimka', const ['Botinka']), isTrue);
    expect(qolipSearchMatches('drass', const ['Kross']), isFalse);
  });

  test('matches words in any order and across fields', () {
    expect(qolipSearchMatches('iskndar kroos', values), isTrue);
    expect(qolipSearchMatches('model kroos', values), isTrue);
  });

  test('recovers text entered with the wrong keyboard layout', () {
    expect(qolipSearchMatches('rhjcc', values), isTrue);
    expect(qolipSearchMatches('лкщыы', values), isTrue);
  });

  test('does not fuzzy-match very short or unrelated queries', () {
    expect(qolipSearchMatches('kr', values), isTrue);
    expect(qolipSearchMatches('ks', values), isFalse);
    expect(qolipSearchMatches('loafer', values), isFalse);
  });

  test('does not guess similar identifiers', () {
    expect(qolipSearchMatches('Q-002', values), isFalse);
    expect(qolipSearchMatches('ITEM-002', values), isFalse);
  });

  test('empty query keeps all values visible', () {
    expect(qolipSearchMatches('', const <String>[]), isTrue);
  });
}
