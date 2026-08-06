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
import 'aparatchi_paddon_detail_screen.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

typedef AparatchiPaddonsLoader = Future<List<AdminPaddon>> Function();

class AparatchiPaddonsScreen extends StatefulWidget {
  const AparatchiPaddonsScreen({super.key, this.loader});

  final AparatchiPaddonsLoader? loader;

  @override
  State<AparatchiPaddonsScreen> createState() => _AparatchiPaddonsScreenState();
}

class _AparatchiPaddonsScreenState extends State<AparatchiPaddonsScreen> {
  late Future<List<AdminPaddon>> _future;
  bool _creatingPaddon = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminPaddon>> _load() {
    final loader = widget.loader;
    return loader == null ? MobileApi.instance.adminPaddons() : loader();
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

  Future<void> _openPaddon(AdminPaddon paddon) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.apparatusPaddonDetail,
      arguments: AparatchiPaddonDetailArgs(code: paddon.code),
    );
    if (mounted) {
      await _retry();
    }
  }

  Future<void> _scanPaddon() async {
    final value = await Navigator.of(context).pushNamed<String>(
      AppRoutes.adminProgressQrScan,
      arguments: const AdminProgressQrScanArgs(scanOnly: true),
    );
    final code = value?.trim() ?? '';
    if (code.isEmpty || !mounted) {
      return;
    }
    try {
      final snapshot = await MobileApi.instance.adminPaddonDetail(code);
      if (!mounted) {
        return;
      }
      await _openPaddon(snapshot.paddon);
    } catch (error) {
      if (mounted) {
        _showError(error, fallback: 'Bu QR paddon kodi emas');
      }
    }
  }

  Future<void> _createPaddon() async {
    if (_creatingPaddon) {
      return;
    }
    setState(() => _creatingPaddon = true);
    try {
      final paddon = await MobileApi.instance.adminPaddonCreate();
      if (!mounted) {
        return;
      }
      await _openPaddon(paddon);
    } catch (error) {
      if (mounted) {
        _showError(error, fallback: 'Paddon yaratilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _creatingPaddon = false);
      }
    }
  }

  void _showError(Object error, {required String fallback}) {
    final message = error is MobileApiException ? error.message : fallback;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Paddonlar',
      subtitle: 'WIP va rulonlarni fizik paddonlar bo‘yicha boshqarish',
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
    return FutureBuilder<List<AdminPaddon>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return AppRetryState(
            onRetry: _retry,
            message: 'Paddonlar ma’lumoti yuklanmadi',
          );
        }
        final paddons = snapshot.data ?? const <AdminPaddon>[];
        final wipCount = paddons.fold<int>(
          0,
          (total, paddon) => total + paddon.itemCount,
        );
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
              _PaddonsSummary(
                paddonCount: paddons.length,
                wipCount: wipCount,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('paddon-create'),
                      onPressed: _creatingPaddon ? null : _createPaddon,
                      icon: _creatingPaddon
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(
                        _creatingPaddon ? 'Yaratilmoqda...' : 'Yangi paddon',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('paddon-scan'),
                      onPressed: _scanPaddon,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('QR scan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Paddonlar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (paddons.isEmpty)
                const _PaddonsEmpty()
              else
                M3SegmentSpacedColumn(
                  children: [
                    for (var index = 0; index < paddons.length; index++)
                      _PaddonCard(
                        key: ValueKey('paddon-card-${paddons[index].code}'),
                        slot:
                            M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index,
                          paddons.length,
                        ),
                        paddon: paddons[index],
                        onTap: () => _openPaddon(paddons[index]),
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

class _PaddonsSummary extends StatelessWidget {
  const _PaddonsSummary({
    required this.paddonCount,
    required this.wipCount,
  });

  final int paddonCount;
  final int wipCount;

  @override
  Widget build(BuildContext context) {
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
              'Fizik joylashuv nazorati',
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Har bir paddon ichidagi WIP larni bitta joydan ko‘ring.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PaddonMetric(label: 'Paddon', value: '$paddonCount'),
                _PaddonMetric(label: 'WIP', value: '$wipCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaddonMetric extends StatelessWidget {
  const _PaddonMetric({required this.label, required this.value});

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

class _PaddonCard extends StatelessWidget {
  const _PaddonCard({
    super.key,
    required this.slot,
    required this.paddon,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminPaddon paddon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              color: scheme.primary,
              size: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          paddon.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (paddon.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      paddon.location,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${paddon.itemCount} ta WIP',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (paddon.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      paddon.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PaddonsEmpty extends StatelessWidget {
  const _PaddonsEmpty();

  @override
  Widget build(BuildContext context) {
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.top,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'Hali paddon yaratilmagan',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Yangi paddon bir bosishda yaratiladi. Code avtomatik beriladi, WIP larni esa keyin ichiga qo‘shasiz.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
