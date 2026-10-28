import 'dart:async';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/search/search_normalizer.dart';
import '../../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../admin/logic/canonical_apparatus_display.dart';
import '../../../admin/models/production_map_models.dart';
import '../../../shared/models/app_models.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'material_sheet_action_style.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/urdu_aware_text.dart';

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
  bool _checkingCandidates = false;
  bool _saving = false;
  Object? _error;
  Object? _candidateError;
  Future<void>? _apparatusLoad;
  bool _apparatusLoaded = false;
  int _loadGeneration = 0;

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
    final generation = ++_loadGeneration;
    final barcode = widget.barcode.trim();
    if (barcode.isEmpty) {
      if (mounted) {
        setState(() {
          _lookup = null;
          _candidateOrders = const [];
          _loading = false;
          _checkingCandidates = false;
          _error = null;
          _candidateError = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _checkingCandidates = false;
        _lookup = null;
        _candidateOrders = const [];
        _error = null;
        _candidateError = null;
      });
    }
    try {
      final lookup = await MobileApi.instance.adminRawMaterialLookup(
        barcode: barcode,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _lookup = lookup;
        _loading = false;
        _checkingCandidates =
            widget.allowAssignment && lookup.assignment == null;
        _error = null;
      });
      if (lookup.assignment != null) {
        unawaited(_ensureApparatusCatalog());
      } else if (widget.allowAssignment) {
        await _loadCandidates(generation);
      }
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _lookup = null;
        _candidateOrders = const [];
        _error = error;
      });
      _reportReadFailure('lookup', error);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCandidates(int generation) async {
    try {
      final orders =
          await MobileApi.instance.adminRawMaterialAssignmentCandidateOrders(
        barcode: widget.barcode.trim(),
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _candidateOrders = orders;
        _candidateError = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _candidateOrders = const [];
        _candidateError = error;
      });
      _reportReadFailure('candidate_orders', error);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _checkingCandidates = false);
      }
    }
  }

  Future<void> _ensureApparatusCatalog() {
    if (_apparatusLoaded) return Future<void>.value();
    return _apparatusLoad ??= _readApparatusCatalog();
  }

  Future<void> _readApparatusCatalog() async {
    try {
      final apparatus = await MobileApi.instance.adminApparatus(
        limit: 10000,
        retryTransient: true,
      );
      if (!mounted) return;
      setState(() {
        _apparatusCatalog = apparatus;
        _apparatusLoaded = true;
      });
    } catch (error) {
      // Names enrich the display; IDs and verified assignment state stay usable.
      _reportReadFailure('apparatus_names', error);
    } finally {
      _apparatusLoad = null;
    }
  }

  void _reportReadFailure(String phase, Object error) {
    final detail = error is MobileApiException
        ? 'code=${error.code} status=${error.statusCode}'
        : 'type=${error.runtimeType}';
    debugPrint('raw_material_assignment_read phase=$phase $detail');
  }

  Future<void> _openOrderPicker() async {
    if (_loading || _checkingCandidates || _candidateError != null ||
        _saving || _candidateOrders.isEmpty) {
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
          title: 'Buyurtmani tanlang',
          hintText: 'Buyurtma qidiring',
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
          title: 'Buyurtmaga ulash',
          message: '${_orderLabel(candidate.order)} buyurtmasiga ulansinmi?',
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
        _showNotice(context, 'Homashyo buyurtmaga ulandi');
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, 'Homashyoni buyurtmaga ulab bo‘lmadi');
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
          message: 'Bu homashyoni buyurtmadan uzasizmi?',
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
        _showNotice(context, 'Homashyo buyurtmadan uzildi');
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, 'Homashyoni buyurtmadan uzib bo‘lmadi');
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
    await _ensureApparatusCatalog();
    if (!mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) => M3PickerSheet<String>(
        key: const ValueKey('raw-material-apparatus-picker'),
        title: context.l10n.uiText('Apparatni tanlang'),
        hintText: context.l10n.adminText('apparatus.search'),
        items: options,
        itemTitle: (option) =>
            canonicalApparatusDisplayLabel(option, _apparatusCatalog),
        itemSubtitle: (_) => '',
        matchesQuery: (option, query) => searchMatches(query, [
          canonicalApparatusDisplayLabel(option, _apparatusCatalog),
        ]),
        onSelected: (option) => Navigator.of(context).pop(option),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assignment = _lookup?.assignment;
    final checking = _loading || _checkingCandidates;
    final readError = _error ?? _candidateError;
    final status = _loading
        ? 'Tekshirilmoqda...'
        : _error != null
            ? 'Xato'
            : assignment != null
                ? 'Ulangan'
                : 'Ulanmagan';
    final statusStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: _error != null && !_loading ? scheme.error : null,
    );
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const noCandidateMessage = 'Bu homashyoga mos faol buyurtma topilmadi';
    const errorMessage = 'Buyurtma ma’lumoti yuklanmadi';
    const candidateErrorMessage = 'Mos buyurtmalar yuklanmadi';
    final showNoCandidate = !_loading &&
        !_checkingCandidates &&
        !_saving &&
        readError == null &&
        assignment == null &&
        widget.allowAssignment &&
        _candidateOrders.isEmpty;

    // Reserve room for each status and message before the lookup completes.
    Widget measureText(String text, TextStyle? style) => IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: RichText(
                text: TextSpan(text: context.l10n.uiText(text), style: style),
                textScaler: MediaQuery.textScalerOf(context),
                textAlign: TextAlign.end,
              ),
            ),
          ),
        );

    Widget action;
    if (!checking && readError != null) {
      action = OutlinedButton.icon(
        key: const ValueKey('raw-material-assignment-retry'),
        style: materialSheetActionStyle,
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
        label: const UrduAwareText('Qayta urinish'),
      );
    } else if (assignment != null) {
      action = OutlinedButton.icon(
        key: const ValueKey('raw-material-unlink-button'),
        style: materialSheetActionStyle,
        onPressed: _saving ? null : () => _unlink(assignment),
        icon: _saving
            ? const AppLoadingIndicator(size: 20, glyphSize: 14)
            : const Icon(Icons.link_off_rounded),
        label: const UrduAwareText('Ulanishni uzish'),
      );
    } else {
      final button = FilledButton.icon(
        key: const ValueKey('raw-material-assign-order-button'),
        style: materialSheetActionStyle,
        onPressed: _loading ||
                _checkingCandidates ||
                readError != null ||
                _saving ||
                !widget.allowAssignment ||
                _candidateOrders.isEmpty
            ? null
            : _openOrderPicker,
        icon: _saving
            ? const AppLoadingIndicator(size: 20, glyphSize: 14)
            : const Icon(Icons.add_link_rounded),
        label: const UrduAwareText('Buyurtmaga ulash'),
      );
      action = checking
          ? _AssignmentLoadingShimmer(
              key: const ValueKey('raw-material-assignment-loading-shimmer'),
              child: button,
            )
          : button;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              !_loading && assignment == null
                  ? Icons.link_off_rounded
                  : Icons.link_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: UrduAwareText(
                'Buyurtma',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                alignment: AlignmentDirectional.centerEnd,
                children: [
                  measureText('Tekshirilmoqda...', statusStyle),
                  measureText('Ulangan', statusStyle),
                  measureText('Ulanmagan', statusStyle),
                  measureText('Xato', statusStyle),
                  UrduAwareText(
                    status,
                    textAlign: TextAlign.end,
                    style: statusStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 32),
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              measureText('Ulangan buyurtma', detailStyle),
              measureText(noCandidateMessage, detailStyle),
              measureText(errorMessage, detailStyle),
              measureText(candidateErrorMessage, detailStyle),
              if (assignment != null)
                SingleChildScrollView(
                  key: const ValueKey('raw-material-current-assignment'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _assignedOrderLabel(_lookup!, assignment),
                        style: detailStyle?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (assignment.apparatus.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          canonicalApparatusDisplayLabel(
                            assignment.apparatus,
                            _apparatusCatalog,
                          ),
                          style: detailStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              if (showNoCandidate)
                UrduAwareText(noCandidateMessage, style: detailStyle),
              if (!checking && readError != null)
                UrduAwareText(
                  _error != null ? errorMessage : candidateErrorMessage,
                  style: detailStyle?.copyWith(color: scheme.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: materialSheetActionGap),
        action,
      ],
    );
  }
}

class _AssignmentLoadingShimmer extends StatefulWidget {
  const _AssignmentLoadingShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<_AssignmentLoadingShimmer> createState() =>
      _AssignmentLoadingShimmerState();
}

class _AssignmentLoadingShimmerState extends State<_AssignmentLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlight =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);
    return Stack(
      children: [
        widget.child,
        if (!MediaQuery.of(context).disableAnimations)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final position = _controller.value * 4 - 2;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(position - 0.7, -0.4),
                          end: Alignment(position + 0.7, 0.4),
                          colors: [
                            Colors.transparent,
                            highlight,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
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
  final title = map.title.trim().isNotEmpty ? map.title.trim() : 'Buyurtma';
  return '$code · $title';
}

void _showNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
