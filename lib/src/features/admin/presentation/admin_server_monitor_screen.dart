import 'dart:async';
import 'dart:math' as math;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/files/backup_file_saver.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _startingBackup = false;
  String? _downloadingBackupId;
  double _downloadProgress = 0;
  bool _importingBackup = false;
  double _importProgress = 0;
  final TextEditingController _serverEndpointController =
      TextEditingController(text: MobileApi.baseUrl);
  bool _switchingServer = false;

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
    _serverEndpointController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await _loadSnapshot();
    _startLiveStream();
  }

  Future<void> _stopLiveStream() async {
    _liveGeneration++;
    final subscription = _liveSubscription;
    _liveSubscription = null;
    await subscription?.cancel();
    if (mounted) {
      setState(() => _liveConnected = false);
    }
  }

  Future<void> _switchServerEndpoint() async {
    if (_switchingServer) {
      return;
    }
    final raw = _serverEndpointController.text.trim();
    if (raw.isEmpty) {
      _showNotice('ERP domenini kiriting');
      return;
    }

    setState(() => _switchingServer = true);
    await _stopLiveStream();
    try {
      final result = await MobileApi.instance.switchServerEndpoint(raw);
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case MobileServerSwitchStatus.switched:
          _serverEndpointController.text = result.baseUrl;
          setState(() {
            _report = null;
            _loading = true;
            _error = null;
            _latencySamples.clear();
          });
          _showNotice('Mini RS ERP topildi va server almashtirildi');
          await _loadSnapshot();
          _startLiveStream();
          return;
        case MobileServerSwitchStatus.alreadyActive:
          _serverEndpointController.text = result.baseUrl;
          _showNotice('Bu domen allaqachon faol');
          await _loadSnapshot();
          _startLiveStream();
          return;
        case MobileServerSwitchStatus.credentialsNotFound:
          final confirmed = await _confirmMissingCredentials(result.baseUrl);
          if (!mounted) {
            return;
          }
          if (confirmed) {
            await MobileApi.instance.confirmServerEndpointWithoutLogin(
              result.baseUrl,
            );
            if (!mounted) {
              return;
            }
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => false,
            );
          } else {
            _startLiveStream();
          }
          return;
        case MobileServerSwitchStatus.invalidEndpoint:
          _showNotice(
            'Domen noto‘g‘ri. Masalan: https://erp.example.com',
          );
          _startLiveStream();
          return;
        case MobileServerSwitchStatus.notMiniRsErp:
          _showNotice('Bu domen Mini RS ERP serveri emas');
          _startLiveStream();
          return;
        case MobileServerSwitchStatus.unavailable:
          _showNotice('Bu domen bilan serverga ulanib bo‘lmadi');
          _startLiveStream();
          return;
      }
    } catch (error) {
      if (mounted) {
        _showNotice('Server almashtirilmadi: $error');
        _startLiveStream();
      }
    } finally {
      if (mounted) {
        setState(() => _switchingServer = false);
      }
    }
  }

  Future<bool> _confirmMissingCredentials(String baseUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.person_off_outlined),
          title: const Text('Login bu domenda topilmadi'),
          content: Text(
            'Sizning hozirgi login raqamingiz va kodingiz $baseUrl domenidagi '
            'Mini RS ERP’da mavjud emas. Domenni tekshirib ko‘ring.\n\n'
            'Tasdiqlasangiz, hozirgi tizimdan chiqib, yangi domenning login '
            'oynasiga o‘tasiz.',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              key: const ValueKey('server-endpoint-logout-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ha, chiqish'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _openBackupDay(_BackupDay day) async {
    unawaited(HapticFeedback.mediumImpact());
    AdminServerMonitorBackupSnapshot? active;
    for (final snapshot in day.snapshots) {
      if (snapshot.running) {
        active = snapshot;
        break;
      }
    }
    if (active != null) {
      await _showBackupStatus(active);
      return;
    }
    final ready = day.snapshots.where((snapshot) => snapshot.ready).toList()
      ..sort(
        (left, right) => right.completedAtUnix.compareTo(left.completedAtUnix),
      );
    if (ready.isNotEmpty) {
      await _showReadyBackups(day, ready);
      return;
    }
    AdminServerMonitorBackupSnapshot? failed;
    for (final snapshot in day.snapshots) {
      if (snapshot.status == 'failed') {
        failed = snapshot;
        break;
      }
    }
    if (day.isToday) {
      await _confirmAndStartBackup(day.date, failed: failed);
      return;
    }
    await _showUnavailablePastBackup(day.date);
  }

  Future<void> _showReadyBackups(
    _BackupDay day,
    List<AdminServerMonitorBackupSnapshot> snapshots,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                '${_formatBackupDay(day.date)} backup',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              for (final snapshot in snapshots) ...[
                Card.filled(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatBackupDateTime(snapshot.completedAtUnix),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_backupSourceLabel(snapshot.source)} • ${_formatBackupBytes(snapshot.sizeBytes)} • Tekshirilgan',
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                        if (snapshot.checksumSha256.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'SHA-256: ${snapshot.checksumSha256.substring(0, math.min(16, snapshot.checksumSha256.length))}…',
                            style: Theme.of(sheetContext).textTheme.labelSmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _downloadingBackupId == null
                                ? () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_downloadBackup(snapshot));
                                  }
                                : null,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Backupni yuklab olish'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (day.isToday) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  key: const ValueKey('server-backup-start-another'),
                  onPressed: _startingBackup
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_confirmAndStartBackup(day.date));
                        },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Bugun yana backup olish'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showUnavailablePastBackup(DateTime day) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.history_rounded),
          title: const Text('Bu kun uchun backup yo‘q'),
          content: Text(
            '${_formatBackupDay(day)} kunidagi database holati saqlanmagan. '
            'O‘tgan holatni bugun qayta yaratib bo‘lmaydi. '
            'Bugungi holat uchun esa alohida yangi backup olishingiz mumkin.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tushunarli'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBackupStatus(
    AdminServerMonitorBackupSnapshot snapshot,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                snapshot.source == 'imported'
                    ? 'Backup import qilinmoqda'
                    : 'Backup tayyorlanmoqda',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(_backupStatusLabel(snapshot.status)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndStartBackup(
    DateTime selectedDay, {
    AdminServerMonitorBackupSnapshot? failed,
  }) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(selectedDay);
    if (selected != today) {
      await _showUnavailablePastBackup(selectedDay);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          icon: const Icon(Icons.backup_outlined),
          title: Text(failed == null ? 'Backup olish' : 'Backupni qayta olish'),
          content: Text(
            failed != null && failed.error.isNotEmpty
                ? '${failed.error}\n\nYangi backup hozirgi database holatidan olinsinmi?'
                : 'Database’ning hozirgi holatidan backup olinsinmi?',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: const ValueKey('server-backup-start-confirm'),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Backup olish'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Bekor qilish'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted || _startingBackup) {
      return;
    }
    setState(() => _startingBackup = true);
    try {
      await MobileApi.instance.adminStartBackup();
      await _loadSnapshot();
      if (mounted) {
        _showNotice('Backup olish boshlandi');
      }
    } catch (error) {
      if (mounted) {
        _showNotice(_backupActionError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _startingBackup = false);
      }
    }
  }

  Future<void> _downloadBackup(
    AdminServerMonitorBackupSnapshot snapshot,
  ) async {
    if (_downloadingBackupId != null) {
      return;
    }
    setState(() {
      _downloadingBackupId = snapshot.id;
      _downloadProgress = 0;
    });
    _showNotice('Backup yuklanmoqda…');
    try {
      final download = await MobileApi.instance.adminDownloadBackup(
        snapshot.id,
      );
      final saved = await saveBackupStream(
        stream: download.stream,
        filename: download.filename,
        contentLength: download.contentLength,
        onProgress: (received, total) {
          if (!mounted || total <= 0) {
            return;
          }
          setState(() {
            _downloadProgress = (received / total).clamp(0, 1);
          });
        },
      );
      if (!mounted) {
        return;
      }
      if (kIsWeb) {
        _showNotice('Backup yuklab olindi');
      } else {
        await _showDownloadedBackup(saved);
      }
    } catch (error) {
      if (mounted) {
        _showNotice(_backupActionError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingBackupId = null;
          _downloadProgress = 0;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    if (_importingBackup) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      // Some iOS document providers do not expose unknown PostgreSQL
      // extensions as a selectable custom UTI. Pick the file first and apply
      // the .dump validation below in the app.
      type: FileType.any,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    final picked = result.files.single;
    final filename = picked.name.trim();
    if (!filename.toLowerCase().endsWith('.dump')) {
      _showNotice('Faqat PostgreSQL .dump backup fayli import qilinadi');
      return;
    }
    final source = picked.bytes != null
        ? XFile.fromData(picked.bytes!, name: filename)
        : picked.path == null
            ? null
            : XFile(picked.path!);
    if (source == null) {
      _showNotice('Backup fayliga kirish imkoni bo‘lmadi');
      return;
    }
    final contentLength = picked.size > 0 ? picked.size : await source.length();
    if (!mounted) {
      return;
    }
    if (contentLength <= 0) {
      _showNotice('Backup fayli bo‘sh');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.restore_rounded),
          title: const Text('Backupni import qilish'),
          content: Text(
            '$filename serverga yuboriladi va serverdagi PostgreSQL '
            'ma’lumotlari shu backup holatiga qaytariladi. Davom etilsinmi?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              key: const ValueKey('server-backup-import-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import qilish'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _importingBackup = true;
      _importProgress = 0;
    });
    _showNotice('Backup serverga yuborilmoqda…');
    try {
      await MobileApi.instance.adminImportBackup(
        filename: filename,
        contentLength: contentLength,
        openStream: source.openRead,
        onProgress: (received, total) {
          if (!mounted || total <= 0) {
            return;
          }
          setState(() {
            _importProgress = (received / total).clamp(0, 1);
          });
        },
      );
      if (!mounted) {
        return;
      }
      // The API returns after the upload is durably staged and the restore job
      // is queued. Do not keep the import button blocked while a monitor
      // refresh waits on a slow network or database response.
      setState(() {
        _importingBackup = false;
        _importProgress = 0;
      });
      _showNotice('Backup qabul qilindi, server restore jarayoni boshlandi');
      unawaited(_loadSnapshot());
    } catch (error) {
      if (mounted) {
        _showNotice(_backupActionError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _importingBackup = false;
          _importProgress = 0;
        });
      }
    }
  }

  Future<void> _showDownloadedBackup(SavedBackupFile saved) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Backup tayyor',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text('${saved.filename} mobil qurilmaga saqlandi.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final box = sheetContext.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(
                      title: saved.filename,
                      subject: saved.filename,
                      files: [XFile(saved.path)],
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Fayllarga saqlash yoki ulashish'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    final endpointPanel = _ServerEndpointPanel(
      controller: _serverEndpointController,
      busy: _switchingServer,
      onSubmit: _switchServerEndpoint,
    );
    final currentServerLabel = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Text(
        'Hozirgi server: ${MobileApi.baseUrl}',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
    if (_loading && report == null) {
      return Column(
        children: [
          currentServerLabel,
          const Expanded(child: Center(child: AppLoadingIndicator())),
          endpointPanel,
        ],
      );
    }
    if (_error != null && report == null) {
      return Column(
        children: [
          currentServerLabel,
          Expanded(child: AppRetryState(onRetry: _reload)),
          endpointPanel,
        ],
      );
    }
    if (report == null) {
      return Column(
        children: [
          currentServerLabel,
          Expanded(child: AppRetryState(onRetry: _reload)),
          endpointPanel,
        ],
      );
    }

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(4, 8, 4, bottomPadding),
        children: [
          currentServerLabel,
          _StatusSummaryPanel(
            report: report,
            liveConnected: _liveConnected,
            lastUpdated: _lastUpdated,
            latencySamples: _latencySamples,
            onBackupDayPressed: _openBackupDay,
            onImportBackup: _importBackup,
            backupDownloadProgress:
                _downloadingBackupId == null ? null : _downloadProgress,
            backupImportProgress: _importingBackup ? _importProgress : null,
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
          const SizedBox(height: 10),
          endpointPanel,
        ],
      ),
    );
  }
}

class _ServerEndpointPanel extends StatelessWidget {
  const _ServerEndpointPanel({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ERP serverini almashtirish',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Build domeni saqlanadi. Yangi domen shu yerda tekshiriladi va '
              'Mini RS ERP bo‘lsa faol serverga almashtiriladi.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('server-endpoint-input'),
              controller: controller,
              enabled: !busy,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                labelText: 'Yangi ERP domeni',
                hintText: 'https://erp.example.com',
                prefixIcon: Icon(Icons.language_rounded),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('server-endpoint-switch'),
              onPressed: busy ? null : onSubmit,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz_rounded),
              label: Text(
                busy
                    ? 'Server tekshirilmoqda…'
                    : 'Domenni tekshirish va ulanish',
              ),
            ),
          ],
        ),
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
    required this.onBackupDayPressed,
    required this.onImportBackup,
    required this.backupDownloadProgress,
    required this.backupImportProgress,
  });

  final AdminServerMonitorReport report;
  final bool liveConnected;
  final DateTime? lastUpdated;
  final List<int> latencySamples;
  final ValueChanged<_BackupDay> onBackupDayPressed;
  final VoidCallback onImportBackup;
  final double? backupDownloadProgress;
  final double? backupImportProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final serverOk = report.server.status == 'running';
    final dbOk = report.database.reachable;
    final backupOk = report.backups.snapshots.isEmpty
        ? report.backups.exists && report.backups.fileCount > 0
        : report.backups.healthy;
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
                    value: '${report.backups.snapshotCount} backup',
                    ok: backupOk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PingSparklinePanel(
              latencyMs: latencySamples.isEmpty ? 0 : latencySamples.last,
              samples: latencySamples,
              connected: liveConnected && report.database.reachable,
            ),
            const SizedBox(height: 10),
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
            _BackupCalendarPanel(
              backups: report.backups,
              onDayPressed: onBackupDayPressed,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('server-backup-import'),
              onPressed: backupImportProgress == null ? onImportBackup : null,
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(
                backupImportProgress == null
                    ? 'Backupni import qilish'
                    : 'Backup import qilinmoqda…',
              ),
            ),
            if (backupDownloadProgress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: backupDownloadProgress),
            ],
            if (backupImportProgress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: backupImportProgress),
            ],
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
    final color = active ? scheme.primary : scheme.tertiary;
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
  const _BackupCalendarPanel({
    required this.backups,
    required this.onDayPressed,
  });

  final AdminServerMonitorBackups backups;
  final ValueChanged<_BackupDay> onDayPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _backupDays(backups.snapshots);
    final backedUpDays = days.where((day) => day.count > 0).length;
    final ok = backups.snapshots.isEmpty
        ? backups.exists && backups.fileCount > 0
        : backups.healthy;
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
              child: Row(
                children: [
                  for (var index = 0; index < days.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _BackupDayCell(
                        day: days[index],
                        activeColor: _statusColor(context, ok),
                        trackColor:
                            scheme.outlineVariant.withValues(alpha: 0.58),
                        onPressed: () => onDayPressed(days[index]),
                      ),
                    ),
                  ],
                ],
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
                '${backups.snapshotCount} ta backup',
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

  List<_BackupDay> _backupDays(
    List<AdminServerMonitorBackupSnapshot> snapshots,
  ) {
    final today = _dateOnly(DateTime.now());
    final byDay = <DateTime, List<AdminServerMonitorBackupSnapshot>>{};
    for (final snapshot in snapshots) {
      final timestamp = snapshot.completedAtUnix > 0
          ? snapshot.completedAtUnix
          : snapshot.createdAtUnix;
      if (timestamp <= 0) {
        continue;
      }
      final day = _dateOnly(
        DateTime.fromMillisecondsSinceEpoch(
          timestamp * 1000,
        ).toLocal(),
      );
      byDay.putIfAbsent(day, () => []).add(snapshot);
    }
    return List<_BackupDay>.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return _BackupDay(
        date: day,
        snapshots: byDay[day] ?? const [],
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
    required this.date,
    required this.snapshots,
    required this.isToday,
  });

  final DateTime date;
  final List<AdminServerMonitorBackupSnapshot> snapshots;
  final bool isToday;

  int get count => snapshots.where((snapshot) => snapshot.ready).length;
  bool get running => snapshots.any((snapshot) => snapshot.running);
  bool get failed =>
      count == 0 && snapshots.any((snapshot) => snapshot.status == 'failed');
}

class _BackupDayCell extends StatelessWidget {
  const _BackupDayCell({
    required this.day,
    required this.activeColor,
    required this.trackColor,
    required this.onPressed,
  });

  final _BackupDay day;
  final Color activeColor;
  final Color trackColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = day.count > 0
        ? activeColor.withValues(alpha: day.count > 1 ? 0.95 : 0.78)
        : day.running
            ? scheme.tertiaryContainer
            : day.failed
                ? scheme.errorContainer
                : trackColor;
    final label = day.count > 0
        ? '${_formatBackupDay(day.date)}: ${day.count} ta backup'
        : day.running
            ? '${_formatBackupDay(day.date)}: backup tayyorlanmoqda'
            : day.failed
                ? '${_formatBackupDay(day.date)}: backup xatosi'
                : '${_formatBackupDay(day.date)}: backup yo‘q';
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: day.isToday
              ? BorderSide(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  width: 1.4,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(
            'server-backup-day-${day.date.year}-${day.date.month}-${day.date.day}',
          ),
          onTap: onPressed,
          onLongPress: onPressed,
          child: day.running
              ? const Center(
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : day.failed
                  ? Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: scheme.onErrorContainer,
                    )
                  : null,
        ),
      ),
    );
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
    return scheme.tertiary;
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

String _formatBackupDay(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _formatBackupDateTime(int unixSeconds) {
  if (unixSeconds <= 0) {
    return 'Vaqt kutilmoqda';
  }
  return formatLocalDateTime(
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000).toLocal(),
  );
}

String _formatBackupBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const kib = 1024;
  const mib = kib * 1024;
  const gib = mib * 1024;
  if (bytes >= gib) {
    return '${(bytes / gib).toStringAsFixed(bytes >= 10 * gib ? 1 : 2)} GB';
  }
  if (bytes >= mib) {
    return '${(bytes / mib).toStringAsFixed(bytes >= 10 * mib ? 1 : 2)} MB';
  }
  if (bytes >= kib) {
    return '${(bytes / kib).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _backupSourceLabel(String source) {
  return switch (source.trim()) {
    'automatic' => 'Avtomatik',
    'manual' => 'Qo‘lda',
    'legacy' => 'Avvalgi',
    'imported' => 'Import qilingan',
    _ => 'Backup Doctor',
  };
}

String _backupStatusLabel(String status) {
  return switch (status.trim()) {
    'queued' => 'Navbatga qo‘yildi',
    'running' => 'Database nusxasi olinmoqda',
    'verifying' => 'Backup tekshirilmoqda',
    'ready' => 'Yuklab olishga tayyor',
    'failed' => 'Backup olishda xato yuz berdi',
    _ => 'Backup holati yangilanmoqda',
  };
}

String _backupActionError(Object error) {
  if (error is MobileApiException && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  if (error is StateError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return 'Backup amali bajarilmadi';
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
