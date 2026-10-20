part of 'app_localizations.dart';

extension AppLocalizationsQolipSharedSets on AppLocalizations {
  String qolipSharedSetText(String key,
      {Map<String, Object> values = const {}}) {
    var text = switch (key) {
      'title' => _t('Mavjud komplektdan foydalanish', 'Reuse existing set',
          'Использовать существующий комплект'),
      'body' => _t(
          'Komplekt: {code}\nBog‘langan mahsulotlar: {products}\n\nKomplektda {count} ta qolip mavjud.\n{members}\n\nShu komplektni mavjud ranglari bilan «{target}» uchun ham qayta ishlatishga rozimisiz?\nFormada tanlangan ranglar va o‘lcham o‘rniga mavjud komplekt ma’lumotlari olinadi.',
          'Set: {code}\nLinked products: {products}\n\nThe set contains {count} molds.\n{members}\n\nReuse this entire set with its existing colors for “{target}”?\nExisting set data will replace the colors and size selected in this form.',
          'Комплект: {code}\nСвязанные товары: {products}\n\nВ комплекте {count} форм.\n{members}\n\nИспользовать весь комплект с существующими цветами также для «{target}»?\nВместо выбранных в форме цветов и размера будут использованы данные существующего комплекта.'),
      'yes' => _t('Ha', 'Yes', 'Да'),
      'no' => _t('Yo‘q', 'No', 'Нет'),
      'changed' => _t(
          'Komplekt tarkibi o‘zgardi. Yangilangan son va ranglarni qayta tasdiqlang.',
          'The set changed. Confirm its updated count and colors.',
          'Состав комплекта изменился. Подтвердите новое количество и цвета.'),
      'ambiguous' => _t(
          'Kodlar bir nechta komplektga tegishli. Komplekt kodini yoki uning ichidagi bitta qolip kodini kiriting.',
          'The codes belong to multiple sets. Enter the set code or one member mold code.',
          'Коды относятся к разным комплектам. Введите код комплекта или одной его формы.'),
      'warehouse' => _t(
          'Yangi komplekt uchun omborni tanlang.',
          'Select a warehouse for the new set.',
          'Выберите склад для нового комплекта.'),
      'id' => _t('Komplekt ID', 'Set ID', 'ID комплекта'),
      'extensions' =>
        _t('Qo‘shimcha qoliplar', 'Additional molds', 'Дополнительные формы'),
      'copied' => _t(
          'Komplekt ID nusxalandi', 'Set ID copied', 'ID комплекта скопирован'),
      'edit' => _t(
          'Bu komplektdan foydalanadigan mahsulotlar: {products}. Saqlangan tahrir ularning barchasida ko‘rinadi.',
          'Products using this set: {products}. Saved changes apply to all of them.',
          'Комплект используется товарами: {products}. Изменения будут видны у всех этих товаров.'),
      'qr' => _t(
          'Qolip kodi o‘zgarsa, uning QR yorlig‘ini qayta chop eting.',
          'Reprint the QR label if you change the mold code.',
          'При изменении кода формы напечатайте новую QR-этикетку.'),
      'transfer' => _t(
          'Qolip bog‘lanishi o‘zgargan. Ro‘yxatni yangilab, qayta tanlang.',
          'The mold assignment changed. Refresh and select again.',
          'Привязка формы изменилась. Обновите список и выберите заново.'),
      _ => key,
    };
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }
}
