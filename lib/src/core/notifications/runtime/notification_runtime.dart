import '../store/notification_unread_store.dart';
import '../../api/mobile_api.dart';
import '../../session/session.dart';
import '../../../features/shared/models/app_models.dart';
import '../service/local_notification_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationRuntime extends StatefulWidget {
  const NotificationRuntime({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationRuntime> createState() => _NotificationRuntimeState();
}

class _NotificationRuntimeState extends State<NotificationRuntime>
    with WidgetsBindingObserver {
  static const String _snapshotPrefix = 'notification_snapshot_v1';
  Timer? _timer;
  bool _polling = false;
  SharedPreferences? _preferences;
  String _snapshotUserKey = '';
  Map<String, String>? _previousSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _poll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      _poll();
    });
  }

  Future<void> _poll() async {
    if (_polling) {
      return;
    }
    final profile = AppSession.instance.profile;
    final accessRole = profile?.accessRole;
    if (profile == null ||
        (accessRole != UserRole.supplier &&
            accessRole != UserRole.werka &&
            accessRole != UserRole.customer)) {
      return;
    }

    _polling = true;
    try {
      final userKey = '${accessRole!.name}:${profile.ref}';
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      if (_snapshotUserKey.isNotEmpty && _snapshotUserKey != userKey) {
        await prefs.remove('$_snapshotPrefix:$_snapshotUserKey');
        _previousSnapshot = null;
      }
      if (_snapshotUserKey != userKey) {
        _snapshotUserKey = userKey;
        _previousSnapshot = _readSnapshot(
          prefs.getString('$_snapshotPrefix:$userKey'),
        );
      }

      final records = await _loadCanonicalRecords(profile);
      final current = <String, String>{
        for (final item in records) item.id: _signature(item),
      };
      final storageKey = '$_snapshotPrefix:$userKey';
      await NotificationUnreadStore.instance.retainForProfile(
        profile: profile,
        ids: current.keys,
      );
      final previous = _previousSnapshot;
      if (previous == null) {
        _previousSnapshot = current;
        await prefs.setString(storageKey, jsonEncode(current));
        return;
      }
      if (_sameSnapshot(previous, current)) {
        return;
      }

      final surfacedRecords = <DispatchRecord>[];
      for (final record in records) {
        final next = _signature(record);
        final old = previous[record.id];
        if ((old == null || old != next) &&
            _shouldSurfaceForCurrentProfile(
              profile,
              record,
              hadPrevious: old != null,
            )) {
          surfacedRecords.add(record);
        }
      }

      if (surfacedRecords.isNotEmpty) {
        await NotificationUnreadStore.instance.markUnread(
          profile: profile,
          ids: surfacedRecords.map((item) => item.id),
        );
        for (final record in surfacedRecords) {
          await LocalNotificationService.instance.showDispatchNotification(
            role: accessRole,
            record: record,
          );
        }
      }
      _previousSnapshot = current;
      await prefs.setString(storageKey, jsonEncode(current));
    } catch (_) {
      // Best-effort runtime notifications.
    } finally {
      _polling = false;
    }
  }

  String _signature(DispatchRecord record) {
    return [
      record.status.name,
      record.note,
      record.sentQty.toStringAsFixed(4),
      record.acceptedQty.toStringAsFixed(4),
    ].join('|');
  }

  Future<List<DispatchRecord>> _loadCanonicalRecords(
    SessionProfile profile,
  ) async {
    switch (profile.accessRole) {
      case UserRole.supplier:
        return MobileApi.instance.supplierHistory();
      case UserRole.werka:
        return MobileApi.instance.werkaNotifications();
      case UserRole.customer:
        final lists = await Future.wait<List<DispatchRecord>>([
          MobileApi.instance.customerStatusDetails(CustomerStatusKind.pending),
          MobileApi.instance
              .customerStatusDetails(CustomerStatusKind.confirmed),
          MobileApi.instance.customerStatusDetails(CustomerStatusKind.rejected),
        ]);
        return <String, DispatchRecord>{
          for (final list in lists)
            for (final item in list) item.id: item,
        }.values.toList(growable: false);
      case UserRole.aparatchi:
      case UserRole.qolipchi:
      case UserRole.boyoqchi:
      case UserRole.materialTaminotchi:
      case UserRole.admin:
      case null:
        return const <DispatchRecord>[];
    }
  }

  Map<String, String>? _readSnapshot(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    } catch (_) {
      return null;
    }
  }

  bool _sameSnapshot(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _shouldSurfaceForCurrentProfile(
    SessionProfile profile,
    DispatchRecord record, {
    required bool hadPrevious,
  }) {
    final accessRole = profile.accessRole;
    if (accessRole == UserRole.supplier) {
      if (record.eventType == 'werka_unannounced_pending') {
        return true;
      }
      if (!hadPrevious &&
          (record.status == DispatchStatus.pending ||
              record.status == DispatchStatus.draft)) {
        return false;
      }
      return true;
    }

    if (accessRole == UserRole.werka) {
      if (record.eventType == 'supplier_ack') {
        return true;
      }
      if (!hadPrevious &&
          record.recordType == 'delivery_note' &&
          record.status == DispatchStatus.pending) {
        return false;
      }
      if (!hadPrevious && record.eventType == 'werka_unannounced_pending') {
        return false;
      }
      return true;
    }

    if (accessRole == UserRole.customer) {
      return !hadPrevious;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
