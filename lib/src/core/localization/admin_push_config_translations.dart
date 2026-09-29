part of 'admin_localization.dart';

const _adminPushConfigTranslations = {
  "admin.push.device_title": {
    "uz": "Shu telefonning holati",
    "en": "This device",
    "ru": "Это устройство"
  },
  "admin.push.device_not_checked": {
    "uz":
        "Telefonda push hali tekshirilmagan. Server tekshiruvi telefon tayyorligini anglatmaydi.",
    "en":
        "Device push has not been checked. Server verification does not confirm device readiness.",
    "ru":
        "Push на устройстве ещё не проверен. Проверка сервера не подтверждает готовность телефона."
  },
  "admin.push.device_registered": {
    "uz":
        "Telefonning push tokeni serverga ulandi. Yetkazishni test xabari bilan tekshiring.",
    "en": "Device push token registered. Use a test message to check delivery.",
    "ru": "Push-токен зарегистрирован. Проверьте доставку тестовым сообщением."
  },
  "admin.push.apply_device": {
    "uz": "Shu telefon sozlamasini yangilash",
    "en": "Apply settings to this device",
    "ru": "Применить настройки на устройстве"
  },
  "admin.push.mobile_title": {
    "uz": "Telefonlar uchun Firebase sozlamalari",
    "en": "Firebase settings for mobile apps",
    "ru": "Настройки Firebase для приложений"
  },
  "admin.push.mobile_instructions": {
    "uz":
        "Shu Firebase loyihasidan Android va iOS konfiguratsiya fayllarini yuklang. Telefonlar ularni serverdan avtomatik oladi. Fayllarni buildga qo‘lda qo‘shish kerak emas.",
    "en":
        "Upload Android and iOS client files from this Firebase project. Devices fetch them automatically; no build-time files are needed.",
    "ru":
        "Загрузите файлы Android и iOS этого проекта Firebase. Устройства получат их с сервера; добавлять файлы в сборку не нужно."
  },
  "admin.push.mobile_configured": {
    "uz": "Ilova konfiguratsiyasi saqlangan",
    "en": "Client configuration saved",
    "ru": "Конфигурация приложения сохранена"
  },
  "admin.push.mobile_missing": {
    "uz": "Konfiguratsiya fayli hali yuklanmagan",
    "en": "Client configuration is missing",
    "ru": "Файл конфигурации ещё не загружен"
  },
  "admin.push.mobile_saved": {
    "uz":
        "Mobil sozlama saqlandi. Telefonlar ilova ochilganda yoki qayta faollashganda oladi.",
    "en":
        "Mobile settings saved. Devices fetch them when the app starts or resumes.",
    "ru":
        "Настройки сохранены. Устройства получат их при запуске или возобновлении приложения."
  },
  "admin.push.invalid_client": {
    "uz":
        "Fayl bu ilovaga mos emas yoki to‘liq emas. Android uchun google-services.json, iPhone uchun GoogleService-Info.plist yuklang.",
    "en":
        "Invalid client file or application ID. Upload google-services.json for Android or GoogleService-Info.plist for iPhone.",
    "ru":
        "Файл неполный или не соответствует приложению. Загрузите google-services.json для Android или GoogleService-Info.plist для iPhone."
  },
  "admin.push.client_missing": {
    "uz":
        "Bu platformaning Firebase fayli serverga yuklanmagan. Pastdagi telefonlar sozlamalari bo‘limida yuklang.",
    "en":
        "Firebase client settings for this platform are missing. Upload them in the mobile settings section below.",
    "ru":
        "Настройки Firebase этой платформы отсутствуют. Загрузите файл в разделе настроек приложений ниже."
  },
  "admin.push.client_save_failed": {
    "uz": "Telefon konfiguratsiyani saqlay olmadi. Qayta urinib ko‘ring.",
    "en": "Could not save configuration on this device. Try again.",
    "ru": "Не удалось сохранить настройки на устройстве. Повторите попытку."
  },
  "admin.push.client_sync_failed": {
    "uz":
        "Telefon Firebase sozlamalarini serverdan ololmadi. Serverga ulanishni tekshiring.",
    "en": "Could not fetch Firebase settings. Check the server connection.",
    "ru":
        "Не удалось получить настройки Firebase. Проверьте соединение с сервером."
  },
  "admin.push.firebase_failed": {
    "uz":
        "Telefonda Firebase ishga tushmadi. Yuklangan ilova konfiguratsiyasini tekshiring.",
    "en":
        "Firebase could not initialize on this device. Check the uploaded client configuration.",
    "ru":
        "Не удалось запустить Firebase. Проверьте загруженную конфигурацию приложения."
  },
  "admin.push.restart_required": {
    "uz":
        "Yangi Firebase sozlamasi telefonga saqlandi. Uni qo‘llash uchun ilovani to‘liq yopib, qayta oching.",
    "en":
        "New Firebase settings saved on the device. Fully close and reopen the app to apply them.",
    "ru":
        "Новые настройки Firebase сохранены. Полностью закройте и откройте приложение."
  },
  "admin.push.token_unavailable": {
    "uz":
        "Firebase telefon tokenini bermadi. Internetni tekshirib, qayta urinib ko‘ring.",
    "en":
        "Firebase did not return a device token. Check the network and retry.",
    "ru":
        "Firebase не вернул токен устройства. Проверьте сеть и повторите попытку."
  },
  "admin.push.title": {
    "uz": "Bildirishnoma sozlamalari",
    "en": "Notification settings",
    "ru": "Настройки уведомлений",
  },
  "admin.push.configured": {
    "uz": "Server: Firebase kaliti saqlangan",
    "en": "Server: Firebase credentials saved",
    "ru": "Сервер: ключ Firebase сохранён",
  },
  "admin.push.not_configured": {
    "uz": "Server: Firebase hali sozlanmagan",
    "en": "Firebase is not configured",
    "ru": "Firebase ещё не настроен",
  },
  "admin.push.project": {
    "uz": "Firebase loyihasi",
    "en": "Firebase project",
    "ru": "Проект Firebase",
  },
  "admin.push.verified": {
    "uz": "Server → Firebase ulanishi tekshirildi",
    "en": "Server → Firebase connection verified",
    "ru": "Соединение сервер → Firebase проверено",
  },
  "admin.push.not_checked": {
    "uz": "Joriy ulanish hali tekshirilmagan",
    "en": "Current connection has not been checked",
    "ru": "Текущее соединение ещё не проверено",
  },
  "admin.push.instructions": {
    "uz":
        "Ilova ulangan Firebase loyihasining service-account JSON faylini yuklang yoki matnini joylashtiring. Kalit serverda shifrlanib saqlanadi. Telefon tokenlari avtomatik olinadi.",
    "en":
        "Upload or paste the service-account JSON for this app’s Firebase project. Credentials are encrypted on the server. Device tokens are registered automatically.",
    "ru":
        "Загрузите или вставьте JSON сервисного аккаунта Firebase-проекта приложения. Ключ шифруется на сервере. Токены устройств регистрируются автоматически.",
  },
  "admin.push.pick": {
    "uz": "JSON faylni tanlash",
    "en": "Choose JSON file",
    "ru": "Выбрать JSON-файл",
  },
  "admin.push.json": {
    "uz": "Service-account JSON matni",
    "en": "Service-account JSON",
    "ru": "JSON сервисного аккаунта",
  },
  "admin.push.save": {
    "uz": "Tekshirish va saqlash",
    "en": "Verify and save",
    "ru": "Проверить и сохранить",
  },
  "admin.push.check": {
    "uz": "Server ulanishini tekshirish",
    "en": "Check server connection",
    "ru": "Проверить соединение сервера",
  },
  "admin.push.test": {
    "uz": "Shu telefonga test yuborish",
    "en": "Send test to this phone",
    "ru": "Отправить тест на этот телефон",
  },
  "admin.push.refresh": {
    "uz": "Holatni yangilash",
    "en": "Refresh status",
    "ru": "Обновить статус",
  },
  "admin.push.saved": {
    "uz": "Kalit tekshirildi va saqlandi. Serverga darhol qo‘llandi.",
    "en": "Credentials verified, saved and applied immediately.",
    "ru": "Ключ проверен, сохранён и сразу применён.",
  },
  "admin.push.test_sent": {
    "uz":
        "Test xabari FCM tomonidan qabul qilindi. Telefonda bildirishnomani tekshiring.",
    "en": "FCM accepted the test. Check notifications on your phone.",
    "ru": "FCM принял тест. Проверьте уведомления на телефоне.",
  },
  "admin.push.ios_hint": {
    "uz":
        "iPhone uchun Firebase Console’da APNs kaliti ulangan va ilovaning push sozlamalari tayyor bo‘lishi kerak.",
    "en":
        "iPhone requires an APNs key in Firebase Console and a build configured for push notifications.",
    "ru":
        "Для iPhone нужен ключ APNs в Firebase Console и сборка с поддержкой push-уведомлений.",
  },
  "admin.push.admin_only": {
    "uz": "Bu sahifa faqat admin uchun",
    "en": "This page is only available to admins",
    "ru": "Страница доступна только администратору",
  },
  "admin.push.invalid": {
    "uz":
        "To‘g‘ri service-account JSON faylini kiriting (32 KB gacha). Oddiy FCM tokeni bu yerga kiritilmaydi.",
    "en":
        "Enter a valid service-account JSON file (up to 32 KB). A device FCM token is not accepted here.",
    "ru":
        "Укажите корректный JSON сервисного аккаунта (до 32 КБ). Токен FCM устройства здесь не подходит.",
  },
  "admin.push.google_rejected": {
    "uz":
        "Google kalitni yoki loyiha ruxsatini tasdiqlamadi. Service-account ruxsatlarini va FCM API yoqilganini tekshiring.",
    "en":
        "Google rejected the credentials or project access. Check service-account permissions and the FCM API.",
    "ru":
        "Google отклонил ключ или доступ к проекту. Проверьте права сервисного аккаунта и FCM API.",
  },
  "admin.push.project_mismatch": {
    "uz": "Kalitdagi Firebase loyihasi ilova ulangan loyihaga mos emas.",
    "en": "The Firebase project in this key does not match this app.",
    "ru": "Firebase-проект ключа не совпадает с проектом приложения.",
  },
  "admin.push.unreachable": {
    "uz": "Server Google xizmatiga ulana olmadi. Qayta urinib ko‘ring.",
    "en": "The server could not reach Google. Try again.",
    "ru": "Сервер не смог подключиться к Google. Повторите попытку.",
  },
  "admin.push.save_failed": {
    "uz":
        "Server kalitni xavfsiz saqlay olmadi. Avvalgi sozlama saqlanib qoldi.",
    "en":
        "The server could not securely save the key. The previous configuration is unchanged.",
    "ru":
        "Сервер не смог безопасно сохранить ключ. Предыдущие настройки сохранены.",
  },
  "admin.push.device_missing": {
    "uz": "Bu telefonning push tokeni serverda ro‘yxatdan o‘tmagan.",
    "en": "This phone is not registered for push notifications.",
    "ru": "Push-токен этого телефона не зарегистрирован на сервере.",
  },
  "admin.push.device_unavailable": {
    "uz":
        "Bu qurilmada Firebase tayyor emas. Test uchun Firebase sozlangan haqiqiy Android yoki iPhone kerak.",
    "en":
        "Firebase is not ready on this device. Use a configured physical Android phone or iPhone.",
    "ru":
        "Firebase не готов на устройстве. Используйте настроенный физический Android или iPhone.",
  },
  "admin.push.permission_denied": {
    "uz":
        "Telefon sozlamalarida Accord uchun bildirishnomalarga ruxsat bering.",
    "en": "Allow Accord notifications in phone settings.",
    "ru": "Разрешите уведомления Accord в настройках телефона.",
  },
  "admin.push.apns_unavailable": {
    "uz":
        "Apple push ro‘yxatidan javob kutilmoqda. Internetni tekshirib, telefon sozlamasini yangilash tugmasini bosing.",
    "en": "Waiting for Apple push registration. Check your connection and refresh this phone's settings.",
    "ru":
        "Ожидается ответ регистрации Apple push. Проверьте интернет и обновите настройки телефона.",
  },
  "admin.push.apns_registering": {
    "uz": "iPhone Apple push xizmatida ro‘yxatdan o‘tmoqda…",
    "en": "Registering this iPhone with Apple push…",
    "ru": "Регистрация iPhone в Apple push…",
  },
  "admin.push.apns_entitlement_missing": {
    "uz": "O‘rnatilgan ilova imzosida Push Notifications huquqi yo‘q. Push huquqi bilan imzolangan yangi iOS build kerak.",
    "en": "The installed app signature has no Push Notifications entitlement. Install an iOS build signed with push enabled.",
    "ru": "В подписи приложения нет права Push Notifications. Установите iOS-сборку, подписанную с поддержкой push.",
  },
  "admin.push.apns_registration_failed": {
    "uz": "Apple push ro‘yxatidan o‘tish amalga oshmadi. Apple qaytargan sabab telefon holatida ko‘rsatilgan.",
    "en": "Apple push registration failed. Apple's error is shown in this phone's status.",
    "ru": "Регистрация Apple push не удалась. Причина указана в состоянии телефона.",
  },
  "admin.push.test_mode": {
    "uz":
        "Sinov rejimida Firebase sozlamalari o‘zgartirilmaydi va push yuborilmaydi.",
    "en": "Firebase settings and push tests are unavailable in test mode.",
    "ru": "Настройка Firebase и отправка push недоступны в тестовом режиме.",
  },
  "admin.push.test_failed": {
    "uz":
        "FCM test xabarini qabul qilmadi. Loyiha, APNs va telefon sozlamalarini tekshiring.",
    "en":
        "FCM did not accept the test. Check the project, APNs and device settings.",
    "ru": "FCM не принял тест. Проверьте проект, APNs и настройки устройства.",
  },
  "admin.push.failed": {
    "uz": "Amal bajarilmadi. Ulanishni tekshirib, qayta urinib ko‘ring.",
    "en": "Request failed. Check the connection and try again.",
    "ru":
        "Не удалось выполнить запрос. Проверьте соединение и повторите попытку.",
  },
};
