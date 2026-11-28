part of '../mobile_api.dart';

const qolipInformationMaxDetails = 4000;
const qolipInformationMaxFileBytes = 20 * 1024 * 1024;

enum QolipInformationTarget {
  product('products'),
  paddon('paddons'),
  archivePaddon('archive/paddons');

  const QolipInformationTarget(this.path);
  final String path;
}

typedef QolipInformationStatus = ({int revision, bool hasContent});

QolipInformationStatus? _qolipInformationStatus(Object? json) {
  if (json
      case {
        'revision': final int revision,
        'has_content': final bool hasContent
      }) {
    return (revision: revision, hasContent: hasContent);
  }
  return null;
}

class QolipProductInformation {
  const QolipProductInformation._({
    required this.revision,
    required this.details,
    this.attachmentName,
    this.attachmentSize,
  });

  final int revision;
  final String details;
  final String? attachmentName;
  final int? attachmentSize;

  bool get hasContent => details.isNotEmpty || attachmentName != null;

  static QolipProductInformation _decode(Object? json) {
    if (json is! Map)
      throw const FormatException('Missing product information');
    final revision = json['revision'];
    final details = json['details'];
    final name = json['attachment_name'];
    final size = json['attachment_size'];
    if (revision is! int ||
        revision < 0 ||
        details is! String ||
        (name == null && size != null) ||
        (name != null &&
            (name is! String ||
                name.isEmpty ||
                size is! int ||
                size <= 0 ||
                size > qolipInformationMaxFileBytes))) {
      throw const FormatException('Invalid product information');
    }
    return QolipProductInformation._(
      revision: revision,
      details: details,
      attachmentName: name as String?,
      attachmentSize: size as int?,
    );
  }
}

extension MobileApiQolipProductInformation on MobileApi {
  Future<QolipProductInformation> qolipInformation(
    QolipInformationTarget target,
    String id,
  ) async {
    final uri = _qolipInformationUri(target, id);
    final response = await _requestQolipInformation(
        (headers) => _get(uri, headers: headers));
    return _decodeQolipInformation(response);
  }

  Future<QolipProductInformation> qolipSaveInformation(
    QolipInformationTarget target,
    String id, {
    required int revision,
    required String details,
    required bool removeAttachment,
    ({String name, Uint8List bytes})? attachment,
  }) async {
    final uri = _qolipInformationUri(target, id);
    final response = await _requestQolipInformation((headers) async {
      final request = http.MultipartRequest('PUT', uri)
        ..headers.addAll(headers)
        ..fields['edit'] = jsonEncode({
          'revision': revision,
          'details': details,
          'remove_attachment': removeAttachment,
        });
      if (attachment != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'attachment',
          attachment.bytes,
          filename: attachment.name,
        ));
      }
      return http.Response.fromStream(await _httpClient.send(request));
    }).timeout(const Duration(seconds: 60));
    return _decodeQolipInformation(response);
  }

  Future<Uint8List> qolipDownloadInformationAttachment(
    QolipInformationTarget target,
    String id,
    QolipProductInformation information,
  ) async {
    final uri = _qolipInformationUri(target, id, revision: information.revision);
    final response = await _requestQolipInformation(
      (headers) => _httpClient.get(uri, headers: headers),
    ).timeout(const Duration(seconds: 60));
    _checkQolipInformationResponse(response);
    if (information.attachmentSize == null ||
        response.bodyBytes.length != information.attachmentSize ||
        response.headers['content-type'] != 'application/octet-stream') {
      throw const FormatException('Invalid product attachment');
    }
    return response.bodyBytes;
  }

  Uri _qolipInformationUri(
    QolipInformationTarget target,
    String id, {
    int? revision,
  }) {
    final path = revision == null ? 'information' : 'information/attachment';
    return Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/${target.path}/$path')
        .replace(queryParameters: {
      'id': id,
      if (revision != null) 'revision': '$revision',
    });
  }

  Future<http.Response> _requestQolipInformation(
    Future<http.Response> Function(Map<String, String>) send,
  ) async {
    final scope = currentSessionReadScope();
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw StateError('Qolip information session changed');
      }
      return send(_headers(requireToken()));
    });
    if (scope != currentSessionReadScope()) {
      throw StateError('Qolip information session changed');
    }
    return response;
  }

  Future<QolipProductInformation> _decodeQolipInformation(
    http.Response response,
  ) async {
    _checkQolipInformationResponse(response);
    final payload = await decodeJsonMapPayload(response.body);
    return QolipProductInformation._decode(payload['information']);
  }

  void _checkQolipInformationResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_information_failed',
        fallbackMessage: 'Qolip ma’lumotini ochib bo‘lmadi',
      );
    }
  }
}
