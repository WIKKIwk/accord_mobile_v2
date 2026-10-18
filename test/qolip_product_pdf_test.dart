import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_product_pdf.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final uz = AppLocalizations(const Locale('uz'));

  QolipProduct mold(int index, {String code = 'PRODUCT-001'}) => QolipProduct(
        code: code,
        name: 'O‘zbekcha mahsulot — Пакет',
        itemGroup: 'Tayyor mahsulot',
        qolipCode: 'MOLD-${index.toString().padLeft(4, '0')}',
        qolipSetId: 'set-${index ~/ 60}',
        qolipSize: 750,
        qolipColor: index.isEven ? '#E53935' : 'PANTON 12',
        isExtension: index == 179,
      );

  test('exports multiple complete sets and extensions across A4 pages',
      () async {
    final bytes = await QolipProductPdf.build(
      productCode: 'PRODUCT-001',
      productName: 'O‘zbekcha mahsulot — Пакет',
      molds: List.generate(180, mold),
      l10n: uz,
      exportedAt: DateTime.utc(2026, 10, 18, 8, 30),
    );
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(pdf.trimRight(), endsWith('%%EOF'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length,
        greaterThanOrEqualTo(5));
    // Embedded fonts and Unicode maps preserve original names and identifiers.
    expect(pdf, contains('/FontFile2'));
    expect(pdf, contains('/ToUnicode'));
  });

  test('rejects an empty or mixed-product register', () async {
    for (final molds in [
      <QolipProduct>[],
      [mold(1), mold(2, code: 'OTHER-PRODUCT')],
    ]) {
      await expectLater(
        QolipProductPdf.build(
          productCode: 'PRODUCT-001',
          productName: 'Product',
          molds: molds,
          l10n: uz,
        ),
        throwsArgumentError,
      );
    }
  });

  test('Urdu labels and names render with an embedded fallback font', () async {
    final bytes = await QolipProductPdf.build(
      productCode: 'PRODUCT-001',
      productName: 'مصنوعات کے سانچے',
      molds: [mold(1)],
      l10n: AppLocalizations(const Locale('ur', 'PK')),
    );
    expect(latin1.decode(bytes), contains('/FontFile2'));
  });

  test('share filenames preserve Unicode and cannot contain path separators',
      () {
    final filename = QolipProductPdf.filename('../Пакет / 20:26?*', 'PRODUCT');
    expect(filename, startsWith('qoliplar-'));
    expect(filename, endsWith('.pdf'));
    expect(filename, contains('Пакет'));
    expect(RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(filename), isFalse);
    expect(QolipProductPdf.filename('', ''), 'qoliplar-mahsulot.pdf');
    expect(QolipProductPdf.filename('a' * 200, 'PRODUCT').length,
        lessThanOrEqualTo(93));
  });
}
