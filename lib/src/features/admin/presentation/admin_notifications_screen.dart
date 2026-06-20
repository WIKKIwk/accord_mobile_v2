import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
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
  String? _expandedRequestId;
  final Set<String> _decidingRequestIds = {};
  StreamSubscription<String>? _liveSubscription;
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
      final requests =
          await MobileApi.instance.adminProductionMapCompletionRequests();
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
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
    final response = await MobileApi.instance.adminProductionMapLiveConnect();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw MobileApiException(
        code: 'production_map_live',
        message: 'Live ulanish ochilmadi',
        statusCode: response.statusCode,
      );
    }

    final completer = Completer<void>();
    final dataLines = <String>[];

    await _liveSubscription?.cancel();
    _liveSubscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (!mounted || generation != _liveGeneration) {
          return;
        }
        if (line.isEmpty) {
          if (dataLines.isEmpty) {
            return;
          }
          final payloadText = dataLines.join('\n');
          dataLines.clear();
          final payload = jsonDecode(payloadText) as Map<String, dynamic>;
          if (payload['ok'] != true) {
            return;
          }
          final snapshot = AdminProductionMapLiveSnapshot.fromJson(payload);
          setState(() {
            _requests = snapshot.completionRequests;
            _loading = false;
            _error = null;
          });
          return;
        }
        if (line.startsWith(':')) {
          return;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
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
        showAdminTopNotice(context, 'Tugatish so‘rovi hal qilinmadi');
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
      title: 'Bildirishnomalar',
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
              'Bildirishnoma yo‘q',
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
    required this.expanded,
    required this.deciding,
    required this.onExpandedChanged,
    required this.onApprove,
    required this.onReject,
  });

  final AdminCompletionRequestNotification request;
  final bool expanded;
  final bool deciding;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _requestDisplayCode(request);
    final worker = _actorLabel(
      displayName: request.workerDisplayName,
      role: request.workerRole,
      ref: request.workerRef,
    );
    final decisionRequired = request.decisionRequired;
    final title = decisionRequired
        ? '$code zakaz 0 holatda'
        : '$code laminatsiya qoldig‘i';
    final subtitle = decisionRequired
        ? '${request.apparatus.trim()} dagi $worker tugatishga urinyapti'
        : '${request.apparatus.trim()} dagi $worker ikkala qavat qoldig‘ini yozdi';

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
    required this.deciding,
    required this.onApprove,
    required this.onReject,
  });

  final AdminCompletionRequestNotification request;
  final bool deciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = <String>[
      if (request.orderTitle.trim().isNotEmpty)
        'Mahsulot: ${request.orderTitle.trim()}',
      if (request.productCode.trim().isNotEmpty)
        'Kod: ${request.productCode.trim()}',
      if (request.apparatus.trim().isNotEmpty)
        '${_apparatusDetailLabel(request.apparatus)}: ${request.apparatus.trim()}',
      'Ishchi: ${_actorLabel(
        displayName: request.workerDisplayName,
        role: request.workerRole,
        ref: request.workerRef,
      )}',
      if (_timeLabel(request.createdAtUnix).isNotEmpty)
        'Vaqt: ${_timeLabel(request.createdAtUnix)}',
    ];

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
              'Tugatishga ruxsat berasizmi?',
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
                    child: const Text('Rad etish'),
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
                        : const Text('Tasdiqlash'),
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

String _requestDisplayCode(AdminCompletionRequestNotification request) {
  final orderNumber = request.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final orderId = request.orderId.trim();
  if (orderId.isNotEmpty) {
    return orderId;
  }
  return 'Zakaz';
}

String _actorLabel({
  required String displayName,
  required String role,
  required String ref,
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
  return 'Ishchi';
}

String _timeLabel(int unix) {
  if (unix <= 0) {
    return '';
  }
  final time = DateTime.fromMillisecondsSinceEpoch(unix * 1000).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.day)}.${two(time.month)}.${time.year} '
      '${two(time.hour)}:${two(time.minute)}';
}

String _apparatusDetailLabel(String apparatus) {
  final normalized = apparatus.trim().toLowerCase();
  if (normalized.contains('laminatsiya')) {
    return 'Laminatsiya mashinasi';
  }
  if (normalized.contains('rezka')) {
    return 'Rezka mashinasi';
  }
  return 'Aparat';
}
