import 'dart:async';
import 'aparatchi_paddon_transfer_screen.dart';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/spring_bottom_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import '../../shared/models/app_models.dart';
import 'aparatchi_paddon_detail_screen.dart';
import 'aparatchi_paddon_scope.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';
import '../../../core/localization/urdu_aware_text.dart';

typedef AparatchiPaddonsLoader = Future<List<AdminPaddon>> Function();

class AparatchiPaddonsScreen extends StatefulWidget {
  const AparatchiPaddonsScreen(
      {super.key, this.loader, this.apparatusId = '', this.apparatusName = ''});

  final AparatchiPaddonsLoader? loader;
  final String apparatusId;
  final String apparatusName;

  @override
  State<AparatchiPaddonsScreen> createState() => _AparatchiPaddonsScreenState();
}

class _AparatchiPaddonsScreenState extends State<AparatchiPaddonsScreen> {
  late Future<List<AdminPaddon>> _future;
  bool _creatingPaddon = false;
  bool _deletingPaddon = false;
  bool _canTransfer = false;
  late String _apparatusId;
  late String _apparatusName;
  List<AdminApparatus> _apparatusOptions = const [];
  int _loadGeneration = 0;

  bool get _needsApparatus =>
      widget.loader == null &&
      AppSession.instance.profile?.role == UserRole.aparatchi &&
      _apparatusId.isEmpty;

  String get _title => _apparatusName.isEmpty
      ? context.l10n.productionText('worker.paddons')
      : apparatusPaddonsTitle(context.l10n, _apparatusName);

  String get _routeName => _apparatusId.isEmpty
      ? AppRoutes.apparatusPaddons
      : apparatusPaddonsRoute(_apparatusId, apparatusName: _apparatusName);

  bool get _canDeletePaddon =>
      AppSession.instance.profile?.hasAnyCapability(
        const [
          'admin.access',
          'production.map.manage',
          'apparatus.queue.manage'
        ],
      ) ??
      false;

  @override
  void initState() {
    super.initState();
    _apparatusId = widget.apparatusId.trim();
    _apparatusName = widget.apparatusName.trim();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AparatchiPaddonsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apparatusId != widget.apparatusId ||
        oldWidget.loader != widget.loader) {
      _apparatusId = widget.apparatusId.trim();
      _apparatusName = widget.apparatusName.trim();
      _apparatusOptions = const [];
      _future = _load();
    }
  }

  Future<List<AdminPaddon>> _load() async {
    final scope = currentSessionReadScope();
    final generation = ++_loadGeneration;
    final loader = widget.loader;
    var canTransfer = false;
    final profile = AppSession.instance.profile;
    if (loader == null && profile?.role == UserRole.aparatchi) {
      final catalog = await MobileApi.instance.adminApparatus(limit: 10000);
      if (!mounted ||
          scope != currentSessionReadScope() ||
          generation != _loadGeneration) {
        return const [];
      }
      final options =
          assignedPaddonApparatus(catalog, profile!.assignedApparatus);
      _apparatusOptions = options;
      if (_apparatusId.isEmpty && options.length == 1) {
        _apparatusId = options.single.id;
        _apparatusName = options.single.name;
      } else if (_apparatusName.isEmpty) {
        for (final apparatus in options) {
          if (apparatus.id == _apparatusId) _apparatusName = apparatus.name;
        }
      }
      canTransfer = options.any((a) => a.id == _apparatusId) &&
          profile.hasAnyCapability(
              const ['admin.access', 'apparatus.queue.manage']);
    } else if (loader == null && profile?.role == UserRole.admin) {
      canTransfer = true;
    }
    final paddons = _needsApparatus
        ? const <AdminPaddon>[]
        : await (loader == null
            ? MobileApi.instance.adminPaddons(
                apparatus: _apparatusId,
              )
            : loader());
    if (mounted &&
        scope == currentSessionReadScope() &&
        generation == _loadGeneration) {
      setState(() => _canTransfer = canTransfer);
    }
    return _apparatusId.isEmpty
        ? paddons
        : paddons
            .where(
              (paddon) => paddon.apparatusId == _apparatusId,
            )
            .toList(growable: false);
  }

  Future<void> _openTransfer() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AparatchiPaddonTransferScreen(apparatusId: _apparatusId),
    ));
    if (mounted) await _retry();
  }

  Future<void> _retry() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the error state.
    }
  }

  Future<void> _openPaddon(AdminPaddon paddon) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.apparatusPaddonDetail,
      arguments: AparatchiPaddonDetailArgs(
        code: paddon.code,
        apparatusId: _apparatusId,
        apparatusName: _apparatusName,
      ),
    );
    if (mounted) {
      await _retry();
    }
  }

  Future<void> _createPaddon() async {
    if (_creatingPaddon || _needsApparatus) {
      return;
    }
    setState(() => _creatingPaddon = true);
    try {
      final paddon = await MobileApi.instance.adminPaddonCreate(
        apparatus: _apparatusId,
      );
      if (!mounted) {
        return;
      }
      await _openPaddon(paddon);
    } catch (error) {
      if (mounted) {
        _showError(
          error,
          fallback: context.l10n.productionText('worker.paddon.create_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creatingPaddon = false);
      }
    }
  }

  Future<void> _paddonActions(AdminPaddon paddon) async {
    if (_deletingPaddon || !_canDeletePaddon) return;
    setState(() => _deletingPaddon = true);
    try {
      final action = await showSpringBottomSheet<String>(
        context: context,
        builder: (_) => AppActionSheet<String>(
          title: paddon.code,
          actions: [
            AppActionSheetAction(
              title: context.l10n.adminText('action.delete'),
              icon: Icons.delete_outline_rounded,
              value: 'delete',
              destructive: true,
            ),
          ],
        ),
      );
      if (!mounted || action != 'delete') return;
      final confirmed = await showM3ConfirmDialog(
        context: context,
        title: context.l10n.productionText('worker.paddon.delete.title'),
        message: context.l10n.productionText(
          'worker.paddon.delete.body',
          values: {'code': paddon.code},
        ),
        cancelLabel: context.l10n.productionText('worker.action.cancel'),
        confirmLabel: context.l10n.adminText('action.delete'),
        confirmButtonKey: const ValueKey('paddon-delete-confirm'),
        destructive: true,
      );
      if (!mounted || confirmed != true) return;
      await MobileApi.instance.adminPaddonDelete(paddon.code);
      if (!mounted) return;
      await _retry();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.l10n.productionText('worker.paddon.deleted')),
        ));
    } catch (error) {
      if (mounted) {
        _showError(
          error,
          fallback: context.l10n.productionText('worker.paddon.delete_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingPaddon = false);
    }
  }

  void _showError(Object error, {required String fallback}) {
    final message = error is MobileApiException
        ? context.l10n.productionErrorMessage(error.code, fallback: fallback)
        : fallback;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _title,
      subtitle: context.l10n.productionText('worker.paddon.subtitle'),
      nativeTopBar: true,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 2,
        selectedRouteName: _routeName,
        apparatusLoader: () async => _apparatusOptions,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      bottom: AparatchiDock(
        activeTab: null,
        primaryActions: [
          if (_canTransfer)
            AdminFabMenuAction(
              title:
                  context.l10n.productionText('worker.paddon.transfer.title'),
              icon: Icons.swap_vert_rounded,
              enabled: !_creatingPaddon && !_deletingPaddon,
              onTap: () => unawaited(_openTransfer()),
            ),
          if (!_needsApparatus)
            AdminFabMenuAction(
              title: context.l10n.productionText('worker.paddon.create'),
              icon: Icons.add_rounded,
              enabled: !_creatingPaddon,
              onTap: () => unawaited(_createPaddon()),
            ),
        ],
      ),
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
            message: context.l10n.productionText('worker.paddon.load_failed'),
          );
        }
        final paddons = snapshot.data ?? const <AdminPaddon>[];
        if (_needsApparatus) {
          return RefreshIndicator(
            onRefresh: _retry,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final apparatus in _apparatusOptions)
                  Material(
                      child: ListTile(
                    key: ValueKey('paddon-apparatus-${apparatus.id}'),
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(
                        apparatusPaddonsTitle(context.l10n, apparatus.name)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => AdminDrawerNavigation.openRoute(
                        context,
                        apparatusPaddonsRoute(apparatus.id,
                            apparatusName: apparatus.name)),
                  )),
              ],
            ),
          );
        }
        final wipCount = paddons.fold<int>(
          0,
          (total, paddon) => total + paddon.itemCount,
        );
        return RefreshIndicator(
          onRefresh: _retry,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              4,
              4,
              4,
              MediaQuery.viewPaddingOf(context).bottom + 120,
            ),
            children: [
              _PaddonsSummary(
                paddonCount: paddons.length,
                wipCount: wipCount,
              ),
              const SizedBox(height: 18),
              Text(
                _title,
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
                        onLongPress: _canDeletePaddon && !_deletingPaddon
                            ? () => _paddonActions(paddons[index])
                            : null,
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
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.productionText('worker.paddon.location.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.productionText('worker.paddon.location.subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PaddonMetric(
                  label: context.l10n.productionText('worker.paddons'),
                  value: '$paddonCount',
                ),
                _PaddonMetric(
                  label: context.l10n.productionText('worker.daily.wip'),
                  value: '$wipCount',
                ),
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
        color: scheme.onSurface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: UrduAwareText(
          '$label: $value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
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
    this.onLongPress,
  });

  final M3SegmentVerticalSlot slot;
  final AdminPaddon paddon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 10, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 45),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: scheme.primary,
                size: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
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
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.productionText(
                        'worker.paddon.wip_count',
                        values: {'count': paddon.itemCount},
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
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
            Text(
              context.l10n.productionText('worker.paddon.empty.title'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.productionText('worker.paddon.empty.body'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
