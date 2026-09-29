part of 'admin_localization.dart';

const _adminPushConfigTranslations = {
  "admin.push.title": {
    "uz": "Bildirishnoma sozlamalari",
    "en": "Notification settings",
    "ru": "Настройки уведомлений",
  },
  "admin.push.configured": {
    "uz": "Firebase kaliti saqlangan",
    "en": "Firebase credentials saved",
    "ru": "Ключ Firebase сохранён",
  },
  "admin.push.not_configured": {
    "uz": "Firebase hali sozlanmagan",
    "en": "Firebase is not configured",
    "ru": "Firebase ещё не настроен",
  },
  "admin.push.project": {
    "uz": "Firebase loyihasi",
    "en": "Firebase project",
    "ru": "Проект Firebase",
  },
  "admin.push.verified": {
    "uz": "Google bilan ulanish tekshirildi",
    "en": "Google connection verified",
    "ru": "Соединение с Google проверено",
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
    "uz": "Ulanishni tekshirish",
    "en": "Check connection",
    "ru": "Проверить соединение",
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
        "iPhone APNs tokeni hali tayyor emas. APNs sozlamalarini tekshiring va qayta urinib ko‘ring.",
    "en": "The iPhone APNs token is not ready. Check APNs setup and try again.",
    "ru":
        "Токен APNs ещё не готов. Проверьте настройки APNs и повторите попытку.",
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
