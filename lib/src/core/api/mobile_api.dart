import '../../features/admin/logic/apparatus_queue_state.dart';
import '../../features/admin/logic/canonical_apparatus_groups.dart';
import '../../features/admin/logic/production_map_chain.dart';
import '../../features/admin/logic/production_map_pechat_rules.dart';
import '../../features/shared/models/app_models.dart';
import '../../features/shared/models/inventory_movement_models.dart';
import '../../features/admin/models/admin_item_group_tree_entry.dart';
import '../../features/admin/models/production_map_models.dart';
import '../../features/admin/telegram/models/telegram_models.dart';
import '../../features/chat/models/chat_models.dart';
import '../../features/chat/models/chat_media_models.dart';
import '../../features/boyoqchi/models/returned_paint_models.dart';
import '../../features/shared/models/stock_entry_lookup.dart';
import '../customer/customer_priority.dart';
import '../notifications/service/push_messaging_service.dart';
import '../native_iroh_transport.dart';
import '../native_usb_printer.dart';
import '../print_transport.dart';
import '../localization/app_localizations.dart';
import '../realtime/warehouse_live_client.dart';
import '../search/search_activity_store.dart';
import '../search/search_normalizer.dart';
import '../network/server_endpoint_store.dart';
import '../session/accounts/saved_account_runtime.dart';
import '../session/session.dart';
import '../test_mode/test_mode_controller.dart';
import '../test_mode/test_mode_demo_data.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'json_payload_decoder.dart';

part 'admin/mobile_api_admin.dart';
part 'admin/mobile_api_admin_settings_monitor.dart';
part 'admin/mobile_api_admin_production_queue_runtime.dart';
part 'admin/mobile_api_admin_queue_models.dart';
part 'admin/mobile_api_admin_order_lifecycle.dart';
part 'admin/mobile_api_admin_production_map.dart';
part 'admin/mobile_api_admin_capacity_schedule.dart';
part 'admin/mobile_api_admin_queue_state.dart';
part 'admin/mobile_api_admin_queue_action_models.dart';
part 'admin/mobile_api_admin_queue_action.dart';
part 'admin/mobile_api_admin_queue_action_result.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_context.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_start.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_worker_handoff.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_pause.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_merge.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_roll_complete.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_resume.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_complete.dart';
part 'admin/mobile_api_admin_queue_action_result_backend.dart';
part 'admin/mobile_api_admin_users_list.dart';
part 'admin/mobile_api_admin_raw_materials.dart';
part 'admin/mobile_api_admin_progress_qr.dart';
part 'admin/mobile_api_admin_users_workers.dart';
part 'admin/mobile_api_admin_suppliers_customers.dart';
part 'admin/mobile_api_admin_qolip_orders.dart';
part 'admin/mobile_api_admin_opening_wip.dart';
part 'admin/mobile_api_admin_training.dart';
part 'admin/mobile_api_admin_telegram.dart';
part 'admin/mobile_api_admin_items.dart';
part 'admin/mobile_api_admin_item_groups.dart';
part 'admin/mobile_api_paddons.dart';
part 'admin/mobile_api_factory_locations.dart';
part 'admin/mobile_api_inventory_movements.dart';
part 'auth/mobile_api_auth_profile.dart';
part 'calculate/mobile_api_calculate.dart';
part 'chat/mobile_api_chat.dart';
part 'boyoqchi/mobile_api_boyoqchi.dart';
part 'customer/mobile_api_customer.dart';
part 'gscale/mobile_api_gscale.dart';
part 'qolip/mobile_api_qolip.dart';
part 'rezka/mobile_api_rezka.dart';
part 'server/mobile_api_server.dart';
part 'supplier/mobile_api_supplier_notifications.dart';
part 'werka/mobile_api_werka.dart';
part 'calculate/mobile_api_calculate_models_part_02.dart';
part 'calculate/mobile_api_calculate_models_part_01.dart';
part 'calculate/mobile_api_calculate_helpers_part_04.dart';
part 'calculate/mobile_api_calculate_declarations_part_03.dart';
part 'admin/mobile_api_admin_queue_state_models_part_02.dart';
part 'admin/mobile_api_inventory_movements_helpers_part_01.dart';
part 'admin/mobile_api_admin_production_map_MobileApiAdminProductionMap_methods_01.dart';
part 'admin/mobile_api_admin_training_MobileApiAdminTrainingWorkspace_methods_03.dart';
part 'admin/mobile_api_admin_order_lifecycle_declarations_part_02.dart';
part 'admin/mobile_api_admin_queue_models_helpers_part_02.dart';
part 'admin/mobile_api_admin_users_workers_models_part_01.dart';
part 'admin/mobile_api_admin_items_MobileApiAdminItems_methods_01.dart';
part 'admin/mobile_api_admin_order_lifecycle_MobileApiAdminOrderLifecycle_methods_02.dart';
part 'admin/mobile_api_admin_training_MobileApiAdminTrainingWorkspace_methods_02.dart';
part 'admin/mobile_api_admin_production_queue_runtime_helpers_part_02.dart';
part 'admin/mobile_api_admin_progress_qr_declarations_part_01.dart';
part 'admin/mobile_api_admin_settings_monitor_declarations_part_01.dart';
part 'admin/mobile_api_inventory_movements_MobileApiInventoryMovements_methods_02.dart';
part 'admin/mobile_api_admin_raw_materials_helpers_part_02.dart';
part 'admin/mobile_api_admin_items_helpers_part_01.dart';
part 'admin/mobile_api_admin_raw_materials_MobileApiAdminRawMaterials_methods_02.dart';
part 'admin/mobile_api_admin_suppliers_customers_MobileApiAdminSuppliersCustomers_methods_01.dart';
part 'admin/mobile_api_admin_production_queue_runtime_declarations_part_01.dart';
part 'admin/mobile_api_admin_raw_materials_MobileApiAdminRawMaterials_methods_03.dart';
part 'admin/mobile_api_admin_users_workers_MobileApiAdminUsersWorkers_methods_02.dart';
part 'admin/mobile_api_admin_opening_wip_declarations_part_02.dart';
part 'admin/mobile_api_inventory_movements_MobileApiInventoryMovements_methods_03.dart';
part 'admin/mobile_api_admin_production_map_models_part_01.dart';
part 'admin/mobile_api_admin_queue_state_helpers_part_01.dart';
part 'admin/mobile_api_admin_items_MobileApiAdminItems_methods_05.dart';
part 'admin/mobile_api_admin_progress_qr_declarations_part_04.dart';
part 'admin/mobile_api_admin_users_workers_MobileApiAdminUsersWorkers_methods_01.dart';
part 'admin/mobile_api_admin_opening_wip_declarations_part_01.dart';
part 'admin/mobile_api_admin_raw_materials_declarations_part_01.dart';
part 'admin/mobile_api_admin_opening_wip_helpers_part_03.dart';
part 'admin/mobile_api_admin_items_helpers_part_02.dart';
part 'admin/mobile_api_admin_raw_materials_MobileApiAdminRawMaterials_methods_01.dart';
part 'admin/mobile_api_admin_suppliers_customers_MobileApiAdminSuppliersCustomers_methods_02.dart';
part 'admin/mobile_api_admin_capacity_schedule_declarations_part_02.dart';
part 'admin/mobile_api_inventory_movements_MobileApiInventoryMovements_methods_01.dart';
part 'admin/mobile_api_admin_training_helpers_part_01.dart';
part 'admin/mobile_api_admin_items_MobileApiAdminItems_methods_04.dart';
part 'admin/mobile_api_admin_queue_models_declarations_part_01.dart';
part 'admin/mobile_api_admin_training_MobileApiAdminTrainingWorkspace_methods_01.dart';
part 'admin/mobile_api_admin_progress_qr_declarations_part_02.dart';
part 'admin/mobile_api_admin_settings_monitor_declarations_part_02.dart';
part 'admin/mobile_api_admin_capacity_schedule_helpers_part_01.dart';
part 'admin/mobile_api_admin_items_MobileApiAdminItems_methods_03.dart';
part 'admin/mobile_api_admin_order_lifecycle_MobileApiAdminOrderLifecycle_methods_01.dart';
part 'admin/mobile_api_admin_progress_qr_helpers_part_03.dart';
part 'admin/mobile_api_admin_order_lifecycle_declarations_part_01.dart';
part 'admin/mobile_api_admin_items_MobileApiAdminItems_methods_02.dart';
part 'admin/mobile_api_admin_training_declarations_part_02.dart';
part 'admin/mobile_api_admin_production_map_helpers_part_02.dart';
part 'admin/mobile_api_admin_production_map_MobileApiAdminProductionMap_methods_02.dart';
part 'qolip/mobile_api_qolip_MobileApiQolip_methods_03.dart';
part 'qolip/mobile_api_qolip_models_part_01.dart';
part 'qolip/mobile_api_qolip_MobileApiQolip_methods_02.dart';
part 'qolip/mobile_api_qolip_MobileApiQolip_methods_04.dart';
part 'qolip/mobile_api_qolip_MobileApiQolip_methods_01.dart';
part 'gscale/mobile_api_gscale_models_part_02.dart';
part 'gscale/mobile_api_gscale_declarations_part_01.dart';
part 'werka/mobile_api_werka_MobileApiWerka_methods_02.dart';
part 'werka/mobile_api_werka_MobileApiWerka_methods_01.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_MobileApiAdminQueueActionResultTestMode_resplit_class.dart';
part 'admin/mobile_api_admin_queue_action_result_test_mode_MobileApiAdminQueueActionResultTestMode_resplit_class_MobileApiAdminQueueActionResultTestMode_resplit2_methods_01.dart';

class MobileApiException implements Exception {
  const MobileApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.apparatusOptions = const [],
    this.details = const [],
  });

  final String code;
  final String message;
  final int? statusCode;
  final List<String> apparatusOptions;
  final List<String> details;

  @override
  String toString() => message;
}

String maskPushToken(String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) {
    return '<empty>';
  }
  if (trimmed.length <= 12) {
    return trimmed;
  }
  return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 6)}';
}

Stream<T> withLiveStreamSilenceTimeout<T>(
  Stream<T> source, {
  Duration timeout = const Duration(seconds: 7),
}) {
  return source.timeout(timeout);
}

class MobileApi {
  MobileApi._();

  static final MobileApi instance = MobileApi._();
  static const String _lastCodeKey = 'last_login_code';
  static const String _lastPhoneKey = 'last_login_phone';
  static const int werkaPickerLimit = 50;

  static const String compiledBaseUrl = ServerEndpointStore.compiledBaseUrl;
  static const Duration _requestTimeout = Duration(seconds: 10);
  int _canonicalMutationCounter = 0;
  Future<bool>? _reauthenticationInFlight;

  static String get baseUrl => ServerEndpointStore.instance.baseUrl;

  Map<String, String> _headers(String token) {
    return {'Authorization': 'Bearer $token'};
  }

  String _nextCanonicalMutationIdempotencyKey(String operation) {
    _canonicalMutationCounter++;
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final counter = _canonicalMutationCounter.toRadixString(36);
    return 'mobile:canonical-apparatus:$operation:$micros-$counter';
  }

  Map<String, String> _canonicalMutationHeaders(
    String token,
    String idempotencyKey,
  ) {
    return _headers(token)
      ..['Content-Type'] = 'application/json'
      ..['idempotency-key'] = idempotencyKey;
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    if (NativeIrohTransport.hasEndpointTicket &&
        !ServerEndpointStore.instance.isRuntimeOverride) {
      return NativeIrohTransport.send(
        method: 'GET',
        uri: uri,
        headers: headers,
      ).timeout(_requestTimeout);
    }
    return http.get(uri, headers: headers).timeout(_requestTimeout);
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (NativeIrohTransport.hasEndpointTicket &&
        !ServerEndpointStore.instance.isRuntimeOverride) {
      return NativeIrohTransport.send(
        method: 'POST',
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(_requestTimeout);
    }
    return http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (NativeIrohTransport.hasEndpointTicket &&
        !ServerEndpointStore.instance.isRuntimeOverride) {
      return NativeIrohTransport.send(
        method: 'PUT',
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(_requestTimeout);
    }
    return http.put(uri, headers: headers, body: body).timeout(_requestTimeout);
  }

  Future<http.Response> _patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (NativeIrohTransport.hasEndpointTicket &&
        !ServerEndpointStore.instance.isRuntimeOverride) {
      return NativeIrohTransport.send(
        method: 'PATCH',
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(_requestTimeout);
    }
    return http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (NativeIrohTransport.hasEndpointTicket &&
        !ServerEndpointStore.instance.isRuntimeOverride) {
      return NativeIrohTransport.send(
        method: 'DELETE',
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(_requestTimeout);
    }
    return http
        .delete(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _directGet(Uri uri) {
    return http.get(uri).timeout(_requestTimeout);
  }

  Future<http.Response> _directPost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  String requireToken() {
    final String? token = AppSession.instance.token;
    final normalizedToken = token?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      throw Exception('No session token');
    }
    return normalizedToken;
  }

  Uri adminWarehouseLiveUri() {
    final Uri base = Uri.parse(baseUrl);
    final String scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/v1/mobile/admin/warehouses/live',
      queryParameters: {'token': requireToken()},
    );
  }

  Stream<Map<String, dynamic>> adminWarehouseLiveEvents() async* {
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    yield* connectWarehouseLive(adminWarehouseLiveUri());
  }

  Future<http.Response> _sendAuthorized(
    Future<http.Response> Function() send,
  ) async {
    final http.Response response = await send();
    if (response.statusCode != 401) {
      return response;
    }

    final bool refreshed = await _reauthenticateFromStorage();
    if (!refreshed) {
      return response;
    }
    return send();
  }

  Future<http.StreamedResponse> _sendMultipartAuthorized(
    Future<http.StreamedResponse> Function() send,
  ) async {
    return _sendStreamedAuthorized(send);
  }

  Future<http.StreamedResponse> _sendStreamedAuthorized(
    Future<http.StreamedResponse> Function() send,
  ) async {
    final http.StreamedResponse response = await send();
    if (response.statusCode != 401) {
      return response;
    }

    final bool refreshed = await _reauthenticateFromStorage();
    if (!refreshed) {
      return response;
    }
    return send();
  }

  Future<bool> _reauthenticateFromStorage() async {
    final inFlight = _reauthenticationInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    late final Future<bool> refresh;
    refresh = _performStoredAccountReauthentication().whenComplete(() {
      if (identical(_reauthenticationInFlight, refresh)) {
        _reauthenticationInFlight = null;
      }
    });
    _reauthenticationInFlight = refresh;
    return refresh;
  }

  Future<bool> _performStoredAccountReauthentication() async {
    final savedAccounts = SavedAccountRuntime.instance;
    if (savedAccounts.isInitialized) {
      final store = savedAccounts.store;
      try {
        return await store.runAccountOperation(() async {
          final activeId = store.activeAccountId;
          final savedSession =
              activeId == null ? null : await store.sessionFor(activeId);
          if (savedSession == null ||
              savedSession.phone.isEmpty ||
              savedSession.code.isEmpty) {
            await store.clearActive();
            await AppSession.instance.clear();
            return false;
          }
          try {
            final result = await _loginAt(
              targetBaseUrl: savedSession.account.baseUrl,
              phone: savedSession.phone,
              code: savedSession.code,
            );
            await store.upsertAuthenticated(
              baseUrl: savedSession.account.baseUrl,
              profile: result.profile,
              token: result.token,
              phone: savedSession.phone,
              code: savedSession.code,
              makeActive: true,
            );
            await AppSession.instance.setSession(
              token: result.token,
              profile: result.profile,
              werkaHomeBootstrap: result.werkaHome,
            );
            return true;
          } catch (_) {
            await store.clearActive();
            await AppSession.instance.clear();
            return false;
          }
        });
      } catch (_) {
        return false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final String phone = prefs.getString(_lastPhoneKey)?.trim() ?? '';
    final String code = prefs.getString(_lastCodeKey)?.trim() ?? '';
    if (phone.isEmpty || code.isEmpty) {
      return false;
    }

    try {
      await _performLogin(phone: phone, code: code);
      return true;
    } catch (_) {
      await AppSession.instance.clear();
      return false;
    }
  }
}
