part of 'app_localizations.dart';

extension AppLocalizationsQolipManagement on AppLocalizations {
  String qolipManagementText(String key,
      {Map<String, Object> values = const {}}) {
    var text = switch (key) {
      'title' => _t('Komplektlar', 'Sets', 'Комплекты'),
      'search' => _t('Komplekt nomi yoki kod', 'Set name or code',
          'Название комплекта или код'),
      'rename' => _t('Komplekt nomini o‘zgartirish', 'Rename set',
          'Изменить название комплекта'),
      'name' => _t('Komplekt nomi', 'Set name', 'Название комплекта'),
      'name_invalid' => _t(
          '1–160 ta belgidan iborat nom kiriting',
          'Enter a name with 1–160 characters',
          'Введите название из 1–160 символов'),
      'name_conflict' => _t(
          'Bu nom boshqa komplektga berilgan. Boshqa nom kiriting.',
          'Another set already uses this name. Enter a different name.',
          'Это название уже используется другим комплектом. Введите другое.'),
      'rename_failed' => _t(
          'Komplekt nomi saqlanmadi',
          'Could not save the set name',
          'Не удалось сохранить название комплекта'),
      'renamed' => _t('Komplekt nomi saqlandi', 'Set name saved',
          'Название комплекта сохранено'),
      'empty' =>
        _t('Komplektlar topilmadi', 'No sets found', 'Комплекты не найдены'),
      'members_empty' => _t('Komplektga qolip kodi qo‘shing',
          'Add a mold code to this set', 'Добавьте код формы в комплект'),
      'add' => _t('Qolip kodi qo‘shish', 'Add mold code', 'Добавить код формы'),
      'create' => _t('Komplekt qo‘shish', 'Add set', 'Добавить комплект'),
      'create_hint' => _t(
          'Komplekt kodi avtomatik beriladi. Mahsulotga keyin ulashingiz mumkin.',
          'The set code is assigned automatically. You can link a product later.',
          'Код комплекта присвоится автоматически. Товар можно привязать позже.'),
      'created' => _t('Komplekt saqlandi: {code}', 'Set saved: {code}',
          'Комплект сохранён: {code}'),
      'warehouse_required' =>
        _t('Omborni tanlang', 'Select a warehouse', 'Выберите склад'),
      'choose' => _t('Komplekt tanlash', 'Choose set', 'Выбрать комплект'),
      'set_name_hint' => _t(
          'Komplekt nomi yoki qolip kodini yozing',
          'Enter a set name or mold code',
          'Введите название комплекта или код формы'),
      'matches' => _t('Mos komplektlar ({count})', 'Matching sets ({count})',
          'Подходящие комплекты ({count})'),
      'all_matches' => _t('Barchasini ko‘rish ({count})', 'Show all ({count})',
          'Показать все ({count})'),
      'lookup_retry' => _t('Komplektlarni qayta qidirish', 'Retry set search',
          'Повторить поиск комплектов'),
      'copy_code' => _t('Komplekt kodini nusxalash', 'Copy set code',
          'Скопировать код комплекта'),
      'new_set' => _t('Yangi muqobil komplekt', 'New alternative set',
          'Новый альтернативный комплект'),
      'new_code' => _t('Yangi kod', 'New code', 'Новый код'),
      'existing_code' => _t('Mavjud kod', 'Existing code', 'Существующий код'),
      'existing_hint' => _t(
          'Faqat shu kod mahsulotga qo‘shiladi. Uning mavjud rangi va o‘lchami olinadi.',
          'Only this code is added to the product, using its existing color and size.',
          'К товару добавится только этот код с существующими цветом и размером.'),
      'set_scope' => _t(
          'Bu o‘zgarish komplekt ulangan barcha mahsulotlarga qo‘llanadi.',
          'This change applies to every product linked to the set.',
          'Изменение применяется ко всем товарам, связанным с комплектом.'),
      'product_scope' => _t(
          'Kod faqat shu mahsulotga qo‘shiladi va uning barcha muqobil komplektlari bilan ishlatiladi. Umumiy komplekt tarkibi saqlanadi.',
          'The code is added only to this product and used with all its alternative sets. The shared set stays unchanged.',
          'Код добавится только к этому товару и будет использоваться со всеми его альтернативными комплектами. Общий состав комплекта сохранится.'),
      'linked' => _t('Bog‘langan mahsulotlar: {count}',
          'Linked products: {count}', 'Связанных товаров: {count}'),
      'delete_title' => _t('Komplektdan o‘chirish?', 'Remove from set?',
          'Удалить из комплекта?'),
      'delete_last' => _t(
          'Bu oxirgi qolip. Bo‘shagan komplekt ro‘yxatda ko‘rsatilmaydi.',
          'This is the last mold. The empty set will be hidden from the list.',
          'Это последняя форма. Пустой комплект больше не будет отображаться в списке.'),
      'delete_body' => _t(
          '«{code}» qolipi komplektdan va undan foydalanadigan barcha mahsulotlardan o‘chiriladi.',
          'Mold “{code}” will be removed from the set and every product using it.',
          'Форма «{code}» будет удалена из комплекта и всех товаров, которые её используют.'),
      'local_delete' => _t(
          '{count} ta qolip faqat tanlangan mahsulotlardan chiqariladi. Komplekt va boshqa mahsulotlardagi tarkib saqlanadi.',
          '{count} molds will be removed only from the selected products. The set and other products stay unchanged.',
          '{count} форм будут исключены только из выбранных товаров. Комплект и другие товары сохранят свой состав.'),
      'saved' =>
        _t('O‘zgarish saqlandi', 'Changes saved', 'Изменения сохранены'),
      'code_required' =>
        _t('Qolip kodini kiriting', 'Enter a mold code', 'Введите код формы'),
      'size_required' => _t('Musbat o‘lcham kiriting', 'Enter a positive size',
          'Введите положительный размер'),
      'color_required' =>
        _t('Rangni tanlang', 'Select a color', 'Выберите цвет'),
      _ => key,
    };
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }
}
