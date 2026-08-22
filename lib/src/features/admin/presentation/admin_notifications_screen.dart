import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import '../../../core/widgets/shell/app_shell.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  var _loading = true;
  Object? _error;
  List<AdminCompletionRequestNotification> _requests = const [];
  List<AdminApparatus> _apparatusCatalog = const [];
  String? _expandedRequestId;
  final Set<String> _decidingRequestIds = {};
  StreamSubscription<AdminProductionMapLiveSnapshot>? _liveSubscription;
  int _liveGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _startLiveStream();
  }

  @override
  void dispose() {
    _liveGeneration++;
    unawaited(_liveSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminProductionMapCompletionRequests(),
        MobileApi.instance.adminApparatus(limit: 10000),
      ]);
      final requests = results[0] as List<AdminCompletionRequestNotification>;
      final apparatus = results[1] as List<AdminApparatus>;
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
        _apparatusCatalog = apparatus;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _startLiveStream() {
    _liveGeneration++;
    unawaited(_runLiveStream(_liveGeneration));
  }

  Future<void> _runLiveStream(int generation) async {
    while (mounted && generation == _liveGeneration) {
      try {
        await _connectLiveStreamOnce(generation);
      } catch (_) {
        await _load();
      }
      if (!mounted || generation != _liveGeneration) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _connectLiveStreamOnce(int generation) async {
    final completer = Completer<void>();

    await _liveSubscription?.cancel();
    _liveSubscription =
        MobileApi.instance.adminProductionMapLiveEvents().listen(
      (snapshot) {
        if (!mounted || generation != _liveGeneration) {
          return;
        }
        setState(() {
          _requests = snapshot.completionRequests;
          _loading = false;
          _error = null;
        });
      },
      onError: (error, _) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  void _openDrawerRoute(String routeName) {
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  Future<void> _decideCompletionRequest(
    AdminCompletionRequestNotification request,
    String decision,
  ) async {
    final eventId = request.eventId.trim();
    if (eventId.isEmpty || _decidingRequestIds.contains(eventId)) {
      return;
    }
    setState(() {
      _decidingRequestIds.add(eventId);
    });
    try {
      final result =
          await MobileApi.instance.adminProductionMapCompletionRequestDecision(
        eventId: eventId,
        decision: decision,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _requests =
            _requests.where((item) => item.eventId.trim() != eventId).toList();
        _expandedRequestId = null;
      });
      showAdminTopNotice(context, result.message);
      unawaited(_load());
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('notification.completion_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _decidingRequestIds.remove(eventId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminNotifications,
        onNavigate: _openDrawerRoute,
      ),
      title: context.l10n.adminText('notification.title'),
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _requests.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null && _requests.isEmpty) {
      return AppRetryState(onRetry: _load);
    }

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 92;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPadding),
        children: [
          if (_requests.isEmpty)
            const _EmptyNotificationState()
          else
            for (var index = 0; index < _requests.length; index++) ...[
              _CompletionRequestNotificationCard(
                request: _requests[index],
                apparatusLabel: canonicalApparatusDisplayLabel(
                  _requests[index].apparatus,
                  _apparatusCatalog,
                ),
                expanded: _expandedRequestId == _requests[index].eventId.trim(),
                deciding: _decidingRequestIds.contains(
                  _requests[index].eventId.trim(),
                ),
                onExpandedChanged: (expanded) {
                  setState(() {
                    _expandedRequestId =
                        expanded ? _requests[index].eventId.trim() : null;
                  });
                },
                onApprove: () =>
                    _decideCompletionRequest(_requests[index], 'approve'),
                onReject: () =>
                    _decideCompletionRequest(_requests[index], 'reject'),
              ),
              if (index != _requests.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.48,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Text(
              context.l10n.adminText('notification.empty'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionRequestNotificationCard extends StatelessWidget {
  const _CompletionRequestNotificationCard({
    required this.request,
    required this.apparatusLabel,
    required this.expanded,
    required this.deciding,
    required this.onExpandedChanged,
    required this.onApprove,
    required this.onReject,
  });

  final AdminCompletionRequestNotification request;
  final String apparatusLabel;
  final bool expanded;
  final bool deciding;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final code = _requestDisplayCode(request, l10n);
    final worker = _actorLabel(
      displayName: request.workerDisplayName,
      role: request.workerRole,
      ref: request.workerRef,
      l10n: l10n,
    );
    final decisionRequired = request.decisionRequired;
    final hasZeroMetrics = request.zeroMetricCodes.isNotEmpty;
    final title = decisionRequired
        ? hasZeroMetrics
            ? l10n.adminText(
                'notification.title_zero_metrics',
                values: {'code': code},
              )
            : l10n.adminText(
                'notification.title_zero_state',
                values: {'code': code},
              )
        : l10n.adminText(
            'notification.title_remainder',
            values: {'code': code},
          );
    final subtitle = decisionRequired
        ? l10n.adminText(
            'notification.subtitle_attempt',
            values: {'apparatus': apparatusLabel, 'worker': worker},
          )
        : l10n.adminText(
            'notification.subtitle_remainder',
            values: {'apparatus': apparatusLabel, 'worker': worker},
          );

    return Material(
      color:
          (decisionRequired ? scheme.errorContainer : scheme.secondaryContainer)
              .withValues(alpha: 0.32),
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 6, expanded ? 8 : 10),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 34,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        decisionRequired
                            ? Icons.priority_high_rounded
                            : Icons.info_outline_rounded,
                        size: 20,
                        color: decisionRequired
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _CompletionRequestDetails(
                    request: request,
                    apparatusLabel: apparatusLabel,
                    deciding: deciding,
                    onApprove: onApprove,
                    onReject: onReject,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CompletionRequestDetails extends StatelessWidget {
  const _CompletionRequestDetails({
    required this.request,
    required this.apparatusLabel,
    required this.deciding,
    required this.onApprove,
    required this.onReject,
  });

  final AdminCompletionRequestNotification request;
  final String apparatusLabel;
  final bool deciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final lines = <String>[
      if (request.orderTitle.trim().isNotEmpty)
        l10n.adminText(
          'notification.item_line',
          values: {'value': request.orderTitle.trim()},
        ),
      if (request.productCode.trim().isNotEmpty)
        l10n.adminText(
          'notification.code_line',
          values: {'value': request.productCode.trim()},
        ),
      if (apparatusLabel.trim().isNotEmpty)
        l10n.adminText(
          'notification.apparatus_line',
          values: {'value': apparatusLabel.trim()},
        ),
      l10n.adminText(
        'notification.worker_line',
        values: {
          'value': _actorLabel(
            displayName: request.workerDisplayName,
            role: request.workerRole,
            ref: request.workerRef,
            l10n: l10n,
          ),
        },
      ),
      if (_timeLabel(request.createdAtUnix).isNotEmpty)
        l10n.adminText(
          'notification.time_line',
          values: {'value': _timeLabel(request.createdAtUnix)},
        ),
    ];
    final zeroMetricLabels = _zeroMetricLabels(
      request.zeroMetricCodes,
      l10n,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (zeroMetricLabels.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              l10n.adminText('notification.zero_metrics'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              zeroMetricLabels.join(', '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (request.description.trim().isNotEmpty)
            Text(
              request.description.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          const SizedBox(height: 14),
          if (request.decisionRequired) ...[
            Text(
              l10n.adminText('notification.approval_question'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: deciding ? null : onReject,
                    child: Text(l10n.adminText('notification.reject')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: deciding ? null : onApprove,
                    child: deciding
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.adminText('notification.confirm')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _requestDisplayCode(
  AdminCompletionRequestNotification request,
  AppLocalizations l10n,
) {
  final orderNumber = request.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final orderId = request.orderId.trim();
  if (orderId.isNotEmpty) {
    return orderId;
  }
  return l10n.adminText('notification.order_fallback');
}

String _actorLabel({
  required String displayName,
  required String role,
  required String ref,
  required AppLocalizations l10n,
}) {
  final name = displayName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final workerRef = ref.trim();
  if (workerRef.isNotEmpty) {
    return workerRef;
  }
  final workerRole = role.trim();
  if (workerRole.isNotEmpty) {
    return workerRole;
  }
  return l10n.adminText('notification.worker_fallback');
}

String _timeLabel(int unix) => formatUnixSecondsLocalDateTime(unix);

List<String> _zeroMetricLabels(
  List<String> codes,
  AppLocalizations l10n,
) {
  final labels = <String, String>{
    'produced_qty': l10n.productionText('worker.qr.passport.produced_quantity'),
    'gross_qty': l10n.productionText('worker.daily.field.weight'),
    'return_ink_kg': l10n.productionText('worker.qr.passport.returned_ink'),
    'lamination_print_leftover_rolls':
        l10n.productionText('worker.daily.field.print_leftover'),
    'lamination_film_leftover_rolls':
        l10n.productionText('worker.daily.field.film_leftover'),
    'rezka_bosma_waste': l10n.productionText('worker.daily.field.print_waste'),
    'rezka_lamination_waste':
        l10n.productionText('worker.daily.field.lamination_waste'),
    'rezka_edge_waste': l10n.productionText('worker.daily.field.edge_waste'),
    'total_waste': l10n.productionText('worker.daily.field.total_waste'),
    'finished_goods_kg':
        l10n.productionText('worker.qr.passport.finished_weight'),
    'finished_goods_meter':
        l10n.productionText('worker.qr.passport.finished_length'),
  };
  return [
    for (final code in codes) labels[code.trim()] ?? code.trim(),
  ].where((label) => label.isNotEmpty).toList(growable: false);
}
