import 'dart:async';
import 'dart:math' as math;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/files/backup_file_saver.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'widgets/admin_shell.dart';

part 'admin_server_monitor_screen__AdminServerMonitorScreenState_methods_01.dart';
part 'admin_server_monitor_screen__AdminServerMonitorScreenState_methods_02.dart';
part 'admin_server_monitor_screen__AdminServerMonitorScreenState_methods_03.dart';
part 'admin_server_monitor_screen_widgets_part_01.dart';
part 'admin_server_monitor_screen_declarations_part_02.dart';
part 'admin_server_monitor_screen_declarations_part_03.dart';
part 'admin_server_monitor_screen_widgets_part_04.dart';

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
  String? _pendingImportJobId;
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
        title: context.l10n.adminText('server.title'),
        selectedRouteName: AppRoutes.adminServerMonitor,
        activeTab: null,
        child: _buildBody(context),
      ),
    );
  }
}
