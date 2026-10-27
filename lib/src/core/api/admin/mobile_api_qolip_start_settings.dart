part of '../mobile_api.dart';

class AdminQolipStartSettings {
  const AdminQolipStartSettings({
    this.automaticConfirmationEnabled = false,
    this.revision = 0,
  });

  final bool automaticConfirmationEnabled;
  final int revision;

  factory AdminQolipStartSettings.fromJson(Map<String, dynamic> json) {
    if (json['automatic_confirmation_enabled'] is! bool ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0) {
      throw _invalidQolipAutomaticConfirmation();
    }
    return AdminQolipStartSettings(
      automaticConfirmationEnabled:
          json['automatic_confirmation_enabled'] as bool,
      revision: json['revision'] as int,
    );
  }
}

class AdminQolipAutomaticSet {
  const AdminQolipAutomaticSet({
    required this.setId,
    required this.fingerprint,
    required this.ready,
    this.blockingReasonCode = '',
  });

  final String setId;
  final String fingerprint;
  final bool ready;
  final String blockingReasonCode;

  factory AdminQolipAutomaticSet.fromJson(Map<String, dynamic> json) {
    if (json['set_id'] is! String ||
        (json['set_id'] as String).trim().isEmpty ||
        json['fingerprint'] is! String ||
        !_qolipFingerprint.hasMatch(json['fingerprint'] as String) ||
        json['ready'] is! bool ||
        json['blocking_reason_code'] is! String ||
        ((json['ready'] as bool) &&
            (json['blocking_reason_code'] as String).isNotEmpty)) {
      throw _invalidQolipAutomaticConfirmation();
    }
    return AdminQolipAutomaticSet(
      setId: (json['set_id'] as String).trim(),
      fingerprint: json['fingerprint'] as String,
      ready: json['ready'] as bool,
      blockingReasonCode: (json['blocking_reason_code'] as String).trim(),
    );
  }

  AdminQolipAutomaticConfirmation confirmation(int policyRevision) {
    if (!ready || blockingReasonCode.isNotEmpty) {
      throw _invalidQolipAutomaticConfirmation();
    }
    return AdminQolipAutomaticConfirmation(
      setId: setId,
      fingerprint: fingerprint,
      policyRevision: policyRevision,
    );
  }
}

class AdminQolipAutomaticConfirmation {
  const AdminQolipAutomaticConfirmation({
    required this.setId,
    required this.fingerprint,
    required this.policyRevision,
  });

  final String setId;
  final String fingerprint;
  final int policyRevision;

  Map<String, dynamic> toJson() {
    if (setId.trim().isEmpty ||
        !_qolipFingerprint.hasMatch(fingerprint) ||
        policyRevision < 0) {
      throw _invalidQolipAutomaticConfirmation();
    }
    return {
      'method': 'automatic',
      'set_id': setId.trim(),
      'fingerprint': fingerprint,
      'policy_revision': policyRevision,
    };
  }
}

final _qolipFingerprint = RegExp(r'^[0-9a-f]{64}$');

MobileApiException _invalidQolipAutomaticConfirmation() =>
    const MobileApiException(
      code: 'qolip_automatic_confirmation_invalid',
      message: 'Qoliplarni avtomatik tasdiqlash ma’lumoti tasdiqlanmadi',
    );

extension MobileApiQolipStartSettings on MobileApi {
  Future<AdminQolipStartSettings> qolipStartSettings() async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-start-settings'),
          headers: _headers(requireToken()),
        ));
    return _qolipStartSettingsResponse(response);
  }

  Future<AdminQolipStartSettings> setQolipAutomaticConfirmationEnabled(
      bool enabled) async {
    final response = await _sendAuthorized(() => _put(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-start-settings'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'automatic_confirmation_enabled': enabled}),
        ));
    final settings = _qolipStartSettingsResponse(response);
    if (settings.automaticConfirmationEnabled != enabled) {
      throw _invalidQolipAutomaticConfirmation();
    }
    return settings;
  }

  AdminQolipStartSettings _qolipStartSettingsResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'qolip_start_settings');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map ||
        payload['ok'] != true ||
        payload['settings'] is! Map) {
      throw _invalidQolipAutomaticConfirmation();
    }
    return AdminQolipStartSettings.fromJson(
        (payload['settings'] as Map).cast<String, dynamic>());
  }
}
