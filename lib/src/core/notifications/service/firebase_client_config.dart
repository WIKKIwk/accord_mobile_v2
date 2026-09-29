import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:xml/xml.dart';

/// Public Firebase SDK options only; never contains service-account credentials.
class FirebaseClientConfig {
  const FirebaseClientConfig(
      {required this.projectId,
      required this.appId,
      required this.apiKey,
      required this.senderId,
      required this.applicationId});
  final String projectId, appId, apiKey, senderId, applicationId;

  factory FirebaseClientConfig.fromJson(Map<String, dynamic> json) =>
      FirebaseClientConfig(
          projectId: json['project_id'] as String,
          appId: json['app_id'] as String,
          apiKey: json['api_key'] as String,
          senderId: json['messaging_sender_id'] as String,
          applicationId: json['application_id'] as String);

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'app_id': appId,
        'api_key': apiKey,
        'messaging_sender_id': senderId,
        'application_id': applicationId
      };

  FirebaseOptions get options => FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: appId.contains(':ios:') ? applicationId : null);

  bool matches(FirebaseOptions other) =>
      appId == other.appId &&
      projectId == other.projectId &&
      apiKey == other.apiKey &&
      senderId == other.messagingSenderId;

  void validate(String platform) {
    final application = platform == 'ios'
        ? 'com.example.accordMobileV2.mirsaid.uzkingshark'
        : 'com.example.accord_mobile_v2';
    if (!['ios', 'android'].contains(platform) ||
        applicationId != application ||
        !RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(projectId) ||
        !RegExp(r'^[0-9]{1,32}$').hasMatch(senderId) ||
        !appId.startsWith('1:$senderId:$platform:') ||
        appId.length <= '1:$senderId:$platform:'.length ||
        appId.length > 200 ||
        !RegExp(r'^AIza[A-Za-z0-9_-]{1,196}$').hasMatch(apiKey)) {
      throw const FormatException('Invalid Firebase client configuration');
    }
  }

  factory FirebaseClientConfig.fromFile(String raw, String platform) {
    if (utf8.encode(raw).length > 131072) {
      throw const FormatException('File too large');
    }
    late FirebaseClientConfig config;
    if (platform == 'android') {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final project = json['project_info'] as Map<String, dynamic>;
      final client = (json['client'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) =>
              c['client_info']?['android_client_info']?['package_name'] ==
              'com.example.accord_mobile_v2');
      config = FirebaseClientConfig(
          projectId: project['project_id'] as String,
          appId: client['client_info']['mobilesdk_app_id'] as String,
          apiKey: (client['api_key'] as List).first['current_key'] as String,
          senderId: project['project_number'].toString(),
          applicationId: client['client_info']['android_client_info']
              ['package_name'] as String);
    } else if (platform == 'ios') {
      final children = XmlDocument.parse(raw)
          .findAllElements('dict')
          .first
          .childElements
          .toList();
      final values = <String, String>{};
      for (var i = 0; i + 1 < children.length; i += 2) {
        if (children[i].name.local == 'key' &&
            children[i + 1].name.local == 'string') {
          values[children[i].innerText] = children[i + 1].innerText;
        }
      }
      config = FirebaseClientConfig(
          projectId: values['PROJECT_ID'] ?? '',
          appId: values['GOOGLE_APP_ID'] ?? '',
          apiKey: values['API_KEY'] ?? '',
          senderId: values['GCM_SENDER_ID'] ?? '',
          applicationId: values['BUNDLE_ID'] ?? '');
    } else {
      throw const FormatException('Unsupported platform');
    }
    config.validate(platform);
    return config;
  }
}
