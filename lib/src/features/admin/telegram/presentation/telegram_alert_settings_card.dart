import 'package:flutter/material.dart';
import '../../../../core/widgets/lists/m3_segmented_list.dart';
import '../models/telegram_models.dart';

class TelegramAlertSettingsCard extends StatefulWidget {
  const TelegramAlertSettingsCard({
    super.key,
    required this.settings,
    required this.users,
    required this.onSelectSender,
  });

  final TelegramAlertSettings settings;
  final List<TelegramUserAccount> users;
  final Future<void> Function(String?) onSelectSender;

  @override
  State<TelegramAlertSettingsCard> createState() =>
      _TelegramAlertSettingsCardState();
}

class _TelegramAlertSettingsCardState extends State<TelegramAlertSettingsCard> {
  bool _saving = false;

  String _text(String uz, String ru, String en) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ru' => ru,
        'en' => en,
        _ => uz,
      };

  Future<void> _select(String id) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSelectSender(id.isEmpty ? null : id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final users = widget.users.where((u) => u.userProfileConnected).toList();
    final sender = widget.users
        .where((u) => u.telegramUserId == settings.senderUserId)
        .firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final empty = _text('Tanlanmagan', 'Не выбрано', 'Not selected');
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.middle,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      backgroundColor: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.notifications_active_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                _text('Telegram ogohlantirishlari', 'Оповещения в Telegram',
                    'Telegram alerts'),
                style: Theme.of(context).textTheme.titleMedium,
              )),
            ]),
            const SizedBox(height: 8),
            Text(_text(
              'Bosmachining homashyo va Qolip ogohlantirishlarini tanlangan profil yuboradi.',
              'Выбранный профиль отправляет запросы печатников о сырье и формах.',
              'The selected profile sends operators’ raw material and mold alerts.',
            )),
            const SizedBox(height: 8),
            PopupMenuButton<String>(
              enabled: !_saving,
              initialValue: settings.senderUserId ?? '',
              onSelected: _select,
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: '',
                    child: Text(_text('O‘chirish', 'Отключить', 'Disable'))),
                for (final user in users)
                  PopupMenuItem(
                      value: user.telegramUserId,
                      child: Text(user.displayName)),
              ],
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_text('Ogohlantiruvchi profil',
                    'Профиль отправителя', 'Alert sender')),
                subtitle: Text(sender?.displayName ?? empty),
                trailing: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_drop_down),
              ),
            ),
            if (users.isEmpty)
              Text(_text(
                'Pastdagi Taklif yuborish bo‘limida Ogohlantiruvchi uchun QR tugmasini bosing yoki taklif linkini yuboring.',
                'В разделе приглашений ниже используйте QR или отправьте ссылку для отправителя оповещений.',
                'Use the Alert sender QR button or share its invite link in the invitation section below.',
              )),
            Text(
                '${_text('Guruh', 'Группа', 'Group')}: ${settings.groupTitle ?? empty}'),
            Text(
                '${_text('Material ta’minotchi', 'Поставщик сырья', 'Material supplier')}: ${settings.materialMembers.isEmpty ? empty : settings.materialMembers.join(', ')}'),
            Text(
                '${_text('Qolipchi', 'Специалист по формам', 'Mold operator')}: ${settings.qolipMembers.isEmpty ? empty : settings.qolipMembers.join(', ')}'),
            const SizedBox(height: 8),
            Text(
                _text(
                  'Guruh va mas’ullarni botning shaxsiy chatida /alerts orqali tanlang. Profilni almashtirsangiz, ularni qayta tanlang.',
                  'Выберите группу и ответственных в личном чате бота командой /alerts. При смене профиля выберите их заново.',
                  'Select the group and responsible members with /alerts in the bot’s private chat. Select them again after changing the sender.',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
