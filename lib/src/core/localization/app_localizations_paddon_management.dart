part of 'app_localizations.dart';

const _paddonManagementTranslations = {
  'qolip.start.settings.title': {
    'uz': 'Bosmachilar qoliplarni skan qilmasdan ish boshlashi',
    'en': 'Printing operators can start without scanning molds',
    'ru': 'Печатники могут начинать работу без сканирования форм',
    'ur': 'پرنٹنگ کارکن سانچے اسکین کیے بغیر کام شروع کر سکتے ہیں',
  },
  'qolip.start.settings.description': {
    'uz':
        'Yoqilganda mavjud qolip komplekti ish boshlashdan oldin avtomatik tekshiriladi. Peredelkadagi, band yoki biriktirilmagan qoliplar bilan ish boshlanmaydi.',
    'en':
        'When enabled, the assigned mold set is checked automatically before starting. Molds in rework, busy molds and missing assignments still block starting.',
    'ru':
        'При включении назначенный комплект форм проверяется автоматически перед началом работы. Формы в переделке, занятые формы и отсутствие назначенных форм блокируют запуск.',
    'ur':
        'فعال ہونے پر کام شروع کرنے سے پہلے مقررہ سانچوں کا سیٹ خودکار طور پر جانچا جاتا ہے۔ مرمت میں موجود، مصروف یا غیر مقررہ سانچے کام شروع کرنے سے روکتے ہیں۔',
  },
  'qolip.start.settings.load_failed': {
    'uz': 'Qolipni tasdiqlash sozlamasi yuklanmadi.',
    'en': 'Could not load the mold confirmation setting.',
    'ru': 'Не удалось загрузить настройку подтверждения форм.',
    'ur': 'سانچوں کی تصدیق کی ترتیب لوڈ نہیں ہو سکی۔',
  },
  'qolip.start.settings.save_failed': {
    'uz': 'Qolipni tasdiqlash sozlamasi saqlanmadi. Qayta urinib ko‘ring.',
    'en': 'Could not save the mold confirmation setting. Please retry.',
    'ru':
        'Не удалось сохранить настройку подтверждения форм. Повторите попытку.',
    'ur': 'سانچوں کی تصدیق کی ترتیب محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
  },
  'qolip.start.auto.confirmed': {
    'uz': 'Qoliplar avtomatik tasdiqlandi',
    'en': 'Molds confirmed automatically',
    'ru': 'Формы подтверждены автоматически',
    'ur': 'سانچوں کی خودکار تصدیق ہو گئی',
  },
  'qolip.start.auto.checking': {
    'uz': 'Qoliplar tekshirilmoqda',
    'en': 'Checking molds',
    'ru': 'Проверка форм',
    'ur': 'سانچوں کی جانچ ہو رہی ہے',
  },
  'qolip.start.auto.choose_set': {
    'uz': 'Ishlatiladigan komplektni tanlang',
    'en': 'Choose the mold set to use',
    'ru': 'Выберите комплект форм для работы',
    'ur': 'استعمال کے لیے سانچوں کا سیٹ منتخب کریں',
  },
  'qolip.start.auto.set_label': {
    'uz': 'Komplekt',
    'en': 'Mold set',
    'ru': 'Комплект форм',
    'ur': 'سانچوں کا سیٹ',
  },
  'qolip.start.auto.blocked': {
    'uz': 'Qolip komplektida muammo bor. Ish boshlash mumkin emas.',
    'en': 'The mold set has a problem. Work cannot start.',
    'ru': 'В комплекте форм есть проблема. Начать работу нельзя.',
    'ur': 'سانچوں کے سیٹ میں مسئلہ ہے۔ کام شروع نہیں ہو سکتا۔',
  },
  'qolip.start.auto.settings_changed': {
    'uz': 'Qolipni tasdiqlash sozlamasi o‘zgardi. Qayta tekshiring.',
    'en': 'The mold confirmation setting changed. Check again.',
    'ru': 'Настройка подтверждения форм изменилась. Повторите проверку.',
    'ur': 'سانچوں کی تصدیق کی ترتیب بدل گئی ہے۔ دوبارہ جانچیں۔',
  },
  'qolip.start.auto.set_changed': {
    'uz': 'Qolip komplekti o‘zgardi. Qayta tekshiring.',
    'en': 'The mold set changed. Check again.',
    'ru': 'Комплект форм изменился. Повторите проверку.',
    'ur': 'سانچوں کا سیٹ بدل گیا ہے۔ دوبارہ جانچیں۔',
  },
  'qolip.start.auto.unavailable': {
    'uz': 'Qoliplar holatini tekshirib bo‘lmadi. Qayta urinib ko‘ring.',
    'en': 'Could not check the molds. Please retry.',
    'ru': 'Не удалось проверить формы. Повторите попытку.',
    'ur': 'سانچوں کی جانچ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
  },
  'qolip.start.auto.missing': {
    'uz': 'Mahsulotga qolip biriktirilmagan',
    'en': 'No mold is assigned to this product',
    'ru': 'К продукту не назначена форма',
    'ur': 'اس پروڈکٹ کے لیے کوئی سانچہ مقرر نہیں ہے',
  },
  'qolip.start.auto.in_use': {
    'uz': 'Qolip boshqa ishda band',
    'en': 'The mold is busy with another job',
    'ru': 'Форма занята в другой работе',
    'ur': 'سانچہ دوسرے کام میں مصروف ہے',
  },
  'qolip.start.auto.checkout_other': {
    'uz': 'Qolip boshqa ishchiga berilgan',
    'en': 'The mold is checked out to another worker',
    'ru': 'Форма выдана другому работнику',
    'ur': 'سانچہ دوسرے کارکن کو دیا گیا ہے',
  },
  'qolip.start.auto.no_location': {
    'uz': 'Qolipning joylashuvi aniqlanmadi',
    'en': 'The mold location is unknown',
    'ru': 'Местоположение формы не определено',
    'ur': 'سانچے کا مقام معلوم نہیں ہے',
  },
  'qolip.start.auto.unknown_state': {
    'uz': 'Qolip holati tasdiqlanmadi',
    'en': 'The mold state could not be confirmed',
    'ru': 'Состояние формы не подтверждено',
    'ur': 'سانچے کی حالت کی تصدیق نہیں ہو سکی',
  },
  'lamination.settings.title': {
    'uz': 'Laminatsiyachi ikki qatlamdan birini kiritish majburiyati',
    'en': 'Require lamination layer remainder entry',
    'ru': 'Обязательный ввод остатков слоёв ламинации',
    'ur': 'لیمینیشن کی تہوں کے بقایا کا لازمی اندراج',
  },
  'lamination.settings.description': {
    'uz':
        'Yoqilganda qatlamlarning sof qoldig‘i so‘raladi va qoldiqqa alohida QR chiqariladi. O‘chirilganda eski astatka va boshqa hisobot maydonlari bilan ishlash davom etadi.',
    'en':
        'When enabled, enter each layer’s net remainder and print a separate QR for it. When disabled, the existing leftover counts and other report fields remain available.',
    'ru':
        'При включении вводится чистый вес остатков слоёв и печатается отдельный QR. При выключении сохраняются прежние поля остатков и остальные поля отчёта.',
    'ur':
        'فعال ہونے پر ہر تہہ کا خالص بقایا درج کریں اور الگ QR پرنٹ کریں۔ بند ہونے پر سابقہ بقایا اور رپورٹ کے دیگر خانے برقرار رہتے ہیں۔',
  },
  'lamination.settings.load_failed': {
    'uz': 'Laminatsiya sozlamasi yuklanmadi.',
    'en': 'Could not load the lamination setting.',
    'ru': 'Не удалось загрузить настройку ламинации.',
    'ur': 'لیمینیشن کی ترتیب لوڈ نہیں ہو سکی۔',
  },
  'lamination.settings.save_failed': {
    'uz': 'Laminatsiya sozlamasi saqlanmadi. Qayta urinib ko‘ring.',
    'en': 'Could not save the lamination setting. Please retry.',
    'ru': 'Не удалось сохранить настройку ламинации. Повторите попытку.',
    'ur': 'لیمینیشن کی ترتیب محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
  },
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
