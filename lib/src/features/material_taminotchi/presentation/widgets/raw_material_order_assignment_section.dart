import 'dart:async';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/search/search_normalizer.dart';
import '../../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../admin/logic/canonical_apparatus_display.dart';
import '../../../admin/models/production_map_models.dart';
import '../../../shared/models/app_models.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'package:flutter/material.dart';

class RawMaterialOrderAssignmentSection extends StatefulWidget {
  const RawMaterialOrderAssignmentSection({
    super.key,
    required this.barcode,
    required this.allowAssignment,
    this.onAssignmentChanged,
  });

  final String barcode;
  final bool allowAssignment;
  final Future<void> Function()? onAssignmentChanged;

  @override
  State<RawMaterialOrderAssignmentSection> createState() =>
      _RawMaterialOrderAssignmentSectionState();
}

class _RawMaterialOrderAssignmentSectionState
    extends State<RawMaterialOrderAssignmentSection> {
  AdminRawMaterialLookup? _lookup;
  List<AdminRawMaterialAssignmentOrderCandidate> _candidateOrders = const [];
  List<AdminApparatus> _apparatusCatalog = const [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RawMaterialOrderAssignmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barcode.trim().toUpperCase() !=
            widget.barcode.trim().toUpperCase() ||
        oldWidget.allowAssignment != widget.allowAssignment) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final barcode = widget.barcode.trim();
    if (barcode.isEmpty) {
      if (mounted) {
        setState(() {
          _lookup = null;
          _candidateOrders = const [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminRawMaterialLookup(barcode: barcode),
        MobileApi.instance.adminApparatus(limit: 10000),
      ]);
      final lookup = results[0] as AdminRawMaterialLookup;
      final apparatus = results[1] as List<AdminApparatus>;
      final candidateOrders = widget.allowAssignment &&
              lookup.assignment == null
          ? await MobileApi.instance.adminRawMaterialAssignmentCandidateOrders(
              barcode: barcode,
            )
          : const <AdminRawMaterialAssignmentOrderCandidate>[];
      if (!mounted ||
          widget.barcode.trim().toUpperCase() != barcode.toUpperCase()) {
        return;
      }
      setState(() {
        _lookup = lookup;
        _candidateOrders = candidateOrders;
        _apparatusCatalog = apparatus;
        _error = null;
      });
    } catch (error) {
      if (!mounted ||
          widget.barcode.trim().toUpperCase() != barcode.toUpperCase()) {
        return;
      }
      setState(() {
        _lookup = null;
        _candidateOrders = const [];
        _error = error;
      });
    } finally {
      if (mounted &&
          widget.barcode.trim().toUpperCase() == barcode.toUpperCase()) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openOrderPicker() async {
    if (_saving || _candidateOrders.isEmpty) {
      return;
    }
    final selected =
        await showModalBottomSheet<AdminRawMaterialAssignmentOrderCandidate>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<AdminRawMaterialAssignmentOrderCandidate>(
          title: 'Zakaz tanlang',
          hintText: 'Zakaz qidiring',
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? _candidateOrders
                : _candidateOrders.where((candidate) {
                    final map = candidate.order.map;
                    return searchMatches(normalizedQuery, [
                      map.id,
                      map.code,
                      map.orderNumber,
                      map.title,
                      map.productCode,
                      _orderLabel(candidate.order),
                    ]);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (candidate) => _orderLabel(candidate.order),
          itemSubtitle: (candidate) => candidate.order.map.id.trim(),
          onSelected: (candidate) => Navigator.of(context).pop(candidate),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    await _confirmAndAssign(selected);
  }

  Future<void> _confirmAndAssign(
    AdminRawMaterialAssignmentOrderCandidate candidate,
  ) async {
    final apparatus = await _selectApparatus(candidate.apparatusOptions);
    if (apparatus == null || !mounted) {
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Orderga ulash',
          message: '${_orderLabel(candidate.order)} zakaziga ulansinmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Ulash',
          verticalActions: true,
          confirmButtonKey: const ValueKey('raw-material-confirm-assignment'),
          confirmBackgroundColor: scheme.primary,
          confirmForegroundColor: scheme.onPrimary,
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: candidate.order.map.id,
        barcode: widget.barcode,
        apparatus: apparatus,
      );
      await _load();
      await widget.onAssignmentChanged?.call();
      if (mounted) {
        _showNotice(context, 'Homashyo zakazga ulandi');
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, 'Homashyoni zakazga ulab bo‘lmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _unlink(AdminRawMaterialAssignment assignment) async {
    if (_saving) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Homashyoni uzish',
          message: 'Bu homashyoni zakazdan uzasizmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Uzish',
          destructive: true,
          verticalActions: true,
          confirmButtonKey: const ValueKey('raw-material-confirm-unlink'),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminUnlinkRawMaterialAssignment(
        orderId: assignment.orderId,
        barcode: assignment.barcode,
      );
      await _load();
      await widget.onAssignmentChanged?.call();
      if (mounted) {
        _showNotice(context, 'Homashyo zakazdan uzildi');
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, 'Homashyoni zakazdan uzib bo‘lmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<String?> _selectApparatus(List<String> options) async {
    if (options.isEmpty) {
      return null;
    }
    if (options.length == 1) {
      return options.first;
    }
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Apparatni tanlang'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(
                canonicalApparatusDisplayLabel(option, _apparatusCatalog),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: AppLoadingIndicator(size: 30, glyphSize: 18)),
      );
    }
    if (_error != null) {
      return Row(
        children: [
          Icon(Icons.link_off_rounded, color: scheme.error),
          const SizedBox(width: 12),
          const Expanded(child: Text('Zakaz ma’lumoti yuklanmadi')),
          IconButton(
            key: const ValueKey('raw-material-assignment-retry'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Qayta urinish',
          ),
        ],
      );
    }
    final assignment = _lookup?.assignment;
    if (assignment != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('raw-material-current-assignment'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link_rounded, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ulangan zakaz',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _assignedOrderLabel(_lookup!, assignment),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (assignment.apparatus.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          canonicalApparatusDisplayLabel(
                            assignment.apparatus,
                            _apparatusCatalog,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('raw-material-unlink-button'),
            onPressed: _saving ? null : () => _unlink(assignment),
            icon: _saving
                ? const AppLoadingIndicator(size: 20, glyphSize: 14)
                : const Icon(Icons.link_off_rounded),
            label: const Text('Ulanishni uzish'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.link_off_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              'Zakaz',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              'Ulanmagan',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (widget.allowAssignment) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('raw-material-assign-order-button'),
            onPressed:
                _saving || _candidateOrders.isEmpty ? null : _openOrderPicker,
            icon: _saving
                ? const AppLoadingIndicator(size: 20, glyphSize: 14)
                : const Icon(Icons.add_link_rounded),
            label: const Text('Orderga ulash'),
          ),
          if (_candidateOrders.isEmpty && !_saving) ...[
            const SizedBox(height: 8),
            Text(
              'Bu homashyoga mos faol zakaz topilmadi',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

String _assignedOrderLabel(
  AdminRawMaterialLookup lookup,
  AdminRawMaterialAssignment assignment,
) {
  final order = lookup.order;
  if (order == null) {
    return assignment.orderId.trim();
  }
  final code = order.code.trim().isNotEmpty
      ? order.code.trim()
      : order.orderNumber.trim().isNotEmpty
          ? order.orderNumber.trim()
          : order.id.trim();
  final title = order.title.trim();
  return title.isEmpty ? code : '$code · $title';
}

String _orderLabel(ProductionMapSaved order) {
  final map = order.map;
  final code = map.code.trim().isNotEmpty
      ? map.code.trim()
      : map.orderNumber.trim().isNotEmpty
          ? map.orderNumber.trim()
          : map.id.trim();
  final title = map.title.trim().isNotEmpty ? map.title.trim() : 'Zakaz';
  return '$code · $title';
}

void _showNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
