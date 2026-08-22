import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/session/state/app_session.dart';
import '../../../admin/logic/canonical_apparatus_display.dart';
import '../../../admin/presentation/admin_production_map_orders_screen.dart';
import '../../../shared/models/app_models.dart';
import '../../models/chat_models.dart';

class ChatOrderFreezeRequestCard extends StatefulWidget {
  const ChatOrderFreezeRequestCard({
    super.key,
    required this.data,
  });

  final OrderFreezeRequestCardData data;

  @override
  State<ChatOrderFreezeRequestCard> createState() =>
      _ChatOrderFreezeRequestCardState();
}

class _ChatOrderFreezeRequestCardState
    extends State<ChatOrderFreezeRequestCard> {
  late OrderFreezeRequestCardStatus _status;
  List<AdminApparatus> _apparatusCatalog = const [];
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _status = widget.data.status;
    unawaited(_loadApparatusCatalog());
  }

  Future<void> _loadApparatusCatalog() async {
    try {
      final apparatus = await MobileApi.instance.adminApparatus(limit: 10000);
      if (!mounted) return;
      setState(() => _apparatusCatalog = apparatus);
    } catch (_) {
      // The exact ApparatusId remains visible if its display projection fails.
    }
  }

  @override
  void didUpdateWidget(covariant ChatOrderFreezeRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.eventSequence != widget.data.eventSequence ||
        oldWidget.data.status != widget.data.status) {
      _status = widget.data.status;
    }
  }

  bool get _isTargetWorker {
    final profile = AppSession.instance.profile;
    return profile != null &&
        userRoleToJson(profile.role) == widget.data.targetWorkerRole.trim() &&
        profile.ref.trim() == widget.data.targetWorkerRef.trim();
  }

  bool get _isRequester {
    final profile = AppSession.instance.profile;
    return profile != null &&
        userRoleToJson(profile.role) == widget.data.requesterRole.trim() &&
        profile.ref.trim() == widget.data.requesterRef.trim();
  }

  Future<void> _pause() async {
    if (_actionInFlight || _status != OrderFreezeRequestCardStatus.pending) {
      return;
    }
    setState(() => _actionInFlight = true);
    try {
      final completed = await showProductionMapFreezePauseFlow(
        context,
        requestId: widget.data.requestId,
        orderId: widget.data.orderId,
        apparatus: widget.data.targetApparatus,
      );
      if (!mounted) return;
      if (completed) {
        setState(() => _status = OrderFreezeRequestCardStatus.frozen);
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _cancel() async {
    if (_actionInFlight || _status != OrderFreezeRequestCardStatus.pending) {
      return;
    }
    setState(() => _actionInFlight = true);
    try {
      await MobileApi.instance.adminProductionMapOrderControl(
        orderId: widget.data.orderId,
        action: AdminOrderControlAction.cancelFreeze,
      );
      if (!mounted) return;
      setState(() => _status = OrderFreezeRequestCardStatus.cancelled);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  void _showError(Object error) {
    final message =
        error is MobileApiException ? error.message : 'Amal bajarilmadi';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = _statusVisual(_status, scheme);
    final orderLabel = widget.data.orderNumber.trim().isEmpty
        ? widget.data.orderId.trim()
        : widget.data.orderNumber.trim();
    return Semantics(
      label: 'Buyurtmani muzlatish so‘rovi',
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.only(top: 10),
            elevation: 0,
            color: visual.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: visual.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: visual.iconBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            visual.icon,
                            color: visual.foreground,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buyurtmani muzlatish so‘rovi',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            _StatusChip(
                              label: visual.label,
                              foreground: visual.foreground,
                              background: visual.iconBackground,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Buyurtma', value: orderLabel),
                  if (widget.data.orderTitle.trim().isNotEmpty)
                    _InfoRow(
                      label: 'Nomi',
                      value: widget.data.orderTitle.trim(),
                    ),
                  _InfoRow(
                    label: 'Bosqich',
                    value: canonicalApparatusDisplayLabel(
                      widget.data.targetApparatus,
                      _apparatusCatalog,
                    ),
                  ),
                  _InfoRow(
                    label: 'Admin',
                    value: widget.data.requesterDisplayName.trim(),
                  ),
                  if (_status == OrderFreezeRequestCardStatus.pending &&
                      (_isTargetWorker || _isRequester)) ...[
                    const SizedBox(height: 14),
                    if (_isTargetWorker)
                      FilledButton.icon(
                        onPressed: _actionInFlight ? null : _pause,
                        icon: _actionInFlight
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.pause_rounded),
                        label: const Text('Pauza qilish'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    if (_isRequester)
                      OutlinedButton.icon(
                        onPressed: _actionInFlight ? null : _cancel,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('So‘rovni bekor qilish'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.iconBackground,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color iconBackground;
  final Color border;
}

_StatusVisual _statusVisual(
  OrderFreezeRequestCardStatus status,
  ColorScheme scheme,
) {
  return switch (status) {
    OrderFreezeRequestCardStatus.pending => _StatusVisual(
        label: 'Kutilmoqda',
        icon: Icons.ac_unit_rounded,
        foreground: scheme.primary,
        background: scheme.primaryContainer.withValues(alpha: 0.28),
        iconBackground: scheme.primaryContainer,
        border: scheme.primary.withValues(alpha: 0.35),
      ),
    OrderFreezeRequestCardStatus.frozen => _StatusVisual(
        label: 'Muzlatildi',
        icon: Icons.lock_rounded,
        foreground: scheme.onTertiaryContainer,
        background: scheme.tertiaryContainer.withValues(alpha: 0.45),
        iconBackground: scheme.tertiaryContainer,
        border: scheme.tertiary.withValues(alpha: 0.35),
      ),
    OrderFreezeRequestCardStatus.cancelled => _StatusVisual(
        label: 'Bekor qilindi',
        icon: Icons.cancel_outlined,
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest,
        iconBackground: scheme.surfaceContainerHigh,
        border: scheme.outlineVariant,
      ),
    OrderFreezeRequestCardStatus.unfrozen => _StatusVisual(
        label: 'Qayta faollashtirildi',
        icon: Icons.lock_open_rounded,
        foreground: scheme.onSecondaryContainer,
        background: scheme.secondaryContainer.withValues(alpha: 0.45),
        iconBackground: scheme.secondaryContainer,
        border: scheme.secondary.withValues(alpha: 0.35),
      ),
  };
}
