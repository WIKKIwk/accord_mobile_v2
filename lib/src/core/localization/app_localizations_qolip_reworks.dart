part of 'app_localizations.dart';

extension AppLocalizationsQolipReworks on AppLocalizations {
  String qolipReworkText(String key, {Map<String, Object> values = const {}}) {
    var text = switch (key) {
      'title' =>
        _t('Peredelkadagi qoliplar', 'Molds in rework', 'Формы на переделке'),
      'send_molds' => _t('Qolipni peredelkaga berish', 'Send molds for rework',
          'Отправить формы на переделку'),
      'send_sets' => _t('Komplektni peredelkaga berish', 'Send sets for rework',
          'Отправить комплекты на переделку'),
      'send_confirm' => _t(
          '{count} ta qolip peredelkaga berilsinmi?\n\n{codes}',
          'Send {count} molds for rework?\n\n{codes}',
          'Отправить формы ({count}) на переделку?\n\n{codes}'),
      'send' => _t('Berish', 'Send', 'Отправить'),
      'sent' => _t(
          '{count} ta qolip peredelkaga berildi',
          '{count} molds sent for rework',
          'Формы отправлены на переделку: {count}'),
      'return' => _t('Qaytdi', 'Mark returned', 'Вернулись'),
      'return_selected' => _t('Tanlanganlar qaytdi ({count})',
          'Mark selected returned ({count})', 'Вернуть выбранные ({count})'),
      'return_confirm' => _t(
          '{count} ta qolip qaytdi deb belgilansinmi? Ularning probegi 0 dan boshlanadi.',
          'Mark {count} molds returned? Their mileage starts again at 0.',
          'Отметить возвращёнными {count} форм? Их пробег начнётся с 0.'),
      'returned' => _t('{count} ta qolip qaytdi', '{count} molds returned',
          'Формы вернулись: {count}'),
      'open' => _t('Peredelkada', 'In rework', 'На переделке'),
      'history' => _t('Qaytganlar', 'Returned', 'Вернувшиеся'),
      'search' => _t('Mahsulot, komplekt yoki qolip kodi',
          'Product, set or mold code', 'Товар, комплект или код формы'),
      'empty' => _t('Peredelkada qolip yo‘q', 'No molds in rework',
          'Нет форм на переделке'),
      'history_empty' => _t(
          'Qaytgan qoliplar yo‘q', 'No returned molds', 'Нет вернувшихся форм'),
      'sent_at' => _t('Berilgan', 'Sent', 'Отправлено'),
      'returned_at' => _t('Qaytgan', 'Returned', 'Возвращено'),
      'in_rework_count' => _t('Peredelkada: {count}', 'In rework: {count}',
          'На переделке: {count}'),
      'mileage' => _t('Probeg tarixi', 'Mileage history', 'История пробега'),
      'distance' => _t('Aylangan masofa:', 'Distance travelled:',
          'Пройденное расстояние:'),
      'current' => _t('Joriy probeg: {meter} m', 'Current mileage: {meter} m',
          'Текущий пробег: {meter} м'),
      'not_started' => _t('Probeg hisobi hali boshlanmagan',
          'Mileage tracking has not started', 'Учёт пробега ещё не начат'),
      'cycle' => _t('{meter} m', '{meter} m', '{meter} м'),
      'active_cycle' => _t('Joriy davr', 'Current cycle', 'Текущий период'),
      'already_away' => _t(
          'Bu qolip peredelkada. Ro‘yxatni yangilang.',
          'This mold is in rework. Refresh the list.',
          'Форма на переделке. Обновите список.'),
      'conflict' => _t(
          'Peredelka holati o‘zgargan. Ro‘yxatni yangilang.',
          'The rework state changed. Refresh the list.',
          'Состояние переделки изменилось. Обновите список.'),
      'failed' => _t(
          'Peredelka amali bajarilmadi',
          'The rework operation failed',
          'Не удалось выполнить операцию переделки'),
      'session_changed' => _t(
          'Sessiya o‘zgardi. Sahifani yangilang.',
          'The session changed. Refresh the page.',
          'Сессия изменилась. Обновите страницу.'),
      'history_locked' => _t(
          'Bu qolipning peredelka va probeg tarixi bor. Uning kodini o‘zgartirish yoki qolipni o‘chirish mumkin emas.',
          'This mold has rework and mileage history. Its code cannot be renamed and the mold cannot be deleted.',
          'У формы есть история переделок и пробега. Изменить её код или удалить форму нельзя.'),
      'order_unavailable' => _t(
          'Buyurtma qoliplari peredelkada. Barcha kerakli qoliplar qaytmaguncha ishni boshlash mumkin emas.',
          'This order has molds in rework. Work cannot start until all required molds return.',
          'Формы заказа на переделке. Начать работу можно после возврата всех необходимых форм.'),
      _ => key,
    };
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }
}
