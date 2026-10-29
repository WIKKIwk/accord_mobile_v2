part of 'app_localizations.dart';

extension AppLocalizationsQolipStorage on AppLocalizations {
  String qolipStorageText(String key) => switch (key) {
        'paddons' => _t('Paddonlar', 'Pallets', 'Поддоны'),
        'archive' => _t('Arxiv', 'Archive', 'Архив'),
        'molds' => _t('Qoliplar', 'Molds', 'Формы'),
        'create' => _t('Yangi paddon', 'New pallet', 'Новый поддон'),
        'paddon_summary' =>
          _t('Qoliplarni saqlash', 'Mold storage', 'Хранение форм'),
        'paddons_hint' => _t(
            'Qoliplarni paddonga joylang, tarkibni tekshiring va qulflang.',
            'Pack molds into a pallet, check the contents and lock it.',
            'Разместите формы на поддоне, проверьте состав и заблокируйте его.'),
        'loaded_paddons' =>
          _t('Ko‘rsatilgan paddonlar', 'Loaded pallets', 'Загруженные поддоны'),
        'paddon_list' => _t(
            'Saqlanayotgan paddonlar', 'Stored pallets', 'Поддоны на хранении'),
        'paddons_empty' => _t(
            'Yangi paddon yaratish yoki QR ochish uchun pastdagi + tugmasini bosing.',
            'Use the + button below to create a pallet or open its QR.',
            'Нажмите + внизу, чтобы создать поддон или открыть его QR.'),
        'paddon_molds_empty' => _t(
            'Pastdagi + tugmasi orqali mavjud qoliplarni tanlang yoki QR kodini skanerlang.',
            'Use the + button below to select existing molds or scan their QR codes.',
            'Нажмите + внизу, чтобы выбрать формы или сканировать их QR.'),
        'refresh' => _t('Yangilash', 'Refresh', 'Обновить'),
        'contents' => _t('Paddon tarkibi', 'Pallet contents', 'Состав поддона'),
        'warehouse' => _t('Ombor', 'Warehouse', 'Склад'),
        'location' => _t('Saqlash joyi', 'Storage location', 'Место хранения'),
        'note' => _t('Izoh', 'Note', 'Примечание'),
        'search' => _t('Kod, mahsulot yoki komplektni qidirish',
            'Search code, product or set', 'Поиск кода, товара или комплекта'),
        'open' => _t('Ochiq', 'Open', 'Открыт'),
        'locked' => _t('Qulflangan', 'Locked', 'Заблокирован'),
        'archived' => _t('Arxivda', 'Archived', 'В архиве'),
        'returned' => _t('Arxivdan chiqarilgan', 'Restored', 'Восстановлен'),
        'history' => _t('Tarix', 'History', 'История'),
        'current' =>
          _t('Hozir arxivda', 'Currently archived', 'Сейчас в архиве'),
        'all' => _t('Barchasi', 'All', 'Все'),
        'add' => _t('Qolip qo‘shish', 'Add molds', 'Добавить формы'),
        'select_molds' =>
          _t('Qoliplarni tanlash', 'Select molds', 'Выбрать формы'),
        'picker_hint' => _t(
            'Ro‘yxatdan tanlang yoki QR kodlarini ketma-ket skanerlang. Tanlovni tekshirib, keyin tasdiqlang.',
            'Select from the list or scan QR codes one after another. Review your selection before confirming.',
            'Выбирайте из списка или сканируйте QR-коды подряд. Проверьте выбор перед подтверждением.'),
        'list_mode' => _t('Ro‘yxat', 'List', 'Список'),
        'scan_mode' => _t('QR skanerlash', 'Scan QR', 'Сканировать QR'),
        'scan_add' => _t('QR skanerlash orqali qo‘shish', 'Add by scanning QR',
            'Добавить сканированием QR'),
        'scan_ready' => _t('Qolip QR kodini skanerlang', 'Scan a mold QR code',
            'Сканируйте QR-код формы'),
        'scan_accepted' =>
          _t('Qolip tanlandi', 'Mold selected', 'Форма выбрана'),
        'scan_pending' => _t(
            'Kodlar tekshirilmoqda. Hammasi tekshirilgach tasdiqlang.',
            'Checking codes. Confirm after every code has been checked.',
            'Проверяем коды. Подтвердите после проверки всех кодов.'),
        'invalid_mold_qr' => _t(
            'Bu paddon QR kodi. Qolipning o‘z QR kodini skanerlang.',
            'This is a pallet QR. Scan the mold’s own QR code.',
            'Это QR поддона. Сканируйте QR самой формы.'),
        'selection_review' =>
          _t('Tanlangan qoliplar', 'Selected molds', 'Выбранные формы'),
        'selected_empty' => _t('Hali qolip tanlanmagan',
            'No molds selected yet', 'Формы ещё не выбраны'),
        'select_loaded_short' => _t('Ko‘rinayotganlarni tanlash',
            'Select loaded', 'Выбрать загруженные'),
        'remove' =>
          _t('Paddondan chiqarish', 'Remove from pallet', 'Убрать с поддона'),
        'lock' => _t('Qulflash', 'Lock', 'Заблокировать'),
        'unlock' => _t('Qulfni ochish', 'Unlock', 'Разблокировать'),
        'archive_action' => _t('Arxivlash', 'Archive', 'Архивировать'),
        'restore' => _t('Arxivdan chiqarish', 'Restore', 'Восстановить'),
        'inspect' =>
          _t('Tarkibni tekshirish', 'Inspect contents', 'Проверить состав'),
        'scan' => _t('QR skanerlash yoki kod kiritish', 'Scan QR or enter code',
            'Сканировать QR или ввести код'),
        'save' => _t('Saqlash', 'Save', 'Сохранить'),
        'cancel' => _t('Bekor qilish', 'Cancel', 'Отмена'),
        'confirm' => _t('Tasdiqlash', 'Confirm', 'Подтвердить'),
        'more' => _t('Yana yuklash', 'Load more', 'Загрузить ещё'),
        'empty' =>
          _t('Ma’lumot topilmadi', 'No records found', 'Записи не найдены'),
        'retry' => _t('Qayta urinish', 'Retry', 'Повторить'),
        'selected' => _t('Tanlangan', 'Selected', 'Выбрано'),
        'deselect' =>
          _t('Tanlovdan chiqarish', 'Deselect mold', 'Убрать из выбора'),
        'mold_details' =>
          _t('Qolip ma’lumotlari', 'Mold details', 'Информация о форме'),
        'available' => _t('Bo‘sh qolip', 'Available mold', 'Свободная форма'),
        'in_use' => _t('Ishlab chiqarishga berilgan', 'Issued to production',
            'Выдана в производство'),
        'in_rework' => _t('Peredelkada', 'In rework', 'На переделке'),
        'transferring' => _t('Ko‘chirilmoqda', 'In transfer', 'Перемещается'),
        'wrong_warehouse' => _t('Boshqa omborga tegishli',
            'Belongs to another warehouse', 'Принадлежит другому складу'),
        'in_paddon' => _t('Paddonda', 'In pallet', 'На поддоне'),
        'size' => _t('O‘lcham', 'Size', 'Размер'),
        'quantity' => _t('Miqdor', 'Quantity', 'Количество'),
        'set' => _t('Komplekt', 'Set', 'Комплект'),
        'mileage' => _t('Probeg va peredelka tarixi',
            'Mileage and rework history', 'Пробег и история переделки'),
        'copy' => _t('Kodni nusxalash', 'Copy code', 'Скопировать код'),
        'found' => _t('Topilgan', 'Found', 'Найдено'),
        'missing' => _t('Topilmagan', 'Missing', 'Не найдено'),
        'unexpected' => _t('Paddonga tegishli emas', 'Not in this pallet',
            'Не входит в поддон'),
        'observed' =>
          _t('Skanerlangan kodlar', 'Scanned codes', 'Отсканированные коды'),
        'inspect_hint' => _t(
            'Skanerlash tarkibni o‘zgartirmaydi. Natija tekshiruv tarixiga yoziladi.',
            'Scanning does not change contents. The result is saved in inspection history.',
            'Сканирование не меняет состав. Результат сохраняется в истории проверок.'),
        'lock_hint' => _t(
            'Qulflangandan keyin tarkibni o‘zgartirish uchun qulfni ochish kerak.',
            'Unlock the pallet before changing its locked contents.',
            'Для изменения заблокированного состава нужно открыть замок.'),
        'archive_hint' => _t(
            'Arxivdagi qoliplar ishga berilmaydi. Tarkib, QR va tarix saqlanadi.',
            'Archived molds cannot be issued. Contents, QR and history are preserved.',
            'Архивные формы нельзя выдавать. Состав, QR и история сохраняются.'),
        'restore_hint' => _t(
            'QR, probeg va oldingi qulf holati saqlanadi.',
            'QR, mileage and the previous lock state are preserved.',
            'QR, пробег и прежнее состояние замка сохраняются.'),
        'remove_hint' => _t(
            'Qolip mavjud saqlash joyiga qaytadi. Qolipning o‘zi o‘chirilmaydi.',
            'The mold returns to its recorded storage location. The mold itself is not deleted.',
            'Форма возвращается в записанное место хранения. Сама форма не удаляется.'),
        'saved' => _t('Saqlandi', 'Saved', 'Сохранено'),
        'failed' => _t(
            'Amal bajarilmadi. Tanlov saqlandi; qayta urinishingiz mumkin.',
            'The action failed. Your selection is preserved; you may retry.',
            'Операция не выполнена. Выбор сохранён; можно повторить.'),
        'changed' => _t(
            'Holat boshqa qurilmada o‘zgargan. Yangilangan tarkibni tekshirib, qayta tasdiqlang.',
            'The state changed on another device. Review the updated contents and confirm again.',
            'Состояние изменилось на другом устройстве. Проверьте обновлённый состав и подтвердите снова.'),
        'session_changed' => _t(
            'Hisob yoki ruxsatlar o‘zgardi. Sahifani qayta oching.',
            'Account or permissions changed. Reopen this page.',
            'Аккаунт или права изменились. Откройте страницу заново.'),
        'not_found' => _t('Bu kod bo‘yicha qolip topilmadi',
            'No mold found for this code', 'Форма с этим кодом не найдена'),
        'duplicate' => _t('Bu kod allaqachon tanlangan',
            'This code is already selected', 'Этот код уже выбран'),
        'choose_warehouse' =>
          _t('Omborni tanlang', 'Select a warehouse', 'Выберите склад'),
        'no_warehouse' => _t('Qolip omboriga ruxsat berilmagan',
            'No mold warehouse assigned', 'Нет доступа к складу форм'),
        'snapshot' => _t('Arxivlangan paytdagi tarkib',
            'Contents at archive time', 'Состав на момент архивации'),
        'current_detail' => _t('Paddonning hozirgi holati',
            'Current pallet state', 'Текущее состояние поддона'),
        'archived_by' => _t('Arxivlagan', 'Archived by', 'Архивировал'),
        'restored_by' => _t('Qaytargan', 'Restored by', 'Восстановил'),
        'leave' => _t('Saqlanmagan tanlovdan chiqilsinmi?',
            'Discard the unsaved selection?', 'Выйти без сохранения выбора?'),
        'select_loaded' => _t(
            'Ko‘rinayotgan mos qoliplarni tanlash',
            'Select loaded eligible molds',
            'Выбрать загруженные доступные формы'),
        'locked_error' => _t('Avval paddon qulfini oching.',
            'Unlock the pallet first.', 'Сначала разблокируйте поддон.'),
        'archived_error' => _t(
            'Avval arxivdan chiqaring.',
            'Restore from the archive first.',
            'Сначала восстановите из архива.'),
        'in_paddon_error' => _t(
            'Qolipni avval mavjud paddonidan chiqaring.',
            'Remove the mold from its current pallet first.',
            'Сначала извлеките форму из текущего поддона.'),
        'empty_error' => _t(
            'Avval paddonga qolip qo‘shing.',
            'Add molds to the pallet first.',
            'Сначала добавьте формы на поддон.'),
        'forbidden_error' => _t(
            'Bu ombor yoki amalga ruxsat yo‘q.',
            'This warehouse or action is not permitted.',
            'Нет доступа к этому складу или действию.'),
        'capacity_error' => _t(
            'Bir amalda ko‘pi bilan 1000 ta qolip tanlang.',
            'Select at most 1000 molds per action.',
            'Выберите не более 1000 форм за одну операцию.'),
        'scan_paddon' =>
          _t('Paddon QR kodini ochish', 'Open pallet QR', 'Открыть QR поддона'),
        'invalid_paddon_qr' => _t(
            'Bu paddon QR kodi emas. Paddon raqamini qidiruvga yozish ham mumkin.',
            'This is not a pallet QR. You can also search by pallet number.',
            'Это не QR поддона. Также можно искать по номеру поддона.'),
        'choose_set' => _t('Butun komplektni tanlash', 'Select complete set',
            'Выбрать полный комплект'),
        'set_unavailable' => _t(
            'Komplekt to‘liq tanlanmadi: quyidagi qoliplar band, boshqa omborda yoki arxivda. Ularning holatini tekshiring.',
            'The complete set was not selected: these molds are unavailable, in another warehouse or archived. Check their state.',
            'Полный комплект не выбран: эти формы заняты, на другом складе или в архиве. Проверьте их состояние.'),
        'dates' => _t('Arxivlangan sana', 'Archive dates', 'Даты архивации'),
        'clear_filters' =>
          _t('Filtrlarni tozalash', 'Clear filters', 'Сбросить фильтры'),
        _ => key,
      };
}
