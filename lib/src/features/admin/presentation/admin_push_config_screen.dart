import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/service/push_messaging_service.dart';
import '../../../core/notifications/service/firebase_client_config.dart';
import '../../../core/session/session.dart';
import '../../shared/models/app_models.dart';
import '../../../core/localization/urdu_aware_text.dart';

class AdminPushConfigScreen extends StatefulWidget {
  const AdminPushConfigScreen({super.key, this.deviceTokenProvider});
  final Future<String> Function()? deviceTokenProvider;

  @override
  State<AdminPushConfigScreen> createState() => _AdminPushConfigScreenState();
}

class _AdminPushConfigScreenState extends State<AdminPushConfigScreen> {
  final _json = TextEditingController();
  AdminPushConfig? _config;
  bool _busy = true;
  String? _error;
  String? _notice;
  String? _fileName;

  bool get _admin => AppSession.instance.profile?.role == UserRole.admin;
  String text(String key) => context.l10n.adminText('push.$key');

  @override
  void initState() {
    super.initState();
    PushMessagingService.instance.deviceStatus
        .addListener(_deviceStatusChanged);
    if (_admin) {
      _load();
    } else {
      _busy = false;
    }
  }

  @override
  void dispose() {
    PushMessagingService.instance.deviceStatus
        .removeListener(_deviceStatusChanged);
    _json.dispose();
    super.dispose();
  }

  void _deviceStatusChanged() {
    if (mounted &&
        PushMessagingService.instance.deviceStatus.value ==
            'device_registered' &&
        (_error?.startsWith('push_config_apns_') ?? false)) {
      setState(() => _error = null);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is MobileApiException
            ? error.code
            : 'push_config_request_failed');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
        final config = await MobileApi.instance.adminPushConfig();
        if (mounted) {
          setState(() {
            _config = config;
            _error = config.error.isEmpty ? null : config.error;
          });
        }
        if (widget.deviceTokenProvider == null) {
          await PushMessagingService.instance.initialize();
        }
      });

  Future<void> _pick() => _run(() async {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: ['json'], withData: true);
        if (result == null) return;
        final file = result.files.single;
        if (!file.name.toLowerCase().endsWith('.json') ||
            file.size > 32768 ||
            file.bytes == null) {
          throw const MobileApiException(
              code: 'push_config_invalid_credentials',
              message: 'Invalid JSON file');
        }
        final raw = utf8.decode(file.bytes!);
        _parseAccount(raw);
        if (mounted) {
          setState(() {
            _json.text = raw;
            _fileName = file.name;
          });
        }
      });

  Map<String, dynamic> _parseAccount(String raw) {
    try {
      if (utf8.encode(raw).length > 32768) throw const FormatException();
      final account = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (account['type'] != 'service_account' ||
          (account['project_id']?.toString().trim().isEmpty ?? true) ||
          (account['private_key']?.toString().trim().isEmpty ?? true) ||
          (account['client_email']?.toString().trim().isEmpty ?? true)) {
        throw const FormatException();
      }
      return account;
    } catch (_) {
      throw const MobileApiException(
          code: 'push_config_invalid_credentials',
          message: 'Invalid service account');
    }
  }

  Future<void> _save() => _run(() async {
        final account = _parseAccount(_json.text);
        final config = await MobileApi.instance.saveAdminPushConfig(account);
        if (mounted) {
          setState(() {
            _config = config;
            _json.clear();
            _fileName = null;
            _notice = 'saved';
          });
        }
      });

  Future<void> _check() => _run(() async {
        final config = await MobileApi.instance.checkAdminPushConfig();
        if (mounted) {
          setState(() {
            _config = config;
            _notice = 'verified';
          });
        }
      });

  Future<void> _test() => _run(() async {
        final token = await (widget.deviceTokenProvider ??
            PushMessagingService.instance.prepareConfigurationTest)();
        await MobileApi.instance.testAdminPushConfig(token);
        if (mounted) setState(() => _notice = 'test_sent');
      });

  Future<void> _pickMobile(String platform) => _run(() async {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [platform == 'ios' ? 'plist' : 'json'],
            withData: true);
        if (result == null) return;
        final file = result.files.single;
        late FirebaseClientConfig client;
        try {
          if (file.size > 131072 || file.bytes == null) {
            throw const FormatException();
          }
          client =
              FirebaseClientConfig.fromFile(utf8.decode(file.bytes!), platform);
        } catch (_) {
          throw const MobileApiException(
              code: 'push_config_invalid_client_config',
              message: 'Invalid client file');
        }
        final config =
            await MobileApi.instance.saveMobilePushConfig(platform, client);
        if (mounted) {
          setState(() {
            _config = config;
            _notice = 'mobile_saved';
          });
        }
        if (widget.deviceTokenProvider == null) {
          await PushMessagingService.instance.initialize();
        }
      });

  Future<void> _applyDevice() => _run(() async {
        await PushMessagingService.instance.initialize();
      });

  String _errorKey(String code) => switch (code) {
        'push_config_invalid_credentials' => 'invalid',
        'push_config_invalid_client_config' => 'invalid_client',
        'push_config_client_missing' => 'client_missing',
        'push_config_client_save_failed' => 'client_save_failed',
        'push_config_client_sync_failed' => 'client_sync_failed',
        'push_config_firebase_failed' => 'firebase_failed',
        'push_config_restart_required' => 'restart_required',
        'push_config_token_unavailable' => 'token_unavailable',
        'device_not_checked' => 'device_not_checked',
        'device_registered' => 'device_registered',
        'push_config_project_mismatch' => 'project_mismatch',
        'push_config_google_rejected' => 'google_rejected',
        'push_config_unreachable' => 'unreachable',
        'push_config_save_failed' => 'save_failed',
        'push_config_not_configured' => 'not_configured',
        'push_config_device_not_registered' => 'device_missing',
        'push_config_test_mode' => 'test_mode',
        'push_config_device_unavailable' => 'device_unavailable',
        'push_config_permission_denied' => 'permission_denied',
        'push_config_apns_unavailable' => 'apns_unavailable',
        'push_config_apns_registering' => 'apns_registering',
        'push_config_apns_entitlement_missing' => 'apns_entitlement_missing',
        'push_config_apns_registration_failed' => 'apns_registration_failed',
        'push_config_test_failed' => 'test_failed',
        'forbidden' => 'admin_only',
        _ => 'failed',
      };

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(title: Text(text('title'))),
      body: !_admin
          ? Center(child: Text(text('admin_only')))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (config != null)
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              text(config.configured
                                  ? 'configured'
                                  : 'not_configured'),
                              style: Theme.of(context).textTheme.titleMedium),
                          if (config.projectId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SelectableText(
                                '${text('project')}: ${config.projectId}'),
                            SelectableText(config.clientEmail),
                          ],
                          const SizedBox(height: 8),
                          Text(text(config.lastVerifiedAt != null
                              ? 'verified'
                              : 'not_checked')),
                        ]),
                  )),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text('device_title'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<String>(
                                valueListenable:
                                    PushMessagingService.instance.deviceStatus,
                                builder: (_, status, __) => Text(
                                    text(_errorKey(status)),
                                    key: const ValueKey('push-device-status'))),
                            ValueListenableBuilder<String?>(
                                valueListenable: PushMessagingService
                                    .instance.deviceErrorDetail,
                                builder: (_, detail, __) => detail == null
                                    ? const SizedBox.shrink()
                                    : Text(detail,
                                        key: const ValueKey(
                                            'push-device-error-detail'))),
                            TextButton(
                                onPressed: _busy ? null : _applyDevice,
                                child: Text(text('apply_device'))),
                          ],
                        ))),
                const SizedBox(height: 16),
                Text(text('instructions')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.upload_file),
                    label: Text(text('pick'))),
                if (_fileName != null) Text(_fileName!),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('push-config-json'),
                  controller: _json,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                      labelText: text('json'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                    key: const ValueKey('push-config-save'),
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(text('save'))),
                const SizedBox(height: 8),
                OutlinedButton(
                    key: const ValueKey('push-config-check'),
                    onPressed:
                        _busy || config?.configured != true ? null : _check,
                    child: Text(text('check'))),
                OutlinedButton(
                    key: const ValueKey('push-config-test'),
                    onPressed:
                        _busy || config?.configured != true ? null : _test,
                    child: Text(text('test'))),
                TextButton(
                    onPressed: _busy ? null : _load,
                    child: Text(text('refresh'))),
                if (_error != null)
                  Text(text(_errorKey(_error!)),
                      key: const ValueKey('push-config-error'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (_notice != null)
                  Text(text(_notice!),
                      key: const ValueKey('push-config-notice')),
                const SizedBox(height: 16),
                Text(text('mobile_title'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(text('mobile_instructions')),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const UrduAwareText('Android'),
                    subtitle: Text(text(config?.android != null
                        ? 'mobile_configured'
                        : 'mobile_missing')),
                    trailing: Icon(config?.android != null
                        ? Icons.check_circle_outline
                        : Icons.error_outline)),
                OutlinedButton.icon(
                    key: const ValueKey('push-config-android'),
                    onPressed: _busy || config?.configured != true
                        ? null
                        : () => _pickMobile('android'),
                    icon: const Icon(Icons.upload_file),
                    label: const UrduAwareText('google-services.json')),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const UrduAwareText('iPhone'),
                    subtitle: Text(text(config?.ios != null
                        ? 'mobile_configured'
                        : 'mobile_missing')),
                    trailing: Icon(config?.ios != null
                        ? Icons.check_circle_outline
                        : Icons.error_outline)),
                OutlinedButton.icon(
                    key: const ValueKey('push-config-ios'),
                    onPressed: _busy || config?.configured != true
                        ? null
                        : () => _pickMobile('ios'),
                    icon: const Icon(Icons.upload_file),
                    label: const UrduAwareText('GoogleService-Info.plist')),
                const SizedBox(height: 16),
                Text(text('ios_hint'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }
}
