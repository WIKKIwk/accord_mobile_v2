import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../api/mobile_api.dart';

/// Constructing the full-size provider is lazy: only displaying the zoom
/// overlay downloads it. Its key can never alias a thumbnail or another login.
class OrderImageProvider extends ImageProvider<OrderImageProvider> {
  OrderImageProvider(String imageUrl, {this.thumbnail = false})
      : url = MobileApi.instance
            .orderImageRequestUri(imageUrl, thumbnail: thumbnail)
            .toString(),
        scope = MobileApi.instance.orderImageCacheScope {
    final query = Uri.parse(url).queryParameters;
    refreshEpoch =
        query['id']?.isNotEmpty == true || query['image_id']?.isNotEmpty == true
            ? 0
            : DateTime.now().millisecondsSinceEpoch ~/ 30000;
  }
  final String url;
  final bool thumbnail;
  final String scope;
  late final int refreshEpoch;

  @override
  Future<OrderImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
          OrderImageProvider key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    if (scope != MobileApi.instance.orderImageCacheScope) {
      throw StateError('Image session changed');
    }
    final bytes = await MobileApi.instance
        .cachedOrderImageBytes(url, thumbnail: thumbnail);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Order image unavailable');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is OrderImageProvider &&
      url == other.url &&
      scope == other.scope &&
      refreshEpoch == other.refreshEpoch &&
      thumbnail == other.thumbnail;
  @override
  int get hashCode => Object.hash(url, scope, thumbnail, refreshEpoch);
}
