import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/admin_progress_qr_scan_screen.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

class AparatchiPaddonDetailArgs {
  const AparatchiPaddonDetailArgs({required this.code});

  final String code;
}

typedef AparatchiPaddonDetailLoader = Future<AdminPaddonSnapshot> Function();

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
  final _availableWipsSectionKey = GlobalKey();
  bool _busy = false;
  bool _showAvailableWips = false;

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
    setState(() => _future = future);
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

  Future<void> _addWip(
    AdminProgressBatch batch,
    int displayedItemCount,
  ) async {
    if (_busy) {
      return;
    }
    final batchId = batch.batchId.trim();
    final qrPayload = batch.qrPayload.trim().toLowerCase();
    final expectedItemCount = displayedItemCount + 1;
    bool isTargetBatch(AdminProgressBatch candidate) {
      final candidateBatchId = candidate.batchId.trim();
      if (batchId.isNotEmpty && candidateBatchId == batchId) {
        return true;
      }
      return qrPayload.isNotEmpty &&
          candidate.qrPayload.trim().toLowerCase() == qrPayload;
    }

    await _runMutation(() async {
      final refreshed = await _load();
      final isStillAvailable = refreshed.availableItems.any(isTargetBatch);
      if (!isStillAvailable) {
        return refreshed;
      }
      return MobileApi.instance.adminPaddonAddWip(
        paddonCode: widget.code,
        progressBatchId: batchId,
      );
    }, confirmsApplied: (snapshot) {
      return snapshot.items.any(isTargetBatch) ||
          (snapshot.items.length >= expectedItemCount &&
              !snapshot.availableItems.any(isTargetBatch));
    }, fallbackMessage: 'WIP qo‘shilmadi: o‘zgarish tasdiqlanmadi');
  }

  Future<void> _removeWip(AdminProgressBatch batch) async {
    if (_busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('WIPni paddondan chiqarishmi?'),
        content: Text(
          '“${_batchTitle(batch)}” WIP paddon tarkibidan chiqariladi.',
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
    await _runMutation(() {
      return MobileApi.instance.adminPaddonRemoveWip(
        paddonCode: widget.code,
        progressBatchId: batch.batchId,
      );
    }, confirmsApplied: (snapshot) {
      return snapshot.items.every((item) => item.batchId != batch.batchId);
    });
  }

  Future<void> _runMutation(
    Future<AdminPaddonSnapshot> Function() mutation, {
    bool Function(AdminPaddonSnapshot snapshot)? confirmsApplied,
    String fallbackMessage = 'Paddon tarkibi o‘zgartirilmadi',
  }) async {
    setState(() => _busy = true);
    try {
      final snapshot = await mutation();
      if (!mounted) {
        return;
      }
      _clearMessages();
      setState(() => _future = Future<AdminPaddonSnapshot>.value(snapshot));
    } catch (error) {
      if (mounted && confirmsApplied != null) {
        try {
          final refreshed = await _load();
          if (!mounted) {
            return;
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
            return;
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
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleAvailableWips() async {
    final shouldShow = !_showAvailableWips;
    if (!shouldShow) {
      setState(() => _showAvailableWips = false);
      return;
    }

    setState(() => _busy = true);
    try {
      final refreshed = await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _future = Future<AdminPaddonSnapshot>.value(refreshed);
        _showAvailableWips = true;
      });
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is MobileApiException && error.message.trim().isNotEmpty
              ? error.message
              : 'WIP qo‘shish ro‘yxati yuklanmadi',
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final sectionContext = _availableWipsSectionKey.currentContext;
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

  Widget _buildAvailableWipsSection(
    BuildContext context,
    AdminPaddonSnapshot data,
  ) {
    return KeyedSubtree(
      key: _availableWipsSectionKey,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Paddonga kirmagan WIP lar',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${data.availableItems.length} ta',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.availableItems.isEmpty)
            const _PaddonItemsEmpty(
              message: 'Paddonga kirmagan WIP topilmadi.',
            )
          else
            M3SegmentSpacedColumn(
              children: [
                for (var index = 0; index < data.availableItems.length; index++)
                  _PaddonWipCard(
                    key: ValueKey(
                      'paddon-available-wip-card-${data.availableItems[index].batchId}',
                    ),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      data.availableItems.length,
                    ),
                    batch: data.availableItems[index],
                    onAdd: _busy
                        ? null
                        : () => _addWip(
                              data.availableItems[index],
                              data.items.length,
                            ),
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
                onPressed: _busy ? null : _scanAndAdd,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('WIP QR scan qilib qo‘shish'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Paddon ichidagi WIP lar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${data.items.length} ta',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  IconButton(
                    key: const ValueKey('paddon-toggle-available-wips'),
                    onPressed: _busy ? null : _toggleAvailableWips,
                    tooltip: _showAvailableWips
                        ? 'WIP qo‘shish ro‘yxatini yopish'
                        : 'WIP qo‘shish',
                    icon: Icon(
                      _showAvailableWips
                          ? Icons.close_rounded
                          : Icons.add_rounded,
                    ),
                  ),
                ],
              ),
              if (_showAvailableWips) _buildAvailableWipsSection(context, data),
              const SizedBox(height: 8),
              if (data.items.isEmpty)
                const _PaddonItemsEmpty(
                  message: 'Bu paddonda hozircha WIP yo‘q.',
                )
              else
                M3SegmentSpacedColumn(
                  children: [
                    for (var index = 0; index < data.items.length; index++)
                      _PaddonWipCard(
                        key: ValueKey(
                          'paddon-wip-card-${data.items[index].batchId}',
                        ),
                        slot:
                            M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index,
                          data.items.length,
                        ),
                        batch: data.items[index],
                        onRemove:
                            _busy ? null : () => _removeWip(data.items[index]),
                      ),
                  ],
                ),
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
    this.onAdd,
    this.onRemove,
  });

  final M3SegmentVerticalSlot slot;
  final AdminProgressBatch batch;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.view_carousel_outlined,
              color: scheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order: $orderId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
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
            if (onAdd != null)
              IconButton(
                key: ValueKey('paddon-add-wip-${batch.batchId}'),
                onPressed: onAdd,
                tooltip: 'Paddonga qo‘shish',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            if (onRemove != null)
              IconButton(
                key: ValueKey('paddon-remove-wip-${batch.batchId}'),
                onPressed: onRemove,
                tooltip: 'Paddondan chiqarish',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

String _batchTitle(AdminProgressBatch batch) {
  final orderId = batch.orderId.trim();
  if (orderId.isNotEmpty) {
    return 'Order: $orderId';
  }
  final epc = batch.qrPayload.trim();
  if (epc.isNotEmpty) {
    return 'EPC: $epc';
  }
  return 'WIP';
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
