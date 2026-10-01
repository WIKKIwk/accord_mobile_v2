part of 'admin_progress_qr_passport.dart';

List<AdminProgressQrSessionResources> _passportResources(
    AdminProgressQrReport report, Iterable<AdminProgressBatch> batches) {
  if (!report.hasScopedHistory) return const [];
  final ids = batches
      .map((batch) => batch.sessionId.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  return report.sessionResources
      .where((resource) => ids.contains(resource.sessionId))
      .toList();
}

String _passportMaterialName(AdminProgressQrMaterial material) {
  final name = _passportReadableText(material.itemName);
  final code = _passportReadableText(material.itemCode);
  final barcode = _passportReadableText(material.barcode);
  final title = name.isNotEmpty ? name : code;
  return [title, if (barcode != title) barcode]
      .where((value) => value.isNotEmpty)
      .join(' · ');
}

List<String> _passportMaterials(
        Iterable<AdminProgressQrSessionResources> resources) =>
    {
      for (final resource in resources)
        if (resource.rawMaterialsAvailable)
          for (final material in resource.rawMaterials)
            _passportMaterialName(material),
    }.where((name) => name.isNotEmpty).toList();

List<String> _passportPlateCodes(Iterable<AdminProgressBatch> batches,
    Iterable<AdminProgressQrSessionResources> resources) {
  // Persisted downstream QolipLineage describes the roll's plate context,
  // never plate use at the downstream apparatus.
  final codes = <String>{
    for (final resource in resources)
      if (resource.qolipAvailable)
        ...resource.qolipCodes.map(_passportReadableText),
  };
  for (final batch in batches) {
    final payload = batch.payloadJson;
    final list = payload['qolip_codes'];
    if (list != null &&
        (list is! List ||
            list.any((code) => code is! String || code.trim().isEmpty))) {
      continue;
    }
    if (list is List) {
      codes.addAll(list.cast<String>().map(_passportReadableText));
    }
    final primary = payload['qolip_code'];
    if (primary is String) codes.add(_passportReadableText(primary));
  }
  final normalized = <String, String>{};
  for (final code in codes.where((code) => code.isNotEmpty)) {
    normalized.putIfAbsent(code.toLowerCase(), () => code);
  }
  return normalized.values.toList();
}

List<ProgressQrPassportLine> _passportResourceLines(
  AdminProgressQrReport report,
  List<AdminProgressBatch> batches,
  AppLocalizations? l10n,
) {
  final resources = _passportResources(report, batches);
  final materials = _passportMaterials(resources);
  final plates = _passportPlateCodes(batches, resources);
  final missing = _passportText(l10n, 'worker.qr.history.resource_missing',
      'Tasdiqlangan ma’lumot qayd etilmagan');
  final sessions = batches
      .map((batch) => batch.sessionId.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final materialHistoryMissing = !report.hasScopedHistory ||
      batches.any((batch) => batch.sessionId.trim().isEmpty) ||
      sessions.any((id) => !resources.any((resource) =>
          resource.sessionId == id && resource.rawMaterialsAvailable));
  return [
    ProgressQrPassportLine(
      _passportText(
          l10n, 'worker.qr.history.materials', 'Ishlatilgan xomashyo'),
      materials.isEmpty ? missing : materials.join('; '),
    ),
    if (materials.isNotEmpty && materialHistoryMissing)
      ProgressQrPassportLine(
        _passportText(l10n, 'worker.wip.info.note', 'Izoh'),
        _passportText(l10n, 'worker.qr.history.materials_incomplete',
            'Ayrim bosqichlarning xomashyo ma’lumoti qayd etilmagan.'),
      ),
    ProgressQrPassportLine(
      _passportText(l10n, 'worker.qr.history.plates', 'Qolip (rulon tarixi)'),
      plates.isEmpty ? missing : plates.join(', '),
    ),
  ];
}

ProgressQrPassportLine? _passportMergeInputs(
  AdminProgressQrReport report,
  AdminProgressBatch batch,
  Map<String, int> stepNumbers,
  Map<String, String> apparatusNamesById,
  AppLocalizations? l10n,
) {
  if (!report.hasScopedHistory) return null;
  final batches = {
    for (final item in report.historyBatches) item.batchId.trim(): item,
    report.scannedBatch.batchId.trim(): report.scannedBatch,
  };
  final parents = {
    for (final edge in report.lineageEdges)
      if (edge.childBatchId == batch.batchId.trim() &&
          batches.containsKey(edge.parentBatchId))
        edge.parentBatchId,
  }.toList()
    ..sort((a, b) => (stepNumbers[a] ?? 0).compareTo(stepNumbers[b] ?? 0));
  if (parents.length < 2) return null;
  final inputs = <String>[];
  for (final id in parents) {
    final input = batches[id]!;
    final ancestors = <String>{};
    void visit(String id) {
      if (!ancestors.add(id)) return;
      for (final edge in report.lineageEdges) {
        if (edge.childBatchId == id &&
            batches.containsKey(edge.parentBatchId)) {
          visit(edge.parentBatchId);
        }
      }
    }

    visit(id);
    final sourceBatches = ancestors.map((id) => batches[id]!);
    final materials =
        _passportMaterials(_passportResources(report, sourceBatches));
    final name = _passportReadableText(input.labelItemName);
    inputs.add([
      '${stepNumbers[id]}. ${_passportApparatusLabel(input.apparatus, apparatusNamesById, l10n: l10n)}',
      if (name.isNotEmpty) name,
      materials.isEmpty
          ? _passportText(l10n, 'worker.qr.history.materials_missing',
              'Xomashyo ma’lumoti qayd etilmagan')
          : materials.join('; '),
    ].join(' — '));
  }
  return ProgressQrPassportLine(
    _passportText(
        l10n, 'worker.qr.history.merge_inputs', 'Birlashtirilgan kirishlar'),
    inputs.join('\n'),
  );
}

bool _passportMetreUnit(Object? unit) => const {
      'm',
      'metr',
      'meter',
      'metre',
      'meters',
      'metres',
      'м'
    }.contains(unit?.toString().trim().toLowerCase());

bool _passportMatchingLengthChange(
        AdminProgressBatchCorrectionRecord correction) =>
    [correction.oldValues, correction.newValues].every((values) =>
        _passportMetreUnit(values['uom']) &&
        values['produced_qty'] is num &&
        values['finished_goods_meter'] is num &&
        _sameValue(values['produced_qty'], values['finished_goods_meter']));
