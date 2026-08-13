import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import '../qolip_search_matcher.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class _QolipDebtEntry {
  const _QolipDebtEntry.checkout(this.checkout) : orderNote = null;

  const _QolipDebtEntry.draft(this.orderNote) : checkout = null;

  final QolipCheckoutEntry? checkout;
  final AdminQolipOrderNote? orderNote;

  bool get isDraft => orderNote != null;

  String get id => checkout?.id ?? 'order-note:${orderNote!.orderId}';

  String get title {
    final itemName = checkout?.itemName ?? orderNote!.itemName;
    if (itemName.trim().isNotEmpty) {
      return itemName.trim();
    }
    return checkout?.itemCode ?? orderNote!.itemCode;
  }

  String get itemCode => checkout?.itemCode ?? orderNote!.itemCode;

  int get quantity => checkout?.quantity ?? orderNote!.qolipCodes.length;

  String get issuedAt => checkout?.issuedAt ?? orderNote!.updatedAt;

  List<String> get qolipCodes =>
      checkout == null ? orderNote!.qolipCodes : <String>[checkout!.qolipCode];
}

class QolipCheckoutsScreen extends StatefulWidget {
  const QolipCheckoutsScreen({super.key});

  @override
  State<QolipCheckoutsScreen> createState() => _QolipCheckoutsScreenState();
}

class _QolipCheckoutsScreenState extends State<QolipCheckoutsScreen> {
  late Future<List<_QolipDebtEntry>> _debtsFuture;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _returning = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _debtsFuture = _loadDebts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<List<_QolipDebtEntry>> _loadDebts() async {
    final checkoutsFuture = MobileApi.instance.qolipCheckouts(
      status: 'open',
      limit: 200,
    );
    // Sequence cards receive the current principal's order notes as part of
    // the queue snapshot. Reuse that same source here so the debt book cannot
    // disagree with the status already shown on the sequence page.
    final snapshotFuture = MobileApi.instance.adminProductionMapQueueSnapshot();
    final checkouts = await checkoutsFuture;
    final snapshot = await snapshotFuture;
    return [
      for (final checkout in checkouts) _QolipDebtEntry.checkout(checkout),
      for (final note in snapshot.qolipOrderNotes.values)
        if (note.isGiven) _QolipDebtEntry.draft(note),
    ];
  }

  Future<void> _reload() async {
    setState(() {
      _debtsFuture = _loadDebts();
    });
    await _debtsFuture;
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _returnCheckout(QolipCheckoutEntry checkout) async {
    if (_returning.contains(checkout.id)) {
      return;
    }
    final cellLabel = await showQolipCellPickerSheet(
      context,
      title: context.l10n.qolipText('checkouts.return_to'),
    );
    if (!mounted || cellLabel == null) {
      return;
    }
    final normalizedCell = normalizeQolipCellLabel(cellLabel);
    final columnNumber = normalizedCell == null
        ? null
        : int.tryParse(normalizedCell.substring(1));
    if (normalizedCell == null || columnNumber == null) {
      return;
    }
    setState(() => _returning.add(checkout.id));
    try {
      await MobileApi.instance.qolipReturnCheckout(
        checkout.id,
        rowLetter: normalizedCell.substring(0, 1),
        columnNumber: columnNumber,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.qolipText(
              'checkouts.returned',
              values: {
                'item': checkout.itemName,
                'cell': normalizedCell,
              },
            ),
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(
              error,
              fallback: context.l10n.qolipText('checkouts.return_failed'),
              l10n: context.l10n,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _returning.remove(checkout.id));
      }
    }
  }

  Future<void> _returnDraft(_QolipDebtEntry debt) async {
    final note = debt.orderNote;
    if (note == null || _returning.contains(debt.id)) {
      return;
    }
    setState(() => _returning.add(debt.id));
    try {
      await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
        orderId: note.orderId,
        status: 'returned',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.qolipText(
              'checkouts.draft_returned',
              values: {'item': debt.title},
            ),
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is MobileApiException
                ? error.message
                : context.l10n.qolipText('checkouts.draft_return_failed'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _returning.remove(debt.id));
      }
    }
  }

  Future<void> _returnDebt(_QolipDebtEntry debt) async {
    if (debt.isDraft) {
      await _returnDraft(debt);
      return;
    }
    final checkout = debt.checkout;
    if (checkout != null) {
      await _returnCheckout(checkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.qolipText('checkouts.title'),
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: l10n.qolipText('checkouts.search'),
        onChanged: (value) {
          setState(() => _query = value.trim());
        },
        onClear: () {
          _searchController.clear();
          setState(() => _query = '');
        },
        onBackWithContext: (context) =>
            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
        leadingIcon: Icons.menu_rounded,
        leadingTooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
        searchCloseKey: const ValueKey('qolip-checkouts-search-close'),
      ),
      drawer: QolipNavigationDrawer(
        selectedIndex: 3,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: FutureBuilder<List<_QolipDebtEntry>>(
        future: _debtsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const _QolipDebtLoadingState();
          }
          if (snapshot.hasError) {
            return AppRetryState(
              onRetry: _reload,
              message: l10n.qolipText('checkouts.load_failed'),
            );
          }
          final debts = snapshot.data ?? const <_QolipDebtEntry>[];
          final visible = _filterDebts(debts, _query);
          if (debts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: _QolipDebtEmptyState(
                message: l10n.qolipText('checkouts.empty'),
              ),
            );
          }
          if (visible.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: _QolipDebtEmptyState(
                message: l10n.qolipText('checkouts.search_empty'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: _QolipDebtList(
              debts: visible,
              returning: _returning,
              onReturn: (debt) {
                unawaited(_returnDebt(debt));
              },
            ),
          );
        },
      ),
    );
  }
}

List<_QolipDebtEntry> _filterDebts(
  List<_QolipDebtEntry> debts,
  String query,
) {
  if (query.isEmpty) {
    return debts;
  }
  return debts.where((debt) {
    final checkout = debt.checkout;
    if (checkout != null) {
      return qolipCheckoutSearchMatches(query, checkout);
    }
    final note = debt.orderNote!;
    return qolipSearchMatches(query, [
      note.orderId,
      note.itemCode,
      note.itemName,
      ...note.qolipCodes,
    ]);
  }).toList(growable: false);
}

class _QolipDebtList extends StatefulWidget {
  const _QolipDebtList({
    required this.debts,
    required this.returning,
    required this.onReturn,
  });

  final List<_QolipDebtEntry> debts;
  final Set<String> returning;
  final ValueChanged<_QolipDebtEntry> onReturn;

  @override
  State<_QolipDebtList> createState() => _QolipDebtListState();
}

class _QolipDebtListState extends State<_QolipDebtList> {
  String? _expandedDebtId;

  @override
  Widget build(BuildContext context) {
    final debts = widget.debts;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        4,
        4,
        4,
        MediaQuery.viewPaddingOf(context).bottom + 112,
      ),
      children: [
        M3SegmentSpacedColumn(
          children: [
            for (var index = 0; index < debts.length; index++)
              _QolipDebtRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  debts.length,
                ),
                debt: debts[index],
                index: index,
                expanded: _expandedDebtId == debts[index].id,
                returning: widget.returning.contains(debts[index].id),
                onExpandedChanged: (expanded) {
                  setState(() {
                    _expandedDebtId = expanded ? debts[index].id : null;
                  });
                },
                onReturn: () => widget.onReturn(debts[index]),
              ),
          ],
        ),
      ],
    );
  }
}

class _QolipDebtRow extends StatelessWidget {
  const _QolipDebtRow({
    required this.slot,
    required this.debt,
    required this.index,
    required this.expanded,
    required this.returning,
    required this.onExpandedChanged,
    required this.onReturn,
  });

  final M3SegmentVerticalSlot slot;
  final _QolipDebtEntry debt;
  final int index;
  final bool expanded;
  final bool returning;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final checkout = debt.checkout;
    final note = debt.orderNote;
    final location = checkout == null
        ? ''
        : checkout.locationLabel.isNotEmpty
            ? checkout.locationLabel
            : checkout.block;
    final subtitle = note != null
        ? <String>[
            l10n.qolipText('checkouts.draft'),
            l10n.qolipText(
              'checkouts.order',
              values: {'id': note.orderId},
            ),
            l10n.qolipCount(debt.quantity),
            _formatIssuedAt(note.updatedAt),
          ].where((value) => value.trim().isNotEmpty).join(' • ')
        : <String>[
            checkout!.issuedToName.trim().isEmpty
                ? l10n.qolipText('checkouts.unknown_worker')
                : checkout.issuedToName.trim(),
            location,
            checkout.qolipCode,
            '${checkout.size}',
            _formatIssuedAt(checkout.issuedAt),
          ].where((value) => value.trim().isNotEmpty).join(' • ');
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: note != null ? scheme.tertiaryContainer : scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 48),
                child: Row(
                  children: [
                    _QolipDebtIndexBadge(index: index),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            debt.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.qolipCount(debt.quantity),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _QolipDebtDetail(
                    debt: debt,
                    returning: returning,
                    onReturn: onReturn,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _QolipDebtIndexBadge extends StatelessWidget {
  const _QolipDebtIndexBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _QolipDebtDetail extends StatelessWidget {
  const _QolipDebtDetail({
    required this.debt,
    required this.returning,
    required this.onReturn,
  });

  final _QolipDebtEntry debt;
  final bool returning;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final checkout = debt.checkout;
    final note = debt.orderNote;
    final location = checkout == null
        ? ''
        : checkout.locationLabel.isNotEmpty
            ? checkout.locationLabel
            : checkout.block;
    final detailLines = note != null
        ? <Widget>[
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.debt_type'),
              value: l10n.qolipText('checkouts.order_draft'),
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.order_label'),
              value: note.orderId,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.product'),
              value: note.itemName,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.item_code'),
              value: note.itemCode,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.mold_codes'),
              value: note.qolipCodes.join(', '),
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.quantity'),
              value: l10n.qolipCount(note.qolipCodes.length),
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.issued_at'),
              value: _formatIssuedAt(note.updatedAt),
            ),
          ]
        : <Widget>[
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.issued_to'),
              value: checkout!.issuedToName,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.product'),
              value: checkout.itemName,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.item_code'),
              value: checkout.itemCode,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.mold_code'),
              value: checkout.qolipCode,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.size'),
              value: '${checkout.size}',
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.quantity'),
              value: l10n.qolipCount(checkout.quantity),
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.block'),
              value: checkout.block,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.cell'),
              value: location,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.warehouse'),
              value: checkout.warehouse,
            ),
            _QolipDebtDetailLine(
              label: l10n.qolipText('checkouts.issued_at'),
              value: _formatIssuedAt(checkout.issuedAt),
            ),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 4, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...detailLines,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: returning ? null : onReturn,
              icon: returning
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_return_rounded, size: 18),
              label: Text(
                note != null
                    ? l10n.qolipText('action.return_molds')
                    : l10n.qolipText('action.return'),
              ),
            ),
          ),
          Text(
            '${note != null ? l10n.qolipText('checkouts.order_id') : l10n.qolipText('checkouts.checkout_id')}: ${debt.id.replaceFirst('order-note:', '')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QolipDebtDetailLine extends StatelessWidget {
  const _QolipDebtDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final clean = value.trim();
    if (clean.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            height: 1.3,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: clean),
          ],
        ),
      ),
    );
  }
}

class _QolipDebtEmptyState extends StatelessWidget {
  const _QolipDebtEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
      children: [
        Icon(
          Icons.assignment_turned_in_outlined,
          size: 48,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _QolipDebtLoadingState extends StatelessWidget {
  const _QolipDebtLoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoadingIndicator(),
          const SizedBox(height: 12),
          Text(
            context.l10n.qolipText('checkouts.loading'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatIssuedAt(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
}
