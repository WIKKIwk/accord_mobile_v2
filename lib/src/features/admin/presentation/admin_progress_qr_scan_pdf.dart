import 'dart:convert';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../models/production_map_models.dart';
import 'admin_progress_qr_passport.dart';

class AdminProgressQrScanPdf {
  const AdminProgressQrScanPdf._();

  static List<int> buildProgress(AdminProgressQrReport report) {
    final passport = buildProgressQrPassport(report);
    final sections = <_PdfSection>[
      _PdfSection('Mahsulot holati', [
        _field('Holati', passport.status),
        if (passport.isOldQr)
          'Skan qilingan QR oldingi bosqichniki. Quyida mahsulotning hozirgi holati berilgan.',
      ]),
      if (passport.plan.isNotEmpty)
        _PdfSection(
          'Buyurtma rejasi',
          [for (final line in passport.plan) line.sentence],
        ),
      if (passport.stages.isNotEmpty) ...[
        for (var index = 0; index < passport.stages.length; index++)
          _PdfSection(
            '${index + 1}. ${passport.stages[index].title}',
            [
              _field('Holati', passport.stages[index].status),
              for (final line in passport.stages[index].lines) line.sentence,
            ],
          ),
      ],
      if (passport.corrections.isNotEmpty) ...[
        for (var index = 0; index < passport.corrections.length; index++)
          _PdfSection(
            'Tahrir ${index + 1}: ${passport.corrections[index].stage}',
            [
              _field('Tahrir qilgan', passport.corrections[index].editor),
              _field('Vaqt', passport.corrections[index].time),
              _field('Sabab', passport.corrections[index].reason),
              for (final change in passport.corrections[index].changes)
                '${change.label}: ${change.before} -> ${change.after}',
            ],
          ),
      ],
      if (passport.issues.isNotEmpty) ...[
        for (var index = 0; index < passport.issues.length; index++)
          _PdfSection(
            'Muammo yoki o‘zgarish ${index + 1}',
            [
              _field('Bosqich', passport.issues[index].title),
              _field('Tafsilot', passport.issues[index].description),
              _field('Vaqt', passport.issues[index].time),
            ],
          ),
      ],
    ];
    return _PdfDocument(
      title: 'Mahsulot pasporti',
      subtitle: [
        if (passport.orderNumber.isNotEmpty) 'Zakaz ${passport.orderNumber}',
        passport.productName,
      ].where((value) => value.isNotEmpty).join(' • '),
      sections: sections,
    ).build();
  }

  static List<int> buildRawMaterial(AdminRawMaterialLookup report) {
    final sections = <_PdfSection>[
      _PdfSection('Homashyo ma’lumotlari', [
        _field('Barcode / QR', report.barcode),
        _field('Ombor', report.warehouse),
        _field('Item code', report.itemCode),
        _field('Item nomi', report.itemName),
        _field('Guruh', report.itemGroup),
        _field('Miqdor', _number(report.qty)),
        _field('O‘lchov birligi', report.uom),
        _field('Holat', report.status),
        _field('Reserved order', report.reservedOrderId),
        _field('Source receipt', report.sourceReceiptId),
      ]),
      if (report.assignment != null)
        _PdfSection(
          'Orderga biriktirish',
          _assignmentLines(report.assignment!),
        ),
      if (report.order != null)
        _PdfSection('Biriktirilgan order', _orderLines(report.order)),
      if (report.queueStates.isNotEmpty)
        _PdfSection(
          'Aparat navbat holatlari',
          _queueStateLinesForRaw(report),
        ),
      if (report.logs.isNotEmpty) ...[
        for (var index = 0; index < report.logs.length; index++)
          _PdfSection(
            'Jarayon hodisasi ${index + 1}/${report.logs.length}',
            _logLines(report.logs[index]),
          ),
      ],
    ];
    return _PdfDocument(
      title: 'Admin homashyo QR report',
      subtitle:
          report.itemName.trim().isNotEmpty ? report.itemName : report.itemCode,
      sections: sections,
    ).build();
  }
}

class _PdfSection {
  const _PdfSection(this.title, this.lines);

  final String title;
  final List<String> lines;
}

List<String> _orderLines(ProductionMapDefinition? order) {
  if (order == null) {
    return [_field('Order', 'Order ma’lumotlari topilmadi')];
  }
  return [
    _field('Buyurtma raqami', order.orderNumber),
    _field('Mahsulot kodi', order.productCode),
    _field('Mahsulot', order.title),
    _field('Mijoz', order.customerName),
    _field(
        'Rulon soni', order.rollCount == null ? '' : _number(order.rollCount!)),
    _field('Eni, mm', order.widthMm == null ? '' : _number(order.widthMm!)),
    _field('Rejadagi og‘irlik, kg',
        order.orderKg == null ? '' : _number(order.orderKg!)),
    _field('Rejadagi uzunlik',
        order.baseLength == null ? '' : _number(order.baseLength!)),
  ];
}

List<String> _queueStateLinesForRaw(AdminRawMaterialLookup report) {
  return [
    for (final entry in report.queueStates.entries) ...[
      'Aparat: ${entry.key}',
      for (final state in entry.value.entries)
        _field('  ${state.key}', state.value),
    ],
  ];
}

List<String> _assignmentLines(AdminRawMaterialAssignment assignment) {
  return [
    _field('Order ID', assignment.orderId),
    _field('Aparat', assignment.apparatus),
    _field('Barcode', assignment.barcode),
    _field('Item code', assignment.itemCode),
    _field('Item nomi', assignment.itemName),
    _field('Guruh', assignment.itemGroup),
    _field('Biriktirgan ref', assignment.assignedByRef),
    _field('Biriktirgan name', assignment.assignedByName),
    _field('Biriktirilgan vaqt', assignment.assignedAt),
    _field('Stock status', assignment.stockStatus),
    _field('Reserved order', assignment.reservedOrderId),
    _field('Stock warehouse', assignment.stockWarehouse),
    _field('Stock quantity', _number(assignment.stockQty)),
    _field('Stock UOM', assignment.stockUom),
    _field('Received quantity', _number(assignment.receivedQty)),
    _field('Consumed quantity', _number(assignment.consumedQty)),
    _field('Remaining quantity', _number(assignment.remainingQty)),
  ];
}

List<String> _logLines(AdminProductionOrderLogEntry log) {
  final transfer = log.transfer;
  final freeze = log.freeze;
  return [
    _field('Event ID', log.eventId),
    _field('Order ID', log.orderId),
    _field('Aparat', log.apparatus),
    _field('Action', log.action),
    _field('Holat o‘zgarishi', '${log.fromState} -> ${log.toState}'),
    _field('Actor role', log.actorRole),
    _field('Actor ref', log.actorRef),
    _field('Actor name', log.actorDisplayName),
    _field('Vaqt', _unix(log.createdAtUnix)),
    _field('Muammo bilan tugagan', log.completedWithIssue ? 'Ha' : 'Yo‘q'),
    _field('Muammo izohi', log.issueNote),
    if (transfer != null) ...[
      'Apparat almashtirish ma’lumotlari:',
      _field('Transfer ID', transfer.transferId),
      _field('Qayerdan', transfer.fromApparatus),
      _field('Qayerga', transfer.toApparatus),
      _field('Sabab', transfer.reason),
      _field('Session ID', transfer.sessionId),
      _field('Progress batch ID', transfer.progressBatchId),
      _field('Material barcode’lari', transfer.materialBarcodes.join(', ')),
    ],
    if (freeze != null) ...[
      'Muzlatish ma’lumotlari:',
      _field('Request ID', freeze.requestId),
      _field('Freeze status', freeze.status),
      _field('Target session', freeze.targetSessionId),
      _field('Target apparatus', freeze.targetApparatus),
      _field('Target worker role', freeze.targetWorkerRole),
      _field('Target worker ref', freeze.targetWorkerRef),
      _field('Target worker name', freeze.targetWorkerDisplayName),
      _field('Requested at', _unix(freeze.requestedAtUnix)),
      _field('Transitioned at', _unix(freeze.transitionedAtUnix)),
    ],
  ];
}

String _field(String label, String value) {
  final cleanLabel = label.trim();
  final cleanValue = value.trim();
  if (cleanLabel.isEmpty || cleanValue.isEmpty) {
    return '';
  }
  return '$cleanLabel: $cleanValue';
}

String _number(num value) {
  final asDouble = value.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return asDouble.toInt().toString();
  }
  return asDouble.toString();
}

String _unix(int value) {
  if (value <= 0) {
    return '';
  }
  return formatUnixSecondsLocalDateTime(value);
}

class _PdfDocument {
  _PdfDocument({
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final List<_PdfSection> sections;

  List<int> build() {
    final pages = <_PdfPage>[];
    var page = _PdfPage(title: title, subtitle: subtitle);
    pages.add(page);
    for (final section in sections) {
      final lines = section.lines
          .map(_asciiText)
          .where((line) => line.trim().isNotEmpty)
          .expand(_wrapPdfLine)
          .toList(growable: false);
      if (lines.isEmpty) {
        continue;
      }
      if (!page.canFit(34)) {
        page = _PdfPage(title: title, subtitle: subtitle);
        pages.add(page);
      }
      page.addSectionTitle(_asciiText(section.title));
      for (final line in lines) {
        if (!page.canFit(14)) {
          page = _PdfPage(title: title, subtitle: subtitle);
          pages.add(page);
          page.addSectionTitle('${_asciiText(section.title)} (davomi)');
        }
        page.addLine(line);
      }
      page.addSpacing(7);
    }

    for (var index = 0; index < pages.length; index++) {
      pages[index].finish(index + 1, pages.length);
    }
    return _serializePdf(pages);
  }
}

class _PdfPage {
  _PdfPage({required String title, required String subtitle})
      : _footerTitle = title,
        _stream = StringBuffer() {
    _stream.write('q 0.29 0.22 0.39 rg 0 772 595 70 re f Q\n');
    _text(title, x: 34, y: 813, size: 18, font: 'F2', color: '1 1 1');
    _text(
      subtitle.isEmpty ? 'Accord Mobile' : subtitle,
      x: 34,
      y: 793,
      size: 9,
      font: 'F1',
      color: '0.92 0.89 0.96',
    );
    _y = 748;
  }

  final String _footerTitle;
  final StringBuffer _stream;
  double _y = 748;

  bool canFit(double height) => _y - height >= 42;

  void addSectionTitle(String title) {
    _stream.write('q 0.95 0.93 0.97 rg 28 ${_y - 5} 539 25 re f Q\n');
    _text(title,
        x: 38, y: _y + 7, size: 10, font: 'F2', color: '0.29 0.22 0.39');
    _y -= 28;
  }

  void addLine(String line) {
    _text(line, x: 40, y: _y, size: 8.5, font: 'F1', color: '0.14 0.13 0.17');
    _y -= 13;
  }

  void addSpacing(double value) {
    _y -= value;
  }

  void finish(int pageNumber, int pageCount) {
    _stream.write('0.82 0.78 0.86 RG 34 34 527 0.6 re S\n');
    _text(
      'Accord Mobile • $_footerTitle • $pageNumber/$pageCount',
      x: 34,
      y: 23,
      size: 7.5,
      font: 'F1',
      color: '0.35 0.32 0.40',
    );
  }

  void _text(
    String value, {
    required double x,
    required double y,
    required double size,
    required String font,
    required String color,
  }) {
    _stream
      ..write('BT /$font $size Tf $color rg 1 0 0 1 $x $y Tm (')
      ..write(_escapePdfText(_asciiText(value)))
      ..write(') Tj ET\n');
  }
}

List<String> _wrapPdfLine(String line) {
  final trimmed = line.trimRight();
  if (trimmed.isEmpty) {
    return const [''];
  }
  const maxChars = 105;
  final result = <String>[];
  var remaining = trimmed;
  while (remaining.length > maxChars) {
    var splitAt = remaining.lastIndexOf(' ', maxChars);
    if (splitAt < 40) {
      splitAt = maxChars;
    }
    result.add(remaining.substring(0, splitAt).trimRight());
    remaining = remaining.substring(splitAt).trimLeft();
  }
  result.add(remaining);
  return result;
}

String _asciiText(String value) {
  const transliteration = <String, String>{
    'А': 'A',
    'Б': 'B',
    'В': 'V',
    'Г': 'G',
    'Д': 'D',
    'Е': 'E',
    'Ё': 'Yo',
    'Ж': 'Zh',
    'З': 'Z',
    'И': 'I',
    'Й': 'Y',
    'К': 'K',
    'Л': 'L',
    'М': 'M',
    'Н': 'N',
    'О': 'O',
    'П': 'P',
    'Р': 'R',
    'С': 'S',
    'Т': 'T',
    'У': 'U',
    'Ф': 'F',
    'Х': 'Kh',
    'Ц': 'Ts',
    'Ч': 'Ch',
    'Ш': 'Sh',
    'Щ': 'Shch',
    'Ъ': '',
    'Ы': 'Y',
    'Ь': '',
    'Э': 'E',
    'Ю': 'Yu',
    'Я': 'Ya',
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ё': 'yo',
    'ж': 'zh',
    'з': 'z',
    'и': 'i',
    'й': 'y',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'kh',
    'ц': 'ts',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'shch',
    'ъ': '',
    'ы': 'y',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
    'Қ': 'Q',
    'Ғ': 'G',
    'Ў': 'O',
    'Ҳ': 'H',
    'қ': 'q',
    'ғ': 'g',
    'ў': 'o',
    'ҳ': 'h',
  };
  final buffer = StringBuffer();
  for (final codePoint in value.replaceAll('\t', ' ').runes) {
    final char = String.fromCharCode(codePoint);
    final mapped = transliteration[char];
    if (mapped != null) {
      buffer.write(mapped);
      continue;
    }
    switch (char) {
      case '‘':
      case '’':
      case '′':
        buffer.write("'");
      case '“':
      case '”':
        buffer.write('"');
      case '–':
      case '—':
      case '→':
        buffer.write('-');
      case '•':
        buffer.write('*');
      case '№':
        buffer.write('No');
      default:
        final code = char.codeUnitAt(0);
        buffer.write(code >= 32 && code <= 126 ? char : '?');
    }
  }
  return buffer.toString();
}

String _escapePdfText(String value) {
  final buffer = StringBuffer();
  for (final codePoint in value.runes) {
    final char = String.fromCharCode(codePoint);
    switch (char) {
      case '\\':
      case '(':
      case ')':
        buffer
          ..write('\\')
          ..write(char);
      case '\n':
      case '\r':
        buffer.write(' ');
      default:
        buffer.write(char);
    }
  }
  return buffer.toString();
}

List<int> _serializePdf(List<_PdfPage> pages) {
  final objectCount = 4 + pages.length * 2;
  final objects = List<String>.filled(objectCount + 1, '');
  objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
  objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';
  objects[4] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>';
  final kids = <String>[];
  for (var index = 0; index < pages.length; index++) {
    final pageId = 5 + index * 2;
    final contentId = pageId + 1;
    final stream = pages[index]._stream.toString();
    objects[pageId] = '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentId 0 R >>';
    objects[contentId] =
        '<< /Length ${stream.length} >>\nstream\n$stream\nendstream';
    kids.add('$pageId 0 R');
  }
  objects[2] =
      '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>';

  final output = StringBuffer('%PDF-1.4\n');
  final offsets = List<int>.filled(objectCount + 1, 0);
  for (var id = 1; id <= objectCount; id++) {
    offsets[id] = output.length;
    output.write('$id 0 obj\n${objects[id]}\nendobj\n');
  }
  final xrefOffset = output.length;
  output.write('xref\n0 ${objectCount + 1}\n');
  output.write('0000000000 65535 f \n');
  for (var id = 1; id <= objectCount; id++) {
    output.write('${offsets[id].toString().padLeft(10, '0')} 00000 n \n');
  }
  output.write(
    'trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\n'
    'startxref\n$xrefOffset\n%%EOF\n',
  );
  return utf8.encode(output.toString());
}
