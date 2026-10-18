part of 'app_localizations.dart';

const _workReactivationTranslations = {
  'worker.reclose.action': {
    'uz': 'Qayta yopish',
    'en': 'Close again',
    'ru': 'Закрыть повторно',
    'ur': 'دوبارہ بند کریں',
  },
  'worker.reclose.success': {
    'uz': 'Ish qayta yopildi. Oldingi hisobotlar saqlandi.',
    'en': 'Work closed again. Previous reports were preserved.',
    'ru': 'Работа повторно закрыта. Прежние отчёты сохранены.',
    'ur': 'کام دوبارہ بند ہو گیا۔ پچھلی رپورٹس محفوظ ہیں۔',
  },
  'worker.reclose.failed': {
    'uz': 'Qayta yopish tasdiqlanmadi. Joriy holat yangilanmoqda.',
    'en': 'Closing was not confirmed. Refreshing the current state.',
    'ru': 'Закрытие не подтверждено. Обновляем текущее состояние.',
    'ur': 'بند ہونے کی تصدیق نہیں ہوئی۔ موجودہ حالت تازہ ہو رہی ہے۔',
  },
  'worker.reactivate.reason_details': {
    'uz': 'Sababini ko‘rish',
    'en': 'View the reason',
    'ru': 'Посмотреть причину',
    'ur': 'وجہ دیکھیں',
  },
  "worker.reactivate.order_action": {
    "uz": "Bu bosqich uchun buyurtmani qayta faollashtirish",
    "en": "Reactivate this order at this stage",
    "ru": "Возобновить заказ на этом этапе",
    "ur": "اس مرحلے پر آرڈر دوبارہ فعال کریں"
  },
  "worker.reactivate.wip_action": {
    "uz": "Bu WIP’ni qayta faollashtirish",
    "en": "Reactivate this WIP",
    "ru": "Возобновить этот WIP",
    "ur": "یہ WIP دوبارہ فعال کریں"
  },
  "worker.reactivate.confirm": {
    "uz": "Qayta faollashtirish",
    "en": "Reactivate",
    "ru": "Возобновить",
    "ur": "دوبارہ فعال کریں"
  },
  "worker.reactivate.details": {
    "uz": "WIP tafsilotlari va QR",
    "en": "WIP details and QR",
    "ru": "Данные WIP и QR",
    "ur": "WIP کی تفصیلات اور QR"
  },
  "worker.reactivate.stage": {
    "uz": "Bosqich: {stage}",
    "en": "Stage: {stage}",
    "ru": "Этап: {stage}",
    "ur": "مرحلہ: {stage}"
  },
  "worker.reactivate.order_explanation": {
    "uz":
        "Buyurtmaning ko‘rsatilgan bosqichidagi ish pauzada qaytadi. Ishlash uchun Davom ettirish tugmasini bosing; hali boshlamagan bo‘lsangiz, Qayta yopish mumkin. Oldin qayd etilgan metraj, kilogramm va chiqindi hisobda qoladi. Davom ettirgach faqat qo‘shimcha ishlab chiqarilgan miqdorni qayd eting. Apparat bandligi, materiallar va joriy holat tasdiqlashda qayta tekshiriladi.",
    "en":
        "Work reopens paused at the stage shown. Press Resume to work, or Close again before starting. Previously recorded metres, kilograms and waste remain recorded. After reopening, record only additional production. The apparatus, resources and current state are checked again when you confirm.",
    "ru":
        "Работа вернётся на паузе на указанном этапе. Для работы нажмите «Продолжить»; до начала можно закрыть её повторно. Ранее учтённые метры, килограммы и отходы сохраняются. После возобновления указывайте только дополнительный выпуск. Занятость аппарата, материалы и текущее состояние проверяются повторно при подтверждении.",
    "ur":
        "کام دکھائے گئے مرحلے پر توقف میں واپس آئے گا۔ کام کے لیے جاری رکھیں دبائیں؛ شروع کرنے سے پہلے دوبارہ بند کر سکتے ہیں۔ پہلے درج میٹر، کلوگرام اور ضائع شدہ مقدار محفوظ رہے گی۔ دوبارہ کھولنے کے بعد صرف اضافی پیداوار درج کریں۔ تصدیق پر مشین، مواد اور موجودہ حالت دوبارہ جانچی جائے گی۔"
  },
  "worker.reactivate.wip_explanation": {
    "uz":
        "Tanlangan WIP bilan bog‘langan bosqichdagi ish pauzada qaytadi. Ishlash uchun Davom ettirish tugmasini bosing; hali boshlamagan bo‘lsangiz, Qayta yopish mumkin. Bog‘langan chiqish WIP’lari ish davomida band bo‘ladi. Oldin qayd etilgan metraj, kilogramm va chiqindi saqlanadi; faqat qo‘shimcha ishlab chiqarilgan miqdorni qayd eting. WIP ishlatilmaganligi va apparat bo‘shligi tasdiqlashda qayta tekshiriladi.",
    "en":
        "The order reopens paused at the exact stage linked to this WIP. Press Resume to work, or Close again before starting. Linked output WIPs are reserved while work continues. Recorded metres, kilograms and waste are retained; enter only additional production. WIP availability and apparatus occupancy are checked again when you confirm.",
    "ru":
        "Заказ вернётся на паузе на этапе этого WIP. Для работы нажмите «Продолжить»; до начала можно закрыть его повторно. Связанные выходные WIP будут заняты на время работы. Учтённые метры, килограммы и отходы сохраняются; вводите только дополнительный выпуск. Доступность WIP и занятость аппарата проверяются повторно при подтверждении.",
    "ur":
        "آرڈر اس WIP کے مرحلے پر توقف میں واپس آئے گا۔ کام کے لیے جاری رکھیں دبائیں؛ شروع کرنے سے پہلے دوبارہ بند کر سکتے ہیں۔ کام کے دوران منسلک آؤٹ پٹ WIP محفوظ رکھے جائیں گے۔ پہلے درج میٹر، کلوگرام اور ضائع شدہ مقدار برقرار رہیں گے؛ صرف اضافی پیداوار درج کریں۔ تصدیق پر WIP کی دستیابی اور مشین کی مصروفیت دوبارہ جانچی جائے گی۔"
  },
  "worker.reactivate.success": {
    "uz": "Ish pauzada qayta ochildi. Ishlash uchun Davom ettirishni bosing.",
    "en": "Work reopened paused. Press Resume to work.",
    "ru": "Работа открыта на паузе. Для работы нажмите «Продолжить».",
    "ur": "کام توقف میں کھل گیا۔ کام کے لیے جاری رکھیں دبائیں۔"
  },
  "worker.reactivate.unconfirmed": {
    "uz":
        "Natija tasdiqlanmadi. Joriy holat yangilanmoqda; amal avtomatik takrorlanmaydi.",
    "en":
        "The result was not confirmed. Refreshing current state; the action will not be retried automatically.",
    "ru":
        "Результат не подтверждён. Обновляем состояние; действие автоматически не повторяется.",
    "ur":
        "نتیجے کی تصدیق نہیں ہوئی۔ موجودہ حالت تازہ ہو رہی ہے؛ کارروائی خودکار طور پر نہیں دہرائی جائے گی۔"
  },
  "worker.reactivate.reason.apparatus_busy": {
    "uz":
        "Apparatda boshqa ish yoki ish boshlash jarayoni bor. U tugamaguncha qayta faollashtirish mumkin emas.",
    "en":
        "The apparatus has another active job or start in progress. Finish it before reopening this work.",
    "ru":
        "На аппарате уже идёт другая работа или запуск. До её завершения возобновление недоступно.",
    "ur":
        "مشین پر دوسرا کام یا آغاز جاری ہے۔ اسے ختم کیے بغیر یہ کام دوبارہ فعال نہیں ہو سکتا۔"
  },
  "worker.reactivate.reason.source_not_free": {
    "uz":
        "Bu ishga bog‘langan WIP ishlatilgan, band qilingan, omborga topshirilgan yoki qaytarilgan. Uni qayta faollashtirish mumkin emas.",
    "en":
        "A linked WIP has been used, reserved, received into stock or returned. This work cannot be reopened.",
    "ru":
        "Связанный WIP уже использован, занят, принят на склад или возвращён. Возобновление недоступно.",
    "ur":
        "منسلک WIP استعمال، محفوظ، گودام میں وصول یا واپس کیا جا چکا ہے۔ یہ کام دوبارہ نہیں کھل سکتا۔"
  },
  "worker.reactivate.reason.final_stage_closed": {
    "uz":
        "Buyurtma production map’ning oxirgi bosqichida yakuniy yopilgan. Bu oynadan qayta faollashtirish mumkin emas.",
    "en":
        "This order was finally closed at the last production stage. It cannot be reopened here.",
    "ru":
        "Заказ окончательно закрыт на последнем этапе производства. Возобновить его здесь нельзя.",
    "ur":
        "آرڈر آخری پیداواری مرحلے پر حتمی طور پر بند ہو چکا ہے۔ یہاں سے دوبارہ فعال نہیں ہو سکتا۔"
  },
  "worker.reactivate.reason.stale_target": {
    "uz":
        "Ish yoki production map holati o‘zgargan. Ro‘yxatni yangilab qayta tekshiring.",
    "en":
        "The work or production map has changed. Refresh the list and check again.",
    "ru":
        "Состояние работы или карты производства изменилось. Обновите список и проверьте снова.",
    "ur": "کام یا پیداواری نقشہ بدل گیا ہے۔ فہرست تازہ کر کے دوبارہ جانچیں۔"
  },
  "worker.reactivate.reason.resource_unavailable": {
    "uz":
        "Kerakli material yoki qolip mavjud emas, qaytarilgan yoki boshqa ishda band. Qayta faollashtirish hozir mumkin emas.",
    "en":
        "A required material or tooling set is unavailable, returned or used by another job. Reopening is currently unavailable.",
    "ru":
        "Нужный материал или комплект форм недоступен, возвращён или занят другой работой. Возобновление сейчас невозможно.",
    "ur":
        "ضروری مواد یا سانچے دستیاب نہیں، واپس ہو چکے ہیں یا دوسرے کام میں مصروف ہیں۔ ابھی دوبارہ فعال نہیں ہو سکتا۔"
  },
  "worker.reactivate.reason.order_closed": {
    "uz":
        "Buyurtma yopilgan, bekor qilingan yoki faol ishlashga ruxsat berilmagan. Qayta faollashtirish mumkin emas.",
    "en":
        "This order is closed, cancelled or blocked from active work. It cannot be reopened.",
    "ru":
        "Заказ закрыт, отменён или заблокирован для работы. Возобновление недоступно.",
    "ur":
        "یہ آرڈر بند، منسوخ یا فعال کام کے لیے مسدود ہے۔ اسے دوبارہ نہیں کھولا جا سکتا۔"
  },
  "worker.reactivate.reason.unsupported_history": {
    "uz":
        "Bu tarixdan aniq va xavfsiz qayta ochiladigan ishni aniqlab bo‘lmadi. Qayta faollashtirish mumkin emas.",
    "en":
        "An exact safe execution cannot be resolved from this history. Reopening is unavailable.",
    "ru":
        "По этой истории нельзя однозначно определить безопасное возобновление работы. Действие недоступно.",
    "ur":
        "اس تاریخ سے عین محفوظ کام متعین نہیں ہو سکا۔ دوبارہ کھولنا دستیاب نہیں۔"
  },
  "worker.reactivate.reason.unavailable": {
    "uz":
        "Server qayta faollashtirishga ruxsatni tasdiqlamadi. Holatni yangilab qayta tekshiring.",
    "en":
        "The server did not confirm permission to reopen. Refresh the current state and check again.",
    "ru":
        "Сервер не подтвердил возможность возобновления. Обновите состояние и проверьте снова.",
    "ur":
        "سرور نے دوبارہ کھولنے کی اجازت کی تصدیق نہیں کی۔ موجودہ حالت تازہ کر کے دوبارہ جانچیں۔"
  }
};
