part of 'app_localizations.dart';

extension AppLocalizationsQolipProductPdf on AppLocalizations {
  String qolipProductPdfText(String key) => switch (key) {
        'share' => _t('Qoliplar PDF’ini ulashish', 'Share molds PDF',
            'Поделиться PDF форм', 'سانچوں کی PDF شیئر کریں'),
        'title' => _t('Mahsulot qoliplari', 'Product molds', 'Формы товара',
            'مصنوعات کے سانچے'),
        'product_code' =>
          _t('Mahsulot kodi', 'Product code', 'Код товара', 'مصنوعات کا کوڈ'),
        'total' => _t('Jami qoliplar', 'Total molds', 'Всего форм', 'کل سانچے'),
        'exported' => _t('Tuzilgan (UTC)', 'Exported (UTC)', 'Создан (UTC)',
            'تیار کردہ (UTC)'),
        'set_id' => _t('Komplekt ID', 'Set ID', 'ID комплекта', 'سیٹ ID'),
        'additional' => _t('Qo‘shimcha qoliplar', 'Additional molds',
            'Дополнительные формы', 'اضافی سانچے'),
        'code' => _t('Qolip kodi', 'Mold code', 'Код формы', 'سانچے کا کوڈ'),
        'size' => _t('Razmer', 'Size', 'Размер', 'سائز'),
        'color' => _t('Rang', 'Color', 'Цвет', 'رنگ'),
        'error' => _t(
            'Qoliplar PDF’ini tayyorlab yoki ulashib bo‘lmadi. Qayta urining.',
            'Could not prepare or share the molds PDF. Try again.',
            'Не удалось создать или отправить PDF форм. Повторите попытку.',
            'سانچوں کی PDF تیار یا شیئر نہیں ہو سکی۔ دوبارہ کوشش کریں۔'),
        _ => key,
      };
}
