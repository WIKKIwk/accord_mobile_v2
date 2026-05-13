import 'package:flutter/material.dart';

ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>?
    _currentAdminTopNotice;

void showAdminTopNotice(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentMaterialBanner();

  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      leading: Icon(icon),
      content: Text(message),
      actions: const [SizedBox.shrink()],
      minActionBarHeight: 0,
    ),
  );
  _currentAdminTopNotice = controller;
  Future<void>.delayed(const Duration(milliseconds: 1850), () {
    if (_currentAdminTopNotice == controller) {
      messenger.hideCurrentMaterialBanner();
      _currentAdminTopNotice = null;
    }
  });
}
