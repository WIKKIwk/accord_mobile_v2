enum TelegramInviteRole {
  admin,
  salesManager;

  factory TelegramInviteRole.fromJson(String? value) {
    return value?.trim().toLowerCase() == 'sales_manager'
        ? TelegramInviteRole.salesManager
        : TelegramInviteRole.admin;
  }

  String get jsonName {
    return this == TelegramInviteRole.salesManager ? 'sales_manager' : 'admin';
  }

  String label(
      {required String adminLabel, required String salesManagerLabel}) {
    return this == TelegramInviteRole.salesManager
        ? salesManagerLabel
        : adminLabel;
  }
}

enum TelegramDeliveryMode {
  bot,
  userProfile;

  factory TelegramDeliveryMode.fromJson(String? value) {
    return value?.trim().toLowerCase() == 'user_profile'
        ? TelegramDeliveryMode.userProfile
        : TelegramDeliveryMode.bot;
  }
}

class TelegramBotSettings {
  const TelegramBotSettings({
    required this.botUsername,
    required this.tokenConfigured,
    required this.tokenHint,
  });

  final String botUsername;
  final bool tokenConfigured;
  final String tokenHint;

  factory TelegramBotSettings.fromJson(Map<String, dynamic> json) {
    return TelegramBotSettings(
      botUsername: json['bot_username'] as String? ?? '',
      tokenConfigured: json['token_configured'] as bool? ?? false,
      tokenHint: json['token_hint'] as String? ?? '',
    );
  }
}

class TelegramUserAccount {
  const TelegramUserAccount({
    required this.telegramUserId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.inviteToken,
    required this.joinedAtUnix,
    this.phoneNumber = '',
    this.deliveryMode = TelegramDeliveryMode.bot,
    this.userProfileConnected = false,
    this.selectedChatId,
    this.selectedChatTitle,
    this.selectedChatType,
  });

  final String telegramUserId;
  final String username;
  final String displayName;
  final TelegramInviteRole role;
  final String inviteToken;
  final int joinedAtUnix;
  final String phoneNumber;
  final TelegramDeliveryMode deliveryMode;
  final bool userProfileConnected;
  final String? selectedChatId;
  final String? selectedChatTitle;
  final String? selectedChatType;

  factory TelegramUserAccount.fromJson(Map<String, dynamic> json) {
    return TelegramUserAccount(
      telegramUserId: json['telegram_user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: TelegramInviteRole.fromJson(json['role'] as String?),
      inviteToken: json['invite_token'] as String? ?? '',
      joinedAtUnix: json['joined_at_unix'] as int? ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      deliveryMode: TelegramDeliveryMode.fromJson(
        json['delivery_mode'] as String?,
      ),
      userProfileConnected: json['user_profile_connected'] as bool? ?? false,
      selectedChatId: json['selected_chat_id']?.toString(),
      selectedChatTitle: json['selected_chat_title']?.toString(),
      selectedChatType: json['selected_chat_type']?.toString(),
    );
  }
}

class TelegramChat {
  const TelegramChat({
    required this.chatId,
    required this.title,
    required this.username,
    required this.chatType,
    required this.threadId,
    required this.connectedAtUnix,
    required this.lastSeenAtUnix,
  });

  final String chatId;
  final String title;
  final String username;
  final String chatType;
  final int? threadId;
  final int connectedAtUnix;
  final int lastSeenAtUnix;

  factory TelegramChat.fromJson(Map<String, dynamic> json) {
    return TelegramChat(
      chatId: json['chat_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      chatType: json['chat_type']?.toString() ?? '',
      threadId: (json['thread_id'] as num?)?.toInt(),
      connectedAtUnix: (json['connected_at_unix'] as num?)?.toInt() ?? 0,
      lastSeenAtUnix: (json['last_seen_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class TelegramAdminOverview {
  const TelegramAdminOverview({
    required this.bot,
    required this.users,
    required this.chats,
  });

  final TelegramBotSettings bot;
  final List<TelegramUserAccount> users;
  final List<TelegramChat> chats;

  factory TelegramAdminOverview.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    return TelegramAdminOverview(
      bot: TelegramBotSettings.fromJson(
        (json['bot'] as Map<dynamic, dynamic>? ?? const {})
            .cast<String, dynamic>(),
      ),
      users: rawUsers is List
          ? rawUsers
              .whereType<Map>()
              .map(
                (item) => TelegramUserAccount.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
          : const <TelegramUserAccount>[],
      chats: json['chats'] is List
          ? (json['chats'] as List)
              .whereType<Map>()
              .map(
                (item) => TelegramChat.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
          : const <TelegramChat>[],
    );
  }
}

class TelegramInvite {
  const TelegramInvite({
    required this.role,
    required this.inviteUrl,
  });

  final TelegramInviteRole role;
  final String inviteUrl;

  factory TelegramInvite.fromJson(Map<String, dynamic> json) {
    return TelegramInvite(
      role: TelegramInviteRole.fromJson(json['role'] as String?),
      inviteUrl: json['invite_url'] as String? ?? '',
    );
  }
}
