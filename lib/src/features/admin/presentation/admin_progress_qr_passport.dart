import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';

class ProgressQrPassportLine {
  const ProgressQrPassportLine(this.label, this.value);

  final String label;
  final String value;

  String get sentence => '$label: $value';
}

class ProgressQrPassportStage {
  const ProgressQrPassportStage({
    required this.title,
    required this.status,
    required this.lines,
    required this.isCurrent,
  });

  final String title;
  final String status;
  final List<ProgressQrPassportLine> lines;
  final bool isCurrent;
}

class ProgressQrPassportChange {
  const ProgressQrPassportChange({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;
}

class ProgressQrPassportCorrection {
  const ProgressQrPassportCorrection({
    required this.stage,
    required this.editor,
    required this.time,
    required this.reason,
    required this.changes,
  });

  final String stage;
  final String editor;
  final String time;
  final String reason;
  final List<ProgressQrPassportChange> changes;
}

class ProgressQrPassportIssue {
  const ProgressQrPassportIssue({
    required this.title,
    required this.description,
    required this.time,
  });

  final String title;
  final String description;
  final String time;
}

class ProgressQrPassport {
  const ProgressQrPassport({
    required this.productName,
    required this.orderNumber,
    required this.status,
    required this.isOldQr,
    required this.plan,
    required this.stages,
    required this.corrections,
    required this.issues,
  });

  final String productName;
  final String orderNumber;
  final String status;
  final bool isOldQr;
  final List<ProgressQrPassportLine> plan;
  final List<ProgressQrPassportStage> stages;
  final List<ProgressQrPassportCorrection> corrections;
  final List<ProgressQrPassportIssue> issues;

  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln('MAHSULOT PASPORTI')
      ..writeln([
        if (orderNumber.isNotEmpty) 'Zakaz $orderNumber',
        productName,
      ].where((value) => value.isNotEmpty).join(' • '))
      ..writeln('Holati: $status');
    if (isOldQr) {
      buffer.writeln(
        'Eslatma: skan qilingan QR oldingi bosqichniki. Quyida mahsulotning hozirgi holati berilgan.',
      );
    }
    if (plan.isNotEmpty) {
      buffer.writeln('\nBUYURTMA REJASI');
      for (final line in plan) {
        buffer.writeln(line.sentence);
      }
    }
    if (stages.isNotEmpty) {
      buffer.writeln('\nISHLAB CHIQARISH BOSQICHLARI');
      for (var index = 0; index < stages.length; index++) {
        final stage = stages[index];
        buffer.writeln(
          '${index + 1}. ${stage.title}${stage.isCurrent ? ' (hozirgi bosqich)' : ''}',
        );
        if (stage.status.isNotEmpty) {
          buffer.writeln('Holati: ${stage.status}');
        }
        for (final line in stage.lines) {
          buffer.writeln(line.sentence);
        }
      }
    }
    if (corrections.isNotEmpty) {
      buffer.writeln('\nTAHRIRLAR');
      for (var index = 0; index < corrections.length; index++) {
        final correction = corrections[index];
        buffer.writeln('${index + 1}. ${correction.stage}');
        buffer.writeln('Tahrir qilgan: ${correction.editor}');
        if (correction.time.isNotEmpty) {
          buffer.writeln('Vaqt: ${correction.time}');
        }
        buffer.writeln('Sabab: ${correction.reason}');
        for (final change in correction.changes) {
          buffer.writeln(
            '${change.label}: ${change.before} → ${change.after}',
          );
        }
      }
    }
    if (issues.isNotEmpty) {
      buffer.writeln('\nMUAMMOLAR VA O‘ZGARISHLAR');
      for (var index = 0; index < issues.length; index++) {
        final issue = issues[index];
        buffer.writeln('${index + 1}. ${issue.title}: ${issue.description}');
        if (issue.time.isNotEmpty) {
          buffer.writeln('Vaqt: ${issue.time}');
        }
      }
    }
    return buffer.toString().trimRight();
  }
}

ProgressQrPassport buildProgressQrPassport(
  AdminProgressQrReport report, {
  AppLocalizations? l10n,
}) {
  final current = report.currentBatch ?? report.scannedBatch;
  final order = report.order;
  final rollCount = order?.rollCount;
  final widthMm = order?.widthMm;
  final orderKg = order?.orderKg;
  final baseLength = order?.baseLength;
  final batchesById = {
    for (final batch in report.progressBatches) batch.batchId.trim(): batch,
  };
  final orderedBatches = [...report.progressBatches];
  if (!orderedBatches.any(
    (batch) => batch.batchId.trim() == current.batchId.trim(),
  )) {
    orderedBatches.add(current);
  }
  orderedBatches.sort(
    (left, right) => _batchTime(left).compareTo(_batchTime(right)),
  );
  final corrections = [...report.corrections]..sort(
      (left, right) => left.createdAtUnix.compareTo(right.createdAtUnix),
    );
  return ProgressQrPassport(
    productName: order?.title.trim().isNotEmpty == true
        ? order!.title.trim()
        : current.labelItemName.trim(),
    orderNumber: order?.orderNumber.trim() ?? '',
    status: progressQrPassportStatus(
      workStatus: current.statusDetail.workStatus.isNotEmpty
          ? current.statusDetail.workStatus
          : current.status,
      flowStatus: current.statusDetail.flowStatus,
      wipStatus: current.wipStatus,
      l10n: l10n,
    ),
    isOldQr: report.isStale,
    plan: [
      if (order?.customerName.trim().isNotEmpty == true)
        ProgressQrPassportLine(
          _passportText(l10n, 'worker.qr.report.customer', 'Mijoz'),
          order!.customerName.trim(),
        ),
      if (rollCount != null && rollCount > 0)
        ProgressQrPassportLine(
          _passportText(
              l10n, 'worker.qr.passport.planned_rolls', 'Rejadagi rulonlar'),
          progressQrReadableQuantity(rollCount, 'ta'),
        ),
      if (widthMm != null && widthMm > 0)
        ProgressQrPassportLine(
          _passportText(
              l10n, 'worker.qr.passport.product_width', 'Mahsulot eni'),
          progressQrReadableQuantity(widthMm, 'mm'),
        ),
      if (orderKg != null && orderKg > 0)
        ProgressQrPassportLine(
          _passportText(
              l10n, 'worker.qr.report.planned_weight', 'Rejadagi og‘irlik'),
          progressQrReadableQuantity(orderKg, 'kg'),
        ),
      if (baseLength != null && baseLength > 0)
        ProgressQrPassportLine(
          _passportText(
              l10n, 'worker.qr.passport.planned_length', 'Rejadagi metraj'),
          progressQrReadableQuantity(baseLength, 'metr'),
        ),
    ],
    stages: [
      for (final batch in orderedBatches)
        _passportStage(
          batch,
          isCurrent: batch.batchId.trim() == current.batchId.trim(),
          l10n: l10n,
        ),
    ],
    corrections: [
      for (final correction in corrections)
        _passportCorrection(
          correction,
          batch: batchesById[correction.batchId.trim()],
          l10n: l10n,
        ),
    ],
    issues: _passportIssues(report.logs, l10n: l10n),
  );
}

int _batchTime(AdminProgressBatch batch) {
  if (batch.startedAtUnix > 0) {
    return batch.startedAtUnix;
  }
  return batch.completedAtUnix;
}

ProgressQrPassportStage _passportStage(
  AdminProgressBatch batch, {
  required bool isCurrent,
  AppLocalizations? l10n,
}) {
  final worker = batch.executorName.trim().isNotEmpty
      ? batch.executorName.trim()
      : batch.workerDisplayName.trim();
  final title = batch.apparatus.trim().isNotEmpty
      ? (l10n?.productionApparatusName(batch.apparatus) ??
          batch.apparatus.trim())
      : _passportText(l10n, 'worker.qr.passport.production_stage',
          'Ishlab chiqarish bosqichi');
  return ProgressQrPassportStage(
    title: batch.action.trim() == 'roll_complete'
        ? '$title — ${_passportText(l10n, 'worker.qr.passport.roll_complete', 'rulon yakuni')}'
        : title,
    status: progressQrPassportStatus(
      workStatus: batch.statusDetail.workStatus.isNotEmpty
          ? batch.statusDetail.workStatus
          : batch.status,
      flowStatus: batch.statusDetail.flowStatus,
      wipStatus: batch.wipStatus,
      l10n: l10n,
    ),
    isCurrent: isCurrent,
    lines: [
      if (worker.isNotEmpty)
        ProgressQrPassportLine(
          _passportText(l10n, 'worker.wip.info.worker', 'Bajargan'),
          worker,
        ),
      if (batch.startedAtUnix > 0)
        ProgressQrPassportLine(
          _passportText(l10n, 'worker.wip.info.started', 'Boshlangan'),
          formatUnixSecondsLocalDateTime(batch.startedAtUnix),
        ),
      if (batch.completedAtUnix > 0)
        ProgressQrPassportLine(
          _passportText(l10n, 'worker.wip.info.finished', 'Tugagan'),
          formatUnixSecondsLocalDateTime(batch.completedAtUnix),
        ),
      ProgressQrPassportLine(
        _passportText(l10n, 'worker.qr.passport.result', 'Natija'),
        progressQrReadableQuantity(batch.producedQty, batch.uom),
      ),
      ..._metricLines(batch, l10n: l10n),
      if (batch.nextApparatus.trim().isNotEmpty)
        ProgressQrPassportLine(
          _passportText(
              l10n, 'worker.wip.info.next_machine', 'Keyingi bosqich'),
          l10n?.productionApparatusName(batch.nextApparatus) ??
              batch.nextApparatus.trim(),
        ),
      if (batch.description.trim().isNotEmpty)
        ProgressQrPassportLine(
          _passportText(l10n, 'worker.wip.info.note', 'Izoh'),
          batch.description.trim(),
        ),
    ],
  );
}

List<ProgressQrPassportLine> _metricLines(
  AdminProgressBatch batch, {
  AppLocalizations? l10n,
}) {
  return [
    if (batch.returnInkKg != null)
      ProgressQrPassportLine(
        _passportText(
            l10n, 'worker.qr.passport.returned_ink', 'Qaytgan bo‘yoq'),
        progressQrReadableQuantity(batch.returnInkKg!, 'kg'),
      ),
    if (batch.laminationPrintLeftoverRolls != null)
      ProgressQrPassportLine(
        _passportText(
          l10n,
          'worker.qr.passport.returned_print_rolls',
          'Qaytgan bosma rulon',
        ),
        progressQrReadableQuantity(
          batch.laminationPrintLeftoverRolls!,
          'ta',
        ),
      ),
    if (batch.laminationFilmLeftoverRolls != null)
      ProgressQrPassportLine(
        _passportText(
          l10n,
          'worker.qr.passport.returned_film_rolls',
          'Qaytgan plyonka rulon',
        ),
        progressQrReadableQuantity(
          batch.laminationFilmLeftoverRolls!,
          'ta',
        ),
      ),
    if (batch.rezkaBosmaWaste != null)
      ProgressQrPassportLine(
        _passportText(
            l10n, 'worker.qr.passport.print_waste', 'Bosma chiqindisi'),
        progressQrReadableQuantity(batch.rezkaBosmaWaste!, 'kg'),
      ),
    if (batch.rezkaLaminationWaste != null)
      ProgressQrPassportLine(
        _passportText(
          l10n,
          'worker.qr.passport.lamination_waste',
          'Laminatsiya chiqindisi',
        ),
        progressQrReadableQuantity(batch.rezkaLaminationWaste!, 'kg'),
      ),
    if (batch.rezkaEdgeWaste != null)
      ProgressQrPassportLine(
        _passportText(l10n, 'worker.qr.passport.edge_waste', 'Chet chiqindisi'),
        progressQrReadableQuantity(batch.rezkaEdgeWaste!, 'kg'),
      ),
    if (batch.totalWaste != null)
      ProgressQrPassportLine(
        _passportText(l10n, 'worker.progress.qty.waste', 'Jami chiqindi'),
        progressQrReadableQuantity(batch.totalWaste!, 'kg'),
      ),
    if (batch.finishedGoodsKg != null)
      ProgressQrPassportLine(
        _passportText(
          l10n,
          'worker.qr.status.product_ready',
          'Tayyor mahsulot',
        ),
        progressQrReadableQuantity(batch.finishedGoodsKg!, 'kg'),
      ),
    if (batch.bobinaKg != null)
      ProgressQrPassportLine(
        _passportText(
            l10n, 'worker.qr.passport.bobbin_weight', 'Babina og‘irligi'),
        progressQrReadableQuantity(batch.bobinaKg!, 'kg'),
      ),
    if (batch.finishedGoodsMeter != null)
      ProgressQrPassportLine(
        _passportText(
          l10n,
          'worker.qr.passport.finished_length',
          'Tayyor mahsulot metraji',
        ),
        progressQrReadableQuantity(batch.finishedGoodsMeter!, 'metr'),
      ),
    if (batch.diameter != null)
      ProgressQrPassportLine(
        _passportText(l10n, 'worker.qr.passport.diameter', 'Diametr'),
        progressQrReadableQuantity(batch.diameter!, 'mm'),
      ),
  ];
}

ProgressQrPassportCorrection _passportCorrection(
  AdminProgressBatchCorrectionRecord correction, {
  required AdminProgressBatch? batch,
  AppLocalizations? l10n,
}) {
  return ProgressQrPassportCorrection(
    stage: batch?.apparatus.trim().isNotEmpty == true
        ? (l10n?.productionApparatusName(batch!.apparatus) ??
            batch!.apparatus.trim())
        : _passportText(
            l10n,
            'worker.qr.passport.production_data',
            'Ishlab chiqarish ma’lumoti',
          ),
    editor: correction.actorDisplayName.trim().isNotEmpty
        ? correction.actorDisplayName.trim()
        : _passportText(l10n, 'worker.wip.info.worker', 'Mas’ul xodim'),
    time: correction.createdAtUnix > 0
        ? formatUnixSecondsLocalDateTime(correction.createdAtUnix)
        : '',
    reason: correction.reason.trim().isNotEmpty
        ? correction.reason.trim()
        : _passportText(
            l10n, 'worker.qr.passport.reason_missing', 'Sabab ko‘rsatilmagan'),
    changes: progressQrCorrectionChanges(correction, l10n: l10n),
  );
}

List<ProgressQrPassportChange> progressQrCorrectionChanges(
  AdminProgressBatchCorrectionRecord correction, {
  AppLocalizations? l10n,
}) {
  const fields = <String>[
    'produced_qty',
    'uom',
    'diameter',
    'return_ink_kg',
    'lamination_print_leftover_rolls',
    'lamination_film_leftover_rolls',
    'rezka_bosma_waste',
    'rezka_lamination_waste',
    'rezka_edge_waste',
    'total_waste',
    'finished_goods_kg',
    'bobina_kg',
    'finished_goods_meter',
    'description',
  ];
  return [
    for (final field in fields)
      if (!_sameValue(
        correction.oldValues[field],
        correction.newValues[field],
      ))
        ProgressQrPassportChange(
          label: _fieldLabel(field, l10n: l10n),
          before: _correctionValue(
            field,
            correction.oldValues[field],
            correction.oldValues,
            l10n: l10n,
          ),
          after: _correctionValue(
            field,
            correction.newValues[field],
            correction.newValues,
            l10n: l10n,
          ),
        ),
  ];
}

List<ProgressQrPassportIssue> _passportIssues(
  List<AdminProductionOrderLogEntry> logs, {
  AppLocalizations? l10n,
}) {
  final issues = <ProgressQrPassportIssue>[];
  for (final log in logs) {
    final time = log.createdAtUnix > 0
        ? formatUnixSecondsLocalDateTime(log.createdAtUnix)
        : '';
    if (log.completedWithIssue && log.issueNote.trim().isNotEmpty) {
      issues.add(
        ProgressQrPassportIssue(
          title: log.apparatus.trim().isNotEmpty
              ? (l10n?.productionApparatusName(log.apparatus) ??
                  log.apparatus.trim())
              : _passportText(
                  l10n, 'worker.qr.passport.production', 'Ishlab chiqarish'),
          description: log.issueNote.trim(),
          time: time,
        ),
      );
    }
    final transfer = log.transfer;
    if (transfer != null && transfer.reason.trim().isNotEmpty) {
      issues.add(
        ProgressQrPassportIssue(
          title:
              '${l10n?.productionApparatusName(transfer.fromApparatus) ?? transfer.fromApparatus} → ${l10n?.productionApparatusName(transfer.toApparatus) ?? transfer.toApparatus}',
          description: _humanReason(transfer.reason, l10n: l10n),
          time: time,
        ),
      );
    }
  }
  return issues;
}

String progressQrPassportStatus({
  required String workStatus,
  required String flowStatus,
  required String wipStatus,
  AppLocalizations? l10n,
}) {
  final key = switch (flowStatus.trim()) {
    'free_wip' ||
    'finished_pending_acceptance' =>
      'worker.qr.status.completed_pending_stock',
    'accepted_to_stock' => 'worker.qr.status.accepted_stock',
    'waiting_next_stage' => 'worker.qr.status.waiting_next',
    'consumed_by_next_stage' => 'worker.qr.status.consumed_next',
    'in_progress' => 'worker.qr.status.in_progress',
    _ => switch (workStatus.trim()) {
        'completed' || 'complete' => 'worker.qr.status.completed',
        'paused' || 'pause' => 'worker.qr.status.paused',
        'active' ||
        'in_progress' ||
        'start' ||
        'resume' =>
          'worker.qr.status.in_progress',
        'pending' || 'waiting' => 'worker.qr.status.waiting_start',
        _ => switch (wipStatus.trim()) {
            'waiting' => 'worker.qr.status.waiting_work',
            'in_use' => 'worker.qr.status.in_progress',
            'processed' => 'worker.qr.status.used',
            _ => 'worker.qr.passport.status_missing',
          },
      },
  };
  return _passportText(l10n, key, _passportStatusFallback(key));
}

String progressQrReadableQuantity(double value, String unit) {
  final raw = formatQuantity(
    value,
    decimalPlaces: 2,
    trimTrailingZeros: true,
  );
  final parts = raw.split('.');
  final integer = parts.first;
  final grouped = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  final formatted = parts.length == 1 ? grouped : '$grouped.${parts.last}';
  return [formatted, unit.trim()].where((part) => part.isNotEmpty).join(' ');
}

bool _sameValue(Object? before, Object? after) {
  if (before is num && after is num) {
    return before.toDouble() == after.toDouble();
  }
  return before?.toString().trim() == after?.toString().trim();
}

String _fieldLabel(String field, {AppLocalizations? l10n}) {
  final key = switch (field) {
    'produced_qty' => 'worker.qr.passport.produced_quantity',
    'uom' => 'worker.qr.passport.unit',
    'diameter' => 'worker.qr.passport.diameter',
    'return_ink_kg' => 'worker.qr.passport.returned_ink',
    'lamination_print_leftover_rolls' =>
      'worker.qr.passport.returned_print_rolls',
    'lamination_film_leftover_rolls' =>
      'worker.qr.passport.returned_film_rolls',
    'rezka_bosma_waste' => 'worker.qr.passport.print_waste',
    'rezka_lamination_waste' => 'worker.qr.passport.lamination_waste',
    'rezka_edge_waste' => 'worker.qr.passport.edge_waste',
    'total_waste' => 'worker.progress.qty.waste',
    'finished_goods_kg' => 'worker.qr.passport.finished_weight',
    'bobina_kg' => 'worker.qr.passport.bobbin_weight',
    'finished_goods_meter' => 'worker.qr.passport.finished_length',
    'description' => 'worker.wip.info.note',
    _ => null,
  };
  if (key == null) {
    return field;
  }
  return _passportText(l10n, key, _fieldLabelFallback(field));
}

String _correctionValue(
  String field,
  Object? value,
  Map<String, dynamic> values, {
  AppLocalizations? l10n,
}) {
  if (value == null || value.toString().trim().isEmpty) {
    return _passportText(
      l10n,
      'worker.qr.report.not_entered',
      'kiritilmagan',
    );
  }
  if (value is num) {
    final unit = switch (field) {
      'produced_qty' => values['uom']?.toString().trim() ?? '',
      'lamination_print_leftover_rolls' ||
      'lamination_film_leftover_rolls' =>
        'ta',
      'finished_goods_meter' => 'metr',
      'diameter' => 'mm',
      'return_ink_kg' ||
      'rezka_bosma_waste' ||
      'rezka_lamination_waste' ||
      'rezka_edge_waste' ||
      'total_waste' ||
      'finished_goods_kg' ||
      'bobina_kg' =>
        'kg',
      _ => '',
    };
    return progressQrReadableQuantity(value.toDouble(), unit);
  }
  return value.toString().trim();
}

String _humanReason(String value, {AppLocalizations? l10n}) {
  final reason = value.trim();
  final key = switch (reason) {
    'apparatus_issue' => 'worker.qr.reason.apparatus_issue',
    'worker_issue' => 'worker.qr.reason.worker_issue',
    'material_issue' => 'worker.qr.reason.material_issue',
    'quality_issue' => 'worker.qr.reason.quality_issue',
    'other' => 'worker.qr.reason.other',
    _ => null,
  };
  if (key != null) {
    return _passportText(l10n, key, _humanReasonFallback(reason));
  }
  return reason.replaceAll('_', ' ');
}

String _passportText(
  AppLocalizations? l10n,
  String key,
  String fallback, {
  Map<String, Object?> values = const {},
}) {
  return l10n?.productionText(key, values: values) ?? fallback;
}

String _passportStatusFallback(String key) {
  return switch (key) {
    'worker.qr.status.completed_pending_stock' =>
      'Ishlab chiqarish tugagan, omborga topshirishni kutmoqda',
    'worker.qr.status.accepted_stock' => 'Omborga qabul qilingan',
    'worker.qr.status.waiting_next' => 'Keyingi bosqichni kutmoqda',
    'worker.qr.status.consumed_next' => 'Keyingi bosqichda ishlatilgan',
    'worker.qr.status.in_progress' => 'Ish jarayonida',
    'worker.qr.status.completed' => 'Ish tugagan',
    'worker.qr.status.paused' => 'Ish vaqtincha to‘xtatilgan',
    'worker.qr.status.waiting_start' => 'Ish boshlanishini kutmoqda',
    'worker.qr.status.waiting_work' => 'Keyingi ishni kutmoqda',
    'worker.qr.status.used' => 'Keyingi bosqichda ishlatilgan',
    _ => 'Holat ko‘rsatilmagan',
  };
}

String _fieldLabelFallback(String field) {
  return switch (field) {
    'produced_qty' => 'Ishlab chiqarilgan miqdor',
    'uom' => 'O‘lchov birligi',
    'diameter' => 'Diametr',
    'return_ink_kg' => 'Qaytgan bo‘yoq',
    'lamination_print_leftover_rolls' => 'Qaytgan bosma rulon',
    'lamination_film_leftover_rolls' => 'Qaytgan plyonka rulon',
    'rezka_bosma_waste' => 'Bosma chiqindisi',
    'rezka_lamination_waste' => 'Laminatsiya chiqindisi',
    'rezka_edge_waste' => 'Chet chiqindisi',
    'total_waste' => 'Jami chiqindi',
    'finished_goods_kg' => 'Tayyor mahsulot og‘irligi',
    'bobina_kg' => 'Babina og‘irligi',
    'finished_goods_meter' => 'Tayyor mahsulot metraji',
    'description' => 'Izoh',
    _ => field,
  };
}

String _humanReasonFallback(String reason) {
  return switch (reason) {
    'apparatus_issue' =>
      'Aparatdagi nosozlik sababli boshqa apparatga o‘tkazilgan',
    'worker_issue' => 'Xodim bilan bog‘liq sabab',
    'material_issue' => 'Homashyo bilan bog‘liq sabab',
    'quality_issue' => 'Sifat bilan bog‘liq sabab',
    'other' => 'Boshqa sabab',
    _ => reason.replaceAll('_', ' '),
  };
}
