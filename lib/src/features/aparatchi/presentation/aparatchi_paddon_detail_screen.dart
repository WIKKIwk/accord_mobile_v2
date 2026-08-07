import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/print_service.dart';
import '../../admin/presentation/admin_progress_qr_scan_screen.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

class AparatchiPaddonDetailArgs {
  const AparatchiPaddonDetailArgs({required this.code});

  final String code;
}

typedef AparatchiPaddonDetailLoader = Future<AdminPaddonSnapshot> Function();

enum _PaddonEditMode { add, remove }

class AparatchiPaddonDetailScreen extends StatefulWidget {
  const AparatchiPaddonDetailScreen({
    super.key,
    required this.code,
    this.loader,
  });

  final String code;
  final AparatchiPaddonDetailLoader? loader;

  @override
  State<AparatchiPaddonDetailScreen> createState() =>
      _AparatchiPaddonDetailScreenState();
}

class _AparatchiPaddonDetailScreenState
    extends State<AparatchiPaddonDetailScreen> {
  late Future<AdminPaddonSnapshot> _future;
  final _selectionListKey = GlobalKey();
  final Set<String> _selectedAvailableBatchIds = <String>{};
  final Set<String> _selectedAssignedBatchIds = <String>{};
  bool _busy = false;
  bool _printingQr = false;
  bool _selectionMode = false;
  _PaddonEditMode _editMode = _PaddonEditMode.add;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminPaddonSnapshot> _load() {
    final loader = widget.loader;
    return loader == null
        ? MobileApi.instance.adminPaddonDetail(widget.code)
        : loader();
  }

  Future<void> _retry() async {
    final future = _load();
    setState(() {
      _future = future;
      _selectedAvailableBatchIds.clear();
      _selectedAssignedBatchIds.clear();
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the error state.
    }
  }

  Future<void> _scanAndAdd() async {
    if (_busy) {
      return;
    }
    try {
      final value = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          settings: const RouteSettings(
            name: AppRoutes.adminProgressQrScan,
          ),
          builder: (_) => const AdminProgressQrScanScreen(scanOnly: true),
        ),
      );
      final qrPayload = value?.trim() ?? '';
      if (qrPayload.isEmpty || !mounted) {
        return;
      }
      await _runMutation(() {
        return MobileApi.instance.adminPaddonAddWip(
          paddonCode: widget.code,
          qrPayload: qrPayload,
        );
      }, confirmsApplied: (snapshot) {
        final normalizedQrPayload = qrPayload.toLowerCase();
        return snapshot.items.any(
          (batch) =>
              batch.qrPayload.trim().toLowerCase() == normalizedQrPayload,
        );
      });
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is MobileApiException && error.message.trim().isNotEmpty
              ? error.message
              : 'QR kamera scanneri ochilmadi',
        );
      }
    }
  }

  Future<void> _printPaddonQr() async {
    if (_busy || _printingQr) {
      return;
    }
    setState(() => _printingQr = true);
    try {
      final printer = await pickProgressPrinter(context);
      if (printer == null || !mounted) {
        return;
      }
      final result = await MobileApi.instance.adminPaddonPrintQr(
        code: widget.code,
        driverUrl: printer.driverUrl,
        printer: printer.printer,
        printMode: printer.printMode,
        printTransport: printer.transport,
      );
      if (printer.transport.isLocal) {
        final printJob = result.printJob;
        if (printJob == null) {
          throw StateError('Paddon QR print ma’lumoti olinmadi');
        }
        final printResult = await PrintService.printRps(
          printJob,
          printerProfile: printer.offlinePrinter,
          bluetoothPrinter: printer.bluetoothPrinter,
          transport: printer.transport,
        );
        if (!printResult.ok) {
          throw StateError('Paddon QR printerga yuborilmadi');
        }
      }
      if (mounted) {
        _showMessage('Paddon ${result.qrPayload} QR chop etildi');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is MobileApiException && error.message.trim().isNotEmpty
              ? error.message
              : 'Paddon QR chop etilmadi',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printingQr = false);
      }
    }
  }

  void _toggleAvailableWip(AdminProgressBatch batch) {
    if (_busy) {
      return;
    }
    final batchId = batch.batchId.trim();
    if (batchId.isEmpty) {
      return;
    }
    setState(() {
      if (_selectedAvailableBatchIds.contains(batchId)) {
        _selectedAvailableBatchIds.remove(batchId);
      } else {
        _selectedAvailableBatchIds.add(batchId);
        _selectedAssignedBatchIds.clear();
      }
    });
  }

  void _toggleAssignedWip(AdminProgressBatch batch) {
    if (_busy) {
      return;
    }
    final batchId = batch.batchId.trim();
    if (batchId.isEmpty) {
      return;
    }
    setState(() {
      if (_selectedAssignedBatchIds.contains(batchId)) {
        _selectedAssignedBatchIds.remove(batchId);
      } else {
        _selectedAssignedBatchIds.add(batchId);
        _selectedAvailableBatchIds.clear();
      }
    });
  }

  Future<void> _addSelectedWips() async {
    if (_busy || _selectedAvailableBatchIds.isEmpty) {
      return;
    }
    final selectedBatchIds = _selectedAvailableBatchIds.toList(growable: false);
    final applied = await _runMutation(
      () => MobileApi.instance.adminPaddonAddWips(
        paddonCode: widget.code,
        progressBatchIds: selectedBatchIds,
      ),
      confirmsApplied: (snapshot) {
        final assignedBatchIds =
            snapshot.items.map((batch) => batch.batchId.trim()).toSet();
        return selectedBatchIds.every(assignedBatchIds.contains);
      },
      fallbackMessage: 'Tanlangan WIP lar qo‘shilmadi',
    );
    if (applied && mounted) {
      setState(() => _selectedAvailableBatchIds.clear());
    }
  }

  Future<void> _removeSelectedWips() async {
    if (_busy || _selectedAssignedBatchIds.isEmpty) {
      return;
    }
    final selectedBatchIds = _selectedAssignedBatchIds.toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tanlangan WIP larni chiqarishmi?'),
        content: Text(
          '${selectedBatchIds.length} ta WIP paddon tarkibidan chiqariladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chiqarish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final applied = await _runMutation(
      () => MobileApi.instance.adminPaddonRemoveWips(
        paddonCode: widget.code,
        progressBatchIds: selectedBatchIds,
      ),
      confirmsApplied: (snapshot) {
        final assignedBatchIds =
            snapshot.items.map((batch) => batch.batchId.trim()).toSet();
        return selectedBatchIds.every(
          (batchId) => !assignedBatchIds.contains(batchId),
        );
      },
      fallbackMessage: 'Tanlangan WIP lar chiqarilmadi',
    );
    if (applied && mounted) {
      setState(() => _selectedAssignedBatchIds.clear());
    }
  }

  Future<bool> _runMutation(
    Future<AdminPaddonSnapshot> Function() mutation, {
    bool Function(AdminPaddonSnapshot snapshot)? confirmsApplied,
    String fallbackMessage = 'Paddon tarkibi o‘zgartirilmadi',
  }) async {
    setState(() => _busy = true);
    try {
      final snapshot = await mutation();
      if (!mounted) {
        return false;
      }
      _clearMessages();
      setState(() => _future = Future<AdminPaddonSnapshot>.value(snapshot));
      return true;
    } catch (error) {
      if (mounted && confirmsApplied != null) {
        try {
          final refreshed = await _load();
          if (!mounted) {
            return false;
          }
          final applied = confirmsApplied(refreshed);
          try {
            setState(
              () => _future = Future<AdminPaddonSnapshot>.value(refreshed),
            );
          } catch (_) {
            // The confirmation below is still authoritative for the mutation.
          }
          if (applied) {
            _clearMessages();
            return true;
          }
        } catch (_) {
          // Show the original mutation error below.
        }
      }
      if (mounted) {
        final message =
            error is MobileApiException && error.message.trim().isNotEmpty
                ? error.message
                : fallbackMessage;
        _showMessage(message);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Set<String> get _selectedBatchIds => _editMode == _PaddonEditMode.add
      ? _selectedAvailableBatchIds
      : _selectedAssignedBatchIds;

  String get _editModeActionLabel {
    final label =
        _editMode == _PaddonEditMode.add ? 'Qo‘shish' : 'Olib tashlash';
    final selectedCount = _selectedBatchIds.length;
    return selectedCount == 0 ? label : '$label ($selectedCount)';
  }

  IconData get _editModeActionIcon => _editMode == _PaddonEditMode.add
      ? Icons.playlist_add_rounded
      : Icons.playlist_remove_rounded;

  Future<void> _handleEditModeAction() async {
    if (_busy) {
      return;
    }
    if (!_selectionMode) {
      setState(() {
        _selectionMode = true;
        _editMode = _PaddonEditMode.add;
        _selectedAvailableBatchIds.clear();
        _selectedAssignedBatchIds.clear();
      });
      _scrollToSelectionList();
      return;
    }

    if (_selectedBatchIds.isNotEmpty) {
      if (_editMode == _PaddonEditMode.add) {
        await _addSelectedWips();
      } else {
        await _removeSelectedWips();
      }
      return;
    }

    setState(() {
      _editMode = _editMode == _PaddonEditMode.add
          ? _PaddonEditMode.remove
          : _PaddonEditMode.add;
      _selectedAvailableBatchIds.clear();
      _selectedAssignedBatchIds.clear();
    });
    _scrollToSelectionList();
  }

  void _scrollToSelectionList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final sectionContext = _selectionListKey.currentContext;
      if (sectionContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        sectionContext,
        alignment: 0.06,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildPaddonItemsSection(
    BuildContext context,
    AdminPaddonSnapshot data,
  ) {
    final showingAvailableItems =
        _selectionMode && _editMode == _PaddonEditMode.add;
    final items = showingAvailableItems ? data.availableItems : data.items;
    final selectedBatchIds = showingAvailableItems
        ? _selectedAvailableBatchIds
        : _selectedAssignedBatchIds;
    return KeyedSubtree(
      key: _selectionListKey,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  showingAvailableItems
                      ? 'Paddonga qo‘shish mumkin bo‘lgan WIP lar'
                      : 'Paddon ichidagi WIP lar',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${items.length} ta',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            _PaddonItemsEmpty(
              message: showingAvailableItems
                  ? 'Paddonga qo‘shish mumkin bo‘lgan WIP topilmadi.'
                  : 'Bu paddonda hozircha WIP yo‘q.',
            )
          else
            M3SegmentSpacedColumn(
              children: [
                for (var index = 0; index < items.length; index++)
                  _PaddonWipCard(
                    key: ValueKey(
                      showingAvailableItems
                          ? 'paddon-available-wip-card-${items[index].batchId}'
                          : 'paddon-wip-card-${items[index].batchId}',
                    ),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      items.length,
                    ),
                    batch: items[index],
                    selected: selectedBatchIds.contains(
                      items[index].batchId.trim(),
                    ),
                    onSelect: showingAvailableItems && !_busy
                        ? () => _toggleAvailableWip(items[index])
                        : !showingAvailableItems && _selectionMode && !_busy
                            ? () => _toggleAssignedWip(items[index])
                            : null,
                    selectionIcon: showingAvailableItems
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearMessages() {
    if (!mounted) {
      return;
    }
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (_) {
      // A completed mutation must not become an error because the old
      // snackbar host was detached during a route refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.code,
      subtitle: 'Paddon tarkibi',
      nativeTopBar: true,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 2,
        selectedRouteName: AppRoutes.apparatusPaddons,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      bottom: const AparatchiDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<AdminPaddonSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return AppRetryState(
            onRetry: _retry,
            message: 'Paddon ma’lumoti yuklanmadi',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return AppRetryState(
            onRetry: _retry,
            message: 'Paddon ma’lumoti topilmadi',
          );
        }
        return RefreshIndicator(
          onRefresh: _retry,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              MediaQuery.viewPaddingOf(context).bottom + 120,
            ),
            children: [
              _PaddonDetailHeader(snapshot: data),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('paddon-add-wip-scan'),
                onPressed: _busy || _printingQr ? null : _scanAndAdd,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('WIP QR scan qilib qo‘shish'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('paddon-print-qr'),
                onPressed: _busy || _printingQr ? null : _printPaddonQr,
                icon: _printingQr
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  _printingQr ? 'QR tayyorlanmoqda...' : 'Paddon QR chop etish',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('paddon-edit-mode-action'),
                  onPressed:
                      _busy || _printingQr ? null : _handleEditModeAction,
                  icon: Icon(_editModeActionIcon),
                  label: Text(_editModeActionLabel),
                ),
              ),
              const SizedBox(height: 8),
              _buildPaddonItemsSection(context, data),
            ],
          ),
        );
      },
    );
  }
}

class _PaddonDetailHeader extends StatelessWidget {
  const _PaddonDetailHeader({required this.snapshot});

  final AdminPaddonSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final paddon = snapshot.paddon;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paddon.code,
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (paddon.location.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paddon.location,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PaddonDetailMetric(
                  label: 'WIP',
                  value: '${snapshot.items.length}',
                ),
                if (paddon.createdByDisplayName.trim().isNotEmpty)
                  _PaddonDetailMetric(
                    label: 'Yaratgan',
                    value: paddon.createdByDisplayName,
                  ),
              ],
            ),
            if (paddon.note.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                paddon.note,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaddonDetailMetric extends StatelessWidget {
  const _PaddonDetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _PaddonWipCard extends StatelessWidget {
  const _PaddonWipCard({
    super.key,
    required this.slot,
    required this.batch,
    this.selected = false,
    this.onSelect,
    required this.selectionIcon,
  });

  final M3SegmentVerticalSlot slot;
  final AdminProgressBatch batch;
  final bool selected;
  final VoidCallback? onSelect;
  final IconData selectionIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final orderId = batch.orderId.trim().isEmpty ? '—' : batch.orderId.trim();
    final epc = batch.qrPayload.trim().isEmpty
        ? (batch.batchId.trim().isEmpty ? '—' : batch.batchId.trim())
        : batch.qrPayload.trim();
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onSelect,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.view_carousel_outlined,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order: $orderId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'EPC: $epc',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onSelect != null) ...[
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle_rounded : selectionIcon,
                  size: 28,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaddonItemsEmpty extends StatelessWidget {
  const _PaddonItemsEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.top,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
