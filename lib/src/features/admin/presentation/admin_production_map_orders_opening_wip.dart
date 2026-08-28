part of 'admin_production_map_orders_screen.dart';

class AdminOpeningWipScreen extends StatefulWidget {
  const AdminOpeningWipScreen({
    super.key,
    this.progressDriverUrlPicker,
  });

  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<AdminOpeningWipScreen> createState() => _AdminOpeningWipScreenState();
}

class _AdminOpeningWipScreenState extends State<AdminOpeningWipScreen> {
  late Future<_OpeningWipPageData> _future;
  int _listRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OpeningWipPageData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminProductionMaps(),
      MobileApi.instance.adminApparatus(limit: 10000),
      MobileApi.instance.adminProductionMapQueueSnapshot(),
    ]);
    final orders = results[0] as List<ProductionMapSaved>;
    final apparatus = results[1] as List<AdminApparatus>;
    final snapshot = results[2] as AdminApparatusQueueSnapshot;
    return _OpeningWipPageData(
      orders: _openingWipEligibleOrders(
        orders: orders,
        stageStatesByOrderId: snapshot.stageStates,
      ),
      apparatus: apparatus,
      stageStatesByOrderId: snapshot.stageStates,
    );
  }

  Future<void> _reload() async {
    final nextFuture = _load();
    setState(() => _future = nextFuture);
    await nextFuture;
  }

  void _handleCreated() {
    if (!mounted) return;
    setState(() => _listRefreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: context.l10n.adminText('production.opening_wip.title'),
      selectedRouteName: AppRoutes.adminOpeningWip,
      activeTab: AdminDockTab.home,
      bottomDockFadeStrength: null,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<_OpeningWipPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: _reload);
            }
            final data = snapshot.data!;
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: const TabBar(
                      tabs: [
                        Tab(height: 38, text: 'Opening WIP'),
                        Tab(height: 38, text: 'WIP list'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OpeningWipWizard(
                          orders: data.orders,
                          apparatusCatalog: data.apparatus,
                          stageStatesByOrderId: data.stageStatesByOrderId,
                          progressDriverUrlPicker:
                              widget.progressDriverUrlPicker,
                          onCreated: _handleCreated,
                        ),
                        _OpeningWipListTab(
                          orders: data.orders,
                          apparatusCatalog: data.apparatus,
                          refreshToken: _listRefreshToken,
                          progressDriverUrlPicker:
                              widget.progressDriverUrlPicker,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

const int _openingWipListFetchLimit = 500;

Future<void> _printOpeningWipBatch({
  required AdminOpeningWipBatch batch,
  required _ProgressPrinterOption printer,
}) async {
  final result = await MobileApi.instance.adminPrintOpeningWip(
    batchId: batch.batchId,
    qrPayload: batch.qrPayload,
    driverUrl: printer.driverUrl,
    printer: printer.printer,
    printMode: printer.printMode,
    printCount: 1,
    printTransport: printer.transport,
  );
  if (!result.ok) {
    throw StateError(result.printStatus);
  }
  if (!printer.transport.isLocal) return;
  final printJob = result.printJob;
  if (printJob == null) {
    throw StateError('Opening WIP print job missing');
  }
  final localResult = await PrintService.printRps(
    printJob,
    printerProfile: printer.offlinePrinter,
    bluetoothPrinter: printer.bluetoothPrinter,
    transport: printer.transport,
  );
  if (!localResult.ok) {
    throw StateError(localResult.printerStatus);
  }
}

class _OpeningWipListTab extends StatefulWidget {
  const _OpeningWipListTab({
    required this.orders,
    required this.apparatusCatalog,
    required this.refreshToken,
    this.progressDriverUrlPicker,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatusCatalog;
  final int refreshToken;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<_OpeningWipListTab> createState() => _OpeningWipListTabState();
}

class _OpeningWipListTabState extends State<_OpeningWipListTab> {
  late Future<List<AdminOpeningWipRecord>> _future;
  String _apparatusFilter = '';
  bool _apparatusFilterExpanded = false;
  String _deletingBatchId = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _OpeningWipListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_reload());
    }
  }

  Future<List<AdminOpeningWipRecord>> _load() {
    return MobileApi.instance.adminOpeningWipRecords(
      status: 'all',
      limit: _openingWipListFetchLimit,
    );
  }

  Future<void> _reload() async {
    final nextFuture = _load();
    setState(() {
      _future = nextFuture;
    });
    await nextFuture;
  }

  void _setApparatusFilter(String value) {
    final next = value.trim();
    if (_apparatusFilter == next) {
      setState(() => _apparatusFilterExpanded = false);
      return;
    }
    setState(() {
      _apparatusFilter = next;
      _apparatusFilterExpanded = false;
    });
  }

  Future<String?> _reprintBatch(AdminOpeningWipBatch batch) async {
    final printer = await _pickProgressPrinter(
      context,
      widget.progressDriverUrlPicker,
    );
    if (!mounted || printer == null) {
      throw const RpsQrReprintCancelled();
    }
    await _printOpeningWipBatch(batch: batch, printer: printer);
    return null;
  }

  Future<void> _showBatchDetails(_OpeningWipBatchEntry entry) async {
    final batch = entry.batch;
    final record = entry.record;
    final payload = batch.qrPayload.trim();
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.adminText(
              'production.opening_wip.reprint_qr_missing',
            ),
          ),
        ),
      );
      return;
    }
    final sourceId = openingWipSourceApparatus(record);
    final source = canonicalApparatusDisplayLabel(
      sourceId,
      widget.apparatusCatalog,
    );
    final locationId = _firstNonEmpty([
      record.intake.currentLocation,
      record.intake.resumeApparatus,
      sourceId,
    ]);
    final location = canonicalApparatusDisplayLabel(
      locationId,
      widget.apparatusCatalog,
    );
    final order = _openingWipOrderForId(widget.orders, batch.orderId);
    final createdAt = formatUnixSecondsLocalDateTime(batch.createdAtUnix);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RpsQrReprintSheet(
        title: sheetContext.l10n.adminText(
          'production.opening_wip.details_title',
        ),
        payload: payload,
        itemName: _openingWipBatchTitle(batch),
        previewKey: ValueKey('opening-wip-preview-${batch.batchId}'),
        reprintButtonKey: ValueKey('opening-wip-reprint-${batch.batchId}'),
        details: [
          RpsQrDetail(
            sheetContext.l10n.adminText('production.opening_wip.order'),
            _openingWipOrderLabel(order, batch.orderId),
          ),
          RpsQrDetail(
            sheetContext.l10n.adminText(
              'production.opening_wip.batch_id',
            ),
            batch.batchId,
          ),
          RpsQrDetail(
            sheetContext.l10n.adminText('wip.quantity'),
            _openingWipQuantityText(batch),
          ),
          if (batch.bobinaKg != null)
            RpsQrDetail(
              sheetContext.l10n.adminText(
                'production.opening_wip.bobina_kg',
              ),
              formatQuantityWithUnit(
                batch.bobinaKg!,
                'kg',
                trimTrailingZeros: true,
              ),
            ),
          if (batch.diameter != null)
            RpsQrDetail(
              sheetContext.l10n.adminText(
                'production.opening_wip.diameter',
              ),
              formatQuantityWithUnit(
                batch.diameter!,
                'mm',
                trimTrailingZeros: true,
              ),
            ),
          RpsQrDetail(
            sheetContext.l10n.adminText(
              'production.opening_wip.source_apparatus',
            ),
            _openingWipDash(source),
          ),
          RpsQrDetail(
            sheetContext.l10n.adminText('wip.current_location'),
            _openingWipDash(location),
          ),
          RpsQrDetail(
            sheetContext.l10n.adminText(
              'production.opening_wip.quantity_basis',
            ),
            _openingWipQuantityBasisText(
              sheetContext,
              batch.quantityBasis,
            ),
          ),
          RpsQrDetail(
            sheetContext.l10n.adminText('wip.product_status'),
            _openingWipStatusLabel(sheetContext, batch.wipStatus),
          ),
          if (createdAt.isNotEmpty)
            RpsQrDetail(
              sheetContext.l10n.adminText('wip.created_at'),
              createdAt,
            ),
          if (record.intake.note.trim().isNotEmpty)
            RpsQrDetail(
              sheetContext.l10n.adminText('production.opening_wip.note'),
              record.intake.note.trim(),
            ),
        ],
        onReprint: () => _reprintBatch(batch),
        errorMessage: (error) => _openingWipReprintError(
          sheetContext,
          error,
        ),
        successMessage: sheetContext.l10n.adminText(
          'production.opening_wip.reprint_success',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(_OpeningWipBatchEntry entry) async {
    final batch = entry.batch;
    if (_deletingBatchId.isNotEmpty) return;
    final canDelete = _openingWipBatchCanDelete(batch);
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: context.l10n.adminText('wip.delete.title'),
      message: context.l10n.adminText(
        canDelete ? 'wip.delete.message' : 'wip.delete.locked',
      ),
      cancelLabel: context.l10n.adminText('wip.delete.cancel'),
      confirmLabel: context.l10n.adminText('wip.delete.confirm'),
      destructive: true,
      blurBackground: true,
      verticalActions: true,
      confirmButtonKey: const ValueKey('opening-wip-delete-confirm'),
      cancelButtonKey: const ValueKey('opening-wip-delete-cancel'),
    );
    if (!mounted || confirmed != true) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminText('wip.delete.locked')),
        ),
      );
      return;
    }
    setState(() => _deletingBatchId = batch.batchId);
    try {
      await MobileApi.instance.adminDeleteOpeningWipBatch(
        batchId: batch.batchId,
      );
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminText('wip.delete.success')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is MobileApiException
          ? error.message
          : context.l10n.adminText('wip.delete.failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _deletingBatchId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: FutureBuilder<List<AdminOpeningWipRecord>>(
        future: _future,
        builder: (context, snapshot) {
          final records = _activeOpeningWipRecords(
            snapshot.data ?? const <AdminOpeningWipRecord>[],
          );
          final options = openingWipApparatusOptions(records);
          final selected =
              options.contains(_apparatusFilter) ? _apparatusFilter : '';
          return Column(
            children: [
              _OpeningWipApparatusFilterBar(
                selectedApparatus: selected,
                apparatusIds: options,
                apparatusCatalog: widget.apparatusCatalog,
                expanded: _apparatusFilterExpanded,
                onToggle: () {
                  setState(() {
                    _apparatusFilterExpanded = !_apparatusFilterExpanded;
                  });
                },
                onChanged: _setApparatusFilter,
              ),
              Expanded(
                child: _buildOpeningWipListContent(
                  context: context,
                  snapshot: snapshot,
                  records: records,
                  selectedApparatus: selected,
                  orders: widget.orders,
                  apparatusCatalog: widget.apparatusCatalog,
                  bottomPadding: bottomPadding,
                  onRefresh: _reload,
                  onTap: _showBatchDetails,
                  onLongPress: _confirmDelete,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OpeningWipApparatusFilterBar extends StatelessWidget {
  const _OpeningWipApparatusFilterBar({
    required this.selectedApparatus,
    required this.apparatusIds,
    required this.apparatusCatalog,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final String selectedApparatus;
  final List<String> apparatusIds;
  final List<AdminApparatus> apparatusCatalog;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminExpandableFilterChip<String>(
      chipKey: const ValueKey('opening-wip-apparatus-filter-chip'),
      label: context.l10n.adminText('wip.apparatus'),
      emptyLabel: context.l10n.adminText('wip.all_apparatus'),
      icon: Icons.precision_manufacturing_outlined,
      selectedValue: selectedApparatus,
      expanded: expanded,
      onToggle: onToggle,
      onSelect: onChanged,
      optionKeyPrefix: 'opening-wip-apparatus-option-chip',
      options: [
        AdminFilterChipOption(
          value: '',
          label: context.l10n.adminText('wip.all_apparatus'),
          key: const ValueKey('opening-wip-apparatus-option-chip-all'),
        ),
        for (final id in apparatusIds)
          AdminFilterChipOption(
            value: id,
            label: canonicalApparatusDisplayLabel(id, apparatusCatalog),
            key: ValueKey('opening-wip-apparatus-option-chip-$id'),
          ),
      ],
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    );
  }
}

Widget _buildOpeningWipListContent({
  required BuildContext context,
  required AsyncSnapshot<List<AdminOpeningWipRecord>> snapshot,
  required List<AdminOpeningWipRecord> records,
  required String selectedApparatus,
  required List<ProductionMapSaved> orders,
  required List<AdminApparatus> apparatusCatalog,
  required double bottomPadding,
  required Future<void> Function() onRefresh,
  required ValueChanged<_OpeningWipBatchEntry> onTap,
  required ValueChanged<_OpeningWipBatchEntry> onLongPress,
}) {
  if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
    return const Center(child: AppLoadingIndicator());
  }
  if (snapshot.hasError) {
    return AppRetryState(onRetry: onRefresh);
  }

  final batches = _openingWipBatchEntries(records, selectedApparatus);
  return AppRefreshIndicator(
    onRefresh: onRefresh,
    allowRefreshOnShortContent: true,
    child: ListView(
      physics: const TopRefreshScrollPhysics(),
      padding: EdgeInsets.fromLTRB(4, 8, 4, bottomPadding),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.l10n.adminText('wip.opening_intro'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
          ),
        ),
        const SizedBox(height: 10),
        if (batches.isEmpty)
          _OpeningWipEmptyCard(
            text: context.l10n.adminText('wip.empty.opening'),
          )
        else
          M3SegmentSpacedColumn(
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < batches.length; index++)
                _OpeningWipBatchTile(
                  entry: batches[index],
                  orders: orders,
                  apparatusCatalog: apparatusCatalog,
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    batches.length,
                  ),
                  onTap: () => onTap(batches[index]),
                  onLongPress: () => onLongPress(batches[index]),
                ),
            ],
          ),
      ],
    ),
  );
}

class _OpeningWipBatchEntry {
  const _OpeningWipBatchEntry({required this.record, required this.batch});

  final AdminOpeningWipRecord record;
  final AdminOpeningWipBatch batch;
}

List<String> openingWipApparatusOptions(
  Iterable<AdminOpeningWipRecord> records,
) {
  final values = <String>{};
  for (final record in records) {
    if (record.intake.status.trim().toLowerCase() == 'cancelled' ||
        !record.batches.any(
          (batch) => batch.wipStatus.trim().toLowerCase() != 'void',
        )) {
      continue;
    }
    final apparatus = openingWipSourceApparatus(record);
    if (apparatus.isNotEmpty) values.add(apparatus);
  }
  final sorted = values.toList(growable: false);
  sorted
      .sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return sorted;
}

String openingWipSourceApparatus(AdminOpeningWipRecord record) {
  final candidates = [
    record.intake.sourceApparatus.trim(),
    record.intake.entryApparatus.trim(),
  ];
  for (final candidate in candidates) {
    if (candidate.isNotEmpty && canonicalApparatusIdIsValid(candidate)) {
      return candidate;
    }
  }
  return '';
}

List<_OpeningWipBatchEntry> _openingWipBatchEntries(
  Iterable<AdminOpeningWipRecord> records,
  String selectedApparatus,
) {
  final selected = selectedApparatus.trim();
  final entries = <_OpeningWipBatchEntry>[];
  for (final record in records) {
    if (record.intake.status.trim().toLowerCase() == 'cancelled') continue;
    final sourceApparatus = openingWipSourceApparatus(record);
    if (selected.isNotEmpty && sourceApparatus != selected) continue;
    for (final batch in record.batches) {
      if (batch.wipStatus.trim().toLowerCase() == 'void') continue;
      entries.add(_OpeningWipBatchEntry(record: record, batch: batch));
    }
  }
  return entries;
}

class _OpeningWipEmptyCard extends StatelessWidget {
  const _OpeningWipEmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.top,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      backgroundColor: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

String _openingWipBatchTitle(AdminOpeningWipBatch batch) {
  final name = batch.labelItemName.trim();
  return name.isEmpty ? 'Opening WIP #${batch.sequenceNo}' : name;
}

class _OpeningWipBatchTile extends StatelessWidget {
  const _OpeningWipBatchTile({
    required this.entry,
    required this.orders,
    required this.apparatusCatalog,
    required this.slot,
    required this.onTap,
    required this.onLongPress,
  });

  final _OpeningWipBatchEntry entry;
  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatusCatalog;
  final M3SegmentVerticalSlot slot;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final batch = entry.batch;
    final record = entry.record;
    final sourceId = openingWipSourceApparatus(record);
    final source = canonicalApparatusDisplayLabel(sourceId, apparatusCatalog);
    final order = _openingWipOrderForId(orders, batch.orderId);
    final orderLabel = _openingWipOrderLabel(order, batch.orderId);
    final title = _openingWipBatchTitle(batch);
    final locationId = _firstNonEmpty([
      record.intake.currentLocation,
      record.intake.resumeApparatus,
      sourceId,
    ]);
    final location = canonicalApparatusDisplayLabel(
      locationId,
      apparatusCatalog,
    );
    final quantity = _openingWipQuantityText(batch);
    final basis = _openingWipQuantityBasisText(context, batch.quantityBasis);
    final createdAt = formatUnixSecondsLocalDateTime(batch.createdAtUnix);

    return M3SegmentFilledSurface(
      key: ValueKey('opening-wip-batch-${batch.batchId}'),
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        orderLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _OpeningWipStatusPill(status: batch.wipStatus),
              ],
            ),
            const SizedBox(height: 12),
            _OpeningWipInfoLine(
              icon: Icons.scale_outlined,
              label: context.l10n.adminText('wip.quantity'),
              value: quantity,
            ),
            _OpeningWipInfoLine(
              icon: Icons.output_rounded,
              label: context.l10n.adminText(
                'production.opening_wip.source_apparatus',
              ),
              value: _openingWipDash(source),
            ),
            _OpeningWipInfoLine(
              icon: Icons.place_outlined,
              label: context.l10n.adminText('wip.current_location'),
              value: _openingWipDash(location),
            ),
            _OpeningWipInfoLine(
              icon: Icons.verified_outlined,
              label: context.l10n.adminText(
                'production.opening_wip.quantity_basis',
              ),
              value: basis,
            ),
            if (createdAt.isNotEmpty)
              _OpeningWipInfoLine(
                icon: Icons.schedule_outlined,
                label: context.l10n.adminText('wip.created_at'),
                value: createdAt,
              ),
            if (record.intake.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.intake.note.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (batch.qrPayload.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                batch.qrPayload.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<AdminOpeningWipRecord> _activeOpeningWipRecords(
  Iterable<AdminOpeningWipRecord> records,
) {
  return [
    for (final record in records)
      if (record.intake.status.trim().toLowerCase() != 'cancelled' &&
          record.batches.any(
            (batch) => batch.wipStatus.trim().toLowerCase() != 'void',
          ))
        record,
  ];
}

bool _openingWipBatchCanDelete(AdminOpeningWipBatch batch) {
  return batch.wipStatus.trim().toLowerCase() == 'waiting' &&
      batch.usedBySessionId.trim().isEmpty &&
      batch.usedByApparatus.trim().isEmpty &&
      batch.processedBySessionId.trim().isEmpty &&
      batch.processedByApparatus.trim().isEmpty;
}

String _openingWipStatusLabel(BuildContext context, String status) {
  return switch (status.trim().toLowerCase()) {
    'waiting' => context.l10n.adminText('wip.status.waiting'),
    'in_use' => context.l10n.adminText('wip.status.in_use'),
    'processed' => context.l10n.adminText('wip.status.processed'),
    _ => context.l10n.adminText('wip.unspecified'),
  };
}

String _openingWipReprintError(BuildContext context, Object error) {
  if (error is MobileApiException && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  if (error is StateError) {
    final message = error.message.toString().trim();
    if (message.isNotEmpty) return message;
  }
  return context.l10n.adminText('production.opening_wip.reprint_failed');
}

class _OpeningWipStatusPill extends StatelessWidget {
  const _OpeningWipStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = status.trim().toLowerCase();
    final Color background;
    final Color foreground;
    switch (normalized) {
      case 'waiting':
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        break;
      case 'in_use':
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        break;
      case 'processed':
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        break;
      default:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          _openingWipStatusLabel(context, status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _OpeningWipInfoLine extends StatelessWidget {
  const _OpeningWipInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ProductionMapSaved? _openingWipOrderForId(
  List<ProductionMapSaved> orders,
  String orderId,
) {
  final normalized = orderId.trim();
  for (final order in orders) {
    if (order.map.id.trim() == normalized) return order;
  }
  return null;
}

String _openingWipOrderLabel(ProductionMapSaved? order, String orderId) {
  final number = order?.map.orderNumber.trim() ?? '';
  final id = number.isEmpty ? orderId.trim() : number;
  final title = order?.map.title.trim() ?? '';
  if (id.isEmpty) return title.isEmpty ? '-' : title;
  return title.isEmpty ? id : '$id • $title';
}

String _openingWipQuantityText(AdminOpeningWipBatch batch) {
  final values = <String>[];
  if (batch.finishedGoodsMeter != null) {
    values.add(
      formatQuantityWithUnit(
        batch.finishedGoodsMeter!,
        'm',
        trimTrailingZeros: true,
      ),
    );
  }
  if (batch.finishedGoodsKg != null) {
    values.add(
      formatQuantityWithUnit(
        batch.finishedGoodsKg!,
        'kg',
        trimTrailingZeros: true,
      ),
    );
  }
  if (values.isEmpty && batch.quantity != null) {
    values.add(
      formatQuantityWithUnit(
        batch.quantity!,
        batch.uom,
        trimTrailingZeros: true,
      ),
    );
  }
  return values.isEmpty ? '-' : values.join(' • ');
}

String _openingWipQuantityBasisText(
  BuildContext context,
  AdminOpeningWipQuantityBasis basis,
) {
  return context.l10n.adminText(
    'production.opening_wip.basis_${basis.apiValue}',
  );
}

String _openingWipDash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

class _OpeningWipPageData {
  const _OpeningWipPageData({
    required this.orders,
    required this.apparatus,
    required this.stageStatesByOrderId,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatus;
  final Map<String, Map<String, String>> stageStatesByOrderId;
}

List<ProductionMapChainStage> _openingWipSourceStages(
  ProductionMapSaved? order,
  Map<String, Map<String, String>> stageStatesByOrderId,
) {
  if (order == null) return const [];
  return productionMapOpeningWipSourceStages(
    map: order.map,
    stageStates: stageStatesByOrderId[order.map.id.trim()] ?? const {},
  ).where((stage) {
    final apparatusId = stage.apparatusId?.trim() ?? '';
    return apparatusId.isNotEmpty && canonicalApparatusIdIsValid(apparatusId);
  }).toList(growable: false);
}

List<ProductionMapSaved> _openingWipEligibleOrders({
  required List<ProductionMapSaved> orders,
  required Map<String, Map<String, String>> stageStatesByOrderId,
}) {
  return [
    for (final order in orders)
      if (_openingWipSourceStages(order, stageStatesByOrderId).isNotEmpty)
        order,
  ];
}

class _OpeningWipWizard extends StatefulWidget {
  const _OpeningWipWizard({
    required this.orders,
    required this.apparatusCatalog,
    required this.stageStatesByOrderId,
    this.progressDriverUrlPicker,
    this.onCreated,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatusCatalog;
  final Map<String, Map<String, String>> stageStatesByOrderId;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;
  final VoidCallback? onCreated;

  @override
  State<_OpeningWipWizard> createState() => _OpeningWipWizardState();
}

class _OpeningWipRollControllers {
  final meter = TextEditingController();
  final kg = TextEditingController();
  final bobinaKg = TextEditingController();
  final diameter = TextEditingController();

  double? parse(TextEditingController controller) => double.tryParse(
        controller.text.trim().replaceAll(',', '.'),
      );

  String get fingerprint => [
        meter.text.trim(),
        kg.text.trim(),
        bobinaKg.text.trim(),
        diameter.text.trim(),
      ].join(',');

  void dispose() {
    meter.dispose();
    kg.dispose();
    bobinaKg.dispose();
    diameter.dispose();
  }
}

class _OpeningWipWizardState extends State<_OpeningWipWizard> {
  final _formKey = GlobalKey<FormState>();
  final _sourceFieldKey = GlobalKey<FormFieldState<String>>();
  final _noteController = TextEditingController();
  final _rollCountController = TextEditingController(text: '1');
  final List<_OpeningWipRollControllers> _rollControllers = [
    _OpeningWipRollControllers(),
  ];
  ProductionMapSaved? _selectedOrder;
  String _sourceStageNodeId = '';
  AdminOpeningWipQuantityBasis _quantityBasis =
      AdminOpeningWipQuantityBasis.measured;
  AdminOpeningWipRecord? _createdRecord;
  final Set<String> _printedBatchIds = {};
  String _idempotencyKey = '';
  String _idempotencyFingerprint = '';
  String _error = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedOrder = widget.orders.isEmpty ? null : widget.orders.first;
    _sourceStageNodeId = _availableSourceStages.isEmpty
        ? ''
        : _availableSourceStages.first.nodeId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _rollCountController.dispose();
    for (final controller in _rollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncRollControllers(String rawCount) {
    final count = int.tryParse(rawCount.trim());
    if (count == null || count < 1 || count > 500) return;
    setState(() {
      while (_rollControllers.length < count) {
        _rollControllers.add(_OpeningWipRollControllers());
      }
      while (_rollControllers.length > count) {
        _rollControllers.removeLast().dispose();
      }
    });
  }

  List<ProductionMapChainStage> get _availableSourceStages =>
      _openingWipSourceStages(_selectedOrder, widget.stageStatesByOrderId);

  ProductionMapChainStage? get _selectedSourceStage {
    for (final stage in _availableSourceStages) {
      if (stage.nodeId.trim() == _sourceStageNodeId.trim()) return stage;
    }
    return null;
  }

  String get _sourceApparatus =>
      _selectedSourceStage?.apparatusId?.trim() ?? '';

  AdminApparatus? get _sourceApparatusDefinition {
    for (final apparatus in widget.apparatusCatalog) {
      if (apparatus.id.trim() == _sourceApparatus) return apparatus;
    }
    return null;
  }

  bool get _requiresDiameter =>
      _sourceApparatusDefinition?.operation.trim().toLowerCase() == 'cut';

  void _selectOrder(ProductionMapSaved? order) {
    final sourceStages = _openingWipSourceStages(
      order,
      widget.stageStatesByOrderId,
    );
    final nextSourceNodeId =
        sourceStages.isEmpty ? '' : sourceStages.first.nodeId;
    setState(() {
      _selectedOrder = order;
      _sourceStageNodeId = nextSourceNodeId;
      for (final roll in _rollControllers) {
        if (!_requiresDiameter) roll.diameter.clear();
      }
    });
    _sourceFieldKey.currentState?.didChange(
      nextSourceNodeId.isEmpty ? null : nextSourceNodeId,
    );
  }

  AdminOpeningWipBatchInput _rollInput(_OpeningWipRollControllers roll) {
    return AdminOpeningWipBatchInput(
      quantityBasis: _quantityBasis,
      finishedGoodsMeter: roll.parse(roll.meter)!,
      finishedGoodsKg: roll.parse(roll.kg)!,
      bobinaKg: roll.parse(roll.bobinaKg)!,
      diameter: _requiresDiameter ? roll.parse(roll.diameter) : null,
    );
  }

  String _submissionIdempotencyKey({
    required ProductionMapSaved order,
    required String sourceApparatus,
    required String sourceStageNodeId,
    required int rollCount,
  }) {
    final fingerprint = [
      order.map.id.trim(),
      sourceApparatus,
      sourceStageNodeId,
      _noteController.text.trim(),
      '$rollCount',
      _quantityBasis.apiValue,
      _rollControllers.map((roll) => roll.fingerprint).join(';'),
    ].join('|');
    if (_idempotencyKey.isEmpty || _idempotencyFingerprint != fingerprint) {
      _idempotencyFingerprint = fingerprint;
      final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      _idempotencyKey = 'mobile:opening-wip:$stamp';
    }
    return _idempotencyKey;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final created = _createdRecord;
    if (created == null && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final sourceStageNodeId = _sourceFieldKey.currentState?.value?.trim() ?? '';
    ProductionMapChainStage? sourceStage;
    for (final candidate in _availableSourceStages) {
      if (candidate.nodeId.trim() == sourceStageNodeId) {
        sourceStage = candidate;
        break;
      }
    }
    if (created == null && sourceStage == null) {
      setState(() {
        _error = context.l10n.adminText(
          'production.opening_wip.location_missing',
        );
      });
      return;
    }
    final printer = await _pickProgressPrinter(
      context,
      widget.progressDriverUrlPicker,
    );
    if (!mounted || printer == null) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      var record = created;
      if (record == null) {
        final order = _selectedOrder!;
        final selectedSource = sourceStage!;
        final sourceApparatus = selectedSource.apparatusId!.trim();
        final rollCount = int.parse(_rollCountController.text.trim());
        final batches = [
          for (var index = 0; index < rollCount; index++)
            _rollInput(_rollControllers[index]),
        ];
        record = await MobileApi.instance.adminCreateOpeningWip(
          AdminOpeningWipCreateInput(
            idempotencyKey: _submissionIdempotencyKey(
              order: order,
              sourceApparatus: sourceApparatus,
              sourceStageNodeId: selectedSource.nodeId,
              rollCount: rollCount,
            ),
            orderId: order.map.id,
            sourceApparatus: sourceApparatus,
            sourceStageNodeId: selectedSource.nodeId,
            note: _noteController.text,
            batches: batches,
          ),
        );
        if (!mounted) return;
        if (record.intake.sourceApparatus.trim() != sourceApparatus ||
            record.intake.sourceStageNodeId.trim() !=
                selectedSource.nodeId.trim()) {
          throw const MobileApiException(
            code: 'opening_wip_source_mismatch',
            message:
                'Tanlangan chiqish apparati serverda saqlanmadi. QR chop etilmadi.',
          );
        }
        setState(() => _createdRecord = record);
        widget.onCreated?.call();
      }

      for (final batch in record.batches) {
        if (_printedBatchIds.contains(batch.batchId)) continue;
        await _printOpeningWipBatch(batch: batch, printer: printer);
        if (!mounted) return;
        setState(() => _printedBatchIds.add(batch.batchId));
      }
      if (!mounted) return;
      DefaultTabController.of(context).animateTo(1);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is MobileApiException
              ? error.message
              : context.l10n.adminText(
                  'production.opening_wip.print_failed',
                  values: {
                    'printed': _printedBatchIds.length,
                    'total': _createdRecord?.batches.length ?? 0,
                  },
                );
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _orderLabel(ProductionMapSaved order) {
    final number = order.map.orderNumber.trim().isEmpty
        ? order.map.id.trim()
        : order.map.orderNumber.trim();
    final title = order.map.title.trim();
    return title.isEmpty ? number : '$number • $title';
  }

  String _apparatusLabel(String apparatusId) {
    return canonicalApparatusDisplayLabel(
      apparatusId,
      widget.apparatusCatalog,
    );
  }

  String? _requiredText(String? value) {
    return value?.trim().isEmpty != false
        ? context.l10n.adminText('production.opening_wip.required')
        : null;
  }

  Widget _metricField({
    required Key key,
    required TextEditingController controller,
    required String labelKey,
    required String unit,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: context.l10n.adminText(labelKey),
        suffixText: unit,
      ),
      validator: (value) {
        final parsed = double.tryParse(
          (value ?? '').trim().replaceAll(',', '.'),
        );
        return parsed == null || !parsed.isFinite || parsed <= 0
            ? context.l10n.adminText(
                'production.opening_wip.invalid_quantity',
              )
            : null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = _selectedOrder;
    final availableSourceStages = _availableSourceStages;
    final requiresDiameter = _requiresDiameter;
    final created = _createdRecord;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.orders.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      context.l10n.adminText(
                        'production.opening_wip.no_eligible',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    key: const ValueKey('opening-wip-fields'),
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      AbsorbPointer(
                        absorbing: created != null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child:
                                  DropdownButtonFormField<ProductionMapSaved>(
                                key: const ValueKey('opening-wip-order'),
                                initialValue: order,
                                decoration: InputDecoration(
                                  labelText: context.l10n.adminText(
                                    'production.opening_wip.order',
                                  ),
                                ),
                                isExpanded: true,
                                items: [
                                  for (final item in widget.orders)
                                    DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        _orderLabel(item),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _selectOrder,
                              ),
                            ),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: const ValueKey(
                                  'opening-wip-source-apparatus'),
                              child: DropdownButtonFormField<String>(
                                key: _sourceFieldKey,
                                initialValue: _sourceStageNodeId.isEmpty
                                    ? null
                                    : _sourceStageNodeId,
                                decoration: InputDecoration(
                                  labelText: context.l10n.adminText(
                                    'production.opening_wip.source_apparatus',
                                  ),
                                ),
                                isExpanded: true,
                                items: [
                                  for (final stage in availableSourceStages)
                                    DropdownMenuItem(
                                      value: stage.nodeId,
                                      child: Text(
                                        stage.displayTitle.trim().isEmpty
                                            ? _apparatusLabel(
                                                stage.apparatusId!)
                                            : stage.displayTitle.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: availableSourceStages.isEmpty
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _sourceStageNodeId = value ?? '';
                                          for (final roll in _rollControllers) {
                                            if (!_requiresDiameter) {
                                              roll.diameter.clear();
                                            }
                                          }
                                        });
                                      },
                                validator: (value) {
                                  if (availableSourceStages.isEmpty) {
                                    return context.l10n.adminText(
                                      'production.opening_wip.location_missing',
                                    );
                                  }
                                  return _requiredText(value);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _noteController,
                              decoration: InputDecoration(
                                labelText: context.l10n.adminText(
                                  'production.opening_wip.note',
                                ),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('opening-wip-roll-count'),
                              controller: _rollCountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                labelText: context.l10n.adminText(
                                  'production.opening_wip.roll_count',
                                ),
                              ),
                              onChanged: _syncRollControllers,
                              validator: (value) {
                                final count = int.tryParse(value?.trim() ?? '');
                                return count == null || count < 1 || count > 500
                                    ? context.l10n.adminText(
                                        'production.opening_wip.invalid_roll_count',
                                      )
                                    : null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<
                                AdminOpeningWipQuantityBasis>(
                              key: const ValueKey(
                                'opening-wip-quantity-basis',
                              ),
                              initialValue: _quantityBasis,
                              decoration: InputDecoration(
                                labelText: context.l10n.adminText(
                                  'production.opening_wip.quantity_basis',
                                ),
                              ),
                              items: [
                                for (final basis in const [
                                  AdminOpeningWipQuantityBasis.measured,
                                  AdminOpeningWipQuantityBasis.estimated,
                                ])
                                  DropdownMenuItem(
                                    value: basis,
                                    child: Text(
                                      context.l10n.adminText(
                                        'production.opening_wip.basis_${basis.apiValue}',
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _quantityBasis = value);
                                }
                              },
                            ),
                            for (var index = 0;
                                index < _rollControllers.length;
                                index++) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: scheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      context.l10n.adminText(
                                        'production.opening_wip.roll_title',
                                        values: {'index': '${index + 1}'},
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 10),
                                    _metricField(
                                      key: ValueKey(
                                        'opening-wip-roll-meter-$index',
                                      ),
                                      controller: _rollControllers[index].meter,
                                      labelKey:
                                          'production.opening_wip.finished_meter',
                                      unit: 'm',
                                    ),
                                    const SizedBox(height: 10),
                                    _metricField(
                                      key: ValueKey(
                                        'opening-wip-roll-kg-$index',
                                      ),
                                      controller: _rollControllers[index].kg,
                                      labelKey:
                                          'production.opening_wip.finished_kg',
                                      unit: 'kg',
                                    ),
                                    const SizedBox(height: 10),
                                    _metricField(
                                      key: ValueKey(
                                        'opening-wip-roll-bobina-$index',
                                      ),
                                      controller:
                                          _rollControllers[index].bobinaKg,
                                      labelKey:
                                          'production.opening_wip.bobina_kg',
                                      unit: 'kg',
                                    ),
                                    if (requiresDiameter) ...[
                                      const SizedBox(height: 10),
                                      _metricField(
                                        key: ValueKey(
                                          'opening-wip-roll-diameter-$index',
                                        ),
                                        controller:
                                            _rollControllers[index].diameter,
                                        labelKey:
                                            'production.opening_wip.diameter',
                                        unit: 'mm',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error,
                          key: const ValueKey('opening-wip-error'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ],
                      if (widget.orders.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('opening-wip-submit'),
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.print_rounded),
                          label: Text(
                            created == null
                                ? context.l10n.adminText(
                                    'production.opening_wip.create_print',
                                  )
                                : context.l10n.adminText(
                                    'production.opening_wip.retry_print',
                                    values: {
                                      'printed': _printedBatchIds.length,
                                      'total': created.batches.length,
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
