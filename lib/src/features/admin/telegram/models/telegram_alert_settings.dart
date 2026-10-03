class TelegramAlertSettings {
  const TelegramAlertSettings({
    this.senderUserId,
    this.groupTitle,
    this.materialMembers = const [],
    this.qolipMembers = const [],
  });

  final String? senderUserId;
  final String? groupTitle;
  final List<String> materialMembers;
  final List<String> qolipMembers;

  factory TelegramAlertSettings.fromJson(Map<String, dynamic> json) {
    List<String> names(Object? raw) => raw is List
        ? raw.whereType<Map>().map((member) {
            final username = member['username']?.toString() ?? '';
            return username.isNotEmpty
                ? '@$username'
                : member['display_name']?.toString() ?? '${member['user_id']}';
          }).toList(growable: false)
        : const [];
    return TelegramAlertSettings(
      senderUserId: json['sender_user_id']?.toString(),
      groupTitle: (json['group'] as Map?)?['title']?.toString(),
      materialMembers: names(json['raw_material_members']),
      qolipMembers: names(json['qolip_members']),
    );
  }
}
