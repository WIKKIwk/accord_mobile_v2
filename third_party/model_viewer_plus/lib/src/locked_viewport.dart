import 'package:webview_flutter/webview_flutter.dart';

/// Configure before navigation so the first gesture cannot zoom the page.
Future<void> configureModelViewerViewport(
  WebViewController controller, {
  required bool locked,
}) async {
  if (!locked) return;
  await controller.enableZoom(false);
  await controller.setOverScrollMode(WebViewOverScrollMode.never);
}
