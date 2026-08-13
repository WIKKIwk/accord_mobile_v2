import 'dart:convert';

import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/production_map_models.dart';
import 'admin_progress_qr_passport.dart';

class AdminProgressQrScanPdf {
  const AdminProgressQrScanPdf._();

  static List<int> buildProgress(
    AdminProgressQrReport report, {
    AppLocalizations? l10n,
  }) {
    final passport = buildProgressQrPassport(report, l10n: l10n);
    final sections = <_PdfSection>[
      _PdfSection(
        _pdfText(l10n, 'worker.qr.report.product_status', 'Mahsulot holati'),
        [
          _field(
            _pdfText(l10n, 'worker.qr.report.status', 'Holati'),
            passport.status,
          ),
          if (passport.isOldQr)
            _pdfText(
              l10n,
              'worker.qr.report.old_qr_notice',
              'Skan qilingan QR oldingi bosqichniki. Quyida mahsulotning hozirgi holati berilgan.',
            ),
        ],
      ),
      if (passport.plan.isNotEmpty)
        _PdfSection(
          _pdfText(l10n, 'worker.qr.report.share_plan', 'Buyurtma rejasi'),
          [for (final line in passport.plan) line.sentence],
        ),
      if (passport.stages.isNotEmpty) ...[
        for (var index = 0; index < passport.stages.length; index++)
          _PdfSection(
            '${index + 1}. ${passport.stages[index].title}',
            [
              _field(
                _pdfText(l10n, 'worker.qr.report.status', 'Holati'),
                passport.stages[index].status,
              ),
              for (final line in passport.stages[index].lines) line.sentence,
            ],
          ),
      ],
      if (passport.corrections.isNotEmpty) ...[
        for (var index = 0; index < passport.corrections.length; index++)
          _PdfSection(
            _pdfText(
              l10n,
              'worker.qr.report.correction_item',
              'Tahrir ${index + 1}: ${passport.corrections[index].stage}',
              values: {
                'index': index + 1,
                'stage': passport.corrections[index].stage,
              },
            ),
            [
              _field(
                _pdfText(l10n, 'worker.qr.report.editor', 'Tahrir qilgan'),
                passport.corrections[index].editor,
              ),
              _field(
                _pdfText(l10n, 'worker.qr.report.time', 'Vaqt'),
                passport.corrections[index].time,
              ),
              _field(
                _pdfText(l10n, 'worker.qr.report.reason', 'Sabab'),
                passport.corrections[index].reason,
              ),
              for (final change in passport.corrections[index].changes)
                '${change.label}: ${change.before} -> ${change.after}',
            ],
          ),
      ],
      if (passport.issues.isNotEmpty) ...[
        for (var index = 0; index < passport.issues.length; index++)
          _PdfSection(
            _pdfText(
              l10n,
              'worker.qr.report.issue_item',
              'Muammo yoki o‘zgarish ${index + 1}',
              values: {'index': index + 1},
            ),
            [
              _field(
                _pdfText(l10n, 'worker.qr.report.stage', 'Bosqich'),
                passport.issues[index].title,
              ),
              _field(
                _pdfText(l10n, 'worker.qr.report.details', 'Tafsilot'),
                passport.issues[index].description,
              ),
              _field(
                _pdfText(l10n, 'worker.qr.report.time', 'Vaqt'),
                passport.issues[index].time,
              ),
            ],
          ),
      ],
    ];
    return _PdfDocument(
      title: _pdfText(
        l10n,
        'worker.qr.report.product_passport',
        'Mahsulot pasporti',
      ),
      subtitle: [
        if (passport.orderNumber.isNotEmpty)
          '${_pdfText(l10n, 'worker.qr.report.order', 'Zakaz')} ${passport.orderNumber}',
        passport.productName,
      ].where((value) => value.isNotEmpty).join(' • '),
      sections: sections,
      continuationLabel: _pdfText(l10n, 'worker.qr.report.continued', 'davomi'),
    ).build();
  }

  static List<int> buildRawMaterial(
    AdminRawMaterialLookup report, {
    AppLocalizations? l10n,
  }) {
    final sections = <_PdfSection>[
      _PdfSection(
        _pdfText(
          l10n,
          'worker.qr.report.material_about',
          'Homashyo ma’lumotlari',
        ),
        [
          _field(
            _pdfText(l10n, 'worker.qr.report.barcode', 'Barcode / QR'),
            report.barcode,
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.warehouse', 'Ombor'),
            report.warehouse,
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.item_code', 'Item code'),
            report.itemCode,
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.item_name', 'Item nomi'),
            report.itemName,
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.item_group', 'Guruh'),
            report.itemGroup,
          ),
          _field(
            _pdfText(l10n, 'worker.wip.info.quantity', 'Miqdor'),
            _number(report.qty),
          ),
          _field(
            _pdfText(l10n, 'worker.qr.passport.unit', 'O‘lchov birligi'),
            report.uom,
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.status', 'Holat'),
            _pdfRawMaterialStatusLabel(report.status, l10n),
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.reserved_order', 'Reserved order'),
            report.reservedOrderId,
          ),
          _field(
            _pdfText(l10n, 'worker.qr.report.receipt', 'Source receipt'),
            report.sourceReceiptId,
          ),
        ],
      ),
      if (report.assignment != null)
        _PdfSection(
          _pdfText(
            l10n,
            'worker.qr.report.assignment_section',
            'Orderga biriktirish',
          ),
          _assignmentLines(report.assignment!, l10n: l10n),
        ),
      if (report.order != null)
        _PdfSection(
          _pdfText(
            l10n,
            'worker.qr.report.assigned_order',
            'Biriktirilgan order',
          ),
          _orderLines(report.order, l10n: l10n),
        ),
      if (report.queueStates.isNotEmpty)
        _PdfSection(
          _pdfText(
            l10n,
            'worker.qr.report.queue_status',
            'Aparat navbat holatlari',
          ),
          _queueStateLinesForRaw(report, l10n: l10n),
        ),
      if (report.logs.isNotEmpty) ...[
        for (var index = 0; index < report.logs.length; index++)
          _PdfSection(
            _pdfText(
              l10n,
              'worker.qr.report.event_count',
              'Jarayon hodisasi ${index + 1}/${report.logs.length}',
              values: {'index': index + 1, 'count': report.logs.length},
            ),
            _logLines(report.logs[index], l10n: l10n),
          ),
      ],
    ];
    return _PdfDocument(
      title: _pdfText(
        l10n,
        'worker.qr.report.material_pdf_title',
        'Admin homashyo QR report',
      ),
      subtitle:
          report.itemName.trim().isNotEmpty ? report.itemName : report.itemCode,
      sections: sections,
      continuationLabel: _pdfText(l10n, 'worker.qr.report.continued', 'davomi'),
    ).build();
  }
}

class _PdfSection {
  const _PdfSection(this.title, this.lines);

  final String title;
  final List<String> lines;
}

List<String> _orderLines(
  ProductionMapDefinition? order, {
  AppLocalizations? l10n,
}) {
  if (order == null) {
    return [
      _field(
        _pdfText(l10n, 'worker.qr.report.order', 'Order'),
        'Order ma’lumotlari topilmadi',
      ),
    ];
  }
  return [
    _field(
      _pdfText(l10n, 'worker.qr.report.order_number', 'Buyurtma raqami'),
      order.orderNumber,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.product_code', 'Mahsulot kodi'),
      order.productCode,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.product', 'Mahsulot'),
      order.title,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.customer', 'Mijoz'),
      order.customerName,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.roll_count', 'Rulon soni'),
      order.rollCount == null ? '' : _number(order.rollCount!),
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.width', 'Eni, mm'),
      order.widthMm == null ? '' : _number(order.widthMm!),
    ),
    _field(
      _pdfText(
        l10n,
        'worker.qr.report.planned_weight',
        'Rejadagi og‘irlik, kg',
      ),
      order.orderKg == null ? '' : _number(order.orderKg!),
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.planned_length', 'Rejadagi uzunlik'),
      order.baseLength == null ? '' : _number(order.baseLength!),
    ),
  ];
}

List<String> _queueStateLinesForRaw(
  AdminRawMaterialLookup report, {
  AppLocalizations? l10n,
}) {
  return [
    for (final entry in report.queueStates.entries) ...[
      _field(
        _pdfText(l10n, 'worker.qr.report.assigned_machine', 'Aparat'),
        l10n?.productionApparatusName(entry.key) ?? entry.key,
      ),
      for (final state in entry.value.entries)
        _field('  ${state.key}', _pdfStateLabel(state.value, l10n)),
    ],
  ];
}

List<String> _assignmentLines(
  AdminRawMaterialAssignment assignment, {
  AppLocalizations? l10n,
}) {
  return [
    _field(
      _pdfText(l10n, 'worker.qr.report.order_id', 'Order ID'),
      assignment.orderId,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.assigned_machine', 'Aparat'),
      l10n?.productionApparatusName(assignment.apparatus) ??
          assignment.apparatus,
    ),
    _field(_pdfText(l10n, 'worker.qr.report.barcode', 'Barcode'),
        assignment.barcode),
    _field(_pdfText(l10n, 'worker.qr.report.item_code', 'Item code'),
        assignment.itemCode),
    _field(_pdfText(l10n, 'worker.qr.report.item_name', 'Item nomi'),
        assignment.itemName),
    _field(_pdfText(l10n, 'worker.qr.report.item_group', 'Guruh'),
        assignment.itemGroup),
    _field(
        _pdfText(l10n, 'worker.qr.report.assigned_by_ref', 'Biriktirgan ref'),
        assignment.assignedByRef),
    _field(
        _pdfText(l10n, 'worker.qr.report.assigned_by_name', 'Biriktirgan name'),
        assignment.assignedByName),
    _field(_pdfText(l10n, 'worker.qr.report.assigned_at', 'Biriktirilgan vaqt'),
        assignment.assignedAt),
    _field(
      _pdfText(l10n, 'worker.qr.report.stock_status', 'Stock status'),
      _pdfRawMaterialStatusLabel(assignment.stockStatus, l10n),
    ),
    _field(_pdfText(l10n, 'worker.qr.report.reserved_order', 'Reserved order'),
        assignment.reservedOrderId),
    _field(
        _pdfText(l10n, 'worker.qr.report.stock_warehouse', 'Stock warehouse'),
        assignment.stockWarehouse),
    _field(_pdfText(l10n, 'worker.qr.report.stock_quantity', 'Stock quantity'),
        _number(assignment.stockQty)),
    _field(_pdfText(l10n, 'worker.qr.passport.unit', 'Stock UOM'),
        assignment.stockUom),
    _field(
        _pdfText(
            l10n, 'worker.qr.report.received_quantity', 'Received quantity'),
        _number(assignment.receivedQty)),
    _field(
        _pdfText(
            l10n, 'worker.qr.report.consumed_quantity', 'Consumed quantity'),
        _number(assignment.consumedQty)),
    _field(
        _pdfText(
            l10n, 'worker.qr.report.remaining_quantity', 'Remaining quantity'),
        _number(assignment.remainingQty)),
  ];
}

List<String> _logLines(
  AdminProductionOrderLogEntry log, {
  AppLocalizations? l10n,
}) {
  final transfer = log.transfer;
  final freeze = log.freeze;
  return [
    _field(
      _pdfText(l10n, 'worker.qr.report.event_id', 'Event ID'),
      log.eventId,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.order_id', 'Order ID'),
      log.orderId,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.assigned_machine', 'Aparat'),
      l10n?.productionApparatusName(log.apparatus) ?? log.apparatus,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.action', 'Action'),
      _pdfActionLabel(log.action, l10n),
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.state_change', 'Holat o‘zgarishi'),
      '${_pdfStateLabel(log.fromState, l10n)} -> ${_pdfStateLabel(log.toState, l10n)}',
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.actor_role', 'Actor role'),
      log.actorRole,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.actor_ref', 'Actor ref'),
      log.actorRef,
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.actor_name', 'Actor name'),
      log.actorDisplayName,
    ),
    _field(_pdfText(l10n, 'worker.qr.report.time', 'Vaqt'),
        _unix(log.createdAtUnix)),
    _field(
      _pdfText(
        l10n,
        'worker.qr.report.completed_with_issue',
        'Muammo bilan tugagan',
      ),
      log.completedWithIssue ? (l10n?.yes ?? 'Ha') : (l10n?.no ?? 'Yo‘q'),
    ),
    _field(
      _pdfText(l10n, 'worker.qr.report.issue_note', 'Muammo izohi'),
      log.issueNote,
    ),
    if (transfer != null) ...[
      '${_pdfText(l10n, 'worker.qr.report.transfer_details', 'Apparat almashtirish ma’lumotlari')}:',
      _field(
        _pdfText(l10n, 'worker.qr.report.transfer_id', 'Transfer ID'),
        transfer.transferId,
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.from', 'Qayerdan'),
        l10n?.productionApparatusName(transfer.fromApparatus) ??
            transfer.fromApparatus,
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.to', 'Qayerga'),
        l10n?.productionApparatusName(transfer.toApparatus) ??
            transfer.toApparatus,
      ),
      _field(
          _pdfText(l10n, 'worker.qr.report.reason', 'Sabab'), transfer.reason),
      _field(
        _pdfText(l10n, 'worker.qr.report.session_id', 'Session ID'),
        transfer.sessionId,
      ),
      _field(
        _pdfText(
            l10n, 'worker.qr.report.progress_batch_id', 'Progress batch ID'),
        transfer.progressBatchId,
      ),
      _field(
        _pdfText(
            l10n, 'worker.qr.report.material_barcodes', 'Material barcodes'),
        transfer.materialBarcodes.join(', '),
      ),
    ],
    if (freeze != null) ...[
      '${_pdfText(l10n, 'worker.qr.report.freeze_details', 'Muzlatish ma’lumotlari')}:',
      _field(
        _pdfText(l10n, 'worker.qr.report.request_id', 'Request ID'),
        freeze.requestId,
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.freeze_status', 'Freeze status'),
        freeze.status,
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.target_session', 'Target session'),
        freeze.targetSessionId,
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.target_apparatus', 'Target apparatus'),
        l10n?.productionApparatusName(freeze.targetApparatus) ??
            freeze.targetApparatus,
      ),
      _field(
        _pdfText(
            l10n, 'worker.qr.report.target_worker_role', 'Target worker role'),
        freeze.targetWorkerRole,
      ),
      _field(
        _pdfText(
            l10n, 'worker.qr.report.target_worker_ref', 'Target worker ref'),
        freeze.targetWorkerRef,
      ),
      _field(
        _pdfText(
            l10n, 'worker.qr.report.target_worker_name', 'Target worker name'),
        freeze.targetWorkerDisplayName,
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.requested_at', 'Requested at'),
        _unix(freeze.requestedAtUnix),
      ),
      _field(
        _pdfText(l10n, 'worker.qr.report.transitioned_at', 'Transitioned at'),
        _unix(freeze.transitionedAtUnix),
      ),
    ],
  ];
}

String _pdfText(
  AppLocalizations? l10n,
  String key,
  String fallback, {
  Map<String, Object?> values = const <String, Object?>{},
}) {
  return l10n?.productionText(key, values: values) ?? fallback;
}

String _pdfStateLabel(String value, AppLocalizations? l10n) {
  final normalized = value.trim();
  final translation = switch (normalized) {
    'start' => ('worker.qr.status.started', 'Boshlandi'),
    'pause' => ('worker.action.pause', 'Pauza'),
    'detach_roll' || 'roll_detached' => (
        'worker.qr.status.roll_removed',
        'Rulon yechildi',
      ),
    'resume' => ('worker.qr.status.resumed', 'Davom etdi'),
    'complete' => ('worker.qr.status.finished', 'Tugadi'),
    'completed' => ('worker.qr.status.completed', 'Tugagan'),
    'pending' => ('worker.qr.status.waiting_start', 'Kutilmoqda'),
    'waiting' => ('worker.qr.status.waiting_work', 'Keyingi ishni kutmoqda'),
    'in_progress' || 'active' || 'in_use' => (
        'worker.qr.status.in_progress',
        'Jarayonda',
      ),
    'paused' => ('worker.qr.status.paused', 'Pauzada'),
    'processed' || 'consumed_by_next_stage' => (
        'worker.qr.status.used',
        'Keyingi bosqichda ishlatilgan',
      ),
    'free_wip' || 'finished_pending_acceptance' => (
        'worker.qr.status.waiting_stock',
        'Omborga topshirishni kutmoqda',
      ),
    'accepted_to_stock' => (
        'worker.qr.status.accepted_stock',
        'Omborga qabul qilingan',
      ),
    'waiting_next_stage' => (
        'worker.qr.status.waiting_next',
        'Keyingi bosqichni kutmoqda',
      ),
    _ => null,
  };
  if (translation == null) {
    return value;
  }
  return _pdfText(l10n, translation.$1, translation.$2);
}

String _pdfActionLabel(String value, AppLocalizations? l10n) {
  final translation = switch (value.trim()) {
    'start' => ('worker.qr.timeline.action.start', 'Bosqichdagi ish boshlandi'),
    'pause' => (
        'worker.qr.timeline.action.pause',
        'Bosqichdagi ish vaqtincha to‘xtatildi',
      ),
    'detach_roll' => (
        'worker.qr.timeline.action.detach_roll',
        'Rulon bosqichdan yechildi',
      ),
    'resume' => (
        'worker.qr.timeline.action.resume',
        'Bosqichdagi ish davom ettirildi',
      ),
    'roll_complete' => (
        'worker.qr.timeline.action.roll_complete',
        'Rulon yakunlandi',
      ),
    'complete' => (
        'worker.qr.timeline.action.complete',
        'Bosqichdagi ish yakunlandi',
      ),
    _ => null,
  };
  if (translation == null) {
    return value;
  }
  return _pdfText(l10n, translation.$1, translation.$2);
}

String _pdfRawMaterialStatusLabel(String value, AppLocalizations? l10n) {
  final translation = switch (value.trim()) {
    'available' => (
        'worker.qr.material.status_available',
        'Bu homashyo omborda mavjud',
      ),
    'in_use' => (
        'worker.qr.material.status_in_use',
        'Bu homashyo ishlab chiqarishda ishlatilmoqda',
      ),
    'consumed' => (
        'worker.qr.material.status_consumed',
        'Bu homashyo ishlatib bo‘lingan',
      ),
    'reserved' => (
        'worker.qr.material.status_reserved',
        'Bu homashyo order uchun band qilingan',
      ),
    _ => null,
  };
  if (translation == null) {
    return value;
  }
  return _pdfText(l10n, translation.$1, translation.$2);
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
    required this.continuationLabel,
  });

  final String title;
  final String subtitle;
  final List<_PdfSection> sections;
  final String continuationLabel;

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
          page.addSectionTitle(
            '${_asciiText(section.title)} (${_asciiText(continuationLabel)})',
          );
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
