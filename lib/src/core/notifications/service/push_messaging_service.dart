import '../../api/mobile_api.dart';
import '../store/customer_delivery_runtime_store.dart';
import '../hub/refresh_hub.dart';
import '../store/notification_unread_store.dart';
import '../../session/session.dart';
import '../../../features/shared/models/app_models.dart';
import '../../../features/chat/state/chat_store.dart';
import 'local_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'firebase_client_bootstrap.dart';
import 'ios_push_registration.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  await FirebaseClientBootstrap.initializeBackground();
}

class PushMessagingService with WidgetsBindingObserver {
  PushMessagingService._();

  static final PushMessagingService instance = PushMessagingService._();
  bool _initialized = false;
  bool _observing = false;
  bool _configurationReady = false;
  Future<void>? _initializing;
  final ValueNotifier<String> deviceStatus =
      ValueNotifier('device_not_checked');
  final ValueNotifier<String?> deviceErrorDetail = ValueNotifier(null);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(initialize());
  }

  bool get _supportsRemotePush =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _shouldInitializePushOnThisDevice =>
      defaultTargetPlatform == TargetPlatform.android ||
      (defaultTargetPlatform == TargetPlatform.iOS &&
          !PlatformHelper.isIOSSimulator);

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return defaultTargetPlatform.name;
    }
  }

  Future<void> initialize() async {
    if (!_observing && !kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    return _initializing ??= _initialize().catchError((Object error) {
      deviceStatus.value = _deviceErrorCode(error);
    }).whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    _configurationReady = false;
    deviceErrorDetail.value = null;
    if (kIsWeb || !_supportsRemotePush || !_shouldInitializePushOnThisDevice) {
      deviceStatus.value = 'push_config_device_unavailable';
      return;
    }
    if (!AppSession.instance.isLoggedIn ||
        AppSession.instance.isTestModeSession) {
      deviceStatus.value = AppSession.instance.isTestModeSession
          ? 'push_config_test_mode'
          : 'device_not_checked';
      return;
    }

    debugPrint('push initialize start platform=$_platformName');
    await FirebaseClientBootstrap.initialize(_platformName);
    _configurationReady = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Bind an early APNs token before the messaging plugin makes SDK calls.
      deviceStatus.value = 'push_config_apns_registering';
      await IosPushRegistration.ensureReady(onReady: () {
        if (_configurationReady) unawaited(initialize());
      });
    }
    await messaging.requestPermission();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Foreground notifications are surfaced below through the local
      // notification service so active chats can suppress them and every other
      // event is shown exactly once.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }

    try {
      await _syncReadyToken();
    } catch (error) {
      deviceStatus.value = _deviceErrorCode(error);
    }

    if (_initialized) return;

    messaging.onTokenRefresh.listen((token) async {
      debugPrint(
        'push token refresh platform=$_platformName token=${maskPushToken(token)}',
      );
      if (_configurationReady &&
          AppSession.instance.isLoggedIn &&
          !AppSession.instance.isTestModeSession) {
        try {
          await _registerToken(token);
          deviceStatus.value = 'device_registered';
        } catch (error) {
          deviceStatus.value = _deviceErrorCode(error);
        }
      }
    });

    FirebaseMessaging.onMessage.listen((message) async {
      if (!_configurationReady) return;
      final data = message.data;
      final profile = AppSession.instance.profile;
      final targetRole = (data['target_role'] ?? '').trim();
      final targetRef = (data['target_ref'] ?? '').trim();
      if (profile == null) {
        return;
      }
      final accessRole = profile.accessRole;
      final acceptedTargetRoles = <String>{
        profile.role.name,
        userRoleToJson(profile.role),
        if (accessRole != null) accessRole.name,
        if (accessRole != null) userRoleToJson(accessRole),
      };
      if (targetRole.isNotEmpty && !acceptedTargetRoles.contains(targetRole)) {
        return;
      }
      if (targetRef.isNotEmpty && targetRef != profile.ref) {
        return;
      }
      if ((data['event_type'] ?? '').trim() == 'push.configuration.test') {
        await LocalNotificationService.instance.showChatNotification(
          id: message.messageId ?? 'push-configuration-test',
          title: message.notification?.title ?? 'Accord',
          body: message.notification?.body ?? 'Bildirishnomalar ulandi',
        );
        return;
      }
      if ((data['event_type'] ?? '').trim() == 'chat.message.created') {
        await ChatStore.instance.handlePush(data);
        final conversationId = data['conversation_id']?.toString() ?? '';
        if (ChatStore.instance.shouldPresentChatNotification(conversationId)) {
          await LocalNotificationService.instance.showChatNotification(
            id: data['message_id'] ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            title: message.notification?.title ?? 'Yangi xabar',
            body: message.notification?.body ?? 'Chatda yangi xabar',
          );
        }
        return;
      }
      final record = DispatchRecord(
        id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        recordType: data['record_type'] ?? '',
        supplierRef: data['supplier_ref'] ?? '',
        supplierName: data['supplier_name'] ?? '',
        itemCode: data['item_code'] ?? '',
        itemName: data['item_name'] ?? '',
        uom: data['uom'] ?? '',
        sentQty: double.tryParse('${data['sent_qty'] ?? 0}') ?? 0,
        acceptedQty: double.tryParse('${data['accepted_qty'] ?? 0}') ?? 0,
        amount: double.tryParse('${data['amount'] ?? 0}') ?? 0,
        currency: data['currency'] ?? '',
        note: data['note'] ?? '',
        eventType: data['event_type'] ?? '',
        highlight: data['highlight'] ?? '',
        status: parseDispatchStatus(data['status'] ?? 'pending'),
        createdLabel: data['created_label'] ?? '',
      );
      await NotificationUnreadStore.instance.markUnread(
        profile: profile,
        ids: [record.id],
      );
      if (accessRole == UserRole.customer &&
          record.status == DispatchStatus.pending) {
        CustomerDeliveryRuntimeStore.instance.recordIncoming(record);
      }
      RefreshHub.instance.emit(accessRole?.name ?? 'custom');
      await LocalNotificationService.instance.showDispatchNotification(
        role: accessRole ?? profile.role,
        record: record,
      );
    });

    _initialized = true;
    debugPrint('push initialize complete platform=$_platformName');
  }

  Future<void> syncCurrentToken() => initialize();

  Future<void> _syncReadyToken() async {
    final profile = AppSession.instance.profile;
    debugPrint(
      'push sync start logged_in=${AppSession.instance.isLoggedIn} '
      'platform=$_platformName '
      'role=${profile?.role.name ?? 'none'} '
      'ref=${profile?.ref ?? ''}',
    );
    if (!_supportsRemotePush ||
        !_shouldInitializePushOnThisDevice ||
        !AppSession.instance.isLoggedIn ||
        AppSession.instance.isTestModeSession) {
      debugPrint(
        'push sync skipped: unsupported platform, simulator, not logged in, or test mode',
      );
      return;
    }
    if (Firebase.apps.isEmpty) {
      debugPrint('push sync skipped: Firebase is not initialized');
      return;
    }
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.getNotificationSettings();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      throw const MobileApiException(
          code: 'push_config_permission_denied',
          message: 'Notifications denied');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await messaging.getAPNSToken();
      debugPrint('push sync apns token=${maskPushToken(apnsToken ?? '')}');
      if (apnsToken == null) {
        throw const MobileApiException(
            code: 'push_config_apns_unavailable',
            message: 'APNs token is missing');
      }
    }
    final token = await messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('push sync skipped: Firebase token is empty');
      throw const MobileApiException(
          code: 'push_config_token_unavailable',
          message: 'FCM token is missing');
    }
    debugPrint(
      'push sync obtained platform=$_platformName token=${maskPushToken(token)}',
    );
    await _registerToken(token);
    deviceStatus.value = 'device_registered';
    debugPrint(
      'push sync stored platform=$_platformName token=${maskPushToken(token)}',
    );
  }

  String? get firebaseProjectId =>
      Firebase.apps.isEmpty ? null : Firebase.app().options.projectId;

  Future<String> prepareConfigurationTest() async {
    if (AppSession.instance.isTestModeSession) {
      throw const MobileApiException(
          code: 'push_config_test_mode', message: 'Test mode');
    }
    if (!_supportsRemotePush || !_shouldInitializePushOnThisDevice) {
      throw const MobileApiException(
          code: 'push_config_device_unavailable',
          message: 'Physical mobile device required');
    }
    try {
      await initialize();
      if (deviceStatus.value != 'device_registered') {
        throw MobileApiException(
            code: deviceStatus.value,
            message: 'Device registration is incomplete');
      }
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        throw const MobileApiException(
            code: 'push_config_permission_denied',
            message: 'Notification permission required');
      }
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        throw const MobileApiException(
            code: 'push_config_apns_unavailable',
            message: 'APNs registration not ready');
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        throw const MobileApiException(
            code: 'push_config_device_unavailable',
            message: 'FCM registration not ready');
      }
      // Do not report successful registration if the backend rejected the token.
      await MobileApi.instance
          .chatRegisterDeviceToken(tokenValue: token, platform: _platformName);
      return token;
    } on MobileApiException {
      rethrow;
    } catch (error) {
      throw MobileApiException(
          code: _deviceErrorCode(error), message: 'Device push setup failed');
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (!_supportsRemotePush ||
        !_shouldInitializePushOnThisDevice ||
        !AppSession.instance.isLoggedIn ||
        AppSession.instance.isTestModeSession) {
      debugPrint(
        'push unregister skipped: unsupported platform, simulator, not logged in, or test mode',
      );
      return;
    }
    if (Firebase.apps.isEmpty) {
      debugPrint('push unregister skipped: Firebase is not initialized');
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('push unregister skipped: Firebase token is empty');
      return;
    }
    debugPrint(
      'push unregister platform=$_platformName token=${maskPushToken(token)}',
    );
    try {
      await MobileApi.instance.chatUnregisterDeviceToken(token);
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    await MobileApi.instance.chatRegisterDeviceToken(
      tokenValue: token,
      platform: _platformName,
    );
  }

  String _deviceErrorCode(Object error) {
    if (error is MobileApiException) return error.code;
    if (error is PlatformException && error.code.startsWith('push_config_')) {
      if (error.code == 'push_config_apns_entitlement_missing' ||
          error.code == 'push_config_apns_registration_failed') {
        final details = error.details;
        deviceErrorDetail.value = details is Map
            ? '${details['domain']} (${details['code']}): ${error.message ?? ''}'
            : error.message;
      }
      return error.code;
    }
    if (error is FirebaseException) {
      if (error.code == 'apns-token-not-set') {
        return 'push_config_apns_unavailable';
      }
      if (error.code == 'duplicate-app') return 'push_config_restart_required';
      if (error.code == 'network-request-failed') {
        return 'push_config_unreachable';
      }
      return 'push_config_firebase_failed';
    }
    return 'push_config_client_sync_failed';
  }
}

class PlatformHelper {
  const PlatformHelper._();

  static bool get isIOSSimulator {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    return _isIOSSimulator;
  }

  static bool _isIOSSimulator = false;

  static Future<void> load() async {
    if (defaultTargetPlatform != TargetPlatform.iOS || kIsWeb) {
      _isIOSSimulator = false;
      return;
    }
    const channel = MethodChannel('accord/device_info');
    try {
      _isIOSSimulator =
          (await channel.invokeMethod<bool>('isIOSSimulator')) ?? false;
    } catch (_) {
      _isIOSSimulator = false;
    }
  }
}
