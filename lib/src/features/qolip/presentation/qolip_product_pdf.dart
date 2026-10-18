import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/localization/app_localizations.dart';
import '../../shared/models/app_models.dart';

/// A product-to-tooling register: the catalog product identifier, physical mold
/// identifiers, their properties and existing set associations stay separate.
/// This preserves the ISA-95 distinction between material and physical assets;
/// the PDF is a human-readable report, not an IEC 62264 interchange message.
abstract final class QolipProductPdf {
  static Future<Uint8List> build({
    required String productCode,
    required String productName,
    required List<QolipProduct> molds,
    required AppLocalizations l10n,
    DateTime? exportedAt,
  }) async {
    if (productCode.trim().isEmpty ||
        molds.isEmpty ||
        molds.any((mold) =>
            mold.qolipCode.trim().isEmpty ||
            mold.code.trim().toLowerCase() !=
                productCode.trim().toLowerCase())) {
      throw ArgumentError('Expected molds for one exact catalog product');
    }
    final baseFont = pw.Font.ttf(await rootBundle
        .load('assets/fonts/google_sans/GoogleSans-Regular.ttf'));
    final boldFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/google_sans/GoogleSans-Bold.ttf'));
    final arabicFont = pw.Font.ttf(await rootBundle
        .load('assets/fonts/noto_naskh_arabic/NotoNaskhArabic.ttf'));
    final logoData =
        await rootBundle.load('assets/branding/accord_pdf_wordmark.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List(
      logoData.offsetInBytes,
      logoData.lengthInBytes,
    ));
    final title = l10n.qolipProductPdfText('title');
    final name = productName.trim().isEmpty ? productCode : productName;
    final date = (exportedAt ?? DateTime.now()).toUtc();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final timestamp = '${twoDigits(date.day)}.${twoDigits(date.month)}.'
        '${date.year}  ${twoDigits(date.hour)}:${twoDigits(date.minute)} UTC';
    final document = pw.Document(
      title: '$name — $title',
      author: 'Accord',
      creator: 'Accord Mobile',
      subject: '$title · $productCode',
      theme: pw.ThemeData.withFont(
        base: l10n.isUrdu ? arabicFont : baseFont,
        bold: l10n.isUrdu ? arabicFont : boldFont,
        fontFallback: [arabicFont, baseFont],
      ),
    );
    const ink = PdfColor.fromInt(0xFF24354D);
    const muted = PdfColor.fromInt(0xFF657185);
    const rule = PdfColor.fromInt(0xFFDCE1E8);
    const tint = PdfColor.fromInt(0xFFF3F5F8);
    final regularMolds = molds.where((mold) => !mold.isExtension).toList()
      ..sort((a, b) {
        final setOrder = a.setId.compareTo(b.setId);
        return setOrder != 0 ? setOrder : a.qolipCode.compareTo(b.qolipCode);
      });
    final groups = <String, List<QolipProduct>>{};
    for (final mold in regularMolds) {
      groups.putIfAbsent(mold.setId, () => []).add(mold);
    }
    final additional = molds.where((mold) => mold.isExtension).toList()
      ..sort((a, b) => a.qolipCode.compareTo(b.qolipCode));
    // Extension membership is distinct from an existing physical set ID.
    final sections = <({String? setId, List<QolipProduct> molds})>[
      for (final entry in groups.entries)
        (setId: entry.key, molds: entry.value),
      if (additional.isNotEmpty) (setId: null, molds: additional),
    ];

    pw.Widget cell(String text,
        {bool heading = false, bool code = false, bool identifier = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: pw.Directionality(
          textDirection: code || identifier || !l10n.isUrdu
              ? pw.TextDirection.ltr
              : pw.TextDirection.rtl,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: code ? boldFont : null,
              fontSize: heading ? 8 : 10,
              fontWeight:
                  heading || code ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: heading ? muted : ink,
            ),
          ),
        ),
      );
    }

    final content = <pw.Widget>[
      pw.SizedBox(height: 24),
      pw.Text(name,
          style: pw.TextStyle(
              fontSize: 21, fontWeight: pw.FontWeight.bold, color: ink)),
      pw.SizedBox(height: 16),
      pw.Wrap(
        spacing: 28,
        runSpacing: 12,
        children: [
          for (final field in [
            (l10n.qolipProductPdfText('product_code'), productCode),
            (l10n.qolipProductPdfText('total'), molds.length.toString()),
          ])
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(field.$1,
                    style: const pw.TextStyle(fontSize: 8, color: muted)),
                pw.SizedBox(height: 4),
                pw.Text(field.$2,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: ink)),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 28),
    ];
    var number = 0;
    for (final section in sections) {
      content.addAll([
        pw.NewPage(freeSpace: 100),
        pw.Text(
          section.setId == null
              ? l10n.qolipProductPdfText('additional')
              : '${l10n.qolipProductPdfText('set_id')}: ${section.setId}',
          style: const pw.TextStyle(fontSize: 8, color: muted),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: pw.FixedColumnWidth(24 + molds.length.toString().length * 6),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.7),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: rule, width: 0.5),
            bottom: pw.BorderSide(color: rule, width: 0.5),
          ),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: tint),
              children: [
                cell('#', heading: true),
                cell(l10n.qolipProductPdfText('code'), heading: true),
                cell(l10n.qolipProductPdfText('size'), heading: true),
                cell(l10n.qolipProductPdfText('color'), heading: true),
              ],
            ),
            for (final mold in section.molds)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  cell((++number).toString(), identifier: true),
                  cell(mold.qolipCode, code: true),
                  cell(mold.qolipSize > 0 ? mold.qolipSize.toString() : '—',
                      identifier: true),
                  cell(mold.qolipColor.trim().isEmpty
                      ? '—'
                      : l10n.qolipColorName(mold.qolipColor)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 20),
      ]);
    }
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 32),
      maxPages: molds.length + 2,
      textDirection: l10n.isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 18),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: rule, width: 0.6)),
        ),
        child: pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // The transparent wordmark sits directly on the paper. Contain
              // preserves the original proportions and the full flourish.
              pw.Image(logo, width: 112, height: 38, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(title,
                        textAlign: pw.TextAlign.right,
                        textDirection: l10n.isUrdu
                            ? pw.TextDirection.rtl
                            : pw.TextDirection.ltr,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: ink)),
                    pw.SizedBox(height: 5),
                    pw.Text(timestamp,
                        style: const pw.TextStyle(fontSize: 8, color: muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: rule, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Accord MES · $productCode',
                style: const pw.TextStyle(fontSize: 8, color: muted)),
            pw.Text('${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      build: (_) => content,
    ));
    return document.save();
  }

  static String filename(String productName, String productCode) {
    var stem = (productName.trim().isEmpty ? productCode : productName)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '-')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'^[.\-]+|[.\-]+$'), '');
    stem = String.fromCharCodes(stem.runes.take(80));
    return 'qoliplar-${stem.isEmpty ? 'mahsulot' : stem}.pdf';
  }
}
