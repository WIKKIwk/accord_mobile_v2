import 'dart:convert';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../models/production_map_models.dart';

class AdminProgressQrScanPdf {
  const AdminProgressQrScanPdf._();

  static List<int> buildProgress(AdminProgressQrReport report) {
    final current = report.currentBatch ?? report.scannedBatch;
    final order = report.order;
    final sections = <_PdfSection>[
      _PdfSection(
        'QR holati',
        [
          _field('Holat', report.isStale ? 'Eski QR' : 'Hozirgi oqimga mos'),
          _field('Eski QR sababi', report.staleReason),
          _field('Scan qilingan batch', report.scannedBatch.batchId),
          _field('Scan qilingan QR', report.scannedBatch.qrPayload),
          _field('Hozirgi batch', current.batchId),
          _field('Hozirgi QR', current.qrPayload),
        ],
      ),
      _PdfSection('Buyurtma ma’lumotlari', _orderLines(order)),
      _PdfSection('Buyurtma holati', _orderStatusLines(report.orderStatus)),
      _PdfSection('Joriy progress batch', _batchLines(current)),
      if (report.progressBatches.isNotEmpty) ...[
        for (var index = 0; index < report.progressBatches.length; index++)
          _PdfSection(
            'Progress batch ${index + 1}/${report.progressBatches.length}',
            _batchLines(report.progressBatches[index]),
          ),
      ],
      if (report.openedBy != null)
        _PdfSection('QR ochilgan ma’lumot', _openedByLines(report.openedBy!)),
      if (report.runSessions.isNotEmpty) ...[
        for (var index = 0; index < report.runSessions.length; index++)
          _PdfSection(
            'Ish sessiyasi ${index + 1}/${report.runSessions.length}',
            _sessionLines(report.runSessions[index]),
          ),
      ],
      if (report.activeSessions.isNotEmpty)
        _PdfSection(
          'Hozir faol sessiyalar',
          [
            for (final session in report.activeSessions)
              ..._sessionLines(session),
          ],
        ),
      if (report.queueStates.isNotEmpty)
        _PdfSection('Aparat navbat holatlari', _queueStateLines(report)),
      if (report.logs.isNotEmpty) ...[
        for (var index = 0; index < report.logs.length; index++)
          _PdfSection(
            'Jarayon hodisasi ${index + 1}/${report.logs.length}',
            _logLines(report.logs[index]),
          ),
      ],
    ];
    return _PdfDocument(
      title: 'Admin QR report',
      subtitle: _progressSubtitle(report),
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
    _field('Order ID', order.id),
    _field('Order raqami', order.orderNumber),
    _field('Order code', order.code),
    _field('Product code', order.productCode),
    _field('Mahsulot', order.title),
    _field('Mijoz', order.customerName),
    _field(
        'Rulon soni', order.rollCount == null ? '' : _number(order.rollCount!)),
    _field('Eni, mm', order.widthMm == null ? '' : _number(order.widthMm!)),
    _field('Order og‘irligi, kg',
        order.orderKg == null ? '' : _number(order.orderKg!)),
    _field('Asosiy uzunlik',
        order.baseLength == null ? '' : _number(order.baseLength!)),
    _field('Map node soni', '${order.nodes.length}'),
    _field('Map edge soni', '${order.edges.length}'),
    if (order.nodes.isNotEmpty) ...[
      'Ishlab chiqarish map node’lari:',
      for (final node in order.nodes)
        _joinNonEmpty([
          node.title,
          if (node.kind.trim().isNotEmpty) 'kind=${node.kind}',
          if (node.roleCode.trim().isNotEmpty) 'role=${node.roleCode}',
          if (node.itemCode.trim().isNotEmpty) 'item=${node.itemCode}',
          if (node.fromLocation.trim().isNotEmpty) 'from=${node.fromLocation}',
          if (node.toLocation.trim().isNotEmpty) 'to=${node.toLocation}',
          if (node.alternativeGroupLabel.trim().isNotEmpty)
            'alternative=${node.alternativeGroupLabel}',
          if (node.formula != null &&
              node.formula!.expression.trim().isNotEmpty)
            'formula=${node.formula!.expression}',
        ]),
    ],
    if (order.edges.isNotEmpty) ...[
      'Map bog‘lanishlari:',
      for (final edge in order.edges)
        _joinNonEmpty([
          '${edge.from} -> ${edge.to}',
          if (edge.branch.trim().isNotEmpty) 'branch=${edge.branch}',
        ]),
    ],
  ];
}

List<String> _orderStatusLines(AdminProductionOrderStatusDetail status) {
  return [
    _field('Order holati', status.orderStatus),
    _field('Ish holati', status.workStatus),
    _field('Flow holati', status.flowStatus),
    _field('Stock holati', status.stockStatus),
    _field('Jami WIP', '${status.totalWipCount}'),
    _field('Waiting WIP', '${status.waitingWipCount}'),
    _field('In-use WIP', '${status.inUseWipCount}'),
    _field('Processed WIP', '${status.processedWipCount}'),
    _field(
        'Keyingi bosqichni kutayotgan WIP', '${status.waitingNextStageCount}'),
    _field(
        'Keyingi bosqich ishlatgan WIP', '${status.consumedByNextStageCount}'),
    _field('Erkin WIP', '${status.freeWipCount}'),
    _field('Omborga qabul qilingan WIP', '${status.acceptedWipCount}'),
    _field('Faol sessiyalar', '${status.activeSessionCount}'),
    _field('Pauzadagi sessiyalar', '${status.pausedSessionCount}'),
    _field('Tugagan navbat ishlari', '${status.completedQueueCount}'),
    _field('Muammo bilan tugagan ishlar', '${status.completedWithIssueCount}'),
  ];
}

List<String> _batchLines(AdminProgressBatch batch) {
  return [
    _field('Batch ID', batch.batchId),
    _field('Session ID', batch.sessionId),
    _field('QR payload', batch.qrPayload),
    _field('Order ID', batch.orderId),
    _field('Aparat', batch.apparatus),
    _field('Current apparatus', batch.currentApparatus),
    _field('Current apparatus key', batch.currentApparatusKey),
    _field('Current location', batch.currentLocation),
    _field('Next apparatus', batch.nextApparatus),
    _field('Action', batch.action),
    _field('Batch status', batch.status),
    _field('Work status', batch.statusDetail.workStatus),
    _field('WIP status', batch.wipStatus),
    _field('Flow status', batch.statusDetail.flowStatus),
    _field('Stock status', batch.statusDetail.stockStatus),
    _field('Produced quantity', _number(batch.producedQty)),
    _field('UOM', batch.uom),
    _field('Label item code', batch.labelItemCode),
    _field('Label item name', batch.labelItemName),
    _field('Executor', batch.executorName),
    _field('Worker role', batch.workerRole),
    _field('Worker ref', batch.workerRef),
    _field('Worker name', batch.workerDisplayName),
    _field('Started at', _unix(batch.startedAtUnix)),
    _field('Completed at', _unix(batch.completedAtUnix)),
    _field('Parent batch ID', batch.parentBatchId),
    _field('Used by session', batch.usedBySessionId),
    _field('Used by apparatus', batch.usedByApparatus),
    _field('Processed by session', batch.processedBySessionId),
    _field('Processed by apparatus', batch.processedByApparatus),
    _field('Return ink, kg', _optionalNumber(batch.returnInkKg)),
    _field('Lamination print leftover, rolls',
        _optionalNumber(batch.laminationPrintLeftoverRolls)),
    _field('Lamination film leftover, rolls',
        _optionalNumber(batch.laminationFilmLeftoverRolls)),
    _field('Rezka bosma waste, kg', _optionalNumber(batch.rezkaBosmaWaste)),
    _field('Rezka lamination waste, kg',
        _optionalNumber(batch.rezkaLaminationWaste)),
    _field('Rezka edge waste, kg', _optionalNumber(batch.rezkaEdgeWaste)),
    _field('Total waste, kg', _optionalNumber(batch.totalWaste)),
    _field('Finished goods, kg', _optionalNumber(batch.finishedGoodsKg)),
    _field('Finished goods, meter', _optionalNumber(batch.finishedGoodsMeter)),
    _field('Description', batch.description),
    ..._jsonLines('Payload JSON', batch.payloadJson),
  ];
}

List<String> _sessionLines(AdminWorkerRunSession session) {
  return [
    _field('Session ID', session.sessionId),
    _field('Order ID', session.orderId),
    _field('Aparat', session.apparatus),
    _field('Status', session.status),
    _field('Worker role', session.workerRole),
    _field('Worker ref', session.workerRef),
    _field('Worker name', session.workerDisplayName),
    _field('Started at', _unix(session.startedAtUnix)),
    _field('Updated at', _unix(session.updatedAtUnix)),
    ..._jsonLines('Payload JSON', session.payloadJson),
  ];
}

List<String> _openedByLines(AdminProgressQrOpenedBy openedBy) {
  return [
    _field('Actor role', openedBy.actorRole),
    _field('Actor ref', openedBy.actorRef),
    _field('Actor name', openedBy.actorDisplayName),
    _field('Opened at', _unix(openedBy.openedAtUnix)),
  ];
}

List<String> _queueStateLines(AdminProgressQrReport report) {
  return [
    for (final entry in report.queueStates.entries) ...[
      'Aparat: ${entry.key}',
      for (final state in entry.value.entries)
        _field('  ${state.key}', state.value),
    ],
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

List<String> _jsonLines(String label, Map<String, dynamic> value) {
  if (value.isEmpty) {
    return const [];
  }
  final encoded = const JsonEncoder.withIndent('  ').convert(value);
  return [label, ...encoded.split('\n')];
}

String _progressSubtitle(AdminProgressQrReport report) {
  final order = report.order;
  final title = order?.title.trim().isNotEmpty == true
      ? order!.title
      : report.scannedBatch.labelItemName;
  final number = order?.orderNumber.trim() ?? '';
  return [
    if (number.isNotEmpty) 'Zakaz $number',
    if (title.trim().isNotEmpty) title,
    if (report.scannedBatch.qrPayload.trim().isNotEmpty)
      'QR: ${report.scannedBatch.qrPayload}',
  ].join(' • ');
}

String _field(String label, String value) {
  final cleanLabel = label.trim();
  final cleanValue = value.trim();
  if (cleanLabel.isEmpty || cleanValue.isEmpty) {
    return '';
  }
  return '$cleanLabel: $cleanValue';
}

String _joinNonEmpty(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' • ');
}

String _number(num value) {
  final asDouble = value.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return asDouble.toInt().toString();
  }
  return asDouble.toString();
}

String _optionalNumber(num? value) => value == null ? '' : _number(value);

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
      : _stream = StringBuffer() {
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
      'Accord Mobile • Admin QR report • $pageNumber/$pageCount',
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
