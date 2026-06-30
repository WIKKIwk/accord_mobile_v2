import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipCheckoutsScreen extends StatefulWidget {
  const QolipCheckoutsScreen({super.key});

  @override
  State<QolipCheckoutsScreen> createState() => _QolipCheckoutsScreenState();
}

class _QolipCheckoutsScreenState extends State<QolipCheckoutsScreen> {
  late Future<List<QolipCheckoutEntry>> _checkoutsFuture;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _returning = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _checkoutsFuture = _loadCheckouts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<List<QolipCheckoutEntry>> _loadCheckouts() {
    return MobileApi.instance.qolipCheckouts(status: 'open', limit: 200);
  }

  Future<void> _reload() async {
    setState(() {
      _checkoutsFuture = _loadCheckouts();
    });
    await _checkoutsFuture;
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
      title: 'Qayerga qaytarasiz?',
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
            content: Text('${checkout.itemName} $normalizedCell ga qaytdi')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(error, fallback: 'Qolip qaytarilmadi'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _returning.remove(checkout.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Qarz daftari',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Qarzdan qidirish',
        onChanged: (value) {
          setState(() => _query = value.trim().toLowerCase());
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
        selectedIndex: 2,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: QolipDockTab.checkouts),
      contentPadding: EdgeInsets.zero,
      child: FutureBuilder<List<QolipCheckoutEntry>>(
        future: _checkoutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const _QolipDebtLoadingState();
          }
          if (snapshot.hasError) {
            return AppRetryState(
              onRetry: _reload,
              message: 'Qarz daftari yuklanmadi',
            );
          }
          final checkouts = snapshot.data ?? const <QolipCheckoutEntry>[];
          final visible = _filterCheckouts(checkouts, _query);
          if (checkouts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: const _QolipDebtEmptyState(message: 'Qarzda qolip yo‘q'),
            );
          }
          if (visible.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: const _QolipDebtEmptyState(message: 'Qidiruvda topilmadi'),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: _QolipDebtList(
              checkouts: visible,
              returning: _returning,
              onReturn: (checkout) {
                unawaited(_returnCheckout(checkout));
              },
            ),
          );
        },
      ),
    );
  }
}

List<QolipCheckoutEntry> _filterCheckouts(
  List<QolipCheckoutEntry> checkouts,
  String query,
) {
  if (query.isEmpty) {
    return checkouts;
  }
  return checkouts.where((checkout) {
    final haystack = [
      checkout.issuedToName,
      checkout.itemName,
      checkout.itemCode,
      checkout.qolipCode,
      checkout.block,
      checkout.warehouse,
      checkout.locationLabel,
      '${checkout.size}',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }).toList(growable: false);
}

class _QolipDebtList extends StatefulWidget {
  const _QolipDebtList({
    required this.checkouts,
    required this.returning,
    required this.onReturn,
  });

  final List<QolipCheckoutEntry> checkouts;
  final Set<String> returning;
  final ValueChanged<QolipCheckoutEntry> onReturn;

  @override
  State<_QolipDebtList> createState() => _QolipDebtListState();
}

class _QolipDebtListState extends State<_QolipDebtList> {
  String? _expandedCheckoutId;

  @override
  Widget build(BuildContext context) {
    final checkouts = widget.checkouts;
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
            for (var index = 0; index < checkouts.length; index++)
              _QolipDebtRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  checkouts.length,
                ),
                checkout: checkouts[index],
                index: index,
                expanded: _expandedCheckoutId == checkouts[index].id,
                returning: widget.returning.contains(checkouts[index].id),
                onExpandedChanged: (expanded) {
                  setState(() {
                    _expandedCheckoutId = expanded ? checkouts[index].id : null;
                  });
                },
                onReturn: () => widget.onReturn(checkouts[index]),
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
    required this.checkout,
    required this.index,
    required this.expanded,
    required this.returning,
    required this.onExpandedChanged,
    required this.onReturn,
  });

  final M3SegmentVerticalSlot slot;
  final QolipCheckoutEntry checkout;
  final int index;
  final bool expanded;
  final bool returning;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = checkout.locationLabel.isNotEmpty
        ? checkout.locationLabel
        : checkout.block;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final subtitle = <String>[
      checkout.issuedToName.trim().isEmpty
          ? 'Noma’lum qolipchi'
          : checkout.issuedToName.trim(),
      location,
      checkout.qolipCode,
      '${checkout.size}',
      _formatIssuedAt(checkout.issuedAt),
    ].where((value) => value.trim().isNotEmpty).join(' • ');
    final title = checkout.itemName.trim().isEmpty
        ? checkout.itemCode.trim()
        : checkout.itemName.trim();

    return Material(
      color: scheme.surface,
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
                            title,
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
                      '${checkout.quantity} ta',
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
                    checkout: checkout,
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
    required this.checkout,
    required this.returning,
    required this.onReturn,
  });

  final QolipCheckoutEntry checkout;
  final bool returning;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = checkout.locationLabel.isNotEmpty
        ? checkout.locationLabel
        : checkout.block;
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 4, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QolipDebtDetailLine(
            label: 'Kimga berilgan',
            value: checkout.issuedToName,
          ),
          _QolipDebtDetailLine(label: 'Mahsulot', value: checkout.itemName),
          _QolipDebtDetailLine(label: 'Item kodi', value: checkout.itemCode),
          _QolipDebtDetailLine(label: 'Qolip kodi', value: checkout.qolipCode),
          _QolipDebtDetailLine(label: 'Razmer', value: '${checkout.size}'),
          _QolipDebtDetailLine(label: 'Soni', value: '${checkout.quantity} ta'),
          _QolipDebtDetailLine(label: 'Blok', value: checkout.block),
          _QolipDebtDetailLine(label: 'Joy', value: location),
          _QolipDebtDetailLine(label: 'Ombor', value: checkout.warehouse),
          _QolipDebtDetailLine(
            label: 'Berilgan vaqt',
            value: _formatIssuedAt(checkout.issuedAt),
          ),
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
              label: const Text('Qaytar'),
            ),
          ),
          Text(
            'Checkout ID: ${checkout.id}',
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
            'Qarz daftari yuklanmoqda',
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
