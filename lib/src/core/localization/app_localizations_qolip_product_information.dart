part of 'app_localizations.dart';

extension QolipProductInformationLocalizations on AppLocalizations {
  String qolipInformationText(String key) => switch (key) {
        'add' =>
          _t('Ma’lumot qo‘shish', 'Add information', 'Добавить сведения'),
        'view' =>
          _t('Ma’lumotni ko‘rish', 'View information', 'Посмотреть сведения'),
        'edit' =>
          _t('Ma’lumotni tahrirlash', 'Edit information', 'Изменить сведения'),
        'details' => _t('Yozma tafsilot', 'Details', 'Подробности'),
        'attach' => _t('Fayl biriktirish', 'Attach file', 'Прикрепить файл'),
        'replace' => _t('Faylni almashtirish', 'Replace file', 'Заменить файл'),
        'remove' => _t('Faylni olib tashlash', 'Remove file', 'Удалить файл'),
        'download' =>
          _t('Faylni yuklab olish', 'Download file', 'Скачать файл'),
        'empty' => _t('Hali ma’lumot qo‘shilmagan.',
            'No information has been added yet.', 'Сведения ещё не добавлены.'),
        'saved' =>
          _t('Ma’lumot saqlandi', 'Information saved', 'Сведения сохранены'),
        'load_failed' => _t(
            'Ma’lumotni yuklab bo‘lmadi.',
            'Could not load the information.',
            'Не удалось загрузить сведения.'),
        'save_failed' => _t(
            'Ma’lumotni saqlab bo‘lmadi. Qayta urinib ko‘ring.',
            'Could not save. Try again.',
            'Не удалось сохранить. Повторите попытку.'),
        'file_failed' => _t('Faylni o‘qib bo‘lmadi.',
            'Could not read the file.', 'Не удалось прочитать файл.'),
        'download_failed' => _t('Faylni yuklab bo‘lmadi.',
            'Could not download the file.', 'Не удалось скачать файл.'),
        'file_too_large' => _t(
            'Hajmi 20 MB dan oshmaydigan fayl tanlang.',
            'Choose a file no larger than 20 MB.',
            'Выберите файл размером не более 20 МБ.'),
        'changed' => _t(
            'Ma’lumot boshqa qurilmada yangilangan. Yangi yozuvni ko‘rish uchun kartani qayta oching.',
            'The information changed on another device. Reopen the card to see the latest version.',
            'Сведения изменились на другом устройстве. Откройте карточку заново.'),
        _ => key,
      };
}
