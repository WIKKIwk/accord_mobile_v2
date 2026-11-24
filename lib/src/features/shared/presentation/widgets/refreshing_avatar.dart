import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/session/session_read_scope.dart';
import '../../../../core/session/state/app_session.dart';

/// Keeps the normal Flutter image cache and renews the API URL once on failure.
class RefreshingAvatar extends StatefulWidget {
  const RefreshingAvatar({
    super.key,
    required this.url,
    required this.refreshUrl,
    required this.builder,
  });

  final String url;
  final Future<String> Function()? refreshUrl;
  final Widget Function(ImageProvider<Object>? image, VoidCallback onError)
      builder;

  @override
  State<RefreshingAvatar> createState() => _RefreshingAvatarState();
}

class _RefreshingAvatarState extends State<RefreshingAvatar> {
  bool attempted = false;
  String? renewed;

  @override
  void didUpdateWidget(RefreshingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      attempted = false;
      renewed = null;
    }
  }

  void onError() {
    final refresh = widget.refreshUrl;
    if (attempted || refresh == null) return;
    attempted = true;
    final original = widget.url;
    final scope = currentSessionReadScope();
    final token = AppSession.instance.token;
    bool current() =>
        mounted &&
        widget.url == original &&
        scope == currentSessionReadScope() &&
        token == AppSession.instance.token;
    // The image's errorBuilder can run during build.
    scheduleMicrotask(() async {
      if (!current()) return;
      try {
        final url = await refresh();
        if (current()) setState(() => renewed = url.trim());
      } catch (_) {
        // Keep the caller's initials if the profile is unavailable.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = renewed ?? widget.url.trim();
    final uri = Uri.tryParse(url);
    final valid = uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    return KeyedSubtree(
      // The server may return the same URL for an unchanged external image.
      key: ValueKey(renewed != null),
      child: widget.builder(valid ? NetworkImage(url) : null, onError),
    );
  }
}
