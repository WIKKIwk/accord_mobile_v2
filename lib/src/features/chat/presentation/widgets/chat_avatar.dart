import 'package:flutter/material.dart';

import '../../../../core/widgets/display/image_fade.dart';
import '../../../../core/api/mobile_api.dart';
import '../../../shared/presentation/widgets/refreshing_avatar.dart';
import '../../models/chat_models.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 22,
    this.peer,
  });

  final String name;
  final String avatarUrl;
  final double radius;
  final ChatPrincipal? peer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final participant = peer;
    return RefreshingAvatar(
        url: avatarUrl,
        refreshUrl: participant == null
            ? null
            : () => MobileApi.instance.chatPeerAvatarUrl(participant),
        builder: (image, onError) => ClipOval(
              child: SizedBox.square(
                dimension: radius * 2,
                child: image == null
                    ? _fallback(scheme, initial)
                    : ImageFade(
                        image: image,
                        fit: BoxFit.cover,
                        cacheWidth: (radius * 4).round(),
                        cacheHeight: (radius * 4).round(),
                        placeholder: _fallback(scheme, initial),
                        errorBuilder: (context, _) {
                          onError();
                          return _fallback(scheme, initial);
                        },
                      ),
              ),
            ));
  }

  Widget _fallback(ColorScheme scheme, String initial) {
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.8,
          ),
        ),
      ),
    );
  }
}
