import 'dart:async';
import 'dart:math' as math;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import 'package:flutter/material.dart';
import 'widgets/admin_shell.dart';

class AdminServerMonitorScreen extends StatefulWidget {
  const AdminServerMonitorScreen({super.key});

  @override
  State<AdminServerMonitorScreen> createState() =>
      _AdminServerMonitorScreenState();
}

class _AdminServerMonitorScreenState extends State<AdminServerMonitorScreen> {
  AdminServerMonitorReport? _report;
  Object? _error;
  bool _loading = true;
  bool _liveConnected = false;
  DateTime? _lastUpdated;
  final List<int> _latencySamples = <int>[];
  StreamSubscription<AdminServerMonitorLiveEvent>? _liveSubscription;
  int _liveGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSnapshot());
    _startLiveStream();
  }

  @override
  void dispose() {
    _liveGeneration++;
    unawaited(_liveSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    await _loadSnapshot();
    _startLiveStream();
  }

  Future<void> _loadSnapshot() async {
    try {
      final report = await MobileApi.instance.adminServerMonitor();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyReport(report);
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
      } catch (error) {
        if (!mounted || generation != _liveGeneration) {
          return;
        }
        setState(() {
          _liveConnected = false;
          _error = _report == null ? error : null;
        });
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
        MobileApi.instance.adminServerMonitorLiveEvents().listen(
      (report) {
        if (!mounted || generation != _liveGeneration) {
          return;
        }
        setState(() {
          final snapshot = report.report;
          if (snapshot != null) {
            _applyReport(snapshot);
          }
          final latency = report.latencyMs;
          if (latency != null) {
            _applyLatency(latency);
          }
          _loading = false;
          _liveConnected = true;
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

  void _applyReport(AdminServerMonitorReport report) {
    _report = report;
    _lastUpdated = DateTime.now();
  }

  void _applyLatency(int latencyMs) {
    if (latencyMs <= 0) {
      return;
    }
    _latencySamples.add(latencyMs);
    if (_latencySamples.length > 24) {
      _latencySamples.removeRange(0, _latencySamples.length - 24);
    }
  }

  void _goHomeOrPop() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushNamedAndRemoveUntil(AppRoutes.adminHome, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goHomeOrPop();
        }
      },
      child: AdminShell(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goHomeOrPop,
        ),
        title: 'Server holati',
        selectedRouteName: AppRoutes.adminServerMonitor,
        activeTab: null,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final report = _report;
    if (_loading && report == null) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null && report == null) {
      return AppRetryState(onRetry: _reload);
    }
    if (report == null) {
      return AppRetryState(onRetry: _reload);
    }

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: [
          _StatusSummaryPanel(
            report: report,
            liveConnected: _liveConnected,
            lastUpdated: _lastUpdated,
            latencySamples: _latencySamples,
          ),
          const SizedBox(height: 12),
          _TechnicalDetailsCard(
            report: report,
            initiallyExpanded: _error != null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _InlineWarning(message: _error.toString()),
          ],
          const SizedBox(height: 10),
          _LastUpdatedCard(
            liveConnected: _liveConnected,
            lastUpdated: _lastUpdated,
          ),
        ],
      ),
    );
  }
}

class _StatusSummaryPanel extends StatelessWidget {
  const _StatusSummaryPanel({
    required this.report,
    required this.liveConnected,
    required this.lastUpdated,
    required this.latencySamples,
  });

  final AdminServerMonitorReport report;
  final bool liveConnected;
  final DateTime? lastUpdated;
  final List<int> latencySamples;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final serverOk = report.server.status == 'running';
    final dbOk = report.database.reachable;
    final backupOk = report.backups.exists && report.backups.fileCount > 0;
    final allOk = liveConnected && serverOk && dbOk && backupOk;
    final score = _healthScore(
      liveConnected: liveConnected,
      serverOk: serverOk,
      dbOk: dbOk,
      backupOk: backupOk,
      cpuPercent: report.runtime.cpuPercent,
      memoryPercent: report.runtime.memoryPercent,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HealthDial(
                  value: score,
                  active: allOk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allOk ? 'Tizim barqaror' : 'Tekshiruv kerak',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: liveConnected ? 'Live' : 'Ulanmoqda',
                  active: liveConnected,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CompactStatusChip(
                    label: 'Server',
                    value: _serverStatusLabel(report.server.status),
                    ok: serverOk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatusChip(
                    label: 'Baza',
                    value: report.database.pingMs > 0
                        ? '${report.database.pingMs} ms'
                        : _databaseStatusLabel(report.database.status),
                    ok: dbOk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactStatusChip(
                    label: 'Backup',
                    value: '${report.backups.fileCount} fayl',
                    ok: backupOk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _UsageTicksPanel(
              label: 'CPU bosim',
              percent: report.runtime.cpuPercent,
              caption: _formatLoad(report.runtime.loadAverage),
            ),
            const SizedBox(height: 10),
            _DataVolumePanel(runtime: report.runtime),
            const SizedBox(height: 10),
            _DatabaseStatusPanel(database: report.database),
            const SizedBox(height: 10),
            _PingSparklinePanel(
              latencyMs: latencySamples.isEmpty ? 0 : latencySamples.last,
              samples: latencySamples,
              connected: liveConnected && report.database.reachable,
            ),
            const SizedBox(height: 10),
            _BackupCalendarPanel(backups: report.backups),
            const SizedBox(height: 12),
            _KeyValueLine(
                label: 'Oxirgi update', value: _formatLocal(lastUpdated)),
            _KeyValueLine(
              label: 'Uptime',
              value: _formatDuration(report.server.uptimeSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthDial extends StatelessWidget {
  const _HealthDial({
    required this.value,
    required this.active,
  });

  final int value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : const Color(0xFFB56B20);
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(92),
            painter: _HealthDialPainter(
              value: value,
              color: color,
              trackColor: scheme.outlineVariant.withValues(alpha: 0.68),
            ),
          ),
          Text(
            '$value%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
          ),
        ],
      ),
    );
  }
}

class _HealthDialPainter extends CustomPainter {
  const _HealthDialPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final int value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 7;
    final activeTicks = ((value.clamp(0, 100) / 100) * 28).round();
    for (var i = 0; i < 28; i++) {
      final angle = -math.pi * 0.78 + i * (math.pi * 1.56 / 27);
      final start = Offset(
        center.dx + math.cos(angle) * (radius - 8),
        center.dy + math.sin(angle) * (radius - 8),
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final paint = Paint()
        ..color = i < activeTicks ? color : trackColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthDialPainter oldDelegate) {
    return value != oldDelegate.value ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
  }
}

class _UsageTicksPanel extends StatelessWidget {
  const _UsageTicksPanel({
    required this.label,
    required this.percent,
    required this.caption,
  });

  final String label;
  final int percent;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safePercent = percent.clamp(0, 100);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$safePercent%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: CustomPaint(
                painter: _VolumeTicksPainter(
                  percent: safePercent,
                  color: _usageColor(context, safePercent),
                  trackColor: scheme.outlineVariant.withValues(alpha: 0.62),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStatusChip extends StatelessWidget {
  const _CompactStatusChip({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(context, ok);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataVolumePanel extends StatelessWidget {
  const _DataVolumePanel({required this.runtime});

  final AdminServerMonitorRuntime runtime;

  @override
  Widget build(BuildContext context) {
    final percent = runtime.diskPercent.clamp(0, 100);
    return _TickStatusPanel(
      title: 'SSD joy',
      percent: percent,
      color: _usageColor(context, percent),
      leadingText: '${_formatStorageMb(runtime.diskUsedMb)} band',
      trailingText: '${_formatStorageMb(runtime.diskTotalMb)} jami',
      footer: runtime.diskPath.trim().isEmpty
          ? null
          : _shortDiskPath(runtime.diskPath),
    );
  }
}

class _DatabaseStatusPanel extends StatelessWidget {
  const _DatabaseStatusPanel({required this.database});

  final AdminServerMonitorDatabase database;

  @override
  Widget build(BuildContext context) {
    final ok = database.reachable;
    return _TickStatusPanel(
      title: 'Ma’lumotlar bazasi',
      percent: ok ? 100 : 0,
      color: _statusColor(context, ok),
      leadingText: ok ? 'Ulangan' : 'Ulanmagan',
      trailingText: database.pingMs > 0
          ? '${database.pingMs} ms'
          : _databaseStatusLabel(database.status),
      footer: ok ? 'Saqlov ishlayapti' : database.error,
    );
  }
}

class _TickStatusPanel extends StatelessWidget {
  const _TickStatusPanel({
    required this.title,
    required this.percent,
    required this.color,
    required this.leadingText,
    required this.trailingText,
    this.footer,
  });

  final String title;
  final int percent;
  final Color color;
  final String leadingText;
  final String trailingText;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safePercent = percent.clamp(0, 100);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                  ),
                ),
                Text(
                  '$safePercent%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: CustomPaint(
                painter: _VolumeTicksPainter(
                  percent: safePercent,
                  color: color,
                  trackColor: scheme.outlineVariant.withValues(alpha: 0.62),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    leadingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  trailingText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (footer != null && footer!.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                footer!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeTicksPainter extends CustomPainter {
  const _VolumeTicksPainter({
    required this.percent,
    required this.color,
    required this.trackColor,
  });

  final int percent;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const tickCount = 42;
    final active = ((percent.clamp(0, 100) / 100) * tickCount).round();
    final tickWidth = size.width / (tickCount * 1.8);
    final gap = (size.width - tickWidth * tickCount) / (tickCount - 1);
    for (var i = 0; i < tickCount; i++) {
      final left = i * (tickWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 1, tickWidth, size.height - 2),
        const Radius.circular(999),
      );
      final paint = Paint()..color = i < active ? color : trackColor;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumeTicksPainter oldDelegate) {
    return percent != oldDelegate.percent ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
  }
}

class _PingSparklinePanel extends StatefulWidget {
  const _PingSparklinePanel({
    required this.latencyMs,
    required this.samples,
    required this.connected,
  });

  final int latencyMs;
  final List<int> samples;
  final bool connected;

  @override
  State<_PingSparklinePanel> createState() => _PingSparklinePanelState();
}

class _PingSparklinePanelState extends State<_PingSparklinePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<int> _fromSamples;
  late List<int> _toSamples;
  late int _fromLatencyMs;
  late int _toLatencyMs;

  @override
  void initState() {
    super.initState();
    _fromSamples = List<int>.of(widget.samples);
    _toSamples = List<int>.of(widget.samples);
    _fromLatencyMs = widget.latencyMs;
    _toLatencyMs = widget.latencyMs;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _PingSparklinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSamples = List<int>.of(widget.samples);
    final nextLatencyMs = widget.latencyMs;
    if (!_sameSamples(_toSamples, nextSamples) ||
        _toLatencyMs != nextLatencyMs) {
      final transition = Curves.easeOutCubic.transform(_controller.value);
      _fromSamples = _lerpSamples(_fromSamples, _toSamples, transition);
      _fromLatencyMs = _lerpInt(_fromLatencyMs, _toLatencyMs, transition);
      _toSamples = nextSamples;
      _toLatencyMs = nextLatencyMs;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final transition = Curves.easeOutCubic.transform(_controller.value);
            final latencyMs = _lerpInt(
              _fromLatencyMs,
              _toLatencyMs,
              transition,
            );
            return Column(
              children: [
                Row(
                  children: [
                    Icon(
                      widget.connected
                          ? Icons.arrow_forward_rounded
                          : Icons.sync_rounded,
                      color: _statusColor(context, widget.connected),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ping',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: _statusColor(context, widget.connected),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Text(
                      latencyMs > 0 ? '$latencyMs ms' : 'aniqlanmadi',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: CustomPaint(
                    painter: _PingSparklinePainter(
                      samples: _toSamples,
                      fromSamples: _fromSamples,
                      transition: transition,
                      lineColor: scheme.primary,
                      gridColor: scheme.outlineVariant.withValues(alpha: 0.7),
                      textColor: scheme.onSurfaceVariant,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<int> _lerpSamples(List<int> from, List<int> to, double transition) {
    final fallback = to.isEmpty ? from : to;
    final length = math.max(from.length, to.length);
    if (length == 0) {
      return <int>[];
    }
    return List<int>.generate(length, (index) {
      final fromValue = _sampleAt(from, fallback, index);
      final toValue = _sampleAt(to, fallback, index);
      return _lerpInt(fromValue, toValue, transition);
    });
  }

  int _lerpInt(int from, int to, double transition) {
    return (from + (to - from) * transition).round();
  }

  int _sampleAt(List<int> source, List<int> fallback, int index) {
    if (source.isEmpty) {
      return fallback[index.clamp(0, fallback.length - 1)];
    }
    if (index < source.length) {
      return source[index];
    }
    return source.last;
  }

  bool _sameSamples(List<int> a, List<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

class _PingSparklinePainter extends CustomPainter {
  const _PingSparklinePainter({
    required this.samples,
    required this.fromSamples,
    required this.transition,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<int> samples;
  final List<int> fromSamples;
  final double transition;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final graphWidth = size.width - 42;
    final graphRect = Rect.fromLTWH(0, 0, graphWidth, size.height);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = graphRect.top + graphRect.height * fraction;
      canvas.drawLine(
          Offset(graphRect.left, y), Offset(graphRect.right, y), gridPaint);
    }

    final values = samples.isEmpty ? const <int>[0] : samples;
    final maxValue = math.max(4, values.reduce(math.max));
    if (values.length == 1) {
      final y = _animatedPingY(graphRect, values, maxValue, 0);
      canvas.drawCircle(
          Offset(graphRect.left, y), 2.5, Paint()..color = lineColor);
    } else {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = graphRect.left + (graphRect.width * i / (values.length - 1));
        final y = _animatedPingY(graphRect, values, maxValue, i);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
    _drawAxisLabel(
        canvas, '${maxValue}ms', Offset(graphRect.right + 8, 0), textColor);
    _drawAxisLabel(
      canvas,
      '${(maxValue / 2).round()}ms',
      Offset(graphRect.right + 8, graphRect.height / 2 - 7),
      textColor,
    );
    _drawAxisLabel(canvas, '0ms',
        Offset(graphRect.right + 8, graphRect.height - 14), textColor);
  }

  double _pingY(Rect rect, int value, int maxValue) {
    final normalized = (value.clamp(0, maxValue) / maxValue).toDouble();
    return rect.bottom - normalized * rect.height;
  }

  double _animatedPingY(Rect rect, List<int> values, int maxValue, int index) {
    final fromValue = _sampleAt(fromSamples, values, index);
    final toValue = values[index];
    final value = fromValue + (toValue - fromValue) * transition;
    return _pingY(rect, value.round(), maxValue)
        .clamp(rect.top + 2, rect.bottom - 2)
        .toDouble();
  }

  int _sampleAt(List<int> source, List<int> fallback, int index) {
    if (source.isEmpty) {
      return fallback[index];
    }
    if (index < source.length) {
      return source[index];
    }
    return source.last;
  }

  void _drawAxisLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PingSparklinePainter oldDelegate) {
    return samples != oldDelegate.samples ||
        fromSamples != oldDelegate.fromSamples ||
        transition != oldDelegate.transition ||
        lineColor != oldDelegate.lineColor ||
        gridColor != oldDelegate.gridColor ||
        textColor != oldDelegate.textColor;
  }
}

class _BackupCalendarPanel extends StatelessWidget {
  const _BackupCalendarPanel({required this.backups});

  final AdminServerMonitorBackups backups;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final files = backups.files.isEmpty && backups.latest != null
        ? [backups.latest!]
        : backups.files;
    final days = _backupDays(files);
    final backedUpDays = days.where((day) => day.count > 0).length;
    final ok = backups.exists && backups.fileCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Backup',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
              Text(
                '$backedUpDays/7 kun',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 34,
              child: CustomPaint(
                painter: _BackupCalendarPainter(
                  days: days,
                  activeColor: _statusColor(context, ok),
                  todayColor: scheme.onSurface,
                  trackColor: scheme.outlineVariant.withValues(alpha: 0.58),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  backups.latest == null
                      ? 'Oxirgi backup yo‘q'
                      : 'Oxirgi backup: ${_shortBackupAgeLabel(backups.latest!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '${backups.fileCount} ta fayl',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_BackupDay> _backupDays(List<AdminServerMonitorBackupFile> files) {
    final today = _dateOnly(DateTime.now());
    final counts = <DateTime, int>{};
    for (final file in files) {
      if (file.modifiedAtUnix <= 0) {
        continue;
      }
      final day = _dateOnly(
        DateTime.fromMillisecondsSinceEpoch(
          file.modifiedAtUnix * 1000,
        ).toLocal(),
      );
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return List<_BackupDay>.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return _BackupDay(
        count: counts[day] ?? 0,
        isToday: index == 6,
      );
    });
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _BackupDay {
  const _BackupDay({
    required this.count,
    required this.isToday,
  });

  final int count;
  final bool isToday;
}

class _BackupCalendarPainter extends CustomPainter {
  const _BackupCalendarPainter({
    required this.days,
    required this.activeColor,
    required this.todayColor,
    required this.trackColor,
  });

  final List<_BackupDay> days;
  final Color activeColor;
  final Color todayColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const segmentCount = 7;
    const gap = 6.0;
    final segmentWidth = (size.width - gap * (segmentCount - 1)) / segmentCount;

    for (var index = 0; index < math.min(days.length, segmentCount); index++) {
      final day = days[index];
      final left = index * (segmentWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, segmentWidth, size.height),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = day.count > 0
              ? activeColor.withValues(alpha: day.count > 1 ? 0.95 : 0.78)
              : trackColor,
      );
      if (day.isToday) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = todayColor.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackupCalendarPainter oldDelegate) {
    return days != oldDelegate.days ||
        activeColor != oldDelegate.activeColor ||
        todayColor != oldDelegate.todayColor ||
        trackColor != oldDelegate.trackColor;
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({
    required this.report,
    required this.initiallyExpanded,
  });

  final AdminServerMonitorReport report;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.tune_rounded),
          title: Text(
            'Texnik tafsilotlar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: const Text('Bind, backup papkasi va xato matnlari'),
          children: [
            _MonitorRow(
                label: 'Server',
                value: _serverStatusLabel(report.server.status)),
            _MonitorRow(label: 'Bind', value: report.server.bindAddr),
            _MonitorRow(
              label: 'Boshlangan vaqt',
              value: _formatUnix(report.server.startedAtUnix),
            ),
            _MonitorRow(
              label: 'DB holati',
              value: _databaseStatusLabel(report.database.status),
            ),
            _MonitorRow(
              label: 'DB ping',
              value: report.database.pingMs > 0
                  ? '${report.database.pingMs} ms'
                  : 'Aniqlanmadi',
            ),
            _MonitorRow(
              label: 'CPU bosim',
              value: '${report.runtime.cpuPercent.clamp(0, 100)}%',
            ),
            _MonitorRow(
              label: 'Xotira',
              value: report.runtime.memoryTotalMb > 0
                  ? '${report.runtime.memoryUsedMb} / ${report.runtime.memoryTotalMb} MB (${report.runtime.memoryPercent.clamp(0, 100)}%)'
                  : 'Aniqlanmadi',
            ),
            _MonitorRow(
              label: 'Load average',
              value: _formatLoad(report.runtime.loadAverage),
            ),
            if (report.database.error.trim().isNotEmpty)
              _MonitorRow(label: 'DB xato', value: report.database.error),
            _MonitorRow(
                label: 'Backup papkasi', value: report.backups.directory),
            _MonitorRow(
              label: 'Backup fayllar',
              value: '${report.backups.fileCount} ta',
            ),
            if (report.backups.latest != null) ...[
              _MonitorRow(
                label: 'Oxirgi backup',
                value: report.backups.latest!.name,
              ),
              _MonitorRow(
                label: 'Yangilangan',
                value: _formatUnix(report.backups.latest!.modifiedAtUnix),
              ),
              _MonitorRow(
                label: 'Hajm',
                value: _formatBytes(report.backups.latest!.sizeBytes),
              ),
            ],
            if (report.backups.error.trim().isNotEmpty)
              _MonitorRow(label: 'Backup xato', value: report.backups.error),
          ],
        ),
      ),
    );
  }
}

class _LastUpdatedCard extends StatelessWidget {
  const _LastUpdatedCard({
    required this.liveConnected,
    required this.lastUpdated,
  });

  final bool liveConnected;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              liveConnected ? Icons.wifi_tethering_rounded : Icons.sync_rounded,
              color: _statusColor(context, liveConnected),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                liveConnected
                    ? 'Live WebSocket ulangan. Yangilandi: ${_formatLocal(lastUpdated)}'
                    : 'Live aloqa qayta ulanmoqda. Oxirgi ma\'lumot: ${_formatLocal(lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 42,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 58,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.15)
            : scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? scheme.onPrimaryContainer : scheme.error,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, bool ok) {
  final scheme = Theme.of(context).colorScheme;
  return ok ? scheme.primary : scheme.error;
}

int _healthScore({
  required bool liveConnected,
  required bool serverOk,
  required bool dbOk,
  required bool backupOk,
  required int cpuPercent,
  required int memoryPercent,
}) {
  var score = 0;
  if (liveConnected) {
    score += 16;
  }
  if (serverOk) {
    score += 22;
  }
  if (dbOk) {
    score += 22;
  }
  if (backupOk) {
    score += 16;
  }
  score += _resourceScore(cpuPercent, 12);
  score += _resourceScore(memoryPercent, 12);
  return score.clamp(0, 100);
}

int _resourceScore(int percent, int weight) {
  if (percent <= 0) {
    return weight;
  }
  if (percent >= 95) {
    return 0;
  }
  if (percent >= 85) {
    return (weight * 0.35).round();
  }
  if (percent >= 70) {
    return (weight * 0.7).round();
  }
  return weight;
}

String _formatLoad(double value) {
  if (value <= 0) {
    return 'load 0.00';
  }
  return 'load ${value.toStringAsFixed(2)}';
}

String _formatStorageMb(int value) {
  if (value <= 0) {
    return '0 GB';
  }
  final gb = value / 1024;
  if (gb >= 100) {
    return '${gb.toStringAsFixed(0)} GB';
  }
  if (gb >= 10) {
    return '${gb.toStringAsFixed(1)} GB';
  }
  return '${gb.toStringAsFixed(2)} GB';
}

String _shortDiskPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final parts = trimmed.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length <= 3) {
    return trimmed;
  }
  return '.../${parts.sublist(parts.length - 3).join('/')}';
}

Color _usageColor(BuildContext context, int percent) {
  final scheme = Theme.of(context).colorScheme;
  if (percent >= 90) {
    return scheme.error;
  }
  if (percent >= 75) {
    return const Color(0xFFB56B20);
  }
  return scheme.primary;
}

String _shortBackupAgeLabel(AdminServerMonitorBackupFile backup) {
  final days = backup.ageSeconds ~/ Duration.secondsPerDay;
  if (days > 0) {
    return '$days kun oldin';
  }
  final hours = backup.ageSeconds ~/ Duration.secondsPerHour;
  if (hours > 0) {
    return '$hours soat oldin';
  }
  final minutes = backup.ageSeconds ~/ Duration.secondsPerMinute;
  if (minutes > 0) {
    return '$minutes daqiqa oldin';
  }
  return 'hozir';
}

String _serverStatusLabel(String status) {
  switch (status.trim()) {
    case 'running':
      return 'Faol';
    default:
      return 'To‘xtagan';
  }
}

String _databaseStatusLabel(String status) {
  switch (status.trim()) {
    case 'online':
      return 'Ulangan';
    case 'offline':
      return 'Ulanmadi';
    case 'unavailable':
      return 'Mavjud emas';
    default:
      return status.trim().isEmpty ? 'Noma\'lum' : status.trim();
  }
}

String _formatUnix(int unixSeconds) {
  if (unixSeconds <= 0) {
    return 'Aniqlanmadi';
  }
  return formatUnixSecondsLocalDateTime(unixSeconds);
}

String _formatLocal(DateTime? value) {
  if (value == null) {
    return 'Kutilmoqda';
  }
  return formatLocalDateTime(value);
}

String _formatDuration(int seconds) {
  if (seconds <= 0) {
    return '0 soniya';
  }
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final parts = <String>[];
  if (days > 0) {
    parts.add('$days kun');
  }
  if (hours > 0) {
    parts.add('$hours soat');
  }
  if (minutes > 0) {
    parts.add('$minutes daqiqa');
  }
  if (parts.isEmpty) {
    parts.add('$seconds soniya');
  }
  return parts.join(' ');
}

String _formatBytes(int value) {
  if (value <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = value.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  if (unitIndex == 0) {
    return '${size.toStringAsFixed(0)} ${units[unitIndex]}';
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
}
