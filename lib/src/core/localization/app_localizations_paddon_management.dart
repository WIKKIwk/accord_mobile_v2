part of 'app_localizations.dart';

const _paddonManagementTranslations = {
  'paddon.management.settings.title': {
    'uz': 'Qo‘shimcha sozlamalar',
    'en': 'Additional settings',
    'ru': 'Дополнительные настройки',
    'ur': 'اضافی ترتیبات',
  },
  'paddon.management.free_movement.title': {
    'uz': 'Rulonlarni paddonlar aro erkin boshqarish',
    'en': 'Manage rolls freely between paddons',
    'ru': 'Свободное перемещение рулонов между паллетами',
    'ur': 'پیلیٹس کے درمیان رول آزادانہ منتقل کریں',
  },
  'paddon.management.free_movement.description': {
    'uz':
        'Yoqilganda barcha ishchilar bir-birining rulonlarini paddonlar orasida ko‘chira oladi va bir-birining paddonlarini qulfdan chiqara oladi. Ko‘chirishdan avval ikkala paddonni qulfdan chiqaring. Omborga qabul qilingan mahsulotlar ko‘chirilmaydi.',
    'en':
        'When enabled, workers can move each other’s rolls between paddons and unlock each other’s paddons. Unlock both paddons before moving rolls. Goods already received into a warehouse cannot be moved.',
    'ru':
        'Все работники смогут перемещать рулоны друг друга между паллетами и разблокировать паллеты друг друга. Перед перемещением разблокируйте обе паллеты. Принятые на склад товары перемещать нельзя.',
    'ur':
        'فعال ہونے پر کارکن ایک دوسرے کے رول منتقل اور پیلیٹس کھول سکتے ہیں۔ منتقلی سے پہلے دونوں پیلیٹس کھولیں۔ گودام میں وصول شدہ مال منتقل نہیں ہوگا۔',
  },
  'paddon.management.free_movement.confirm': {
    'uz': 'Erkin ko‘chirish yoqilsinmi?',
    'en': 'Enable free movement?',
    'ru': 'Включить свободное перемещение?',
    'ur': 'آزاد منتقلی فعال کریں؟',
  },
  'paddon.management.worker_visibility.title': {
    'uz': 'Ishchilar bir-birining paddonlarini ko‘rishi',
    'en': 'Workers can see each other’s paddons',
    'ru': 'Работники видят паллеты друг друга',
    'ur': 'کارکن ایک دوسرے کے پیلیٹس دیکھ سکتے ہیں',
  },
  'paddon.management.worker_visibility.description': {
    'uz':
        'Yoqilganda rezka ishchilari boshqa ishchilar ochgan paddonlarni ham ko‘radi. O‘chirilganda har bir ishchi faqat o‘zi ochgan paddonlarni ko‘radi.',
    'en':
        'When enabled, cutting workers also see paddons created by other workers. When disabled, each worker sees only their own paddons.',
    'ru':
        'При включении работники резки видят паллеты других работников. При выключении каждый работник видит только созданные им паллеты.',
    'ur':
        'فعال ہونے پر کٹنگ کارکن دوسرے کارکنوں کے بنائے ہوئے پیلیٹس بھی دیکھ سکتے ہیں۔ بند ہونے پر ہر کارکن صرف اپنے بنائے ہوئے پیلیٹس دیکھتا ہے۔',
  },
  'paddon.management.free_movement.hint': {
    'uz':
        'Erkin ko‘chirish yoqilgan. Rulon QR’ini qo‘shsangiz, u eski paddondan shu paddonga ko‘chadi.',
    'en':
        'Free movement is enabled. Adding a roll QR moves it from its previous paddon to this paddon.',
    'ru':
        'Свободное перемещение включено. Добавление QR рулона перенесёт его с прежнего паллета на этот.',
    'ur':
        'آزاد منتقلی فعال ہے۔ رول کا QR شامل کرنے پر وہ پچھلے پیلیٹ سے اس پیلیٹ میں منتقل ہوگا۔',
  },
  'paddon.management.settings.failed': {
    'uz': 'Sozlama saqlanmadi. Qayta urinib ko‘ring.',
    'en': 'The setting could not be saved. Please retry.',
    'ru': 'Не удалось сохранить настройку. Повторите попытку.',
    'ur': 'ترتیب محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
  },
  'worker.paddon.transfer.title': {
    'uz': 'Paddonlar aro WIP ko‘chirish',
    'en': 'Move WIP between paddons',
    'ru': 'Перемещение НЗП между паллетами',
    'ur': 'پیلیٹس کے درمیان WIP منتقل کریں',
  },
  'worker.paddon.transfer.hint': {
    'uz':
        'Ikkala paddonni tanlang. WIP’ni belgilang yoki boshqa panelga torting. Faqat qulfdan chiqarilgan paddonlar orasida ko‘chiriladi.',
    'en':
        'Choose two paddons. Select WIP or drag it to the other pane. Both paddons must be unlocked.',
    'ru':
        'Выберите две паллеты. Отметьте НЗП или перетащите в другую панель. Обе паллеты должны быть разблокированы.',
    'ur':
        'دو پیلیٹس منتخب کریں۔ WIP منتخب کریں یا دوسرے پینل میں گھسیٹیں۔ دونوں پیلیٹس کھلے ہونے چاہئیں۔',
  },
  'worker.paddon.transfer.source': {
    'uz': 'Boshlang‘ich paddon',
    'en': 'Source paddon',
    'ru': 'Исходная паллета',
    'ur': 'ماخذ پیلیٹ',
  },
  'worker.paddon.transfer.target': {
    'uz': 'Qabul qiluvchi paddon',
    'en': 'Destination paddon',
    'ru': 'Целевая паллета',
    'ur': 'منزل پیلیٹ',
  },
  'worker.paddon.transfer.choose': {
    'uz': 'Qulfdan chiqarilgan paddonni tanlang',
    'en': 'Choose an unlocked paddon',
    'ru': 'Выберите разблокированную паллету',
    'ur': 'کھلا پیلیٹ منتخب کریں',
  },
  'worker.paddon.transfer.empty': {
    'uz': 'Paddonda WIP yo‘q',
    'en': 'No WIP in this paddon',
    'ru': 'На паллете нет НЗП',
    'ur': 'اس پیلیٹ میں WIP نہیں',
  },
  'worker.paddon.transfer.move': {
    'uz': '{count} ta WIP ko‘chirish',
    'en': 'Move {count} WIP',
    'ru': 'Переместить НЗП: {count}',
    'ur': '{count} WIP منتقل کریں',
  },
  'worker.paddon.transfer.confirm': {
    'uz': '{source} paddondan {target} paddonga {count} ta WIP ko‘chirilsinmi?',
    'en': 'Move {count} WIP from paddon {source} to paddon {target}?',
    'ru': 'Переместить НЗП ({count}) с паллеты {source} на паллету {target}?',
    'ur': '{source} سے {target} پیلیٹ میں {count} WIP منتقل کریں؟',
  },
  'worker.paddon.transfer.success': {
    'uz': 'WIP’lar ko‘chirildi',
    'en': 'WIP moved',
    'ru': 'НЗП перемещено',
    'ur': 'WIP منتقل ہو گیا',
  },
  'worker.paddon.transfer.failed': {
    'uz': 'Ko‘chirish tasdiqlanmadi. Paddonlarning joriy holatini tekshiring.',
    'en': 'Transfer was not confirmed. Check the current paddon contents.',
    'ru': 'Перемещение не подтверждено. Проверьте содержимое паллет.',
    'ur': 'منتقلی کی تصدیق نہیں ہوئی۔ پیلیٹس کی موجودہ حالت دیکھیں۔',
  },
  'worker.paddon.transfer.refresh': {
    'uz': 'Yangilash',
    'en': 'Refresh',
    'ru': 'Обновить',
    'ur': 'تازہ کریں',
  },
  'worker.paddon.transfer.forbidden': {
    'uz': 'Boshqa ishchining paddonidagi WIP’ni ko‘chirishga ruxsat yo‘q.',
    'en': 'You cannot move WIP from another worker’s paddon.',
    'ru': 'Нет разрешения на перемещение НЗП с паллеты другого работника.',
    'ur': 'دوسرے کارکن کے پیلیٹ کا WIP منتقل کرنے کی اجازت نہیں۔',
  },
};
