import 'package:flutter/widgets.dart';

import 'admin_localization.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('uz'), Locale('en'), Locale('ru')];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isUzbek => locale.languageCode == 'uz';
  bool get isRussian => locale.languageCode == 'ru';

  String _t(String uz, String en, String ru) {
    if (isUzbek) return uz;
    if (isRussian) return ru;
    return en;
  }

  String get appTitle => _t('Accord Mobile', 'Accord Mobile', 'Accord Mobile');
  String get welcomeToAccord => _t(
        'Accord Mobile ilovasiga xush kelibsiz',
        'Welcome to Accord Mobile',
        'Добро пожаловать в Accord Mobile',
      );
  String get signInTitle => _t('Kirish', 'Sign in', 'Вход');
  String get getStarted => _t('Boshlash', 'Get started', 'Начать');
  String get loginAction => _t('Kirish', 'Login', 'Войти');
  String get codeLabel => _t('Kod', 'Code', 'Код');
  String get loginRequiredFields => _t(
        'Telefon raqam va kodni kiriting',
        'Enter phone number and code',
        'Введите номер телефона и код',
      );
  String get loginFailed =>
      _t('Kirish muvaffaqiyatsiz', 'Login failed', 'Не удалось войти');
  String get connectInternetPrompt => _t(
        'Iltimos internetga ulaning.',
        'Please connect to the internet.',
        'Пожалуйста, подключитесь к интернету.',
      );
  String get profileTitle => _t('Profil', 'Profile', 'Профиль');
  String get accountSwitchTitle =>
      _t('Profilni tanlang', 'Choose a profile', 'Выберите профиль');
  String get accountSwitchHint => _t(
        'Profil tugmasini bosib turing',
        'Press and hold the profile button',
        'Нажмите и удерживайте кнопку профиля',
      );
  String get accountAdd =>
      _t('Profil qo‘shish', 'Add profile', 'Добавить профиль');
  String get accountCurrent => _t('Joriy', 'Current', 'Текущий');
  String accountPinPrompt(String name) => _t(
        '$name uchun PIN kiriting',
        'Enter the PIN for $name',
        'Введите PIN для $name',
      );
  String get accountSwitchFailed => _t(
        'Profilga o‘tib bo‘lmadi',
        'Could not switch profile',
        'Не удалось переключить профиль',
      );
  String get addProfileTitle =>
      _t('Yangi profil', 'New profile', 'Новый профиль');
  String get adminUserTitle => _t('Foydalanuvchi', 'User', 'Пользователь');
  String get profileSettingsTitle =>
      _t('Profil sozlamalari', 'Profile settings', 'Настройки профиля');
  String get profileSettingsBody => _t(
        'Til, tema va xavfsizlik sozlamalari',
        'Language, theme, and security settings',
        'Язык, тема и настройки безопасности',
      );
  String get profileEditTitle =>
      _t('Profilni tahrirlash', 'Edit profile', 'Редактировать профиль');
  String get profileEditBody => _t(
        'Nickname, profil rasmi va orqa fon rasmini yangilang',
        'Update nickname, profile photo, and cover photo',
        'Обновите псевдоним, фото профиля и фоновое фото',
      );
  String get profilePhotoTitle =>
      _t('Profil rasmi', 'Profile photo', 'Фото профиля');
  String get profileCoverTitle =>
      _t('Orqa fon rasmi', 'Cover photo', 'Фоновое фото');
  String get chooseImage =>
      _t('Rasm tanlash', 'Choose image', 'Выбрать изображение');
  String get changeImage => _t('Almashtirish', 'Change', 'Изменить');
  String get werkaAccount =>
      _t('Omborchi akkaunti', 'Wmanager account', 'Аккаунт кладовщика');
  String get supplierAccount =>
      _t('Ta\'minotchi akkaunti', 'Supplier account', 'Аккаунт поставщика');
  String get customerAccount =>
      _t('Haridor akkaunti', 'Customer account', 'Аккаунт покупателя');
  String get adminAccount =>
      _t('Admin akkaunti', 'Admin account', 'Аккаунт администратора');
  String get capabilityBasedAccount => _t(
        'Role asosidagi account',
        'Role-based account',
        'Аккаунт на основе роли',
      );
  String get nicknameSaveFailed => _t(
        'Nickname saqlanmadi',
        'Nickname was not saved',
        'Псевдоним не сохранен',
      );
  String get imagePickFailed => _t(
        'Rasm tanlanmadi',
        'Image selection failed',
        'Не удалось выбрать изображение',
      );
  String get imageSaveFailed =>
      _t('Rasm saqlanmadi', 'Image was not saved', 'Изображение не сохранено');
  String get save => _t('Saqlash', 'Save', 'Сохранить');
  String get saveChanges =>
      _t('O‘zgarishlarni saqlash', 'Save changes', 'Сохранить изменения');
  String get phoneLabel => _t('Telefon', 'Phone', 'Телефон');
  String get legalNameLabel => _t('Asl ism', 'Legal name', 'Официальное имя');
  String get nicknameLabel => _t('Nickname', 'Nickname', 'Псевдоним');
  String get nicknameHint => _t(
        'O‘zingizga ko‘rinadigan ism',
        'The name visible to you',
        'Имя, видимое только вам',
      );
  String get securityTitle => _t('Xavfsizlik', 'Security', 'Безопасность');
  String get pinEnabled => _t('PIN yoqilgan', 'PIN enabled', 'PIN включен');
  String get pinDisabled => _t('PIN o‘rnating', 'Set PIN', 'Установите PIN');
  String get pinSaving => _t('Saqlanmoqda...', 'Saving...', 'Сохранение...');
  String get pinSet => _t('PIN o‘rnatish', 'Set PIN', 'Установить PIN');
  String get pinChange => _t('PIN almashtirish', 'Change PIN', 'Изменить PIN');
  String get pinRemove => _t('PIN o‘chirish', 'Remove PIN', 'Удалить PIN');
  String get pinEnterTitle => _t('PIN kiriting', 'Enter PIN', 'Введите PIN');
  String get pinRepeatTitle =>
      _t('PIN takrorlang', 'Repeat PIN', 'Повторите PIN');
  String get pinMismatch => _t(
        'PIN bir xil emas. Qayta kiriting.',
        'PINs do not match. Enter again.',
        'PIN не совпадает. Введите заново.',
      );
  String get biometricEnableTitle => _t(
        'Biometrik autentifikatsiya',
        'Biometric authentication',
        'Биометрическая аутентификация',
      );
  String get biometricEnabledBody => _t('Yoqilgan', 'Enabled', 'Включено');
  String get biometricDisabledBody =>
      _t('O‘chirilgan', 'Disabled', 'Выключено');
  String get biometricQuickUnlockTitle =>
      _t('Tezkor ochish', 'Quick unlock', 'Быстрая разблокировка');
  String get biometricQuickUnlockPrompt => _t(
        'Face ID yoki fingerprint bilan tez ochishni yoqasizmi?',
        'Enable quick unlock with Face ID or fingerprint?',
        'Включить быструю разблокировку через Face ID или отпечаток?',
      );
  String get pinSaveFailed =>
      _t('PIN saqlanmadi', 'PIN was not saved', 'PIN не сохранен');
  String get pinRemoveFailed =>
      _t('PIN o‘chirilmadi', 'PIN was not removed', 'PIN не удален');
  String get biometricEnableFailed => _t(
        'Biometrik ochish yoqilmadi',
        'Biometric unlock was not enabled',
        'Биометрическая разблокировка не включена',
      );
  String get biometricDisableFailed => _t(
        'Biometrik ochish o‘chirilmadi',
        'Biometric unlock was not disabled',
        'Биометрическая разблокировка не отключена',
      );
  String get profileAvatarZoomLabel => _t(
        'Profil rasmini kattalashtirish',
        'Enlarge profile photo',
        'Увеличить фото профиля',
      );
  String get languageTitle => _t('Til', 'Language', 'Язык');
  String get languageUnselected =>
      _t('Tanlanmagan', 'Unselected', 'Не выбрано');
  String get languageBody => _t(
        'Ilova tilini tanlang',
        'Choose the app language',
        'Выберите язык приложения',
      );
  String get themeTitle => _t('Tema', 'Theme', 'Тема');
  String get themeBody => _t(
        'Rang uslubini tanlang',
        'Choose the color style',
        'Выберите цветовой стиль',
      );
  String get themeModeTitle =>
      _t('Yorug‘lik rejimi', 'Appearance mode', 'Режим оформления');
  String get themeModeBody => _t(
        'Yorug‘ yoki qorong‘i ko‘rinishni tanlang',
        'Choose light or dark appearance',
        'Выберите светлое или темное оформление',
      );
  String get themeClassicLabel => _t('Klassik', 'Classic', 'Классика');
  String get themeKalmarLabel => _t('Kalmar', 'Kalmar', 'Калмар');
  String get themeMossLabel => _t('Yaproq', 'Moss', 'Листва');
  String get themeLavenderLabel => _t('Lavanda', 'Lavender', 'Лаванда');
  String get themeBlissLabel => _t('Bliss', 'Bliss', 'Bliss');
  String get themeWhiteLabel => _t('Oq', 'Pure White', 'Белая');
  String get uzbek => _t('O‘zbekcha', 'Uzbek', 'Узбекский');
  String get english => _t('English', 'English', 'Английский');
  String get russian => _t('Ruscha', 'Russian', 'Русский');
  String get selectedImageNotice => _t(
        'Yangi rasm tanlandi. Saqlashni bossangiz profil yangilanadi.',
        'A new image was selected. Save to update the profile.',
        'Выбрано новое изображение. Нажмите сохранить, чтобы обновить профиль.',
      );
  String get appLockTitle =>
      _t('App qulfi', 'App lock', 'Блокировка приложения');
  String get appLockSubtitle => _t(
        '4 xonali PIN kiriting',
        'Enter your 4-digit PIN',
        'Введите 4-значный PIN',
      );
  String get unlock => _t('Ochish', 'Unlock', 'Открыть');
  String get checking => _t('Tekshirilmoqda...', 'Checking...', 'Проверка...');
  String get biometricCta => _t(
        'Biometrik autentifikatsiya',
        'Biometric authentication',
        'Биометрическая аутентификация',
      );
  String get pinWrong => _t('PIN noto‘g‘ri', 'Incorrect PIN', 'Неверный PIN');
  String get biometricFailed => _t(
        'Biometrik tasdiq bajarilmadi',
        'Biometric verification did not complete',
        'Биометрическая проверка не выполнена',
      );

  String get clearTitle => _t('Tozalash', 'Clear', 'Очистить');
  String get logoutTitle => _t('Chiqish', 'Logout', 'Выход');
  String get logoutBody => _t(
        'Joriy sessiyani yakunlash',
        'End the current session',
        'Завершить текущую сессию',
      );
  String get logoutPrompt => _t(
        'Dasturdan chiqaymi?',
        'Do you want to log out?',
        'Выйти из приложения?',
      );
  String get yes => _t('Ha', 'Yes', 'Да');
  String get no => _t('Yo‘q', 'No', 'Нет');
  String get retry => _t('Qayta urinish', 'Retry', 'Повторить');
  String get loading => _t('Yuklanmoqda...', 'Loading...', 'Загрузка...');
  String get appUpdateSettingsTitle => _t(
        'Ilovani yangilash',
        'App update',
        'Обновление приложения',
      );
  String get appUpdateSettingsBody => _t(
        'Yangi versiyani tekshirish',
        'Check for a new version',
        'Проверить новую версию',
      );
  String get appUpdateAvailableTitle => _t(
        'Yangi versiya mavjud',
        'A new version is available',
        'Доступна новая версия',
      );
  String get appUpdateRequiredTitle => _t(
        'Yangilanish talab qilinadi',
        'Update required',
        'Требуется обновление',
      );
  String appUpdateAvailableBody(String version) => _t(
        'Accord Mobile $version versiyasiga yangilanishi mumkin.',
        'Accord Mobile can be updated to version $version.',
        'Accord Mobile можно обновить до версии $version.',
      );
  String appUpdateRequiredBody(String version) => _t(
        'Ishni davom ettirish uchun $version versiyasini o‘rnating.',
        'Install version $version to continue.',
        'Установите версию $version, чтобы продолжить.',
      );
  String get appUpdateReleaseNotes =>
      _t('Nimalar yangilandi', 'What changed', 'Что изменилось');
  String get appUpdateAction => _t('Yangilash', 'Update', 'Обновить');
  String get appUpdateLater => _t('Keyinroq', 'Later', 'Позже');
  String get appUpdateCancel => _t('Bekor qilish', 'Cancel', 'Отменить');
  String get appUpdateCurrent => _t(
        'Sizda eng so‘nggi versiya o‘rnatilgan.',
        'You already have the latest version.',
        'У вас уже установлена последняя версия.',
      );
  String get appUpdateUnsupported => _t(
        'APK update faqat Android ilovasida ishlaydi.',
        'APK updates are only available in the Android app.',
        'Обновление APK доступно только в приложении Android.',
      );
  String get appUpdateCheckFailed => _t(
        'Yangilanishni tekshirib bo‘lmadi.',
        'Could not check for updates.',
        'Не удалось проверить обновления.',
      );
  String get appUpdateDownloadFailed => _t(
        'Yangilanish yuklanmadi. Qayta urining.',
        'The update could not be downloaded. Try again.',
        'Не удалось загрузить обновление. Повторите попытку.',
      );
  String get appUpdateInstallPermission => _t(
        'Accord Mobile uchun “Noma’lum ilovalarni o‘rnatish” ruxsatini yoqing, so‘ng Yangilashni yana bosing.',
        'Allow “Install unknown apps” for Accord Mobile, then tap Update again.',
        'Разрешите Accord Mobile устанавливать неизвестные приложения, затем снова нажмите «Обновить».',
      );
  String get appUpdateInstallerLaunched => _t(
        'APK tayyor. Android o‘rnatuvchisi ochildi — o‘rnatishni tizim oynasida tasdiqlang.',
        'The APK is ready. Android Installer opened — confirm the installation in the system window.',
        'APK готов. Установщик Android открыт — подтвердите установку в системном окне.',
      );
  String get appUpdateOpenInstaller => _t(
        'O‘rnatuvchini qayta ochish',
        'Open Installer again',
        'Открыть установщик снова',
      );
  String appUpdateDownloadProgress(double downloadedMb, double totalMb) => _t(
        '${downloadedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB',
        '${downloadedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB',
        '${downloadedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} МБ',
      );
  String get appUpdateBackgroundHint => _t(
        'Boshqa oynaga o‘tsangiz ham yuklash davom etadi.',
        'The download continues if you switch to another screen.',
        'Загрузка продолжится, даже если вы перейдёте в другое окно.',
      );
  String get accessDenied => _t('Ruxsat yo‘q', 'Access denied', 'Нет доступа');
  String get confirmTitle => _t('Tasdiqlash', 'Confirm', 'Подтверждение');
  String get qtyRequired =>
      _t('Miqdor kiriting', 'Enter quantity', 'Введите количество');
  String get amountLabel => _t('Miqdor', 'Quantity', 'Количество');
  String get customerLabel => _t('Haridor', 'Customer', 'Покупатель');
  String get supplierLabel => _t('Ta\'minotchi', 'Supplier', 'Поставщик');
  String get itemLabel => _t('Mahsulot', 'Item', 'Товар');
  String get selectCustomer =>
      _t('Haridor tanlang', 'Select customer', 'Выберите покупателя');
  String get searchCustomer =>
      _t('Haridor qidiring', 'Search customer', 'Поиск покупателя');
  String get selectSupplier =>
      _t('Ta\'minotchi tanlang', 'Select supplier', 'Выберите поставщика');
  String get searchSupplier =>
      _t('Ta\'minotchi qidiring', 'Search supplier', 'Поиск поставщика');
  String get selectItem =>
      _t('Mahsulot tanlang', 'Select item', 'Выберите товар');
  String get searchItem =>
      _t('Mahsulot qidiring', 'Search item', 'Поиск товара');
  String get aiSearchTakePhoto =>
      _t('Rasmga olish', 'Take photo', 'Сделать фото');
  String get aiSearchChoosePhoto =>
      _t('Gallereyadan tanlash', 'Choose from gallery', 'Выбрать из галереи');
  String get aiSearchNotConfigured => _t(
        'AI qidiruv sozlanmagan.',
        'AI search is not configured.',
        'AI-поиск не настроен.',
      );
  String get aiSearchNoResult => _t(
        'AI rasm bo‘yicha qidiruv so‘zini topolmadi.',
        'AI could not infer a search query from the image.',
        'AI не смог подобрать поисковый запрос по изображению.',
      );
  String aiSearchFailed(String error) => _t(
        'AI qidiruv bajarilmadi: $error',
        'AI search failed: $error',
        'AI-поиск не выполнен: $error',
      );
  String get createHubTitle => _t('Qayd', 'Create', 'Создать');
  String get unannouncedTitle =>
      _t('Aytilmagan mahsulot', 'Unannounced item', 'Незаявленный товар');
  String get customerIssueTitle =>
      _t('Mahsulot jo‘natish', 'Send item', 'Отправить товар');
  String get unannouncedDescription => _t(
        'Ta\'minotchi, mahsulot va miqdorni bir oqimda tanlang',
        'Choose supplier, item, and quantity in one flow',
        'Выберите поставщика, товар и количество в одном потоке',
      );
  String get customerIssueDescription => _t(
        'Haridorga jo‘natma yaratish oqimi',
        'Flow for creating a shipment to a customer',
        'Поток создания отправки для покупателя',
      );
  String get batchDispatchTitle => _t(
        'Ko‘p mahsulot chiqarish',
        'Multi-item dispatch',
        'Массовая отправка товаров',
      );
  String get batchDispatchDescription => _t(
        'Bir oqimda bir nechta jo‘natma tayyorlang',
        'Prepare multiple shipments in one flow',
        'Подготовьте несколько отправок в одном потоке',
      );
  String get nextItemAction => _t('Keyingi', 'Next', 'Далее');
  String get addAnotherAction => _t('Yana', 'Add another', 'Добавить еще');
  String get batchReviewTitle =>
      _t('Ro‘yxatni tekshirish', 'Review list', 'Проверка списка');
  String get batchReviewUnlockHint => _t(
        'Tasdiqlash uchun ro‘yxatni oxirigacha ko‘ring',
        'Review the full list to unlock confirm',
        'Просмотрите список до конца, чтобы разблокировать подтверждение',
      );
  String get batchDraftAdded =>
      _t('Ro‘yxatga qo‘shildi', 'Added to the list', 'Добавлено в список');
  String get batchNeedAtLeastTwoItems => _t(
        'Kamida 2 ta mahsulot kerak.',
        'At least 2 items are required.',
        'Нужно минимум 2 товара.',
      );
  String get batchSubmitResultTitle => _t('Natija', 'Result', 'Результат');
  String get closeAction => _t('Yopish', 'Close', 'Закрыть');
  String get homeNavTitle => _t('Uy', 'Home', 'Главная');
  String get notificationsTitle =>
      _t('Bildirishnomalar', 'Notifications', 'Уведомления');
  String get notificationsShortTitle => _t('Bildirish', 'Notify', 'Уведомл.');
  String get createNavTitle => _t('Yangi', 'New', 'Новый');
  String get historyNavTitle => _t('Tarix', 'History', 'История');
  String get archiveNavTitle => _t('Arxiv', 'Archive', 'Архив');
  String get monitoringNavTitle => _t('Kuzatish', 'Monitoring', 'Мониторинг');
  String get noNotifications => _t(
        'Hali bildirishnomalar yo‘q.',
        'No notifications yet.',
        'Уведомлений пока нет.',
      );
  String get clearAllNotificationsPrompt => _t(
        'Hamma bildirishnomalarni tozalaysizmi?',
        'Clear all notifications?',
        'Очистить все уведомления?',
      );
  String get notificationsLoadFailed => _t(
        'Bildirishnomalar yuklanmadi',
        'Failed to load notifications',
        'Не удалось загрузить уведомления',
      );
  String get archiveTitle => _t('Data', 'Data', 'Data');
  String get archivePlaceholder => _t(
        'Bu bo‘limga keyin yangi archive logikasi qo‘yiladi.',
        'A new archive flow will be added here later.',
        'Позже сюда будет добавлена новая логика архива.',
      );
  String get archiveReceivedTitle =>
      _t('Qabul qilingan', 'Received', 'Принятые');
  String get archiveSentTitle => _t('Jo\'natilgan', 'Sent', 'Отправленные');
  String get archiveReturnedTitle =>
      _t('Qaytarilgan', 'Returned', 'Возвращённые');
  String get archiveDailyTitle => _t('Kunlik', 'Daily', 'Дневной');
  String get archiveMonthlyTitle => _t('Oylik', 'Monthly', 'Месячный');
  String get archiveYearlyTitle => _t('Yillik', 'Yearly', 'Годовой');
  String get archiveCustomRangeTitle =>
      _t('Sana oralig‘i', 'Date range', 'Период дат');
  String get archiveDateTitle => _t('Sana', 'Date', 'Дата');
  String get archiveMonthTitle => _t('Oy', 'Month', 'Месяц');
  String get archiveCalendarHint => _t(
        'Maʼlumot bor kunlar belgilangan.',
        'Days with data are highlighted.',
        'Дни с данными выделены.',
      );
  String get archiveCalendarEmptyMonth => _t(
        'Bu oyda yozuv topilmadi.',
        'No records found in this month.',
        'За этот месяц записей не найдено.',
      );
  String get archiveMonthCalendarHint => _t(
        'Maʼlumot bor oylar belgilangan.',
        'Months with data are highlighted.',
        'Месяцы с данными выделены.',
      );
  String get archiveYearCalendarHint => _t(
        'Maʼlumot bor yillar belgilangan.',
        'Years with data are highlighted.',
        'Годы с данными выделены.',
      );
  String get archiveCalendarEmptyYear => _t(
        'Bu yilda yozuv topilmadi.',
        'No records found in this year.',
        'За этот год записей не найдено.',
      );
  String get archiveStartDateLabel =>
      _t('Boshlanish sana', 'Start date', 'Дата начала');
  String get archiveEndDateLabel =>
      _t('Tugash sana', 'End date', 'Дата окончания');
  String get archiveSelectDateAction => _t('Tanlash', 'Select', 'Выбрать');
  String get archiveSelectMonthAction =>
      _t('Oy tanlash', 'Choose month', 'Выбрать месяц');
  String get archiveViewAction => _t('Ko‘rish', 'View', 'Открыть');
  String get archiveCustomRangeHint => _t(
        'Aynan kerakli kun yoki oraliqni tanlang.',
        'Choose the exact day or range you need.',
        'Выберите нужный день или диапазон.',
      );
  String get archiveInvalidRange => _t(
        'Tugash sana boshlanish sanadan oldin bo‘lishi mumkin emas.',
        'End date cannot be before start date.',
        'Дата окончания не может быть раньше даты начала.',
      );
  String get archiveChoosePeriod =>
      _t('Periodni tanlang', 'Choose a period', 'Выберите период');
  String get archiveNoItems => _t(
        'Bu bo‘limda hozircha yozuv yo‘q.',
        'There are no records in this section yet.',
        'В этом разделе пока нет записей.',
      );
  String get archiveDownloadPdfAction =>
      _t('Yuklab olish', 'Download', 'Скачать');
  String get archiveDownloadingPdf =>
      _t('PDF yuklanmoqda...', 'Downloading PDF...', 'PDF загружается...');
  String get archivePdfReadyTitle =>
      _t('PDF tayyor', 'PDF is ready', 'PDF готов');
  String get archivePdfReadyMessage => _t(
        'Uni Files ga, Photos ga saqlashingiz yoki share qilishingiz mumkin.',
        'You can save it to Files, save it to Photos, or share it.',
        'Вы можете сохранить его в Files, в Фото или поделиться им.',
      );
  String get archiveSaveToFilesAction =>
      _t('Files ga saqlash', 'Save to Files', 'Сохранить в Files');
  String get archiveShareAction => _t('Ulashish', 'Share', 'Поделиться');
  String get batchViewListAction =>
      _t('Ro‘yxatni ko‘rish', 'View list', 'Открыть список');
  String get archiveSavePhotoAction =>
      _t('Rasmga saqlash', 'Save photo', 'Сохранить как фото');
  String get archivePdfSavedToPhotos => _t(
        'PDF birinchi sahifasi Photos ga saqlandi.',
        'The first PDF page was saved to Photos.',
        'Первая страница PDF сохранена в Фото.',
      );
  String get archivePdfPhotoFailed => _t(
        'PDF ni rasm sifatida saqlab bo‘lmadi.',
        'Failed to save the PDF as a photo.',
        'Не удалось сохранить PDF как фото.',
      );
  String archivePdfSavedAt(String location) => _t(
        'PDF saqlandi: $location',
        'PDF saved: $location',
        'PDF сохранён: $location',
      );
  String get archivePdfSavedToFiles => _t(
        'PDF Files ga saqlandi.',
        'PDF saved to Files.',
        'PDF сохранён в Files.',
      );
  String get archivePdfSavedOnIPhone => _t(
        'PDF Files ilovasiga saqlandi: On My iPhone > Accord Mobile',
        'PDF saved in Files: On My iPhone > Accord Mobile',
        'PDF сохранён в Files: На моём iPhone > Accord Mobile',
      );
  String get archivePdfDownloadStartedWeb => _t(
        'PDF yuklab olish boshlandi.',
        'PDF download started.',
        'Загрузка PDF началась.',
      );
  String get archivePdfFailed => _t(
        'PDF yuklab bo‘lmadi. Qayta urinib ko‘ring.',
        'Failed to download PDF. Try again.',
        'Не удалось загрузить PDF. Попробуйте снова.',
      );
  String archiveRecordCountLabel(int count) =>
      _t('$count ta yozuv', '$count records', '$count записей');
  String archiveTotalByUomLabel(String uom, double qty) => _t(
        '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $uom',
        '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $uom',
        '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $uom',
      );
  String get recentTitle =>
      _t('So‘nggi harakatlar', 'Recent', 'Недавние действия');
  String get recentSubtitle => _t(
        'Avvalgi harakatni prefill bilan qayta ishlating',
        'Reuse previous actions with prefill',
        'Повторно используйте предыдущие действия с предзаполнением',
      );
  String get recentLoadFailed => _t(
        'Recent yuklanmadi',
        'Failed to load recent',
        'Не удалось загрузить раздел недавних',
      );
  String get noRecentActions => _t(
        'Hali repeat qilish uchun recent harakat yo‘q.',
        'There are no recent actions to repeat yet.',
        'Пока нет недавних действий для повтора.',
      );
  String get repeatSendAgain =>
      _t('Yana jo‘natish', 'Send again', 'Отправить снова');
  String get repeatCreateAgain =>
      _t('Yana qayd qilish', 'Create again', 'Создать снова');
  String get pendingStatus => _t('Jarayonda', 'In progress', 'В процессе');
  String get confirmedStatus => _t('Tasdiqlangan', 'Confirmed', 'Подтверждено');
  String get returnedStatus => _t('Qaytarilgan', 'Returned', 'Возвращено');
  String get serverDisconnectedRetry => _t(
        'Server uzilgan. Qayta urining.',
        'Server disconnected. Try again.',
        'Сервер отключен. Повторите попытку.',
      );
  String get inProgressItemsTitle =>
      _t('Jarayondagi mahsulotlar', 'Items in progress', 'Товары в процессе');
  String get recordsLoadFailed => _t(
        'Yozuvlar yuklanmadi',
        'Failed to load records',
        'Не удалось загрузить записи',
      );
  String get noRecordsYet => _t(
        'Bu ro‘yxatda hozircha yozuv yo‘q.',
        'No records in this list yet.',
        'В этом списке пока нет записей.',
      );
  String get statusListLoadFailed => _t(
        'Status ro‘yxati yuklanmadi',
        'Failed to load status list',
        'Не удалось загрузить список статусов',
      );
  String get noStatusRecords => _t(
        'Bu statusda hozircha yozuv yo‘q.',
        'No records in this status yet.',
        'В этом статусе пока нет записей.',
      );
  String get receiptsSuffix => _t('ta receipt', 'receipts', 'документов');
  String get sentToCustomer =>
      _t('haridorga yuborilgan', 'sent to customer', 'отправлено покупателю');
  String get receivedFromSupplier => _t(
        'ta\'minotchidan qabul qilingan',
        'received from supplier',
        'получено от поставщика',
      );
  String get acceptedFromQtyPrefix => _t('Qabul', 'Accepted', 'Принято');
  String get createFlowBack =>
      _t('Qaydga qaytish', 'Back to create', 'Назад к созданию');
  String backToFlow(String flowName) =>
      _t('$flowName ga qaytish', 'Back to $flowName', 'Назад к $flowName');
  String get pendingListBack => _t(
        'Pending listga qaytish',
        'Back to pending list',
        'Назад к списку ожидания',
      );
  String get sentSuccess => _t('Jo‘natildi', 'Sent', 'Отправлено');
  String get createdSuccess => _t('Qayd qilindi', 'Created', 'Создано');
  String get receivedSuccess => _t('Qabul qilindi', 'Received', 'Принято');
  String get customerApproved =>
      _t('Haridor tasdiqlagan', 'Customer approved', 'Покупатель подтвердил');
  String get customerRejected =>
      _t('Haridor rad etgan', 'Customer rejected', 'Покупатель отклонил');
  String get partiallyCompleted =>
      _t('Qisman yakunlangan', 'Partially completed', 'Частично завершено');
  String get cancelled => _t('Bekor qilingan', 'Cancelled', 'Отменено');
  String get waitingCustomerResponse => _t(
        'Haridor javobi kutilmoqda',
        'Waiting for customer response',
        'Ожидается ответ покупателя',
      );
  String get draft => _t('Draft', 'Draft', 'Черновик');
  String get noExtraNote => _t(
        'Qo‘shimcha izoh yo‘q.',
        'No additional note.',
        'Дополнительного примечания нет.',
      );
  String get customerShipmentTitle =>
      _t('Haridor jo‘natmasi', 'Customer shipment', 'Отправка покупателю');
  String get statusLabel => _t('Status', 'Status', 'Статус');
  String get dateLabel => _t('Sana', 'Date', 'Дата');
  String get detailsStateTitle => _t('Holat', 'State', 'Состояние');

  String statusWithName(String name, String status) => '$status • $name';
  String recordsLoadFailedWith(Object error) => serverDisconnectedRetry;
  String statusListLoadFailedWith(Object error) => serverDisconnectedRetry;
  String notificationsLoadFailedWith(Object error) => serverDisconnectedRetry;
  String recentLoadFailedWith(Object error) => serverDisconnectedRetry;
  String sentQtyStatus(num qty, String uom, String statusWord) =>
      '${qty.toStringAsFixed(0)} $uom $statusWord';
  String receiptCountLabel(int count) =>
      isUzbek ? '$count ta receipt' : '$count receipts';
  String recordCountLabel(int count) =>
      isUzbek ? '$count ta hujjat' : '$count records';
  String customerFlowMetric(num qty, String uom) =>
      '${qty.toStringAsFixed(0)} $uom $sentToCustomer';
  String supplierFlowMetric(num qty, String uom) =>
      '${qty.toStringAsFixed(0)} $uom $receivedFromSupplier';
  String acceptedQtyLabel(num qty, String uom) =>
      '$acceptedFromQtyPrefix: ${qty.toStringAsFixed(0)} $uom';
  String batchDraftCountLabel(int count) => _t(
        'Ro‘yxatda $count ta mahsulot',
        '$count items in the list',
        'В списке $count товаров',
      );
  String batchCustomerCountLabel(int count) =>
      _t('$count ta haridor', '$count customers', '$count покупателей');
  String batchCreatedCountLabel(int count) => _t(
        '$count ta jo‘natma yaratildi',
        '$count shipments created',
        'Создано $count отправок',
      );
  String batchFailedCountLabel(int count) => _t(
        '$count ta jo‘natma xato bo‘ldi',
        '$count shipments failed',
        '$count отправок завершились ошибкой',
      );
  String batchSentLine(int count) => _t(
        '$count ta jo‘natma yuborildi',
        '$count shipments sent',
        'Отправлено $count отправок',
      );
  String customerShipmentPendingNote() => isUzbek
      ? 'Bu jo‘natma omborchi tomonidan haridorga yuborilgan. Qaytarish yoki tasdiqlash haridor tomonidan qilinadi.'
      : isRussian
          ? 'Эта отправка была сделана кладовщиком для покупателя. Возврат или подтверждение должен выполнить покупатель.'
          : 'This shipment was sent by Werka to the customer. Any rejection or approval must be done by the customer.';
  String sentToCustomerLine(num qty, String uom) => _t(
        '${qty.toStringAsFixed(2)} $uom haridorga jo‘natildi',
        '${qty.toStringAsFixed(2)} $uom sent to customer',
        '${qty.toStringAsFixed(2)} $uom отправлено покупателю',
      );
  String createdLine(num qty, String uom) => _t(
        '${qty.toStringAsFixed(2)} $uom qayd qilindi',
        '${qty.toStringAsFixed(2)} $uom recorded',
        '${qty.toStringAsFixed(2)} $uom зафиксировано',
      );
  String receivedLine(num qty, String uom) => _t(
        '${qty.toStringAsFixed(2)} $uom qabul qilindi',
        '${qty.toStringAsFixed(2)} $uom received',
        '${qty.toStringAsFixed(2)} $uom принято',
      );
  String customerIssueFailed(Object error) => _t(
        'Server uzilgan. Qayta urining.',
        'Server disconnected. Try again.',
        'Сервер отключен. Повторите попытку.',
      );
  String get insufficientStockMessage => _t(
        'Omborda yetarli mahsulot yo‘q.',
        'There is not enough stock in the warehouse.',
        'На складе недостаточно товара.',
      );
  String unannouncedSuppliersFailed(Object error) => _t(
        'Server uzilgan. Qayta urining.',
        'Server disconnected. Try again.',
        'Сервер отключен. Повторите попытку.',
      );
  String customersLoadFailed(Object error) => _t(
        'Server uzilgan. Qayta urining.',
        'Server disconnected. Try again.',
        'Сервер отключен. Повторите попытку.',
      );

  String get werkaRoleName => _t('Omborchi', 'Wmanager', 'Кладовщик');
  String get customerRoleName => _t('Haridor', 'Customer', 'Покупатель');
  String get supplierRoleName => _t('Ta\'minotchi', 'Supplier', 'Поставщик');
  String get adminRoleName => _t('Admin', 'Admin', 'Админ');
  String get submittedStatus => _t('Qabul qilingan', 'Accepted', 'Принято');
  String get supplierAcceptedByWerkaTitle => _t(
        'Omborchi qabul qilganlar',
        'Accepted by Werka',
        'Принято кладовщиком',
      );
  String get supplierAcceptedUnannouncedTitle => _t(
        'Aytilmagan mahsulot tasdiqlanganlar',
        'Approved unannounced items',
        'Подтвержденные незаявленные товары',
      );
  String get supplierPendingDispatchesTitle => _t(
        'Jo‘natilgan, javob kutilayotganlar',
        'Sent and awaiting response',
        'Отправлено, ожидается ответ',
      );
  String get supplierPendingUnannouncedTitle => _t(
        'Aytilmagan mahsulot bo‘yicha javob kutilayotganlar',
        'Awaiting reply on unannounced items',
        'Ожидается ответ по незаявленным товарам',
      );
  String get supplierHomeLoadFailed => _t(
        'Home yuklanmadi',
        'Home failed to load',
        'Не удалось загрузить главную',
      );
  String get noSupplierReceiptsYet =>
      _t('Hozircha receipt yo‘q.', 'No receipts yet.', 'Пока нет приходов.');
  String get noSupplierShipmentsYet =>
      _t('Hali jo‘natishlar yo‘q.', 'No shipments yet.', 'Пока нет отправок.');
  String get adminSummaryLoadFailed => _t(
        'Admin summary yuklanmadi',
        'Admin summary failed to load',
        'Не удалось загрузить сводку администратора',
      );
  String get adminSettingsTitle =>
      _t('Admin sozlamalari', 'Admin settings', 'Настройки администратора');
  String get adminTelegramTitle =>
      _t('Telegram bot', 'Telegram bot', 'Telegram-бот');
  String get adminTelegramSubtitle => _t(
        'Admin va sotuv managerlari uchun Telegram ulanishi',
        'Telegram access for admins and sales managers',
        'Telegram-доступ для администраторов и менеджеров продаж',
      );
  String get adminTelegramGroupsTitle => _t(
        'Buyurtma guruhlari',
        'Order groups',
        'Группы заказов',
      );
  String get adminTelegramGroupsHint => _t(
        'Botni guruhga qo‘shing va guruhda /connect yuboring.',
        'Add the bot to a group and send /connect there.',
        'Добавьте бота в группу и отправьте там /connect.',
      );
  String get adminTelegramNoGroups => _t(
        'Hali Telegram guruhi ulanmagan',
        'No Telegram group connected yet',
        'Группа Telegram ещё не подключена',
      );
  String get adminTelegramBotSettingsTitle => _t(
        'Bot settings',
        'Bot settings',
        'Настройки бота',
      );
  String get adminTelegramBotSettingsSubtitle => _t(
        'Bot username va tokenni shu yerda sozlang',
        'Configure the bot username and token here',
        'Настройте здесь имя и токен бота',
      );
  String get adminTelegramBotUsernameLabel => _t(
        'Bot username',
        'Bot username',
        'Имя пользователя бота',
      );
  String get adminTelegramBotTokenLabel => _t(
        'Bot token',
        'Bot token',
        'Токен бота',
      );
  String get adminTelegramBotTokenHint => _t(
        'Token bo‘sh qolsa, mavjud token saqlanadi.',
        'Leave the token empty to keep the current token.',
        'Оставьте токен пустым, чтобы сохранить текущий.',
      );
  String get adminTelegramSaveBotSettings => _t(
        'Saqlash',
        'Save',
        'Сохранить',
      );
  String get adminTelegramSettingsSaved => _t(
        'Telegram sozlamalari saqlandi',
        'Telegram settings saved',
        'Настройки Telegram сохранены',
      );
  String get adminTelegramSettingsSaveFailed => _t(
        'Telegram sozlamalari saqlanmadi',
        'Telegram settings could not be saved',
        'Не удалось сохранить настройки Telegram',
      );
  String get adminTelegramBotNotConfigured => _t(
        'Bot sozlanmagan',
        'Bot is not configured',
        'Бот не настроен',
      );
  String get adminTelegramInviteRolesTitle => _t(
        'Taklif yuborish',
        'Send an invite',
        'Отправить приглашение',
      );
  String get adminTelegramInviteRolesSubtitle => _t(
        'Role ni tanlang va native share orqali kerakli userga yuboring',
        'Choose a role and send it to the user through native sharing',
        'Выберите роль и отправьте ссылку пользователю через системную отправку',
      );
  String get adminTelegramAdminRoleTitle =>
      _t('Admin', 'Admin', 'Администратор');
  String get adminTelegramSalesManagerRoleTitle => _t(
        'Sotuv manageri',
        'Sales manager',
        'Менеджер продаж',
      );
  String get adminTelegramInviteRoleDescription => _t(
        'Link yaratib Telegram orqali yuborish',
        'Create a link and send it through Telegram',
        'Создать ссылку и отправить через Telegram',
      );
  String get adminTelegramShareInvite => _t(
        'Invite linkni ulashish',
        'Share invite link',
        'Поделиться ссылкой-приглашением',
      );
  String get adminTelegramShareTitle => _t(
        'Accord Telegram taklifi',
        'Accord Telegram invite',
        'Приглашение Accord в Telegram',
      );
  String get adminTelegramInviteFailed => _t(
        'Telegram invite yaratilmadi',
        'Telegram invite could not be created',
        'Не удалось создать приглашение Telegram',
      );
  String get adminTelegramUsersTitle => _t(
        'Ulangan Telegram userlar',
        'Connected Telegram users',
        'Подключенные пользователи Telegram',
      );
  String get adminTelegramNoUsers => _t(
        'Hali hech kim start bosmagan.',
        'No one has started the bot yet.',
        'Пока никто не запустил бота.',
      );
  String get adminTelegramUnknownUser => _t(
        'Noma’lum user',
        'Unknown user',
        'Неизвестный пользователь',
      );
  String get adminTelegramDeliveryBot => _t(
        'Bot orqali',
        'Via bot',
        'Через бота',
      );
  String get adminTelegramDeliveryUserProfile => _t(
        'User profile orqali',
        'Via user profile',
        'Через профиль пользователя',
      );
  String get adminTelegramUserProfileConnected => _t(
        'User profile ulangan',
        'User profile connected',
        'Профиль пользователя подключен',
      );
  String get adminTelegramUserProfileNotConnected => _t(
        'User profile ulanmagan',
        'User profile not connected',
        'Профиль пользователя не подключен',
      );
  String get adminTelegramSelectedGroup => _t(
        'Tanlangan guruh',
        'Selected group',
        'Выбранная группа',
      );
  String get adminActivityTitle => _t('Harakatlar', 'Activity', 'Активность');
  String get adminActivityNavTitle => _t('Faoliyat', 'Activity', 'Активность');
  String get adminDrawerSections => _t('Bo‘limlar', 'Sections', 'Разделы');
  String get adminHomeNavTitle => _t('Uy', 'Home', 'Главная');
  String get adminWorkMapNavTitle =>
      _t('Ish xaritasi', 'Work map', 'Карта работ');
  String get adminSemiFinishedProductsNavTitle => _t(
        'Yarim tayyor mahsulotlar',
        'Semi-finished products',
        'Полуфабрикаты',
      );
  String get adminNotificationsNavTitle =>
      _t('Bildirishnomalar', 'Notifications', 'Уведомления');
  String get adminEquipmentNavTitle =>
      _t('Aparatlar', 'Equipment', 'Оборудование');
  String get adminWarehousesNavTitle => _t('Omborlar', 'Warehouses', 'Склады');
  String get adminFactoryStatesNavTitle =>
      _t('State’lar', 'Factory states', 'Зоны производства');
  String get adminRawMaterialRulesNavTitle => _t(
        'Homashyo qoidalari',
        'Raw material rules',
        'Правила сырья',
      );
  String get adminProductGroupsNavTitle => _t(
        'Mahsulot guruhlari',
        'Product groups',
        'Группы товаров',
      );
  String get adminServerStatusNavTitle =>
      _t('Server holati', 'Server status', 'Состояние сервера');
  String get adminFactoryMapNavTitle =>
      _t('Zavod kartasi', 'Factory map', 'Карта завода');
  String get adminScalesModeNavTitle =>
      _t('Tarozilar rejimi', 'Scales mode', 'Режим весов');
  String get adminCuttingNavTitle => _t('Kesish', 'Cutting', 'Резка');
  String get adminQuickOrdersTitle =>
      _t('Tezkor buyurtmalar', 'Quick orders', 'Быстрые заказы');
  String get adminProductionMapTestTitle =>
      _t('Ish xaritasi testi', 'Work map test', 'Тест карты работ');
  String get adminTotalUsersTitle =>
      _t('Jami foydalanuvchilar', 'Total users', 'Всего пользователей');
  String get adminActiveUsersTitle =>
      _t('Faol foydalanuvchilar', 'Active users', 'Активные пользователи');
  String get adminBlockedUsersTitle => _t(
        'Bloklangan foydalanuvchilar',
        'Blocked users',
        'Заблокированные пользователи',
      );
  String get adminBlockedUsersControlTitle =>
      _t('Blok nazorati', 'Block control', 'Контроль блокировок');
  String adminBlockedUsersCountLabel(int count) => _t(
        'Bloklangan foydalanuvchilar: $count ta',
        'Blocked users: $count',
        'Заблокированные пользователи: $count',
      );
  String get adminUsersTitle => _t('Foydalanuvchilar', 'Users', 'Пользователи');
  String get adminWorkersNavTitle => _t('Ishchilar', 'Workers', 'Сотрудники');
  String get adminProductsTitle => _t('Mahsulotlar', 'Products', 'Товары');
  String get adminRolesTitle => _t('Rollar', 'Roles', 'Роли');
  String get adminRolesAssignTab => _t('Biriktirish', 'Assign', 'Назначить');
  String get adminNewRole => _t('Yangi role', 'New role', 'Новая роль');
  String get adminEditRole =>
      _t('Roleni tahrirlash', 'Edit role', 'Редактировать роль');
  String get adminRoleNameLabel =>
      _t('Role nomi', 'Role name', 'Название роли');
  String get adminBaseRoleLabel =>
      _t('Asosiy role', 'Base role', 'Базовая роль');
  String get adminRoleDetailsShow =>
      _t('Tafsilotlarni ko‘rsatish', 'Show details', 'Показать детали');
  String get adminRoleDetailsHide =>
      _t('Tafsilotlarni yashirish', 'Hide details', 'Скрыть детали');
  String get adminSystemRoleKind => _t('tizim', 'system', 'система');
  String get adminCustomRoleKind => _t('maxsus', 'custom', 'пользовательская');
  String get adminDefaultRole =>
      _t('Standart role', 'Default role', 'Роль по умолчанию');
  String get adminRoleSaved =>
      _t('Role saqlandi', 'Role saved', 'Роль сохранена');
  String get adminRoleSaveFailed =>
      _t('Role saqlanmadi', 'Role was not saved', 'Роль не сохранена');
  String get adminRoleAssigned =>
      _t('Role biriktirildi', 'Role assigned', 'Роль назначена');
  String get adminRoleAssignFailed =>
      _t('Role biriktirilmadi', 'Role was not assigned', 'Роль не назначена');
  String adminRoleForPrincipal(String name) =>
      _t('$name uchun role', 'Role for $name', 'Роль для $name');
  String adminRoleKindLabel(bool system) =>
      system ? adminSystemRoleKind : adminCustomRoleKind;
  String roleLabelForCode(String code) {
    switch (code) {
      case 'admin':
        return adminRoleName;
      case 'werka':
        return werkaRoleName;
      case 'customer':
        return customerRoleName;
      case 'supplier':
        return supplierRoleName;
      default:
        return code;
    }
  }

  String systemRoleLabel(String id, String fallback) {
    switch (id.trim().toLowerCase()) {
      case 'admin':
        return adminRoleName;
      case 'werka':
        return werkaRoleName;
      case 'customer':
        return customerRoleName;
      case 'supplier':
        return supplierRoleName;
      default:
        return fallback;
    }
  }

  String adminCapabilityLabel(String code, String fallback) {
    switch (code) {
      case 'admin.access':
        return _t('Admin panel', 'Admin panel', 'Панель администратора');
      case 'role.capability.read':
        return _t(
          'Role huquqlarini ko‘rish',
          'Role capability catalog read',
          'Просмотр каталога прав ролей',
        );
      case 'role.capability.manage':
        return _t(
          'Role huquqlarini boshqarish',
          'Role capability manage',
          'Управление правами ролей',
        );
      case 'admin.settings.read':
        return _t(
          'Admin sozlamalarini ko‘rish',
          'Admin settings read',
          'Просмотр настроек администратора',
        );
      case 'admin.settings.manage':
        return _t(
          'Admin sozlamalarini boshqarish',
          'Admin settings manage',
          'Управление настройками администратора',
        );
      case 'werka.access':
        return _t(
          'Omborchi oynasi',
          'Werka workspace',
          'Рабочее место кладовщика',
        );
      case 'supplier.access':
        return _t(
          'Ta\'minotchi oynasi',
          'Supplier workspace',
          'Рабочее место поставщика',
        );
      case 'customer.access':
        return _t(
          'Haridor oynasi',
          'Customer workspace',
          'Рабочее место покупателя',
        );
      case 'push.token.manage':
        return _t(
          'Push token boshqarish',
          'Push token manage',
          'Управление push-токенами',
        );
      case 'supplier.avatar.manage':
        return _t(
          'Ta\'minotchi avatarini boshqarish',
          'Supplier avatar manage',
          'Управление аватаром поставщика',
        );
      case 'catalog.item.read':
        return _t(
          'Katalog mahsulotlarini ko‘rish',
          'Catalog item read',
          'Просмотр товаров каталога',
        );
      case 'catalog.item.create':
        return _t(
          'Katalog mahsulot yaratish',
          'Catalog item create',
          'Создание товара каталога',
        );
      case 'catalog.item_group.read':
        return _t(
          'Mahsulot guruhlarini ko‘rish',
          'Catalog item group read',
          'Просмотр групп товаров',
        );
      case 'catalog.item_group.manage':
        return _t(
          'Mahsulot guruhlarini boshqarish',
          'Catalog item group manage',
          'Управление группами товаров',
        );
      case 'catalog.item.bulk_move':
        return _t(
          'Mahsulotlarni guruhlar orasida ko‘chirish',
          'Catalog item bulk move',
          'Массовый перенос товаров между группами',
        );
      case 'party.supplier.read':
        return _t(
          'Ta\'minotchilar ro‘yxatini ko‘rish',
          'Supplier directory read',
          'Просмотр справочника поставщиков',
        );
      case 'party.supplier.manage':
        return _t(
          'Ta\'minotchilarni boshqarish',
          'Supplier directory manage',
          'Управление поставщиками',
        );
      case 'party.supplier.item.assign':
        return _t(
          'Ta\'minotchiga mahsulot biriktirish',
          'Supplier item assign',
          'Назначение товаров поставщику',
        );
      case 'party.supplier.code.manage':
        return _t(
          'Ta\'minotchi kodini boshqarish',
          'Supplier code manage',
          'Управление кодом поставщика',
        );
      case 'party.customer.read':
        return _t(
          'Haridorlar ro‘yxatini ko‘rish',
          'Customer directory read',
          'Просмотр справочника покупателей',
        );
      case 'party.customer.manage':
        return _t(
          'Haridorlarni boshqarish',
          'Customer directory manage',
          'Управление покупателями',
        );
      case 'party.customer.item.assign':
        return _t(
          'Haridorga mahsulot biriktirish',
          'Customer item assign',
          'Назначение товаров покупателю',
        );
      case 'party.customer.code.manage':
        return _t(
          'Haridor kodini boshqarish',
          'Customer code manage',
          'Управление кодом покупателя',
        );
      case 'admin.activity.read':
        return _t(
          'Admin harakatlarini ko‘rish',
          'Admin activity read',
          'Просмотр активности администратора',
        );
      case 'werka.code.manage':
        return _t(
          'Omborchi kodini boshqarish',
          'Werka code manage',
          'Управление кодом кладовщика',
        );
      case 'production.map.manage':
        return _t(
          'Production map boshqarish',
          'Production map manage',
          'Управление картой производства',
        );
      case 'gscale.catalog.read':
        return _t(
          'GScale katalogini ko‘rish',
          'GScale catalog read',
          'Просмотр каталога GScale',
        );
      case 'gscale.print':
        return _t('GScale chop etish', 'GScale print', 'Печать GScale');
      case 'rps.batch.manage':
        return _t(
          'RPS batch boshqarish',
          'RPS batch manage',
          'Управление batch RPS',
        );
      case 'rezka.split.manage':
        return _t(
          'Rezka bo‘lishni boshqarish',
          'Rezka split manage',
          'Управление резкой',
        );
      default:
        return fallback;
    }
  }

  String get adminNoActivity =>
      _t('Hali harakat yo‘q.', 'No activity yet.', 'Активности пока нет.');
  String get adminCreateTitle => _t('Qo‘shish', 'Create', 'Создать');
  String get adminCreateUserTitle =>
      _t('Foydalanuvchi qo‘shish', 'Add user', 'Добавить пользователя');
  String get adminCreateUserSubtitle => _t(
        'Omborchi, haridor yoki ta\'minotchi yaratish',
        'Create a warehouse worker, customer, or supplier',
        'Создание кладовщика, покупателя или поставщика',
      );
  String get adminSettingsLoadFailed => _t(
        'Settings yuklanmadi',
        'Settings failed to load',
        'Не удалось загрузить настройки',
      );
  String get settingsSaved =>
      _t('Sozlamalar saqlandi', 'Settings saved', 'Настройки сохранены');
  String get erpConnectionTitle =>
      _t('ERP ulanishi', 'ERP connection', 'ERP подключение');
  String get erpConnectionSubtitle => _t(
        'Core integratsiya va stock default sozlamalari',
        'Core integration and stock defaults',
        'Интеграция с ядром и значения по умолчанию для склада',
      );
  String get adminCreateSupplierTitle =>
      _t('Ta\'minotchi qo‘shish', 'Add supplier', 'Добавить поставщика');
  String get adminCreateSupplierSubtitle => _t(
        'Ta\'minotchi yaratish va code boshqaruvi',
        'Create a supplier and manage codes',
        'Создание поставщика и управление кодами',
      );
  String get adminCreateCustomerTitle =>
      _t('Haridor qo‘shish', 'Add customer', 'Добавить покупателя');
  String get adminCreateCustomerSubtitle => _t(
        'Haridor yaratish va jo‘natma qabul oqimi',
        'Create a customer and manage receiving flow',
        'Создание покупателя и управление потоком приемки',
      );
  String get adminCreateWerkaTitle =>
      _t('Omborchi qo‘shish', 'Add Werka', 'Добавить кладовщика');
  String get adminCreateWerkaSubtitle => _t(
        'Omborchi phone va name sozlash',
        'Configure warehouse worker phone and name',
        'Настройка телефона и имени кладовщика',
      );
  String get adminErpSettingsTitle =>
      _t('ERP sozlamalari', 'ERP settings', 'Настройки ERP');
  String get adminErpSettingsSubtitle => _t(
        'URL, key, secret va ombor sozlamalari',
        'URL, key, secret, and warehouse settings',
        'URL, key, secret и настройки склада',
      );
  String get adminCreateItemTitle =>
      _t('Mahsulot qo‘shish', 'Add item', 'Добавить товар');
  String get adminCreateItemSubtitle =>
      _t('Yangi mahsulot yaratish', 'Create a new item', 'Создать новый товар');
  String get adminCreateItemGroupTitle =>
      _t('Item Group yaratish', 'Create item group', 'Создать группу товаров');
  String get adminQrScanTitle =>
      _t('QR skanerlash', 'QR scan', 'Сканировать QR');
  String get adminCreateOrderTitle =>
      _t('Buyurtma yaratish', 'Create order', 'Создать заказ');
  String get adminCreateItemGroupSubtitle => _t(
        'Parent-child mahsulot guruhlarini yaratish',
        'Create parent-child item groups',
        'Создание родительских и дочерних групп товаров',
      );
  String get adminSettingsSectionTitle =>
      _t('Omborchi sozlamalari', 'Werka defaults', 'Настройки кладовщика');
  String get adminSettingsSectionSubtitle => _t(
        'Mobil oqimda ishlatiladigan contact qiymatlar',
        'Contact values used by the mobile flow',
        'Контактные значения, используемые в мобильном потоке',
      );
  String get supplierAckTitle => _t(
        'Ta\'minotchi tasdiqladi',
        'Supplier acknowledged',
        'Поставщик подтвердил',
      );

  String get pendingLabel => _t('Kutilmoqda', 'Pending', 'Ожидается');
  String get rejectedLabel => _t('Rad etilgan', 'Rejected', 'Отклонено');
  String get recentShipmentsTitle =>
      _t('So‘nggi jo‘natmalar', 'Recent shipments', 'Недавние отправки');
  String get noShipments => _t('Jo‘natma yo‘q', 'No shipments', 'Нет отправок');
  String get shipmentsFlowTitle =>
      _t('Jo‘natmalar oqimi', 'Shipment flow', 'Поток отправок');
  String get detailsTitle => _t('Batafsil', 'Details', 'Детали');
  String get shipmentInfoTitle =>
      _t('Jo‘natma ma’lumoti', 'Shipment details', 'Информация об отправке');
  String get noteTitle => _t('Izoh', 'Note', 'Примечание');
  String get commentsTitle => _t('Izohlar', 'Comments', 'Комментарии');
  String get openDiscussionAction =>
      _t('Muhokamani ochish', 'Open discussion', 'Открыть обсуждение');
  String get responseTitle => _t('Javob', 'Response', 'Ответ');
  String get rejectTitle => _t('Rad etish', 'Reject', 'Отклонить');
  String get partialAcceptTitle =>
      _t('Qisman qabul', 'Partial acceptance', 'Частичное принятие');
  String get partialAcceptAction =>
      _t('Qisman qabul qilish', 'Accept partially', 'Принять частично');
  String get reportIssueTitle =>
      _t('Muammo bildirish', 'Report issue', 'Сообщить о проблеме');
  String get reportIssueAction =>
      _t('Muammo bildirish', 'Report issue', 'Сообщить о проблеме');
  String get reasonLabel => _t('Sabab', 'Reason', 'Причина');
  String get returningQtyLabel => _t(
        'Qaytarilayotgan miqdor',
        'Returning quantity',
        'Возвращаемое количество',
      );
  String get returnedQtyLabel =>
      _t('Qaytarilgan miqdor', 'Returned quantity', 'Возвращаемое количество');
  String get rejectReasonRequired => _t(
        'Sabab tanlang yoki kamida 3 harf izoh yozing',
        'Select a reason or enter at least 3 characters',
        'Выберите причину или введите минимум 3 символа',
      );
  String get rejectReasonDefective => _t('Yaroqsiz', 'Defective', 'Брак');
  String get rejectReasonWrongItem =>
      _t('Noto‘g‘ri mahsulot', 'Wrong item', 'Неверный товар');
  String get rejectReasonQtyMismatch =>
      _t('Miqdor noto‘g‘ri', 'Quantity mismatch', 'Неверное количество');
  String get extraCommentLabel => _t('Izoh', 'Comment', 'Комментарий');
  String get optionalReasonHint =>
      _t('Sabab (ixtiyoriy)', 'Reason (optional)', 'Причина (необязательно)');
  String get confirmQuestion => _t(
        'Haqiqatan ham tasdiqlaysizmi?',
        'Are you sure you want to confirm?',
        'Вы уверены, что хотите подтвердить?',
      );
  String responseSendFailed(Object error) => _t(
        'Javob yuborilmadi: $error',
        'Response was not sent: $error',
        'Ответ не был отправлен: $error',
      );
  String get approveAction => _t('Tasdiqlayman', 'Approve', 'Подтверждаю');
  String get rejectAction => _t('Rad etaman', 'Reject', 'Отклоняю');
  String get sending => _t('Yuborilmoqda...', 'Sending...', 'Отправка...');
  String get approvedLabel => _t('Tasdiqlandi', 'Approved', 'Подтверждено');
  String get rejectedStatusLabel => _t('Rad etildi', 'Rejected', 'Отклонено');

  static const Map<String, Map<String, String>> _productionTranslations = {
    'worker.daily': {
      'uz': 'Kunlik ish',
      'en': 'Daily work',
      'ru': 'Ежедневная работа',
    },
    'worker.paddons': {
      'uz': 'Paddonlar',
      'en': 'Paddons',
      'ru': 'Паддоны',
    },
    'worker.instructions': {
      'uz': 'App yo‘riqnomasi',
      'en': 'App guide',
      'ru': 'Инструкция по приложению',
    },
    'worker.transfer': {
      'uz': 'Joylashtirish va transfer',
      'en': 'Placement and transfer',
      'ru': 'Размещение и передача',
    },
    'worker.actions': {
      'uz': 'Amallar',
      'en': 'Actions',
      'ru': 'Действия',
    },
    'worker.queue.search.open': {
      'uz': 'Ochilgan zakaz qidirish',
      'en': 'Search open orders',
      'ru': 'Поиск открытых заказов',
    },
    'worker.queue.search.sequence': {
      'uz': 'Ketma-ketlikdan zakaz qidirish',
      'en': 'Search orders in sequence',
      'ru': 'Поиск заказов в последовательности',
    },
    'worker.queue.tab.completed': {
      'uz': 'Tugallangan',
      'en': 'Completed',
      'ru': 'Завершенные',
    },
    'worker.queue.empty.apparatus': {
      'uz': 'Aparatlar topilmadi',
      'en': 'No machines found',
      'ru': 'Оборудование не найдено',
    },
    'worker.queue.your.apparatus': {
      'uz': 'Sizning aparatingiz',
      'en': 'Your machine',
      'ru': 'Ваш аппарат',
    },
    'worker.queue.empty.orders': {
      'uz': '{apparatus} uchun zakaz yo‘q',
      'en': 'No orders for {apparatus}',
      'ru': 'Нет заказов для аппарата «{apparatus}»',
    },
    'worker.queue.completed.heading': {
      'uz': 'Ish yakunlari',
      'en': 'Completed work',
      'ru': 'Завершенные работы',
    },
    'worker.queue.completed.empty': {
      'uz': 'Yakunlangan ishlar yo‘q',
      'en': 'No completed work',
      'ru': 'Завершенных работ нет',
    },
    'worker.queue.status.in_progress': {
      'uz': 'Jarayonda',
      'en': 'In progress',
      'ru': 'В процессе',
    },
    'worker.queue.status.paused': {
      'uz': 'Pauzada',
      'en': 'Paused',
      'ru': 'На паузе',
    },
    'worker.queue.status.completed': {
      'uz': 'Tugallangan',
      'en': 'Completed',
      'ru': 'Завершено',
    },
    'worker.queue.status.frozen': {
      'uz': 'Muzlatilgan',
      'en': 'Frozen',
      'ru': 'Заморожено',
    },
    'worker.queue.status.pending': {
      'uz': 'Navbatda',
      'en': 'Queued',
      'ru': 'В очереди',
    },
    'worker.queue.status.completed_partial': {
      'uz': 'Tugallanmoqda',
      'en': 'Partially completed',
      'ru': 'Частично завершено',
    },
    'worker.finish.title': {
      'uz': 'Ishimni tugatish',
      'en': 'Report work output',
      'ru': 'Отчитаться о выполненной работе',
    },
    'worker.finish.description': {
      'uz':
          'Bu amal faqat order astatkasini qayd qiladi. Pauza ham, Tugatish ham bosilmaydi; queue va WIP holati o‘zgarmaydi.',
      'en':
          'This only records the order remainder. It does not pause or complete the order, and the queue and WIP status stay unchanged.',
      'ru':
          'Это только фиксирует остаток по заказу. Заказ не ставится на паузу и не завершается, а состояние очереди и WIP не меняется.',
    },
    'worker.handoff.title': {
      'uz': 'Apparatdagi rulon',
      'en': 'Roll on the machine',
      'ru': 'Рулон на аппарате',
    },
    'worker.handoff.description': {
      'uz':
          'Hozir apparatda rulon bor, u oxirigacha urilmagan. Uni davom ettirish yoki apparatdan yechib, metraj va kg bilan qayd qilish mumkin.',
      'en':
          'A roll is currently on the machine and has not been fully processed. You can continue it or remove it and record its length and weight.',
      'ru':
          'На аппарате сейчас находится не полностью обработанный рулон. Его можно продолжить или снять, указав метраж и вес.',
    },
    'worker.handoff.continue': {
      'uz': 'Davom ettirish',
      'en': 'Continue',
      'ru': 'Продолжить',
    },
    'worker.handoff.detach': {
      'uz': 'Rulonni yechish',
      'en': 'Remove roll',
      'ru': 'Снять рулон',
    },
    'worker.action.start': {
      'uz': 'Boshlash',
      'en': 'Start',
      'ru': 'Начать',
    },
    'worker.action.pause': {
      'uz': 'Pauza',
      'en': 'Pause',
      'ru': 'Пауза',
    },
    'worker.action.detach_roll': {
      'uz': 'Rulonni yechish',
      'en': 'Remove roll',
      'ru': 'Снять рулон',
    },
    'worker.freeze.safe_stop.action': {
      'uz': 'Rulonni yechib muzlatish',
      'en': 'Remove roll and freeze',
      'ru': 'Снять рулон и заморозить',
    },
    'worker.action.resume': {
      'uz': 'Davom ettirish',
      'en': 'Resume',
      'ru': 'Продолжить',
    },
    'worker.action.roll_complete': {
      'uz': 'Rulonni tugatish',
      'en': 'Finish roll',
      'ru': 'Завершить рулон',
    },
    'worker.action.complete': {
      'uz': 'Tugatish',
      'en': 'Complete job',
      'ru': 'Завершить',
    },
    'worker.action.report': {
      'uz': 'Ishimni tugatish',
      'en': 'Report work output',
      'ru': 'Отчитаться о работе',
    },
    'worker.action.view_map': {
      'uz': 'Mapni ko‘rish',
      'en': 'View map',
      'ru': 'Открыть карту',
    },
    'worker.action.back_to_order': {
      'uz': 'Orderga qaytish',
      'en': 'Back to order',
      'ru': 'Вернуться к заказу',
    },
    'worker.action.close_scanner': {
      'uz': 'Scannerni yopish',
      'en': 'Close scanner',
      'ru': 'Закрыть сканер',
    },
    'worker.action.receive_material': {
      'uz': 'Yana homashyo olish',
      'en': 'Receive more material',
      'ru': 'Принять еще сырье',
    },
    'worker.action.scan_material': {
      'uz': 'Homashyo QR scan',
      'en': 'Scan material QR',
      'ru': 'Сканировать QR сырья',
    },
    'worker.action.material_confirmed': {
      'uz': 'Homashyolar tasdiqlandi',
      'en': 'Materials confirmed',
      'ru': 'Сырье подтверждено',
    },
    'worker.action.scan_mold': {
      'uz': 'Qolip QR scan',
      'en': 'Scan mold QR',
      'ru': 'Сканировать QR формы',
    },
    'worker.action.scan_more_molds': {
      'uz': 'Yana qolip scan qilish ({progress})',
      'en': 'Scan more molds ({progress})',
      'ru': 'Сканировать еще формы ({progress})',
    },
    'worker.action.scan_again': {
      'uz': 'Qayta scan',
      'en': 'Scan again',
      'ru': 'Сканировать снова',
    },
    'worker.action.scan': {
      'uz': 'QR scan qilish',
      'en': 'Scan QR',
      'ru': 'Сканировать',
    },
    'worker.action.cancel': {
      'uz': 'Bekor qilish',
      'en': 'Cancel',
      'ru': 'Отмена',
    },
    'worker.action.confirm': {
      'uz': 'Tasdiqlash',
      'en': 'Confirm',
      'ru': 'Подтвердить',
    },
    'worker.action.close': {
      'uz': 'Yopish',
      'en': 'Close',
      'ru': 'Закрыть',
    },
    'worker.action.retry': {
      'uz': 'Qayta urinish',
      'en': 'Retry',
      'ru': 'Повторить',
    },
    'worker.scanner.prompt': {
      'uz': 'Qolip yoki homashyo QR kodini tirqishga olib keling',
      'en': 'Present a mold or material QR code to the scanner',
      'ru': 'Поднесите QR-код формы или сырья к сканеру',
    },
    'worker.scanner.manual.hide': {
      'uz': 'Barcode maydonini yopish',
      'en': 'Hide barcode field',
      'ru': 'Скрыть поле штрихкода',
    },
    'worker.scanner.manual.show': {
      'uz': 'Barcode kiritish',
      'en': 'Enter barcode',
      'ru': 'Ввести штрихкод',
    },
    'worker.scanner.manual.label': {
      'uz': 'QR / barcode',
      'en': 'QR / barcode',
      'ru': 'QR / штрихкод',
    },
    'worker.scanner.accept': {
      'uz': 'Qabul qilish',
      'en': 'Accept',
      'ru': 'Принять',
    },
    'worker.scanner.unavailable': {
      'uz': 'Kamera ochilmadi. Quyidagi maydonga QR yoki barcode kiriting.',
      'en': 'The camera could not be opened. Enter a QR code or barcode below.',
      'ru': 'Камера не открылась. Введите QR-код или штрихкод ниже.',
    },
    'worker.scanner.guide': {
      'uz': 'QR kodni shu to‘r ichiga olib keling',
      'en': 'Bring the QR code inside the frame',
      'ru': 'Поместите QR-код внутрь рамки',
    },
    'worker.scanner.progress_prompt': {
      'uz': 'Progress QR kodini ramkaga olib keling',
      'en': 'Place the progress QR code inside the frame',
      'ru': 'Поместите QR-код прогресса в рамку',
    },
    'worker.scanner.manual.title': {
      'uz': 'QR ni qo‘lda kiritish',
      'en': 'Enter QR code manually',
      'ru': 'Ввести QR-код вручную',
    },
    'worker.scanner.manual.verify': {
      'uz': 'Tekshirish',
      'en': 'Verify',
      'ru': 'Проверить',
    },
    'worker.scanner.manual.payload': {
      'uz': 'QR payload',
      'en': 'QR payload',
      'ru': 'QR payload',
    },
    'worker.scanner.camera_failed': {
      'uz': 'Kamera ochilmadi',
      'en': 'The camera could not be opened',
      'ru': 'Не удалось открыть камеру',
    },
    'worker.scanner.camera_permission': {
      'uz': 'Kamera ochilmadi. Ruxsatlarni tekshiring.',
      'en': 'The camera could not be opened. Check camera permissions.',
      'ru': 'Камера не открылась. Проверьте разрешения.',
    },
    'worker.scanner.invalid_qr': {
      'uz': 'QR bo‘sh yoki noto‘g‘ri',
      'en': 'The QR code is empty or invalid',
      'ru': 'QR-код пустой или недействительный',
    },
    'worker.scanner.lookup': {
      'uz': 'Order oqimi yig‘ilmoqda...',
      'en': 'Loading the order flow...',
      'ru': 'Загрузка потока заказа...',
    },
    'worker.scanner.report_ready': {
      'uz': 'Hisobot tayyor',
      'en': 'Report ready',
      'ru': 'Отчет готов',
    },
    'worker.scanner.paddon_ready': {
      'uz': 'Paddon hisoboti tayyor',
      'en': 'Paddon report ready',
      'ru': 'Отчет по паддону готов',
    },
    'worker.scanner.material_ready': {
      'uz': 'Homashyo hisoboti tayyor',
      'en': 'Material report ready',
      'ru': 'Отчет по сырью готов',
    },
    'worker.scanner.report_failed': {
      'uz': 'QR hisoboti olinmadi',
      'en': 'The QR report could not be loaded',
      'ru': 'Не удалось загрузить отчет по QR-коду',
    },
    'worker.scanner.pdf_error': {
      'uz': 'PDF tayyorlash yoki ulashishda xatolik',
      'en': 'The PDF could not be prepared or shared',
      'ru': 'Не удалось подготовить или отправить PDF',
    },
    'worker.scanner.scan_again': {
      'uz': 'Yana scan qilish',
      'en': 'Scan another code',
      'ru': 'Сканировать другой код',
    },
    'worker.scanner.back': {
      'uz': 'Orqaga',
      'en': 'Back',
      'ru': 'Назад',
    },
    'worker.scanner.unsupported': {
      'uz': 'Bu qurilmada kamera orqali QR scan qo‘llab-quvvatlanmaydi.',
      'en': 'Camera-based QR scanning is not supported on this device.',
      'ru':
          'Сканирование QR через камеру не поддерживается на этом устройстве.',
    },
    'worker.scanner.pdf_preparing': {
      'uz': 'PDF tayyorlanmoqda...',
      'en': 'Preparing PDF...',
      'ru': 'Подготовка PDF...',
    },
    'worker.scanner.share_pdf': {
      'uz': 'PDF ulashish',
      'en': 'Share PDF',
      'ru': 'Поделиться PDF',
    },
    'worker.qr.report.stale': {
      'uz': 'Bu eski QR. Hozirgi holat quyida.',
      'en': 'This is an old QR code. The current status is shown below.',
      'ru': 'Это старый QR-код. Текущий статус указан ниже.',
    },
    'worker.qr.report.current': {
      'uz': 'QR hozirgi oqimga mos.',
      'en': 'This QR code matches the current flow.',
      'ru': 'QR-код соответствует текущему потоку.',
    },
    'worker.qr.report.product_passport': {
      'uz': 'Mahsulot pasporti',
      'en': 'Product passport',
      'ru': 'Паспорт продукта',
    },
    'worker.qr.report.product_status': {
      'uz': 'Mahsulot holati',
      'en': 'Product status',
      'ru': 'Статус продукта',
    },
    'worker.qr.report.old_qr_notice': {
      'uz':
          'Skan qilingan QR oldingi bosqichniki. Quyida mahsulotning hozirgi holati berilgan.',
      'en':
          'The scanned QR code belongs to an earlier stage. The product’s current status is shown below.',
      'ru':
          'Отсканированный QR-код относится к предыдущему этапу. Ниже указан текущий статус продукта.',
    },
    'worker.qr.report.correction_item': {
      'uz': 'Tahrir {index}: {stage}',
      'en': 'Correction {index}: {stage}',
      'ru': 'Исправление {index}: {stage}',
    },
    'worker.qr.report.issue_item': {
      'uz': 'Muammo yoki o‘zgarish {index}',
      'en': 'Issue or change {index}',
      'ru': 'Проблема или изменение {index}',
    },
    'worker.qr.report.stage': {
      'uz': 'Bosqich',
      'en': 'Stage',
      'ru': 'Этап',
    },
    'worker.qr.report.details': {
      'uz': 'Tafsilot',
      'en': 'Details',
      'ru': 'Подробности',
    },
    'worker.qr.report.material_pdf_title': {
      'uz': 'Admin homashyo QR hisoboti',
      'en': 'Admin raw material QR report',
      'ru': 'Отчет администратора по QR сырья',
    },
    'worker.qr.report.assignment_section': {
      'uz': 'Orderga biriktirish',
      'en': 'Order assignment',
      'ru': 'Назначение заказа',
    },
    'worker.qr.report.event': {
      'uz': 'Jarayon hodisasi',
      'en': 'Process event',
      'ru': 'Событие процесса',
    },
    'worker.qr.report.event_count': {
      'uz': 'Jarayon hodisasi {index}/{count}',
      'en': 'Process event {index}/{count}',
      'ru': 'Событие процесса {index}/{count}',
    },
    'worker.qr.report.event_id': {
      'uz': 'Hodisa ID',
      'en': 'Event ID',
      'ru': 'ID события',
    },
    'worker.qr.report.order_id': {
      'uz': 'Order ID',
      'en': 'Order ID',
      'ru': 'ID заказа',
    },
    'worker.qr.report.action': {
      'uz': 'Harakat',
      'en': 'Action',
      'ru': 'Действие',
    },
    'worker.qr.report.state_change': {
      'uz': 'Holat o‘zgarishi',
      'en': 'Status change',
      'ru': 'Изменение статуса',
    },
    'worker.qr.report.actor_role': {
      'uz': 'Ijrochi roli',
      'en': 'Actor role',
      'ru': 'Роль исполнителя',
    },
    'worker.qr.report.actor_ref': {
      'uz': 'Ijrochi IDsi',
      'en': 'Actor reference',
      'ru': 'ID исполнителя',
    },
    'worker.qr.report.actor_name': {
      'uz': 'Ijrochi',
      'en': 'Actor',
      'ru': 'Исполнитель',
    },
    'worker.qr.report.completed_with_issue': {
      'uz': 'Muammo bilan tugagan',
      'en': 'Completed with an issue',
      'ru': 'Завершено с проблемой',
    },
    'worker.qr.report.issue_note': {
      'uz': 'Muammo izohi',
      'en': 'Issue note',
      'ru': 'Описание проблемы',
    },
    'worker.qr.report.transfer_details': {
      'uz': 'Apparat almashtirish ma’lumotlari',
      'en': 'Machine transfer details',
      'ru': 'Данные о перемещении между аппаратами',
    },
    'worker.qr.report.from': {
      'uz': 'Qayerdan',
      'en': 'From',
      'ru': 'Откуда',
    },
    'worker.qr.report.to': {
      'uz': 'Qayerga',
      'en': 'To',
      'ru': 'Куда',
    },
    'worker.qr.report.freeze_details': {
      'uz': 'Muzlatish ma’lumotlari',
      'en': 'Freeze details',
      'ru': 'Данные о заморозке',
    },
    'worker.qr.report.transfer_id': {
      'uz': 'Transfer ID',
      'en': 'Transfer ID',
      'ru': 'ID перемещения',
    },
    'worker.qr.report.session_id': {
      'uz': 'Session ID',
      'en': 'Session ID',
      'ru': 'ID сессии',
    },
    'worker.qr.report.progress_batch_id': {
      'uz': 'Progress batch ID',
      'en': 'Progress batch ID',
      'ru': 'ID партии прогресса',
    },
    'worker.qr.report.material_barcodes': {
      'uz': 'Homashyo barcode’lari',
      'en': 'Material barcodes',
      'ru': 'Штрихкоды сырья',
    },
    'worker.qr.report.request_id': {
      'uz': 'Request ID',
      'en': 'Request ID',
      'ru': 'ID запроса',
    },
    'worker.qr.report.freeze_status': {
      'uz': 'Muzlatish holati',
      'en': 'Freeze status',
      'ru': 'Статус заморозки',
    },
    'worker.qr.report.target_session': {
      'uz': 'Maqsad session',
      'en': 'Target session',
      'ru': 'Целевая сессия',
    },
    'worker.qr.report.target_apparatus': {
      'uz': 'Maqsad aparat',
      'en': 'Target machine',
      'ru': 'Целевой аппарат',
    },
    'worker.qr.report.target_worker_role': {
      'uz': 'Maqsad ishchi roli',
      'en': 'Target worker role',
      'ru': 'Роль целевого работника',
    },
    'worker.qr.report.target_worker_ref': {
      'uz': 'Maqsad ishchi IDsi',
      'en': 'Target worker reference',
      'ru': 'ID целевого работника',
    },
    'worker.qr.report.target_worker_name': {
      'uz': 'Maqsad ishchi',
      'en': 'Target worker',
      'ru': 'Целевой работник',
    },
    'worker.qr.report.requested_at': {
      'uz': 'So‘ralgan vaqt',
      'en': 'Requested at',
      'ru': 'Время запроса',
    },
    'worker.qr.report.transitioned_at': {
      'uz': 'O‘tkazilgan vaqt',
      'en': 'Transitioned at',
      'ru': 'Время перехода',
    },
    'worker.qr.report.continued': {
      'uz': 'davomi',
      'en': 'continued',
      'ru': 'продолжение',
    },
    'worker.qr.report.material_title': {
      'uz': 'Bu homashyo QR.',
      'en': 'This is a raw material QR code.',
      'ru': 'Это QR-код сырья.',
    },
    'worker.qr.report.paddon_title': {
      'uz': 'Paddon QR',
      'en': 'Paddon QR code',
      'ru': 'QR-код паддона',
    },
    'worker.qr.report.paddon_count': {
      'uz': '{count} ta WIP shu package ichida',
      'en': '{count} WIP(s) in this package',
      'ru': 'WIP в этом пакете: {count}',
    },
    'worker.qr.report.location': {
      'uz': 'Joylashuv',
      'en': 'Location',
      'ru': 'Расположение',
    },
    'worker.qr.report.note': {
      'uz': 'Izoh',
      'en': 'Note',
      'ru': 'Примечание',
    },
    'worker.qr.report.paddon_wips': {
      'uz': 'Paddon ichidagi WIP lar ({count})',
      'en': 'WIPs in the paddon ({count})',
      'ru': 'WIP в паддоне ({count})',
    },
    'worker.qr.report.paddon_empty': {
      'uz': 'Bu package ichida hozircha WIP yo‘q.',
      'en': 'There are no WIPs in this package yet.',
      'ru': 'В этом пакете пока нет WIP.',
    },
    'worker.qr.report.order': {
      'uz': 'Zakaz',
      'en': 'Order',
      'ru': 'Заказ',
    },
    'worker.qr.report.epc': {
      'uz': 'EPC / QR',
      'en': 'EPC / QR',
      'ru': 'EPC / QR',
    },
    'worker.qr.report.batch_id': {
      'uz': 'Batch ID',
      'en': 'Batch ID',
      'ru': 'ID партии',
    },
    'worker.qr.report.status': {
      'uz': 'Holati',
      'en': 'Status',
      'ru': 'Статус',
    },
    'worker.qr.report.share_plan': {
      'uz': 'Buyurtma rejasi',
      'en': 'Order plan',
      'ru': 'План заказа',
    },
    'worker.qr.report.stages': {
      'uz': 'Ishlab chiqarish bosqichlari',
      'en': 'Production stages',
      'ru': 'Этапы производства',
    },
    'worker.qr.report.current_label': {
      'uz': 'Hozirgi',
      'en': 'Current',
      'ru': 'Текущий',
    },
    'worker.qr.report.corrections': {
      'uz': 'Tahrirlar',
      'en': 'Corrections',
      'ru': 'Исправления',
    },
    'worker.qr.report.issues': {
      'uz': 'Muammolar va o‘zgarishlar',
      'en': 'Issues and changes',
      'ru': 'Проблемы и изменения',
    },
    'worker.qr.report.product_order': {
      'uz': 'Mahsulot va buyurtma',
      'en': 'Product and order',
      'ru': 'Продукт и заказ',
    },
    'worker.qr.report.order_number': {
      'uz': 'Buyurtma raqami',
      'en': 'Order number',
      'ru': 'Номер заказа',
    },
    'worker.qr.report.product': {
      'uz': 'Mahsulot',
      'en': 'Product',
      'ru': 'Продукт',
    },
    'worker.qr.report.product_code': {
      'uz': 'Mahsulot kodi',
      'en': 'Product code',
      'ru': 'Код продукта',
    },
    'worker.qr.report.customer': {
      'uz': 'Mijoz',
      'en': 'Customer',
      'ru': 'Клиент',
    },
    'worker.qr.report.roll_count': {
      'uz': 'Rulon soni',
      'en': 'Roll count',
      'ru': 'Количество рулонов',
    },
    'worker.qr.report.width': {
      'uz': 'Eni, mm',
      'en': 'Width, mm',
      'ru': 'Ширина, мм',
    },
    'worker.qr.report.planned_weight': {
      'uz': 'Rejadagi og‘irlik, kg',
      'en': 'Planned weight, kg',
      'ru': 'Плановый вес, кг',
    },
    'worker.qr.report.planned_length': {
      'uz': 'Rejadagi uzunlik',
      'en': 'Planned length',
      'ru': 'Плановая длина',
    },
    'worker.qr.report.queue_status': {
      'uz': 'Aparat navbatlarining holati',
      'en': 'Machine queue status',
      'ru': 'Состояние очередей аппаратов',
    },
    'worker.qr.report.material_about': {
      'uz': 'Homashyo haqida',
      'en': 'About the raw material',
      'ru': 'О сырье',
    },
    'worker.qr.report.material_status': {
      'uz': 'Homashyo holati',
      'en': 'Raw material status',
      'ru': 'Состояние сырья',
    },
    'worker.qr.report.where_used': {
      'uz': 'Qayerga ishlatiladi',
      'en': 'Where it is used',
      'ru': 'Где используется',
    },
    'worker.qr.report.technical': {
      'uz': 'Texnik homashyo ma’lumotlari',
      'en': 'Technical raw material data',
      'ru': 'Технические данные сырья',
    },
    'worker.qr.report.barcode': {
      'uz': 'QR / barcode',
      'en': 'QR / barcode',
      'ru': 'QR / штрихкод',
    },
    'worker.qr.report.warehouse': {
      'uz': 'Ombor',
      'en': 'Warehouse',
      'ru': 'Склад',
    },
    'worker.qr.report.item_code': {
      'uz': 'Item kodi',
      'en': 'Item code',
      'ru': 'Код позиции',
    },
    'worker.qr.report.item_name': {
      'uz': 'Item nomi',
      'en': 'Item name',
      'ru': 'Название позиции',
    },
    'worker.qr.report.item_group': {
      'uz': 'Item guruhi',
      'en': 'Item group',
      'ru': 'Группа позиции',
    },
    'worker.qr.report.receipt': {
      'uz': 'Kirim hujjati',
      'en': 'Receipt',
      'ru': 'Приходный документ',
    },
    'worker.qr.report.reserved_order': {
      'uz': 'Band qilingan buyurtma',
      'en': 'Reserved order',
      'ru': 'Зарезервированный заказ',
    },
    'worker.qr.report.assigned_order': {
      'uz': 'Biriktirilgan buyurtma',
      'en': 'Assigned order',
      'ru': 'Назначенный заказ',
    },
    'worker.qr.report.assigned_machine': {
      'uz': 'Biriktirilgan aparat',
      'en': 'Assigned machine',
      'ru': 'Назначенный аппарат',
    },
    'worker.qr.report.assigned_by_ref': {
      'uz': 'Biriktirgan xodim IDsi',
      'en': 'Assigner reference',
      'ru': 'ID назначившего',
    },
    'worker.qr.report.assigned_by_name': {
      'uz': 'Biriktirgan xodim',
      'en': 'Assigned by',
      'ru': 'Назначил',
    },
    'worker.qr.report.assigned_at': {
      'uz': 'Biriktirilgan vaqt',
      'en': 'Assigned at',
      'ru': 'Время назначения',
    },
    'worker.qr.report.stock_status': {
      'uz': 'Ombor holati',
      'en': 'Stock status',
      'ru': 'Состояние запасов',
    },
    'worker.qr.report.stock_warehouse': {
      'uz': 'Ombor nomi',
      'en': 'Stock warehouse',
      'ru': 'Склад запасов',
    },
    'worker.qr.report.stock_quantity': {
      'uz': 'Ombordagi miqdor',
      'en': 'Stock quantity',
      'ru': 'Количество на складе',
    },
    'worker.qr.report.received_quantity': {
      'uz': 'Qabul qilingan miqdor',
      'en': 'Received quantity',
      'ru': 'Принятое количество',
    },
    'worker.qr.report.consumed_quantity': {
      'uz': 'Ishlatilgan miqdor',
      'en': 'Consumed quantity',
      'ru': 'Израсходованное количество',
    },
    'worker.qr.report.remaining_quantity': {
      'uz': 'Qolgan miqdor',
      'en': 'Remaining quantity',
      'ru': 'Оставшееся количество',
    },
    'worker.qr.report.history': {
      'uz': 'Mahsulot tarixi',
      'en': 'Product history',
      'ru': 'История продукта',
    },
    'worker.qr.report.editor': {
      'uz': 'Tahrir qilgan',
      'en': 'Edited by',
      'ru': 'Изменил',
    },
    'worker.qr.report.time': {
      'uz': 'Vaqt',
      'en': 'Time',
      'ru': 'Время',
    },
    'worker.qr.report.reason': {
      'uz': 'Sabab',
      'en': 'Reason',
      'ru': 'Причина',
    },
    'worker.qr.report.transfer_reason': {
      'uz': 'O‘tkazish sababi',
      'en': 'Transfer reason',
      'ru': 'Причина перемещения',
    },
    'worker.qr.report.completed_note': {
      'uz': 'Izoh',
      'en': 'Note',
      'ru': 'Примечание',
    },
    'worker.qr.report.not_entered': {
      'uz': 'kiritilmagan',
      'en': 'not entered',
      'ru': 'не указано',
    },
    'worker.qr.passport.planned_rolls': {
      'uz': 'Rejadagi rulonlar',
      'en': 'Planned rolls',
      'ru': 'Плановые рулоны',
    },
    'worker.qr.passport.product_width': {
      'uz': 'Mahsulot eni',
      'en': 'Product width',
      'ru': 'Ширина продукта',
    },
    'worker.qr.passport.planned_length': {
      'uz': 'Rejadagi metraj',
      'en': 'Planned length',
      'ru': 'Плановая длина',
    },
    'worker.qr.passport.production_stage': {
      'uz': 'Ishlab chiqarish bosqichi',
      'en': 'Production stage',
      'ru': 'Этап производства',
    },
    'worker.qr.passport.roll_complete': {
      'uz': 'rulon yakuni',
      'en': 'roll completed',
      'ru': 'завершение рулона',
    },
    'worker.qr.passport.result': {
      'uz': 'Natija',
      'en': 'Output',
      'ru': 'Результат',
    },
    'worker.qr.passport.returned_ink': {
      'uz': 'Qaytgan bo‘yoq',
      'en': 'Returned ink',
      'ru': 'Возвращенная краска',
    },
    'worker.qr.passport.returned_print_rolls': {
      'uz': 'Qaytgan bosma rulon',
      'en': 'Returned printed rolls',
      'ru': 'Возвращенные печатные рулоны',
    },
    'worker.qr.passport.returned_film_rolls': {
      'uz': 'Qaytgan plyonka rulon',
      'en': 'Returned film rolls',
      'ru': 'Возвращенные рулоны пленки',
    },
    'worker.qr.passport.print_waste': {
      'uz': 'Bosma chiqindisi',
      'en': 'Printing waste',
      'ru': 'Отходы печати',
    },
    'worker.qr.passport.lamination_waste': {
      'uz': 'Laminatsiya chiqindisi',
      'en': 'Lamination waste',
      'ru': 'Отходы ламинации',
    },
    'worker.qr.passport.edge_waste': {
      'uz': 'Chet chiqindisi',
      'en': 'Edge waste',
      'ru': 'Кромочные отходы',
    },
    'worker.qr.passport.bobbin_weight': {
      'uz': 'Bobina og‘irligi',
      'en': 'Bobbin weight',
      'ru': 'Вес бобины',
    },
    'worker.qr.passport.finished_length': {
      'uz': 'Tayyor mahsulot metraji',
      'en': 'Finished product length',
      'ru': 'Длина готового продукта',
    },
    'worker.qr.passport.produced_quantity': {
      'uz': 'Ishlab chiqarilgan miqdor',
      'en': 'Produced quantity',
      'ru': 'Произведенное количество',
    },
    'worker.qr.passport.unit': {
      'uz': 'O‘lchov birligi',
      'en': 'Unit of measure',
      'ru': 'Единица измерения',
    },
    'worker.qr.passport.finished_weight': {
      'uz': 'Tayyor mahsulot og‘irligi',
      'en': 'Finished product weight',
      'ru': 'Вес готового продукта',
    },
    'worker.qr.passport.production_data': {
      'uz': 'Ishlab chiqarish ma’lumoti',
      'en': 'Production data',
      'ru': 'Производственные данные',
    },
    'worker.qr.passport.reason_missing': {
      'uz': 'Sabab ko‘rsatilmagan',
      'en': 'No reason provided',
      'ru': 'Причина не указана',
    },
    'worker.qr.passport.production': {
      'uz': 'Ishlab chiqarish',
      'en': 'Production',
      'ru': 'Производство',
    },
    'worker.qr.passport.status_missing': {
      'uz': 'Holat ko‘rsatilmagan',
      'en': 'Status unavailable',
      'ru': 'Статус не указан',
    },
    'worker.qr.material.unassigned': {
      'uz':
          'Bu homashyo hali hech qaysi orderga ulanmagan. Uni scan qilgan odam hozircha faqat ombordagi homashyo ma’lumotini ko‘radi.',
      'en':
          'This material is not assigned to any order yet. Scanning it currently shows only its warehouse information.',
      'ru':
          'Это сырье пока не привязано ни к одному заказу. При сканировании пока отображается только складская информация.',
    },
    'worker.qr.material.scanned': {
      'uz': '{name} homashyosi scan qilindi.',
      'en': '{name} material was scanned.',
      'ru': 'Сырье «{name}» отсканировано.',
    },
    'worker.qr.material.recorded': {
      'uz': '{name} {quantity} miqdorda qayd qilingan.',
      'en': '{name} recorded quantity: {quantity}.',
      'ru': '{name}, количество: {quantity}.',
    },
    'worker.qr.material.group': {
      'uz': 'Bu homashyo {group} guruhiga kiradi.',
      'en': 'This material belongs to the {group} group.',
      'ru': 'Это сырье относится к группе «{group}».',
    },
    'worker.qr.material.warehouse': {
      'uz': 'Hozirgi ombor: {warehouse}.',
      'en': 'Current warehouse: {warehouse}.',
      'ru': 'Текущий склад: {warehouse}.',
    },
    'worker.qr.material.quantity': {
      'uz': 'Miqdori: {quantity}.',
      'en': 'Quantity: {quantity}.',
      'ru': 'Количество: {quantity}.',
    },
    'worker.qr.material.assigned_order': {
      'uz': 'Bu homashyo {order} orderiga ulangan.',
      'en': 'This material is assigned to order {order}.',
      'ru': 'Это сырье привязано к заказу {order}.',
    },
    'worker.qr.material.assigned_order_number': {
      'uz': 'Bu homashyo Zakaz {number} bo‘yicha {order} orderiga ulangan.',
      'en':
          'This material is assigned to order {order} under order number {number}.',
      'ru': 'Это сырье привязано к заказу {order}, номер заказа: {number}.',
    },
    'worker.qr.material.assigned_apparatus': {
      'uz': 'Homashyo {apparatus} aparatida ishlatiladi.',
      'en': 'The material is used on the {apparatus} machine.',
      'ru': 'Сырье используется на аппарате «{apparatus}».',
    },
    'worker.qr.material.queue_state': {
      'uz': 'Orderning shu aparatdagi holati: {state}.',
      'en': 'The order status on this machine is: {state}.',
      'ru': 'Статус заказа на этом аппарате: {state}.',
    },
    'worker.qr.material.assigned_by': {
      'uz': '{name} tomonidan ulangan.',
      'en': 'Assigned by {name}.',
      'ru': 'Назначил: {name}.',
    },
    'worker.qr.material.assigned_at': {
      'uz': 'Ulangan vaqt: {time}.',
      'en': 'Assigned at: {time}.',
      'ru': 'Время назначения: {time}.',
    },
    'worker.qr.material.status_available': {
      'uz': 'Bu homashyo omborda mavjud.',
      'en': 'This material is available in the warehouse.',
      'ru': 'Это сырье есть на складе.',
    },
    'worker.qr.material.status_in_use': {
      'uz': 'Bu homashyo ishlab chiqarishda ishlatilmoqda.',
      'en': 'This material is currently in use in production.',
      'ru': 'Это сырье сейчас используется в производстве.',
    },
    'worker.qr.material.status_consumed': {
      'uz': 'Bu homashyo ishlatib bo‘lingan.',
      'en': 'This material has been consumed.',
      'ru': 'Это сырье уже израсходовано.',
    },
    'worker.qr.material.status_reserved': {
      'uz': 'Bu homashyo order uchun band qilingan.',
      'en': 'This material is reserved for an order.',
      'ru': 'Это сырье зарезервировано для заказа.',
    },
    'worker.qr.material.status_generic': {
      'uz': 'Homashyo holati: {status}.',
      'en': 'Material status: {status}.',
      'ru': 'Статус сырья: {status}.',
    },
    'worker.qr.apparatus.purpose.lamination': {
      'uz': 'U yerda mahsulot laminatsiya qilinadi.',
      'en': 'The product is laminated there.',
      'ru': 'Там выполняется ламинация продукта.',
    },
    'worker.qr.apparatus.purpose.printing': {
      'uz': 'U yerda mahsulotga pechat/bosma ishi bajariladi.',
      'en': 'Printing is performed there.',
      'ru': 'Там выполняется печать продукта.',
    },
    'worker.qr.apparatus.purpose.cutting': {
      'uz': 'U yerda mahsulot kesiladi, ya’ni rezka ishi bajariladi.',
      'en': 'The product is slit there.',
      'ru': 'Там выполняется резка продукта.',
    },
    'worker.qr.apparatus.purpose.mold': {
      'uz': 'U yerda qolip bilan bog‘liq ishlab chiqarish ishi bajariladi.',
      'en': 'Mold-related production work is performed there.',
      'ru': 'Там выполняется производственная работа с формой.',
    },
    'worker.qr.apparatus.purpose.next': {
      'uz': 'U yerda keyingi ishlab chiqarish ishi bajariladi.',
      'en': 'The next production operation is performed there.',
      'ru': 'Там выполняется следующая производственная операция.',
    },
    'worker.qr.status.completed_pending_stock': {
      'uz': 'Ishlab chiqarish tugagan, omborga topshirishni kutmoqda',
      'en':
          'Production is complete and the output is awaiting warehouse receipt',
      'ru': 'Производство завершено, выпуск ожидает передачи на склад',
    },
    'worker.qr.status.waiting_stock': {
      'uz': 'Omborga topshirishni kutmoqda',
      'en': 'Awaiting warehouse receipt',
      'ru': 'Ожидает передачи на склад',
    },
    'worker.qr.status.free_wip': {
      'uz': 'erkin WIP holatida',
      'en': 'free WIP',
      'ru': 'свободный WIP',
    },
    'worker.qr.status.accepted_stock': {
      'uz': 'Omborga qabul qilingan',
      'en': 'Accepted into warehouse stock',
      'ru': 'Принято на склад',
    },
    'worker.qr.status.waiting_next': {
      'uz': 'Keyingi bosqichni kutmoqda',
      'en': 'Waiting for the next stage',
      'ru': 'Ожидает следующего этапа',
    },
    'worker.qr.status.consumed_next': {
      'uz': 'Keyingi bosqichda ishlatilgan',
      'en': 'Used by the next stage',
      'ru': 'Использовано на следующем этапе',
    },
    'worker.qr.status.in_progress': {
      'uz': 'Ish jarayonida',
      'en': 'In production',
      'ru': 'В производстве',
    },
    'worker.qr.status.completed': {
      'uz': 'Ishi tugagan',
      'en': 'Completed',
      'ru': 'Завершено',
    },
    'worker.qr.status.paused': {
      'uz': 'Ishi vaqtincha to‘xtatilgan',
      'en': 'Paused',
      'ru': 'Приостановлено',
    },
    'worker.qr.status.roll_removed': {
      'uz': 'Rulon yechilgan',
      'en': 'Roll removed',
      'ru': 'Рулон снят',
    },
    'worker.qr.status.waiting_start': {
      'uz': 'Ish boshlanishini kutmoqda',
      'en': 'Waiting to start',
      'ru': 'Ожидает начала',
    },
    'worker.qr.status.waiting_work': {
      'uz': 'Keyingi ishni kutmoqda',
      'en': 'Waiting for the next operation',
      'ru': 'Ожидает следующей операции',
    },
    'worker.qr.status.started': {
      'uz': 'Boshlandi',
      'en': 'Started',
      'ru': 'Начато',
    },
    'worker.qr.status.resumed': {
      'uz': 'Davom etdi',
      'en': 'Resumed',
      'ru': 'Возобновлено',
    },
    'worker.qr.status.finished': {
      'uz': 'Tugadi',
      'en': 'Finished',
      'ru': 'Завершено',
    },
    'worker.qr.state.started': {
      'uz': 'ish boshlangan',
      'en': 'work has started',
      'ru': 'работа начата',
    },
    'worker.qr.state.paused': {
      'uz': 'ish vaqtincha pauzada',
      'en': 'work is paused',
      'ru': 'работа приостановлена',
    },
    'worker.qr.state.roll_removed': {
      'uz': 'rulon apparatdan yechilgan',
      'en': 'the roll has been removed from the machine',
      'ru': 'рулон снят с аппарата',
    },
    'worker.qr.state.resumed': {
      'uz': 'ish davom ettirilgan',
      'en': 'work has resumed',
      'ru': 'работа возобновлена',
    },
    'worker.qr.state.completed': {
      'uz': 'ish tugagan',
      'en': 'work is complete',
      'ru': 'работа завершена',
    },
    'worker.qr.state.waiting_start': {
      'uz': 'ish boshlanishini kutmoqda',
      'en': 'waiting for work to start',
      'ru': 'ожидает начала работы',
    },
    'worker.qr.state.in_progress': {
      'uz': 'ish jarayonida',
      'en': 'work is in progress',
      'ru': 'работа выполняется',
    },
    'worker.qr.state.stopped': {
      'uz': 'ish to‘xtatilgan',
      'en': 'work has stopped',
      'ru': 'работа остановлена',
    },
    'worker.qr.state.waiting_stock': {
      'uz': 'omborga topshirishni kutmoqda',
      'en': 'awaiting warehouse receipt',
      'ru': 'ожидает передачи на склад',
    },
    'worker.qr.state.waiting_next': {
      'uz': 'keyingi bosqichni kutmoqda',
      'en': 'waiting for the next stage',
      'ru': 'ожидает следующего этапа',
    },
    'worker.qr.state.used_next': {
      'uz': 'keyingi bosqichda ishlatilgan',
      'en': 'used by the next stage',
      'ru': 'использовано на следующем этапе',
    },
    'worker.qr.status.used': {
      'uz': 'Keyingi bosqichda ishlatilgan',
      'en': 'Used by the next stage',
      'ru': 'Использовано на следующем этапе',
    },
    'worker.qr.status.product_ready': {
      'uz': 'Tayyor mahsulot',
      'en': 'Finished product',
      'ru': 'Готовый продукт',
    },
    'worker.qr.status.semi_finished': {
      'uz': 'Yarim tayyor mahsulot',
      'en': 'Semi-finished product',
      'ru': 'Полуфабрикат',
    },
    'worker.qr.status.label': {
      'uz': '{kind} holati: {status}',
      'en': '{kind} status: {status}',
      'ru': 'Статус: {kind} — {status}',
    },
    'worker.qr.timeline.start': {
      'uz': 'Bosqichdagi ish boshlandi',
      'en': 'Stage work started',
      'ru': 'Работа на этапе начата',
    },
    'worker.qr.timeline.pause': {
      'uz': 'Bosqichdagi ish vaqtincha to‘xtatildi',
      'en': 'Stage work was paused',
      'ru': 'Работа на этапе приостановлена',
    },
    'worker.qr.timeline.detach_roll': {
      'uz': 'Bosqichdagi rulon yechildi',
      'en': 'The stage roll was removed',
      'ru': 'Рулон этапа снят',
    },
    'worker.qr.timeline.resume': {
      'uz': 'Bosqichdagi ish davom ettirildi',
      'en': 'Stage work resumed',
      'ru': 'Работа на этапе возобновлена',
    },
    'worker.qr.timeline.roll_complete': {
      'uz': 'Bitta rulon yakunlandi',
      'en': 'One roll was completed',
      'ru': 'Один рулон завершен',
    },
    'worker.qr.timeline.complete': {
      'uz': 'Bosqichdagi ish yakunlandi',
      'en': 'Stage work was completed',
      'ru': 'Работа на этапе завершена',
    },
    'worker.qr.timeline.generic': {
      'uz': 'Amal bajarildi',
      'en': 'Action performed',
      'ru': 'Действие выполнено',
    },
    'worker.qr.timeline.action.start': {
      'uz': '{actor} {apparatus} bosqichida ishni boshladi.',
      'en': '{actor} started work on the {apparatus} stage.',
      'ru': '{actor} начал работу на этапе «{apparatus}».',
    },
    'worker.qr.timeline.action.pause': {
      'uz': '{actor} {apparatus} bosqichidagi ishni vaqtincha to‘xtatdi.',
      'en': '{actor} paused work on the {apparatus} stage.',
      'ru': '{actor} приостановил работу на этапе «{apparatus}».',
    },
    'worker.qr.timeline.action.detach_roll': {
      'uz': '{actor} {apparatus} bosqichidagi rulonni yechdi.',
      'en': '{actor} removed the roll from the {apparatus} stage.',
      'ru': '{actor} снял рулон с этапа «{apparatus}».',
    },
    'worker.qr.timeline.action.resume': {
      'uz': '{actor} {apparatus} bosqichidagi ishni davom ettirdi.',
      'en': '{actor} resumed work on the {apparatus} stage.',
      'ru': '{actor} продолжил работу на этапе «{apparatus}».',
    },
    'worker.qr.timeline.action.roll_complete': {
      'uz': '{actor} {apparatus} bosqichidagi bitta rulonni yakunladi.',
      'en': '{actor} completed one roll on the {apparatus} stage.',
      'ru': '{actor} завершил один рулон на этапе «{apparatus}».',
    },
    'worker.qr.timeline.action.complete': {
      'uz': '{actor} {apparatus} bosqichidagi ishni yakunladi.',
      'en': '{actor} completed work on the {apparatus} stage.',
      'ru': '{actor} завершил работу на этапе «{apparatus}».',
    },
    'worker.qr.timeline.action.generic': {
      'uz': '{actor} {apparatus} bosqichida amal bajardi.',
      'en': '{actor} performed an action on the {apparatus} stage.',
      'ru': '{actor} выполнил действие на этапе «{apparatus}».',
    },
    'worker.qr.timeline.time': {
      'uz': 'Vaqt: {time}.',
      'en': 'Time: {time}.',
      'ru': 'Время: {time}.',
    },
    'worker.qr.reason.apparatus_issue': {
      'uz': 'Aparatdagi nosozlik',
      'en': 'Machine issue',
      'ru': 'Неисправность аппарата',
    },
    'worker.qr.reason.worker_issue': {
      'uz': 'Xodim bilan bog‘liq sabab',
      'en': 'Worker-related issue',
      'ru': 'Причина, связанная с работником',
    },
    'worker.qr.reason.material_issue': {
      'uz': 'Homashyo bilan bog‘liq sabab',
      'en': 'Material-related issue',
      'ru': 'Причина, связанная с сырьем',
    },
    'worker.qr.reason.quality_issue': {
      'uz': 'Sifat bilan bog‘liq sabab',
      'en': 'Quality issue',
      'ru': 'Проблема качества',
    },
    'worker.qr.reason.other': {
      'uz': 'Boshqa sabab',
      'en': 'Other reason',
      'ru': 'Другая причина',
    },
    'worker.material.scanner.title': {
      'uz': 'Homashyo QR',
      'en': 'Material QR',
      'ru': 'QR сырья',
    },
    'worker.material.scanner.manual': {
      'uz': 'Barcode',
      'en': 'Barcode',
      'ru': 'Штрихкод',
    },
    'worker.order.code': {
      'uz': 'Zakaz kodi',
      'en': 'Order code',
      'ru': 'Код заказа',
    },
    'worker.summary.expected.title': {
      'uz': 'Kutilayotgan buyurtma ko‘rsatkichlari',
      'en': 'Expected order metrics',
      'ru': 'Ожидаемые показатели заказа',
    },
    'worker.summary.expected.subtitle': {
      'uz': 'Buyurtma bo‘yicha taxminiy ma’lumotlar',
      'en': 'Estimated order information',
      'ru': 'Расчетные данные по заказу',
    },
    'worker.summary.length': {
      'uz': 'Metraj',
      'en': 'Length',
      'ru': 'Метраж',
    },
    'worker.summary.weight': {
      'uz': 'Og‘irlik',
      'en': 'Weight',
      'ru': 'Вес',
    },
    'worker.summary.shafts': {
      'uz': 'Val',
      'en': 'Shafts',
      'ru': 'Валы',
    },
    'worker.summary.shaft_value': {
      'uz': '{count} ta {width} mm eniga ega bo‘lgan val ishlatiladi',
      'en': '{count} shaft(s) with a width of {width} mm will be used',
      'ru': 'Будет использовано валов: {count}, ширина {width} мм',
    },
    'worker.detail.current_machine': {
      'uz': 'Joriy apparat',
      'en': 'Current machine',
      'ru': 'Текущий аппарат',
    },
    'worker.detail.step': {
      'uz': 'Qadam {step}',
      'en': 'Step {step}',
      'ru': 'Шаг {step}',
    },
    'worker.freeze.active': {
      'uz':
          'Buyurtma muzlatilgan. Admin aktiv qilmaguncha davom ettirib bo‘lmaydi.',
      'en':
          'The order is frozen. It cannot continue until an admin activates it.',
      'ru':
          'Заказ заморожен. Продолжить можно только после активации администратором.',
    },
    'worker.freeze.requested': {
      'uz':
          'Admin muzlatishni so‘radi. Avval rulonni xavfsiz yeching yoki muammo sababini yozing.',
      'en':
          'An admin requested a freeze. Safely remove the roll first, or enter the issue reason.',
      'ru':
          'Администратор запросил заморозку. Сначала безопасно снимите рулон или укажите причину проблемы.',
    },
    'worker.freeze.safe_stop.title': {
      'uz': 'Rulonni yechib muzlatish',
      'en': 'Remove roll and freeze',
      'ru': 'Снять рулон и заморозить',
    },
    'worker.freeze.safe_stop.form_instruction': {
      'uz':
          'Sog‘lom rulon bo‘lsa barcha miqdorlarni kiriting. Ishlab chiqarish imkonsiz bo‘lsa miqdorlarni bo‘sh qoldirib, faqat muammo izohini yozing.',
      'en':
          'For a healthy roll, enter every output quantity. If production output is impossible, leave quantities empty and enter only the issue note.',
      'ru':
          'Для исправного рулона введите все выходные значения. Если выпуск невозможен, оставьте количества пустыми и укажите только описание проблемы.',
    },
    'worker.freeze.safe_stop.issue_note': {
      'uz': 'Muammo izohi',
      'en': 'Issue note',
      'ru': 'Описание проблемы',
    },
    'worker.freeze.safe_stop.output_or_issue_required': {
      'uz': 'Miqdorlarni to‘liq kiriting yoki faqat muammo izohini yozing.',
      'en': 'Enter all quantities or only the issue note.',
      'ru': 'Введите все количества или только описание проблемы.',
    },
    'worker.freeze.safe_stop.output_incomplete': {
      'uz':
          'Miqdorlar to‘liq emas. Barcha majburiy qiymatlarni kiriting yoki maydonlarni tozalab, faqat muammo izohini yozing.',
      'en':
          'Output is incomplete. Enter every required value, or clear the quantity fields and enter only the issue note.',
      'ru':
          'Выходные данные неполные. Заполните все обязательные значения или очистите количества и укажите только описание проблемы.',
    },
    'worker.freeze.safe_stop.metadata_missing': {
      'uz':
          'Muzlatish so‘rovi ma’lumoti eskirgan yoki to‘liq emas. Navbatni yangilab qayta urinib ko‘ring.',
      'en':
          'The freeze request metadata is stale or incomplete. Refresh the queue and try again.',
      'ru':
          'Данные запроса на заморозку устарели или неполны. Обновите очередь и повторите попытку.',
    },
    'worker.freeze.safe_stop.healthy_success': {
      'uz': 'Rulon yechildi va order muzlatildi',
      'en': 'The roll was removed and the order was frozen',
      'ru': 'Рулон снят, заказ заморожен',
    },
    'worker.freeze.safe_stop.issue_success': {
      'uz': 'Order muammo bilan muzlatildi',
      'en': 'The order was frozen with an issue',
      'ru': 'Заказ заморожен с указанием проблемы',
    },
    'worker.materials.start': {
      'uz': 'Ish boshlash uchun homashyolar',
      'en': 'Materials required to start',
      'ru': 'Сырье для начала работы',
    },
    'worker.materials.start.empty': {
      'uz': 'Ish boshlash uchun homashyo topilmadi',
      'en': 'No starting materials found',
      'ru': 'Сырье для начала работы не найдено',
    },
    'worker.materials.pending': {
      'uz': 'Hali qabul qilinmagan homashyolar',
      'en': 'Materials not yet received',
      'ru': 'Еще не принятое сырье',
    },
    'worker.materials.pending.empty': {
      'uz': 'Hali qabul qilinmagan homashyo yo‘q',
      'en': 'No materials are waiting to be received',
      'ru': 'Ожидающего приемки сырья нет',
    },
    'worker.materials.attached': {
      'uz': 'Biriktirilgan homashyolar',
      'en': 'Attached materials',
      'ru': 'Прикрепленное сырье',
    },
    'worker.materials.attached.empty': {
      'uz': 'Homashyo biriktirilmagan',
      'en': 'No materials attached',
      'ru': 'Сырье не прикреплено',
    },
    'worker.molds': {
      'uz': 'Qoliplar',
      'en': 'Molds',
      'ru': 'Формы',
    },
    'worker.progress.previous.confirmed': {
      'uz': 'Oldingi bosqich tasdiqlandi',
      'en': 'Previous stage confirmed',
      'ru': 'Предыдущий этап подтвержден',
    },
    'worker.progress.previous.qr': {
      'uz': 'Oldingi bosqich QR',
      'en': 'Previous stage QR',
      'ru': 'QR предыдущего этапа',
    },
    'worker.progress.products': {
      'uz': 'Oldingi bosqichdan kelgan mahsulotlar',
      'en': 'Products from the previous stage',
      'ru': 'Продукция с предыдущего этапа',
    },
    'worker.progress.none': {
      'uz': '{stage} hali bu order uchun mahsulot chiqarmagan.',
      'en': '{stage} has not produced anything for this order yet.',
      'ru': 'Аппарат «{stage}» еще не выпустил продукцию по этому заказу.',
    },
    'worker.progress.scan_required': {
      'uz': 'Scan qilish kerak',
      'en': 'Scan required',
      'ru': 'Нужно сканировать',
    },
    'worker.progress.used': {
      'uz': 'Ishlatilgan',
      'en': 'Used',
      'ru': 'Использовано',
    },
    'worker.progress.batch_status': {
      'uz': '{status} • Miqdor: {qty} {uom}',
      'en': '{status} • Quantity: {qty} {uom}',
      'ru': '{status} • Количество: {qty} {uom}',
    },
    'worker.progress.qr': {
      'uz': 'QR: {qr}',
      'en': 'QR: {qr}',
      'ru': 'QR: {qr}',
    },
    'worker.material.balance': {
      'uz': 'Homashyo balansi',
      'en': 'Material balance',
      'ru': 'Баланс сырья',
    },
    'worker.material.balance.summary': {
      'uz': 'Qabul: {received} • Sarf: {used} • Qoldiq: {remaining}',
      'en': 'Received: {received} • Used: {used} • Remaining: {remaining}',
      'ru': 'Принято: {received} • Расход: {used} • Остаток: {remaining}',
    },
    'worker.material.unlink': {
      'uz': 'Ulanishni uzish',
      'en': 'Unlink',
      'ru': 'Отвязать',
    },
    'worker.material.unlink.disabled': {
      'uz': '{status}: uzib bo‘lmaydi',
      'en': '{status}: cannot unlink',
      'ru': '{status}: нельзя отвязать',
    },
    'worker.material.status.consumed': {
      'uz': 'Sarf qilingan',
      'en': 'Consumed',
      'ru': 'Израсходовано',
    },
    'worker.material.status.in_use': {
      'uz': 'Ishlatilmoqda',
      'en': 'In use',
      'ru': 'Используется',
    },
    'worker.material.status.attached': {
      'uz': 'Band',
      'en': 'Attached',
      'ru': 'Закреплено',
    },
    'worker.material.group.print': {
      'uz': 'Bosma uchun biriktirilgan',
      'en': 'Attached for printing',
      'ru': 'Прикреплено для печати',
    },
    'worker.material.group.lamination': {
      'uz': 'Laminatsiya uchun biriktirilgan',
      'en': 'Attached for lamination',
      'ru': 'Прикреплено для ламинации',
    },
    'worker.material.group.cutting': {
      'uz': 'Rezka uchun biriktirilgan',
      'en': 'Attached for slitting',
      'ru': 'Прикреплено для резки',
    },
    'worker.material.group.unknown': {
      'uz': 'Bosqichi ko‘rsatilmagan homashyolar',
      'en': 'Materials without a stage',
      'ru': 'Сырье без указанного этапа',
    },
    'worker.map.cutting': {
      'uz': 'Map bo‘yicha rezka',
      'en': 'Slitting from map',
      'ru': 'Резка по карте',
    },
    'worker.map.progress': {
      'uz': '{completed} / {total} bosqich',
      'en': '{completed} / {total} stages',
      'ru': '{completed} / {total} этапов',
    },
    'worker.split.rolls': {
      'uz': 'Rulon {frames} ta alohida WIP ga bo‘linadi',
      'en': 'The roll will be split into {frames} separate WIPs',
      'ru': 'Рулон будет разделен на {frames} отдельных WIP',
    },
    'worker.split.qr': {
      'uz': 'Har bir WIP uchun alohida QR chiqadi',
      'en': 'A separate QR code will be created for each WIP',
      'ru': 'Для каждого WIP будет создан отдельный QR-код',
    },
    'worker.split.same': {
      'uz': 'Har bir WIP uchun alohida metraj, kg, babina va diametr kiriting',
      'en': 'Enter length, weight, core, and diameter separately for each WIP',
      'ru': 'Для каждого WIP введите отдельно метраж, вес, втулку и диаметр',
    },
    'worker.split.label_length': {
      'uz': 'Etiketka uzunligi: {length} mm',
      'en': 'Label length: {length} mm',
      'ru': 'Длина этикетки: {length} мм',
    },
    'worker.split.summary': {
      'uz': 'WIP {count} bo‘lakka bo‘linadi',
      'en': 'The WIP will be split into {count} parts',
      'ru': 'WIP будет разделен на {count} частей',
    },
    'worker.split.part': {
      'uz': '{index}-bo‘lak: {frames} kadr',
      'en': 'Part {index}: {frames} frames',
      'ru': 'Часть {index}: {frames} кадров',
    },
    'worker.split.total': {
      'uz': 'Jami: {frames} kadr',
      'en': 'Total: {frames} frames',
      'ru': 'Всего: {frames} кадров',
    },
    'worker.wip.details': {
      'uz': 'WIP tafsilotlari',
      'en': 'WIP details',
      'ru': 'Детали WIP',
    },
    'worker.wip.description': {
      'uz': 'Bu order bo‘yicha hosil bo‘lgan yarim tayyor mahsulotlar:',
      'en': 'Semi-finished products created for this order:',
      'ru': 'Полуфабрикаты, созданные по этому заказу:',
    },
    'worker.wip.waiting': {
      'uz': 'Kutmoqda',
      'en': 'Waiting',
      'ru': 'Ожидает',
    },
    'worker.wip.in_use': {
      'uz': 'Ishda',
      'en': 'In use',
      'ru': 'В работе',
    },
    'worker.wip.info.quantity': {
      'uz': 'Miqdor',
      'en': 'Quantity',
      'ru': 'Количество',
    },
    'worker.wip.info.started': {
      'uz': 'Boshlangan',
      'en': 'Started',
      'ru': 'Начато',
    },
    'worker.wip.info.finished': {
      'uz': 'Tugagan',
      'en': 'Finished',
      'ru': 'Завершено',
    },
    'worker.wip.info.source': {
      'uz': 'Qayerdan chiqdi',
      'en': 'Source machine',
      'ru': 'Исходный аппарат',
    },
    'worker.wip.info.action': {
      'uz': 'Amal',
      'en': 'Action',
      'ru': 'Действие',
    },
    'worker.wip.info.location': {
      'uz': 'Hozirgi joyi',
      'en': 'Current location',
      'ru': 'Текущее место',
    },
    'worker.wip.info.next_machine': {
      'uz': 'Keyingi aparat',
      'en': 'Next machine',
      'ru': 'Следующий аппарат',
    },
    'worker.wip.info.worker': {
      'uz': 'Ishchi',
      'en': 'Worker',
      'ru': 'Рабочий',
    },
    'worker.wip.info.id': {
      'uz': 'WIP ID',
      'en': 'WIP ID',
      'ru': 'ID WIP',
    },
    'worker.wip.info.qr': {
      'uz': 'QR:',
      'en': 'QR:',
      'ru': 'QR:',
    },
    'worker.wip.info.note': {
      'uz': 'Izoh',
      'en': 'Note',
      'ru': 'Примечание',
    },
    'worker.wip.load_failed': {
      'uz': 'WIP ma’lumotlari yuklanmadi',
      'en': 'WIP data could not be loaded',
      'ru': 'Не удалось загрузить данные WIP',
    },
    'worker.wip.empty': {
      'uz': 'Bu order bo‘yicha WIP topilmadi',
      'en': 'No WIP found for this order',
      'ru': 'WIP по этому заказу не найден',
    },
    'worker.wip.history.title': {
      'uz': 'WIP tafsilotlari',
      'en': 'WIP details',
      'ru': 'Детали WIP',
    },
    'worker.wip.history.summary': {
      'uz': '{count} ta WIP yaratilgan',
      'en': '{count} WIPs produced',
      'ru': 'Выпущено партий WIP: {count}',
    },
    'worker.wip.history.description': {
      'uz': 'Bu order bo‘yicha hosil bo‘lgan yarim tayyor mahsulotlar:',
      'en': 'Semi-finished products produced for this order:',
      'ru': 'Полуфабрикаты, произведенные по этому заказу:',
    },
    'worker.wip.status.free': {
      'uz': 'Erkin WIP',
      'en': 'Available WIP',
      'ru': 'Свободный WIP',
    },
    'worker.wip.status.accepted': {
      'uz': 'Omborga qabul qilingan',
      'en': 'Accepted into stock',
      'ru': 'Принят на склад',
    },
    'worker.wip.status.waiting_next': {
      'uz': 'Keyingi bosqichni kutmoqda',
      'en': 'Waiting for the next stage',
      'ru': 'Ожидает следующий этап',
    },
    'worker.wip.status.consumed_next': {
      'uz': 'Keyingi bosqichda ishlatilgan',
      'en': 'Used by the next stage',
      'ru': 'Использован на следующем этапе',
    },
    'worker.wip.status.in_progress': {
      'uz': 'Ish jarayonida',
      'en': 'In progress',
      'ru': 'В работе',
    },
    'worker.wip.status.waiting': {
      'uz': 'Kutmoqda',
      'en': 'Waiting',
      'ru': 'Ожидает',
    },
    'worker.wip.status.used': {
      'uz': 'Ishlatilgan',
      'en': 'Used',
      'ru': 'Использован',
    },
    'worker.wip.status.paused': {
      'uz': 'Pauzada',
      'en': 'Paused',
      'ru': 'На паузе',
    },
    'worker.wip.status.finished': {
      'uz': 'Tugagan',
      'en': 'Finished',
      'ru': 'Завершен',
    },
    'worker.wip.action.pause': {
      'uz': 'Pauza qilib chiqarilgan',
      'en': 'Produced during a pause',
      'ru': 'Выпущен на паузе',
    },
    'worker.wip.action.detach_roll': {
      'uz': 'Rulon yechib chiqarilgan',
      'en': 'Produced after removing the roll',
      'ru': 'Выпущен после снятия рулона',
    },
    'worker.wip.action.roll_complete': {
      'uz': 'Rulonni tugatib chiqarilgan',
      'en': 'Produced after finishing the roll',
      'ru': 'Выпущен после завершения рулона',
    },
    'worker.wip.action.complete': {
      'uz': 'Tugatib chiqarilgan',
      'en': 'Produced at completion',
      'ru': 'Выпущен при завершении',
    },
    'worker.wip.action.resume': {
      'uz': 'Davom ettirilgan',
      'en': 'Produced after resuming',
      'ru': 'Выпущен после возобновления',
    },
    'worker.wip.history.error': {
      'uz': 'WIP ma’lumotlari yuklanmadi',
      'en': 'WIP data could not be loaded',
      'ru': 'Не удалось загрузить данные WIP',
    },
    'worker.wip.history.empty': {
      'uz': 'Bu order bo‘yicha WIP topilmadi',
      'en': 'No WIP found for this order',
      'ru': 'WIP по этому заказу не найден',
    },
    'worker.paddon.subtitle': {
      'uz': 'WIP va rulonlarni fizik paddonlar bo‘yicha boshqarish',
      'en': 'Manage WIPs and rolls by physical paddons',
      'ru': 'Управление WIP и рулонами по физическим паддонам',
    },
    'worker.paddon.location.title': {
      'uz': 'Fizik joylashuv nazorati',
      'en': 'Physical location control',
      'ru': 'Контроль физического размещения',
    },
    'worker.paddon.location.subtitle': {
      'uz': 'Har bir paddon ichidagi WIP larni bitta joydan ko‘ring.',
      'en': 'View the WIPs inside every paddon in one place.',
      'ru': 'Просматривайте WIP внутри каждого паддона в одном месте.',
    },
    'worker.paddon.empty.title': {
      'uz': 'Hali paddon yaratilmagan',
      'en': 'No paddons created yet',
      'ru': 'Паддоны еще не созданы',
    },
    'worker.paddon.empty.body': {
      'uz':
          'Yangi paddon bir bosishda yaratiladi. Code avtomatik beriladi, WIP larni esa keyin ichiga qo‘shasiz.',
      'en':
          'Create a new paddon with one tap. Its code is generated automatically, and you can add WIPs later.',
      'ru':
          'Создайте новый паддон одним нажатием. Код сгенерируется автоматически, а WIP можно добавить позже.',
    },
    'worker.paddon.wip_count': {
      'uz': '{count} ta WIP',
      'en': '{count} WIP',
      'ru': '{count} WIP',
    },
    'worker.paddon.create': {
      'uz': 'Yangi paddon',
      'en': 'New paddon',
      'ru': 'Новый паддон',
    },
    'worker.paddon.creating': {
      'uz': 'Yaratilmoqda...',
      'en': 'Creating...',
      'ru': 'Создание...',
    },
    'worker.paddon.scan': {
      'uz': 'QR scan',
      'en': 'Scan QR',
      'ru': 'Сканировать QR',
    },
    'worker.paddon.add_wip': {
      'uz': 'WIP QR scan qilib qo‘shish',
      'en': 'Scan WIP QR to add',
      'ru': 'Сканировать QR WIP для добавления',
    },
    'worker.paddon.printing': {
      'uz': 'QR tayyorlanmoqda...',
      'en': 'Preparing QR...',
      'ru': 'Подготовка QR...',
    },
    'worker.paddon.print': {
      'uz': 'Paddon QR chop etish',
      'en': 'Print paddon QR',
      'ru': 'Напечатать QR паддона',
    },
    'worker.paddon.add': {
      'uz': 'Qo‘shish',
      'en': 'Add',
      'ru': 'Добавить',
    },
    'worker.paddon.remove': {
      'uz': 'Olib tashlash',
      'en': 'Remove',
      'ru': 'Убрать',
    },
    'worker.paddon.confirm.remove.title': {
      'uz': 'Tanlangan WIP larni chiqarishmi?',
      'en': 'Remove selected WIPs?',
      'ru': 'Убрать выбранные WIP?',
    },
    'worker.paddon.confirm.remove.body': {
      'uz': 'Tanlangan WIP lar ushbu paddondan chiqariladi.',
      'en': 'The selected WIPs will be removed from this paddon.',
      'ru': 'Выбранные WIP будут убраны из этого паддона.',
    },
    'worker.daily.subtitle': {
      'uz': '{apparatus} tomonidan chiqarilgan WIP va orderlar',
      'en': 'WIPs and orders produced by {apparatus}',
      'ru': 'WIP и заказы, выпущенные аппаратом «{apparatus}»',
    },
    'worker.daily.choose_date': {
      'uz': 'Kun tanlash',
      'en': 'Choose date',
      'ru': 'Выбрать дату',
    },
    'worker.daily.choose_date.title': {
      'uz': 'Kunlik ish kunini tanlang',
      'en': 'Choose the daily work date',
      'ru': 'Выберите дату ежедневной работы',
    },
    'worker.daily.order': {
      'uz': 'Order',
      'en': 'Order',
      'ru': 'Заказ',
    },
    'worker.daily.wip': {
      'uz': 'WIP',
      'en': 'WIP',
      'ru': 'WIP',
    },
    'worker.daily.used': {
      'uz': 'Ishlatilgan',
      'en': 'Used',
      'ru': 'Использовано',
    },
    'worker.daily.edit_wip': {
      'uz': 'WIPni o‘zgartirish',
      'en': 'Edit WIP',
      'ru': 'Изменить WIP',
    },
    'worker.daily.empty': {
      'uz': 'Bu kunda WIP chiqarilmagan',
      'en': 'No WIP was produced on this date',
      'ru': 'В этот день WIP не выпускался',
    },
    'worker.daily.edit.title': {
      'uz': 'WIPni o‘zgartirish',
      'en': 'Edit WIP',
      'ru': 'Изменить WIP',
    },
    'worker.daily.field.quantity': {
      'uz': 'Miqdor',
      'en': 'Quantity',
      'ru': 'Количество',
    },
    'worker.daily.field.length': {
      'uz': 'Metraj',
      'en': 'Length',
      'ru': 'Метраж',
    },
    'worker.daily.field.weight': {
      'uz': 'Og‘irlik',
      'en': 'Weight',
      'ru': 'Вес',
    },
    'worker.daily.field.roll': {
      'uz': 'Babina',
      'en': 'Roll',
      'ru': 'Бобина',
    },
    'worker.daily.field.diameter': {
      'uz': 'Diametr',
      'en': 'Diameter',
      'ru': 'Диаметр',
    },
    'worker.daily.field.returned_ink': {
      'uz': 'Qaytarilgan bo‘yoq',
      'en': 'Returned ink',
      'ru': 'Возвращенная краска',
    },
    'worker.daily.field.print_leftover': {
      'uz': 'Bosmadan ortgan rulon',
      'en': 'Print leftover rolls',
      'ru': 'Оставшиеся после печати рулоны',
    },
    'worker.daily.field.film_leftover': {
      'uz': 'Plyonkadan ortgan rulon',
      'en': 'Film leftover rolls',
      'ru': 'Оставшиеся после пленки рулоны',
    },
    'worker.daily.field.total_waste': {
      'uz': 'Jami chiqindi',
      'en': 'Total waste',
      'ru': 'Общие отходы',
    },
    'worker.daily.field.print_waste': {
      'uz': 'Bosma chiqindisi',
      'en': 'Print waste',
      'ru': 'Отходы печати',
    },
    'worker.daily.field.lamination_waste': {
      'uz': 'Laminatsiya chiqindisi',
      'en': 'Lamination waste',
      'ru': 'Отходы ламинации',
    },
    'worker.daily.field.edge_waste': {
      'uz': 'Chet chiqindisi',
      'en': 'Edge waste',
      'ru': 'Отходы кромки',
    },
    'worker.daily.field.note': {
      'uz': 'WIP izohi',
      'en': 'WIP note',
      'ru': 'Примечание WIP',
    },
    'worker.daily.correction.title': {
      'uz': 'O‘zgartirish sababi',
      'en': 'Reason for change',
      'ru': 'Причина изменения',
    },
    'worker.daily.correction.hint': {
      'uz': 'Nima uchun qiymat o‘zgartirilmoqda?',
      'en': 'Why is this value being changed?',
      'ru': 'Почему изменяется это значение?',
    },
    'worker.daily.correction.required': {
      'uz': 'Izohsiz o‘zgartirib bo‘lmaydi',
      'en': 'A note is required to make a change',
      'ru': 'Для изменения требуется примечание',
    },
    'worker.daily.invalid_number': {
      'uz': 'To‘g‘ri raqam kiriting',
      'en': 'Enter a valid number',
      'ru': 'Введите корректное число',
    },
    'worker.daily.positive_number': {
      'uz': '0 dan katta raqam kiriting',
      'en': 'Enter a number greater than 0',
      'ru': 'Введите число больше 0',
    },
    'worker.guide.subtitle': {
      'uz': 'Zakazni appda to‘g‘ri yuritish tartibi',
      'en': 'How to manage an order correctly in the app',
      'ru': 'Порядок правильной работы с заказом в приложении',
    },
    'worker.guide.open_order': {
      'uz': 'Kuzatishdan zakazni ochish',
      'en': 'Open an order from Monitoring',
      'ru': 'Откройте заказ в разделе «Мониторинг»',
    },
    'worker.guide.states_actions': {
      'uz': 'Ekrandagi holatlar va tugmalar',
      'en': 'Statuses and buttons on the screen',
      'ru': 'Статусы и кнопки на экране',
    },
    'worker.guide.before_start': {
      'uz': '1. Boshlashdan oldingi ekrandagi tasdiqlar',
      'en': '1. Checks before starting',
      'ru': '1. Проверки перед началом',
    },
    'worker.guide.pause': {
      'uz': '2. Pauza qilish',
      'en': '2. Pausing work',
      'ru': '2. Постановка на паузу',
    },
    'worker.guide.complete': {
      'uz': '3. Tugatish tartibi',
      'en': '3. How to complete work',
      'ru': '3. Порядок завершения',
    },
    'worker.guide.partial': {
      'uz': '4. To‘liq bo‘lmagan tugatish',
      'en': '4. Partial completion',
      'ru': '4. Неполное завершение',
    },
    'worker.notice.action_sent': {
      'uz': 'Amal serverga yuborildi. Holat avtomatik yangilanadi',
      'en':
          'The action was sent to the server. The status will update automatically.',
      'ru': 'Действие отправлено на сервер. Состояние обновится автоматически.',
    },
    'worker.notice.action_print_failed': {
      'uz': 'Amal bajarildi, local printer chop etmadi',
      'en': 'The action succeeded, but the local printer did not print.',
      'ru': 'Действие выполнено, но локальный принтер не напечатал.',
    },
    'worker.notice.material_received': {
      'uz': 'Homashyo qabul qilindi{qty}. Yana QR scan qiling',
      'en': 'Material received{qty}. Scan another QR code.',
      'ru': 'Сырье принято{qty}. Сканируйте следующий QR-код.',
    },
    'worker.notice.material_received_short': {
      'uz': 'Homashyo qabul qilindi{qty}',
      'en': 'Material received{qty}',
      'ru': 'Сырье принято{qty}',
    },
    'worker.notice.all_materials_received': {
      'uz': 'Barcha kutilayotgan homashyolar qabul qilindi',
      'en': 'All pending materials have been received',
      'ru': 'Все ожидающие материалы приняты',
    },
    'worker.notice.materials_confirmed': {
      'uz': 'Ish boshlash uchun homashyolar tasdiqlandi',
      'en': 'Materials required to start are confirmed',
      'ru': 'Сырье для начала работы подтверждено',
    },
    'worker.notice.completion_request_sent': {
      'uz': 'Tugatish so‘rovi adminga yuborildi',
      'en': 'The completion request was sent to the admin',
      'ru': 'Запрос на завершение отправлен администратору',
    },
    'worker.error.action_failed': {
      'uz': 'Amal bajarilmadi',
      'en': 'The action could not be completed',
      'ru': 'Не удалось выполнить действие',
    },
    'worker.error.network_timeout': {
      'uz': 'Internet yoki server javob bermadi. Qayta urinib ko‘ring',
      'en': 'The internet or server did not respond. Try again.',
      'ru': 'Интернет или сервер не ответил. Повторите попытку.',
    },
    'worker.error.sync': {
      'uz': 'Ish holati server bilan sinxron emas. Sahifani yangilang.',
      'en':
          'The work state is not synchronized with the server. Refresh the page.',
      'ru':
          'Состояние работы не синхронизировано с сервером. Обновите страницу.',
    },
    'worker.error.rule_loading': {
      'uz': 'Homashyo qoidasi yuklanmoqda',
      'en': 'Loading material rules',
      'ru': 'Загрузка правил сырья',
    },
    'worker.error.rule_failed': {
      'uz': 'Homashyo qoidasi yuklanmadi',
      'en': 'Material rules could not be loaded',
      'ru': 'Не удалось загрузить правила сырья',
    },
    'worker.error.no_materials': {
      'uz': 'Ish boshlash uchun homashyo biriktirilmagan',
      'en': 'No materials are attached to start the work',
      'ru': 'Для начала работы сырье не прикреплено',
    },
    'worker.error.incomplete_material_groups': {
      'uz': 'Majburiy homashyo guruhlari to‘liq biriktirilmagan',
      'en': 'Required material groups are not fully attached',
      'ru': 'Обязательные группы сырья прикреплены не полностью',
    },
    'worker.error.material_not_at_machine': {
      'uz': 'Apparat oldiga homashyo olib kelinmagan',
      'en': 'The material has not been brought to the machine',
      'ru': 'Сырье не доставлено к аппарату',
    },
    'worker.error.scan_all_materials': {
      'uz': 'Avval state’dagi barcha homashyolarni QR scan qiling',
      'en': 'Scan all materials shown in the list first',
      'ru': 'Сначала отсканируйте все материалы из списка',
    },
    'worker.error.scan_required_materials': {
      'uz': 'Avval har bir majburiy guruhdan minimum homashyo QR scan qiling',
      'en':
          'Scan at least one material QR code from every required group first',
      'ru':
          'Сначала отсканируйте минимум один QR-код сырья из каждой обязательной группы',
    },
    'worker.error.scan_molds': {
      'uz': 'Avval qolip QR scan qiling',
      'en': 'Scan the mold QR code first',
      'ru': 'Сначала отсканируйте QR формы',
    },
    'worker.error.scan_previous': {
      'uz': 'Oldingi bosqich QR sini scan qiling',
      'en': 'Scan the previous stage QR code first',
      'ru': 'Сначала отсканируйте QR предыдущего этапа',
    },
    'worker.error.qr_other_order': {
      'uz': 'Bu QR boshqa orderni boshlash uchun mos emas',
      'en': 'This QR code cannot be used to start another order',
      'ru': 'Этот QR-код нельзя использовать для запуска другого заказа',
    },
    'worker.error.assigned_machine': {
      'uz': 'Bu QR siz biriktirilgan apparatga mos emas',
      'en': 'This QR code does not belong to your assigned machine',
      'ru': 'Этот QR-код не относится к назначенному вам аппарату',
    },
    'worker.error.machine_flow': {
      'uz': 'Bu QR ushbu apparat oqimiga mos emas',
      'en': 'This QR code does not belong to this machine flow',
      'ru': 'Этот QR-код не относится к потоку этого аппарата',
    },
    'worker.error.current_order_missing': {
      'uz': 'Shu apparatdagi joriy order aniqlanmadi',
      'en': 'The current order on this machine could not be found',
      'ru': 'Не удалось найти текущий заказ на этом аппарате',
    },
    'worker.error.current_order_qr': {
      'uz': 'Bu QR hozirgi orderga tegishli',
      'en': 'This QR code belongs to the current order',
      'ru': 'Этот QR-код относится к текущему заказу',
    },
    'worker.error.other_order_lookup': {
      'uz': 'QR orqali boshqa order aniqlanmadi',
      'en': 'No other order was found from the QR code',
      'ru': 'По QR-коду другой заказ не найден',
    },
    'worker.error.machine_roll': {
      'uz': 'Apparatdagi rulon holati olinmadi',
      'en': 'The roll status on the machine could not be loaded',
      'ru': 'Не удалось загрузить состояние рулона на аппарате',
    },
    'worker.error.no_pending_material': {
      'uz': 'Hali qabul qilinmagan homashyo yo‘q',
      'en': 'There are no pending materials to receive',
      'ru': 'Нет сырья, ожидающего приемки',
    },
    'worker.summary.length_value': {
      'uz': '{value} metr',
      'en': '{value} m',
      'ru': '{value} м',
    },
    'worker.summary.weight_value': {
      'uz': '{value} kg',
      'en': '{value} kg',
      'ru': '{value} кг',
    },
    'worker.detail.kind.start': {
      'uz': 'Boshlanish',
      'en': 'Start',
      'ru': 'Начало',
    },
    'worker.detail.kind.lamination': {
      'uz': 'Laminatsiya mashinasi',
      'en': 'Lamination machine',
      'ru': 'Ламинационная машина',
    },
    'worker.detail.kind.cutting': {
      'uz': 'Rezka mashinasi',
      'en': 'Slitting machine',
      'ru': 'Резальная машина',
    },
    'worker.detail.kind.machine': {
      'uz': 'Aparat',
      'en': 'Machine',
      'ru': 'Аппарат',
    },
    'worker.detail.kind.end': {
      'uz': 'Yakun',
      'en': 'End',
      'ru': 'Конец',
    },
    'worker.waiting.previous': {
      'uz': 'Oldingi bosqich tugallanguncha kutilmoqda: {stage}',
      'en': 'Waiting for the previous stage to finish: {stage}',
      'ru': 'Ожидание завершения предыдущего этапа: {stage}',
    },
    'worker.waiting.sequence': {
      'uz': 'Buyurtma apparat navbatidagi o‘z vaqtini kutmoqda',
      'en': 'The order is waiting for its turn in the machine queue',
      'ru': 'Заказ ожидает своей очереди на аппарате',
    },
    'worker.material.group.dynamic': {
      'uz': '{apparatus} uchun biriktirilgan',
      'en': 'Attached for {apparatus}',
      'ru': 'Прикреплено для аппарата «{apparatus}»',
    },
    'worker.progress.summary.empty': {
      'uz': '{stage} chiqargan mahsulotlar shu yerda ko‘rinadi.',
      'en': 'Products produced by {stage} will appear here.',
      'ru': 'Здесь появится продукция, выпущенная аппаратом «{stage}».',
    },
    'worker.progress.summary.unused': {
      'uz':
          '{stage} chiqargan {total} ta mahsulot bor. {open} tasini scan qilish kerak.',
      'en': '{stage} produced {total} items. {open} still need to be scanned.',
      'ru':
          'Аппарат «{stage}» выпустил продукции: {total}. Нужно сканировать: {open}.',
    },
    'worker.progress.summary.used_all': {
      'uz': '{stage} chiqargan {total} ta mahsulotning hammasi ishlatilgan.',
      'en': 'All {total} items produced by {stage} have been used.',
      'ru':
          'Вся продукция ({total} шт.), выпущенная аппаратом «{stage}», использована.',
    },
    'worker.progress.summary.mixed': {
      'uz':
          '{stage} chiqargan {total} ta mahsulot bor: {open} tasi scan qilinadi, {used} tasi ishlatilgan.',
      'en':
          '{stage} produced {total} items: {open} need scanning and {used} have been used.',
      'ru':
          'Аппарат «{stage}» выпустил {total} шт.: нужно сканировать {open}, использовано {used}.',
    },
    'worker.progress.action.complete': {
      'uz': 'tugatib chiqargan',
      'en': 'completed',
      'ru': 'завершил',
    },
    'worker.progress.action.pause': {
      'uz': 'pauzada chiqargan',
      'en': 'paused',
      'ru': 'выпустил на паузе',
    },
    'worker.progress.action.detach_roll': {
      'uz': 'rulonni yechib chiqargan',
      'en': 'removed the roll and produced',
      'ru': 'снял рулон и выпустил',
    },
    'worker.progress.action.roll_complete': {
      'uz': 'rulonni tugatib chiqargan',
      'en': 'finished the roll and produced',
      'ru': 'завершил рулон и выпустил',
    },
    'worker.progress.action.output': {
      'uz': 'chiqargan',
      'en': 'produced',
      'ru': 'выпустил',
    },
    'worker.progress.batch_title': {
      'uz': '{source} {action} mahsulot',
      'en': 'Product {action} by {source}',
      'ru': 'Продукция, которую аппарат «{source}» {action}',
    },
    'worker.mold.code': {
      'uz': 'Qolip kodi: {code}',
      'en': 'Mold code: {code}',
      'ru': 'Код формы: {code}',
    },
    'worker.mold.color': {
      'uz': 'Rang: {color}',
      'en': 'Color: {color}',
      'ru': 'Цвет: {color}',
    },
    'worker.mold.color.missing': {
      'uz': 'Rang: kiritilmagan',
      'en': 'Color: not specified',
      'ru': 'Цвет: не указан',
    },
    'worker.error.progress_qr': {
      'uz': 'Progress QR tekshirilmadi',
      'en': 'The progress QR code could not be verified',
      'ru': 'Не удалось проверить QR прогресса',
    },
    'worker.material.unlink.title': {
      'uz': 'Homashyoni uzish',
      'en': 'Unlink material',
      'ru': 'Отвязать сырье',
    },
    'worker.material.unlink.message': {
      'uz': 'Bu homashyoni zakazdan uzasizmi?',
      'en': 'Unlink this material from the order?',
      'ru': 'Отвязать это сырье от заказа?',
    },
    'worker.material.unlink.confirm': {
      'uz': 'Uzish',
      'en': 'Unlink',
      'ru': 'Отвязать',
    },
    'worker.material.unlink.success': {
      'uz': 'Homashyo zakazdan uzildi',
      'en': 'Material unlinked from the order',
      'ru': 'Сырье отвязано от заказа',
    },
    'worker.material.unlink.failed': {
      'uz': 'Homashyoni zakazdan uzib bo‘lmaydi',
      'en': 'The material cannot be unlinked from the order',
      'ru': 'Нельзя отвязать сырье от заказа',
    },
    'worker.mold.requirements.loading': {
      'uz': 'Mahsulot qoliplari yuklanmoqda',
      'en': 'Loading product molds',
      'ru': 'Загрузка форм для продукта',
    },
    'worker.mold.requirements.empty': {
      'uz': 'Mahsulotga qolip biriktirilmagan',
      'en': 'No mold is attached to this product',
      'ru': 'К продукту не прикреплена форма',
    },
    'worker.mold.qr_title': {
      'uz': 'Qolip QR',
      'en': 'Mold QR',
      'ru': 'QR формы',
    },
    'worker.mold.code_label': {
      'uz': 'Qolip kodi',
      'en': 'Mold code',
      'ru': 'Код формы',
    },
    'worker.mold.already_scanned': {
      'uz': 'Bu qolip avval scan qilingan ({scanned}/{required} ta)',
      'en': 'This mold was already scanned ({scanned}/{required})',
      'ru': 'Эта форма уже отсканирована ({scanned}/{required})',
    },
    'worker.mold.progress': {
      'uz': '{scanned}/{required} ta',
      'en': '{scanned}/{required}',
      'ru': '{scanned}/{required}',
    },
    'worker.mold.added': {
      'uz': 'Qolip qo‘shildi ({scanned}/{required} ta)',
      'en': 'Mold added ({scanned}/{required})',
      'ru': 'Форма добавлена ({scanned}/{required})',
    },
    'worker.error.scan_molds_count': {
      'uz': 'Barcha qoliplarni scan qiling ({scanned}/{required} ta)',
      'en': 'Scan all molds ({scanned}/{required})',
      'ru': 'Отсканируйте все формы ({scanned}/{required})',
    },
    'worker.error.scan_embedded_mold': {
      'uz': 'Avval yuqoridagi embedded scanner orqali qolip QR scan qiling',
      'en': 'First scan the mold QR code with the scanner above',
      'ru': 'Сначала отсканируйте QR формы встроенным сканером выше',
    },
    'worker.scanner.checking': {
      'uz': 'QR tekshirilmoqda...',
      'en': 'Checking QR code...',
      'ru': 'Проверка QR-кода...',
    },
    'worker.notice.material_confirmed_item': {
      'uz': '{item} tasdiqlandi',
      'en': '{item} confirmed',
      'ru': '{item} подтверждено',
    },
    'worker.error.previous_stage_qr': {
      'uz': 'Bu QR oldingi bosqichga mos emas',
      'en': 'This QR code does not belong to the previous stage',
      'ru': 'Этот QR-код не относится к предыдущему этапу',
    },
    'worker.error.wip_not_in_order': {
      'uz': 'Bu WIP QR ushbu order ro‘yxatida topilmadi',
      'en': 'This WIP QR code was not found in the order list',
      'ru': 'Этот QR WIP не найден в списке заказа',
    },
    'worker.error.wip_machine_mismatch': {
      'uz': 'Bu WIP QR ushbu aparatga mos emas',
      'en': 'This WIP QR code does not belong to this machine',
      'ru': 'Этот QR WIP не относится к этому аппарату',
    },
    'worker.order.switch.title': {
      'uz': 'Boshqa order aniqlandi',
      'en': 'Another order detected',
      'ru': 'Обнаружен другой заказ',
    },
    'worker.order.switch.complete_current': {
      'uz':
          'Bu QR boshqa orderga tegishli. Hozirgi ishni to‘liq tugatib, yangi orderni boshlaysizmi?',
      'en':
          'This QR code belongs to another order. Complete the current work and start the new order?',
      'ru':
          'Этот QR-код относится к другому заказу. Завершить текущую работу и начать новый заказ?',
    },
    'worker.order.switch.report_current': {
      'uz':
          'Bu QR boshqa orderga tegishli. Hozirgi ish uchun astatka qayd qilib, yangi orderni boshlaysizmi?',
      'en':
          'This QR code belongs to another order. Record the current remainder and start the new order?',
      'ru':
          'Этот QR-код относится к другому заказу. Зафиксировать остаток текущей работы и начать новый заказ?',
    },
    'worker.order.switch.stop_current': {
      'uz':
          'Bu QR boshqa orderga tegishli. Hozirgi ishni to‘xtatib, yangi orderni boshlaysizmi?',
      'en':
          'This QR code belongs to another order. Stop the current work and start the new order?',
      'ru':
          'Этот QR-код относится к другому заказу. Остановить текущую работу и начать новый заказ?',
    },
    'worker.action.no': {
      'uz': 'Yo‘q',
      'en': 'No',
      'ru': 'Нет',
    },
    'worker.order.switch.confirm': {
      'uz': 'Ha, boshlash',
      'en': 'Yes, start',
      'ru': 'Да, начать',
    },
    'worker.order.switch.starting': {
      'uz': 'Yangi order boshlanmoqda...',
      'en': 'Starting the new order...',
      'ru': 'Запуск нового заказа...',
    },
    'worker.order.switch.started_with_id': {
      'uz': 'Yangi order boshlandi: {order}',
      'en': 'New order started: {order}',
      'ru': 'Новый заказ начат: {order}',
    },
    'worker.order.switch.started': {
      'uz': 'Yangi order boshlandi',
      'en': 'New order started',
      'ru': 'Новый заказ начат',
    },
    'worker.notice.astatka_recorded': {
      'uz': 'Order astatkasi qayd qilindi',
      'en': 'Order remainder recorded',
      'ru': 'Остаток по заказу зафиксирован',
    },
    'worker.error.material_order_mismatch': {
      'uz': 'Bu homashyo zakazga mos emas',
      'en': 'This material does not belong to the order',
      'ru': 'Это сырье не относится к заказу',
    },
    'worker.scanner.additional_material_prompt': {
      'uz': 'Qo‘shimcha homashyo QR kodini yuqoridagi tirqishga olib keling',
      'en': 'Present the additional material QR code to the scanner above',
      'ru': 'Поднесите QR-код дополнительного сырья к сканеру выше',
    },
    'worker.error.order_machine_missing': {
      'uz': 'Zakaz yoki aparat topilmadi',
      'en': 'The order or machine could not be found',
      'ru': 'Заказ или аппарат не найден',
    },
    'worker.scanner.receiving_material': {
      'uz': 'Qo‘shimcha homashyo qabul qilinmoqda...',
      'en': 'Receiving additional material...',
      'ru': 'Прием дополнительного сырья...',
    },
    'worker.action.select': {
      'uz': 'Tanlash',
      'en': 'Select',
      'ru': 'Выбрать',
    },
    'worker.daily.wip_qr_missing': {
      'uz': 'WIP QR topilmadi',
      'en': 'WIP QR code not found',
      'ru': 'QR WIP не найден',
    },
    'worker.daily.wip_qr_missing.body': {
      'uz':
          'Bu WIP uchun qayta chop qilishga kerak bo‘ladigan QR payload serverdan kelmadi.',
      'en':
          'The server did not return the QR payload needed to reprint this WIP.',
      'ru':
          'Сервер не вернул QR payload, необходимый для повторной печати этого WIP.',
    },
    'worker.daily.wip_qr': {
      'uz': 'WIP QR',
      'en': 'WIP QR',
      'ru': 'QR WIP',
    },
    'worker.daily.status': {
      'uz': 'Holat',
      'en': 'Status',
      'ru': 'Статус',
    },
    'worker.daily.wip_qr.reprinted': {
      'uz': 'WIP QR qayta chop etildi',
      'en': 'WIP QR code reprinted',
      'ru': 'QR WIP напечатан повторно',
    },
    'worker.daily.wip_updated': {
      'uz': 'WIP o‘zgartirildi va izoh saqlandi',
      'en': 'WIP updated and note saved',
      'ru': 'WIP изменен, примечание сохранено',
    },
    'worker.daily.load_failed': {
      'uz': 'Kunlik ish ma’lumoti yuklanmadi',
      'en': 'Daily work data could not be loaded',
      'ru': 'Не удалось загрузить данные ежедневной работы',
    },
    'worker.daily.produced_wips': {
      'uz': 'Chop etilgan WIPlar',
      'en': 'Produced WIPs',
      'ru': 'Выпущенные WIP',
    },
    'worker.daily.card.collapse_hint': {
      'uz': 'Yopish uchun bosing • QR uchun uzoq bosing',
      'en': 'Tap to collapse • Long press for QR',
      'ru': 'Нажмите, чтобы свернуть • Удерживайте для QR',
    },
    'worker.daily.card.expand_hint': {
      'uz': 'Batafsil uchun bosing • QR uchun uzoq bosing',
      'en': 'Tap for details • Long press for QR',
      'ru': 'Нажмите для деталей • Удерживайте для QR',
    },
    'worker.daily.required_field': {
      'uz': '{label} kiriting',
      'en': 'Enter {label}',
      'ru': 'Введите: {label}',
    },
    'worker.daily.apparatus.print': {
      'uz': 'Pechatchi',
      'en': 'Printing operator',
      'ru': 'Оператор печати',
    },
    'worker.daily.apparatus.cutting': {
      'uz': 'Rezka',
      'en': 'Slitting',
      'ru': 'Резка',
    },
    'worker.daily.apparatus.lamination': {
      'uz': 'Laminatsiya',
      'en': 'Lamination',
      'ru': 'Ламинация',
    },
    'worker.daily.apparatus.worker': {
      'uz': 'Aparatchi',
      'en': 'Machine operator',
      'ru': 'Оператор аппарата',
    },
    'worker.daily.reprint_failed': {
      'uz': 'WIP QR kodini qayta chop etib bo‘lmadi',
      'en': 'The WIP QR code could not be reprinted',
      'ru': 'Не удалось повторно напечатать QR WIP',
    },
    'worker.daily.correction_failed': {
      'uz': 'WIPni o‘zgartirib bo‘lmadi',
      'en': 'The WIP could not be updated',
      'ru': 'Не удалось изменить WIP',
    },
    'worker.paddon.qr_invalid': {
      'uz': 'Bu QR paddon kodi emas',
      'en': 'This QR code is not a paddon code',
      'ru': 'Этот QR-код не является кодом паддона',
    },
    'worker.paddon.create_failed': {
      'uz': 'Paddon yaratilmadi',
      'en': 'The paddon could not be created',
      'ru': 'Не удалось создать паддон',
    },
    'worker.paddon.load_failed': {
      'uz': 'Paddonlar ma’lumoti yuklanmadi',
      'en': 'Paddon data could not be loaded',
      'ru': 'Не удалось загрузить данные паддонов',
    },
    'worker.paddon.detail.subtitle': {
      'uz': 'Paddon tarkibi',
      'en': 'Paddon contents',
      'ru': 'Содержимое паддона',
    },
    'worker.paddon.camera_failed': {
      'uz': 'QR kamera scanneri ochilmadi',
      'en': 'The QR camera scanner could not be opened',
      'ru': 'Не удалось открыть QR-сканер камеры',
    },
    'worker.paddon.print_data_failed': {
      'uz': 'Paddon QR print ma’lumoti olinmadi',
      'en': 'Paddon QR print data was not returned',
      'ru': 'Данные для печати QR паддона не получены',
    },
    'worker.paddon.print_send_failed': {
      'uz': 'Paddon QR printerga yuborilmadi',
      'en': 'The paddon QR was not sent to the printer',
      'ru': 'QR паддона не отправлен на принтер',
    },
    'worker.paddon.printed': {
      'uz': 'Paddon {qr} QR chop etildi',
      'en': 'Paddon QR {qr} printed',
      'ru': 'QR паддона {qr} напечатан',
    },
    'worker.paddon.print_failed': {
      'uz': 'Paddon QR chop etilmadi',
      'en': 'Paddon QR could not be printed',
      'ru': 'Не удалось напечатать QR паддона',
    },
    'worker.paddon.add_failed': {
      'uz': 'Tanlangan WIP lar qo‘shilmadi',
      'en': 'The selected WIPs were not added',
      'ru': 'Выбранные WIP не добавлены',
    },
    'worker.paddon.remove_failed': {
      'uz': 'Tanlangan WIP lar chiqarilmadi',
      'en': 'The selected WIPs were not removed',
      'ru': 'Выбранные WIP не убраны',
    },
    'worker.paddon.update_failed': {
      'uz': 'Paddon tarkibi o‘zgartirilmadi',
      'en': 'The paddon contents were not updated',
      'ru': 'Содержимое паддона не изменено',
    },
    'worker.paddon.confirm.remove.body.count': {
      'uz': '{count} ta WIP paddon tarkibidan chiqariladi.',
      'en': '{count} WIP(s) will be removed from the paddon.',
      'ru': 'WIP будет убрано из паддона: {count}.',
    },
    'worker.paddon.available.title': {
      'uz': 'Paddonga qo‘shish mumkin bo‘lgan WIP lar',
      'en': 'WIPs available to add to the paddon',
      'ru': 'WIP, доступные для добавления в паддон',
    },
    'worker.paddon.assigned.title': {
      'uz': 'Paddon ichidagi WIP lar',
      'en': 'WIPs in the paddon',
      'ru': 'WIP в паддоне',
    },
    'worker.paddon.available.empty': {
      'uz': 'Paddonga qo‘shish mumkin bo‘lgan WIP topilmadi.',
      'en': 'No WIPs are available to add to the paddon.',
      'ru': 'Нет WIP, доступных для добавления в паддон.',
    },
    'worker.paddon.assigned.empty': {
      'uz': 'Bu paddonda hozircha WIP yo‘q.',
      'en': 'This paddon has no WIPs yet.',
      'ru': 'В этом паддоне пока нет WIP.',
    },
    'worker.paddon.not_found': {
      'uz': 'Paddon ma’lumoti topilmadi',
      'en': 'Paddon data was not found',
      'ru': 'Данные паддона не найдены',
    },
    'worker.paddon.created_by': {
      'uz': 'Yaratgan',
      'en': 'Created by',
      'ru': 'Создал',
    },
    'worker.order.fallback': {
      'uz': 'Zakaz',
      'en': 'Order',
      'ru': 'Заказ',
    },
    'worker.order.info': {
      'uz': 'Buyurtma ma’lumotlari',
      'en': 'Order details',
      'ru': 'Данные заказа',
    },
    'worker.queue.apparatus_count': {
      'uz': '{count} ta aparat',
      'en': '{count} machines',
      'ru': '{count} аппарата',
    },
    'worker.queue.empty.select_apparatus': {
      'uz': 'Avval aparat tanlang',
      'en': 'Select a machine first',
      'ru': 'Сначала выберите аппарат',
    },
    'worker.queue.empty.for_apparatus': {
      'uz': '{apparatus} uchun zakaz yo‘q',
      'en': 'No orders for {apparatus}',
      'ru': 'Для аппарата «{apparatus}» заказов нет',
    },
    'worker.queue.filter.apparatus': {
      'uz': 'Aparat',
      'en': 'Machine',
      'ru': 'Аппарат',
    },
    'worker.queue.select_apparatus': {
      'uz': 'Aparat tanlang',
      'en': 'Select a machine',
      'ru': 'Выберите аппарат',
    },
    'worker.queue.filter.unselected': {
      'uz': 'Tanlanmagan',
      'en': 'Not selected',
      'ru': 'Не выбран',
    },
    'worker.queue.orders_count': {
      'uz': '{count} ta zakaz',
      'en': '{count} orders',
      'ru': '{count} заказов',
    },
    'worker.queue.reorder_hint': {
      'uz': 'Tartibni o‘zgartirish uchun zakazni ushlab torting',
      'en': 'Press and drag an order to change its position',
      'ru': 'Нажмите и перетащите заказ, чтобы изменить его позицию',
    },
    'worker.queue.interaction_hint': {
      'uz': 'Bir marta bosing — ma’lumot. Uzoq bosing — homashyo ulash.',
      'en': 'Tap for details. Press and hold to attach raw materials.',
      'ru': 'Нажмите для просмотра. Удерживайте, чтобы прикрепить сырьё.',
    },
    'worker.completion.notifications': {
      'uz': 'Bildirishnomalar',
      'en': 'Notifications',
      'ru': 'Уведомления',
    },
    'worker.completion.requests': {
      'uz': 'Tugatish so‘rovlari',
      'en': 'Completion requests',
      'ru': 'Запросы на завершение',
    },
    'worker.completion.zero_title': {
      'uz': '{code} zakaz 0 holatda',
      'en': '{code} order has zero output',
      'ru': 'Заказ {code} имеет нулевой выпуск',
    },
    'worker.completion.remainder_title': {
      'uz': '{code} laminatsiya qoldig‘i',
      'en': '{code} lamination remainder',
      'ru': 'Остаток ламинации {code}',
    },
    'worker.completion.zero_subtitle': {
      'uz': '{worker} {apparatus} da tugatishga urinyapti',
      'en': '{worker} is trying to complete work on {apparatus}',
      'ru': '{worker} пытается завершить работу на аппарате «{apparatus}»',
    },
    'worker.completion.remainder_subtitle': {
      'uz': '{worker} {apparatus} da ikkala qavat qoldig‘ini yozdi',
      'en': '{worker} recorded the remainder of both layers on {apparatus}',
      'ru': '{worker} записал остаток обоих слоев на аппарате «{apparatus}»',
    },
    'worker.completion.product': {
      'uz': 'Mahsulot',
      'en': 'Product',
      'ru': 'Продукт',
    },
    'worker.completion.code': {
      'uz': 'Kod',
      'en': 'Code',
      'ru': 'Код',
    },
    'worker.completion.worker': {
      'uz': 'Ishchi',
      'en': 'Worker',
      'ru': 'Рабочий',
    },
    'worker.completion.time': {
      'uz': 'Vaqt',
      'en': 'Time',
      'ru': 'Время',
    },
    'worker.progress.qty.standard': {
      'uz': 'Standart miqdor',
      'en': 'Standard quantity',
      'ru': 'Стандартное количество',
    },
    'worker.progress.qty.excess_rolls': {
      'uz': 'Ortiqcha rulonlar',
      'en': 'Excess rolls',
      'ru': 'Оставшиеся рулоны',
    },
    'worker.progress.qty.waste': {
      'uz': 'Chiqindilar',
      'en': 'Waste',
      'ru': 'Отходы',
    },
    'worker.progress.qty.finished_goods': {
      'uz': 'Tayyor mahsulot',
      'en': 'Finished product',
      'ru': 'Готовая продукция',
    },
    'worker.progress.qty.rezka_frames': {
      'uz': 'Kadrlar ({count} ta)',
      'en': 'Frames ({count})',
      'ru': 'Кадры ({count} шт.)',
    },
    'worker.progress.qty.rezka_frame': {
      'uz': '{index}-kadr',
      'en': 'Frame {index}',
      'ru': '{index}-й кадр',
    },
    'worker.progress.qty.returned_paint_and_waste': {
      'uz': 'Qaytim va chiqindi',
      'en': 'Returned ink and waste',
      'ru': 'Возвратная краска и отходы',
    },
    'worker.progress.qty.note': {
      'uz': 'Izoh',
      'en': 'Note',
      'ru': 'Примечание',
    },
    'worker.progress.qty.optional_note': {
      'uz': 'Izoh (ixtiyoriy)',
      'en': 'Note (optional)',
      'ru': 'Примечание (необязательно)',
    },
    'worker.progress.qty.reason': {
      'uz': '0 yoki noodatiy tugatish sababi',
      'en': 'Reason for zero or partial completion',
      'ru': 'Причина нулевого или неполного завершения',
    },
    'worker.progress.qty.roll_required': {
      'uz': 'Babina kg kiriting',
      'en': 'Enter the roll weight',
      'ru': 'Введите вес бобины',
    },
    'worker.progress.qty.invalid_number': {
      'uz': 'To‘g‘ri raqam kiriting',
      'en': 'Enter a valid number',
      'ru': 'Введите корректное число',
    },
    'worker.progress.qty.positive_number': {
      'uz': '0 dan katta raqam kiriting',
      'en': 'Enter a value greater than 0',
      'ru': 'Введите значение больше 0',
    },
    'worker.progress.qty.waste_required': {
      'uz': 'Kamida bitta chiqindi maydonini to‘ldiring',
      'en': 'Fill in at least one waste field',
      'ru': 'Заполните хотя бы одно поле отходов',
    },
    'worker.progress.qty.returned_paint_invalid': {
      'uz': 'Qaytarilgan bo‘yoq qiymatlarini to‘g‘ri raqamda kiriting.',
      'en': 'Enter valid numbers for the returned-ink values.',
      'ru': 'Введите корректные числовые значения возвратной краски.',
    },
    'worker.progress.qty.returned_paint_min': {
      'uz':
          'Har bir tabda kamida 3 ta maydon to‘ldiring. Rasxot: {rasxot}/3, Astatka: {astatka}/3.',
      'en':
          'Fill in at least 3 fields on each tab. Waste: {rasxot}/3, Remainder: {astatka}/3.',
      'ru':
          'Заполните минимум 3 поля на каждой вкладке. Расход: {rasxot}/3, остаток: {astatka}/3.',
    },
    'worker.progress.qty.returned_paint_image': {
      'uz':
          'Kamida 3 ta qaytarilgan bo‘yoq maydonini to‘ldiring yoki rasm yuklang.',
      'en': 'Fill in at least 3 returned-ink fields or upload an image.',
      'ru':
          'Заполните минимум 3 поля возвратной краски или загрузите изображение.',
    },
    'worker.progress.qty.completion_reason': {
      'uz': '0 yoki to‘liq bo‘lmagan hisobot uchun sababini yozing.',
      'en': 'Enter a reason for zero or partial completion.',
      'ru': 'Укажите причину нулевого или неполного завершения.',
    },
    'worker.progress.qty.title.remove_roll': {
      'uz': 'Rulonni yechib tashlash',
      'en': 'Remove roll',
      'ru': 'Снять рулон',
    },
    'worker.progress.qty.title.pause': {
      'uz': 'Pauza miqdori',
      'en': 'Pause quantity',
      'ru': 'Количество для паузы',
    },
    'worker.progress.qty.title.detach_roll': {
      'uz': 'Rulonni yechish',
      'en': 'Remove roll',
      'ru': 'Снять рулон',
    },
    'worker.progress.qty.title.roll_complete': {
      'uz': 'Rulonni tugatish',
      'en': 'Finish roll',
      'ru': 'Завершить рулон',
    },
    'worker.progress.qty.title.complete': {
      'uz': 'Tugatish miqdori',
      'en': 'Completion quantity',
      'ru': 'Количество завершения',
    },
    'worker.progress.qty.subtitle.astatka': {
      'uz':
          'Bu faqat order astatkasini qayd qiladi. Pauza va Tugatish holati o‘zgarmaydi.',
      'en':
          'This only records the order remainder. The pause and completion states remain unchanged.',
      'ru':
          'Это только фиксирует остаток по заказу. Состояния паузы и завершения не меняются.',
    },
    'worker.progress.qty.subtitle.handoff': {
      'uz': 'Rulon apparatda qoladi. Astatka va chiqindini kiriting.',
      'en': 'The roll stays on the machine. Enter the remainder and waste.',
      'ru': 'Рулон остается на аппарате. Введите остаток и отходы.',
    },
    'worker.progress.qty.subtitle.remove_roll': {
      'uz': 'Rulon apparatdan olinadi. Metraj va og‘irlikni kiriting.',
      'en':
          'The roll will be removed from the machine. Enter its length and weight.',
      'ru': 'Рулон будет снят с аппарата. Введите его метраж и вес.',
    },
    'worker.progress.qty.subtitle.full_report': {
      'uz': '0 yoki to‘liq bo‘lmagan hisobot uchun izoh yozing',
      'en': 'Add a note for a zero or partial completion report',
      'ru': 'Добавьте примечание для нулевого или неполного отчета',
    },
    'worker.progress.qty.subtitle.current': {
      'uz': 'Joriy miqdorni kiriting',
      'en': 'Enter the current quantity',
      'ru': 'Введите текущее количество',
    },
    'worker.progress.qty.unit.meter': {
      'uz': 'metr',
      'en': 'm',
      'ru': 'м',
    },
    'worker.progress.qty.unit.kg': {
      'uz': 'kg',
      'en': 'kg',
      'ru': 'кг',
    },
    'worker.progress.qty.unit.mm': {
      'uz': 'mm',
      'en': 'mm',
      'ru': 'мм',
    },
    'worker.progress.qty.unit.roll': {
      'uz': 'ta',
      'en': 'rolls',
      'ru': 'шт.',
    },
    'worker.guide.intro': {
      'uz':
          'Bu yo‘riqnoma appdagi zakazni yuritish uchun. Pastda faqat sizga biriktirilgan apparatlar uchun ekrandagi tasdiqlar va tugatish formasi tushuntirilgan.',
      'en':
          'This guide explains how to manage orders in the app. It covers the checks and completion forms for the machines assigned to you.',
      'ru':
          'Эта инструкция объясняет работу с заказами в приложении. Ниже описаны проверки и формы завершения для назначенных вам аппаратов.',
    },
    'worker.guide.no_machine.title': {
      'uz': 'Sizga aparat biriktirilmagan',
      'en': 'No machine is assigned to you',
      'ru': 'Вам не назначен аппарат',
    },
    'worker.guide.no_machine.body': {
      'uz':
          'Admin profilingizga aparat biriktirgandan keyin app yo‘riqnomasi shu yerda ko‘rinadi.',
      'en':
          'The app guide will appear here after an admin assigns a machine to your profile.',
      'ru':
          'Инструкция появится здесь после того, как администратор назначит аппарат вашему профилю.',
    },
    'worker.guide.open_order.1': {
      'uz':
          'Yo‘riqnomadan chiqish uchun yuqoridagi ← tugmasini bosing. Siz Kuzatish sahifasiga qaytasiz.',
      'en':
          'Tap the ← button at the top to leave the guide and return to Monitoring.',
      'ru':
          'Нажмите ← вверху, чтобы выйти из инструкции и вернуться в раздел «Мониторинг».',
    },
    'worker.guide.open_order.2': {
      'uz':
          'Kuzatish sahifasini chap drawerdagi Kuzatish bandi orqali ham ochasiz.',
      'en':
          'You can also open Monitoring from the Monitoring item in the left drawer.',
      'ru': 'Раздел «Мониторинг» также можно открыть через левое боковое меню.',
    },
    'worker.guide.open_order.3': {
      'uz':
          'Kuzatishda apparat nomi yozilgan tabni bosing. Sizga biriktirilgan apparatlarda zakaz kartasi shu yerda chiqadi.',
      'en':
          'In Monitoring, tap the tab with the machine name. Order cards for your assigned machines appear there.',
      'ru':
          'В «Мониторинге» нажмите вкладку с названием аппарата. Здесь появятся карточки заказов назначенных вам аппаратов.',
    },
    'worker.guide.open_order.4': {
      'uz':
          'Agar Zakaz yo‘q yozuvi chiqsa, hozir bu apparatga faol zakaz berilmagan. Boshlash uchun karta chiqishini kuting.',
      'en':
          'If you see “No orders”, there is no active order for this machine. Wait for an order card before starting.',
      'ru':
          'Если отображается «Нет заказов», для аппарата сейчас нет активного заказа. Дождитесь карточки заказа.',
    },
    'worker.guide.open_order.5': {
      'uz':
          'Zakaz kartasi chiqqanda uning ustiga bosing. Keyingi ekranda mahsulot, metraj va og‘irlikni tekshiring.',
      'en':
          'When an order card appears, tap it. On the next screen, check the product, length, and weight.',
      'ru':
          'Когда появится карточка заказа, нажмите на нее. На следующем экране проверьте продукт, метраж и вес.',
    },
    'worker.guide.states_actions.1': {
      'uz':
          'Kutmoqda holatidagi zakazda shartlar bajarilgach Boshlash chiqadi. Navbatda oldinda boshqa zakaz bo‘lsa, siznikini boshlay olmaysiz.',
      'en':
          'For a queued order, Start appears after all checks pass. You cannot start while another order is ahead in the queue.',
      'ru':
          'Для заказа в очереди кнопка «Начать» появится после всех проверок. Нельзя начать заказ, пока впереди есть другой.',
    },
    'worker.guide.states_actions.2': {
      'uz': 'Jarayonda holatida Pauza va Tugatish tugmalari chiqadi.',
      'en':
          'When the order is in progress, Pause and Complete buttons are shown.',
      'ru':
          'В состоянии «В процессе» отображаются кнопки «Пауза» и «Завершить».',
    },
    'worker.guide.states_actions.3': {
      'uz':
          'Pauzada holatida faqat Davom ettirish chiqadi. U bosilganda forma ochilmaydi: zakaz yana Jarayonda holatiga o‘tadi.',
      'en':
          'When paused, only Resume is shown. Tapping it does not open a form; the order returns to In progress.',
      'ru':
          'В состоянии «На паузе» отображается только «Продолжить». Форма не открывается, заказ возвращается в работу.',
    },
    'worker.guide.states_actions.4': {
      'uz':
          'Admin buyurtmani muzlatishni so‘rasa, avval Pauza qiling. Muzlatilgan zakazni admin aktiv qilmaguncha davom ettirib bo‘lmaydi.',
      'en':
          'If an admin requests a freeze, pause the order first. A frozen order cannot continue until the admin activates it.',
      'ru':
          'Если администратор просит заморозить заказ, сначала поставьте его на паузу. Замороженный заказ нельзя продолжить без активации.',
    },
    'worker.guide.partial.1': {
      'uz':
          'Tugatish miqdorida 0 yoki to‘liq bo‘lmagan hisobot bo‘lsa, Izoh maydonidagi 0 yoki noodatiy tugatish sababi yozilmasa Tasdiqlash qabul qilinmaydi.',
      'en':
          'If the completion quantity is zero or incomplete, confirmation is rejected unless the Note field explains the zero or unusual completion.',
      'ru':
          'Если количество завершения равно нулю или отчет неполный, подтверждение отклоняется без причины в поле «Примечание».',
    },
    'worker.guide.partial.2': {
      'uz':
          'Sabab yozib Tasdiqlashni bossangiz, app Tugatish so‘rovi adminga yuborildi xabarini chiqaradi. Bu to‘liq tugatish emas, admin ko‘radigan so‘rov.',
      'en':
          'After entering a reason and tapping Confirm, the app sends a completion request to the admin. This is a request, not a full completion.',
      'ru':
          'После указания причины и нажатия «Подтвердить» приложение отправляет администратору запрос на завершение. Это не полное завершение.',
    },
    'worker.guide.partial.3': {
      'uz':
          'Pauza formasida izoh bilan chetlab o‘tish yo‘q: chiqarilgan maydonlarning har biri 0 dan katta, haqiqiy son bo‘lishi kerak.',
      'en':
          'The pause form has no note-based bypass: every displayed quantity must be a valid number greater than zero.',
      'ru':
          'В форме паузы нельзя обойти проверку примечанием: каждое отображаемое количество должно быть числом больше нуля.',
    },
    'worker.guide.kind.print.flexo': {
      'uz': 'Flexo bosma uchun app yo‘riqnomasi',
      'en': 'App guide for flexographic printing',
      'ru': 'Инструкция для флексографской печати',
    },
    'worker.guide.kind.print.color': {
      'uz': '{count} ta rangli bosma uchun app yo‘riqnomasi',
      'en': 'App guide for {count}-color printing',
      'ru': 'Инструкция для {count}-цветной печати',
    },
    'worker.guide.kind.lamination': {
      'uz': 'Laminatsiya uchun app yo‘riqnomasi',
      'en': 'App guide for lamination',
      'ru': 'Инструкция для ламинации',
    },
    'worker.guide.kind.cutting': {
      'uz': 'Rezka uchun app yo‘riqnomasi',
      'en': 'App guide for slitting',
      'ru': 'Инструкция для резки',
    },
    'worker.guide.kind.machine': {
      'uz': 'Ushbu apparat uchun app yo‘riqnomasi',
      'en': 'App guide for this machine',
      'ru': 'Инструкция для этого аппарата',
    },
    'worker.guide.print.start.1': {
      'uz':
          'Ish boshlash uchun homashyolar qatorini oching. Sarlavhadagi son barcha majburiy homashyo QR kodi tasdiqlanganda to‘ladi.',
      'en':
          'Open the materials section. Its count is complete when every required material QR code is confirmed.',
      'ru':
          'Откройте раздел сырья. Счетчик заполнится после подтверждения QR-кодов всего обязательного сырья.',
    },
    'worker.guide.print.start.2': {
      'uz':
          'Qoliplar qatorini oching va talab qilingan qoliplarning hammasini QR orqali tasdiqlang. Qoliplar soni to‘lmaguncha Boshlash faol bo‘lmaydi.',
      'en':
          'Open the Molds section and confirm every required mold by QR. Start stays disabled until the mold count is complete.',
      'ru':
          'Откройте раздел форм и подтвердите QR всех требуемых форм. «Начать» будет недоступна, пока счетчик не заполнен.',
    },
    'worker.guide.print.start.3': {
      'uz':
          'Oldingi bosqich QR qatori chiqsa, shu zakazning oldingi bosqichidan kelgan WIP QR kodini scan qiling.',
      'en':
          'If the previous-stage QR section appears, scan the WIP QR code produced by the previous stage of this order.',
      'ru':
          'Если появился раздел QR предыдущего этапа, отсканируйте QR WIP, выпущенного предыдущим этапом этого заказа.',
    },
    'worker.guide.print.start.4': {
      'uz':
          'Homashyo, qolip va oldingi bosqich talablari to‘lgandan keyin Boshlash tugmasini bosing.',
      'en':
          'Tap Start after the material, mold, and previous-stage requirements are complete.',
      'ru':
          'Нажмите «Начать» после выполнения требований по сырью, формам и предыдущему этапу.',
    },
    'worker.guide.print.pause.1': {
      'uz': 'Pauza tugmasini bosing. Pauza miqdori oynasi ochiladi.',
      'en': 'Tap Pause. The pause quantity form opens.',
      'ru': 'Нажмите «Пауза». Откроется форма количества паузы.',
    },
    'worker.guide.print.pause.2': {
      'uz':
          'Rulon almashganda Metraj (metr) va Og‘irlik (kg) maydonlarini hozirgi real qiymat bilan to‘ldiring. Pauzada Jami chiqindi va kraska astatkasi kiritilmaydi. 0 qabul qilinmaydi.',
      'en':
          'When changing a roll, enter the current Length (m) and Weight (kg). Total waste and ink remainder are not entered during a pause; zero is not accepted.',
      'ru':
          'При смене рулона укажите текущие метраж (м) и вес (кг). Во время паузы общие отходы и остаток краски не вводятся; ноль не принимается.',
    },
    'worker.guide.print.pause.3': {
      'uz':
          'Tasdiqlashni bosing, keyin chiqadigan printer tanlash oynasidan ishchi printerni tanlang. Printer tanlanmasa pauza yuborilmaydi.',
      'en':
          'Tap Confirm, then select the work printer. The pause is not sent if no printer is selected.',
      'ru':
          'Нажмите «Подтвердить» и выберите рабочий принтер. Без выбора принтера пауза не отправляется.',
    },
    'worker.guide.print.complete.1': {
      'uz':
          'Barcha rulonlar tugagach, oxirgi rulonda Tugatish tugmasini bosing. Order bo‘yicha jami chiqindini (Jami chiqindi), Metraj va Og‘irlikni bir marta kiriting.',
      'en':
          'After all rolls are finished, tap Complete on the last roll. Enter the order total waste, Length, and Weight once.',
      'ru':
          'После завершения всех рулонов нажмите «Завершить» на последнем. Один раз укажите общие отходы заказа, метраж и вес.',
    },
    'worker.guide.print.complete.2': {
      'uz':
          'Qaytarilgan bo‘yoq tugmasini bosing. Rasxot va Astatka tablarining har birida kamida 3 ta qiymat kiriting yoki qaytarilgan bo‘yoq rasmini yuklang.',
      'en':
          'Tap Returned ink. Enter at least three values on both Consumption and Remainder tabs, or upload a photo of the returned ink.',
      'ru':
          'Нажмите «Возвращенная краска». Введите минимум 3 значения на вкладках расхода и остатка или загрузите фото краски.',
    },
    'worker.guide.print.complete.3': {
      'uz':
          'Tasdiqlashdan keyin printer tanlang. To‘liq hisobot va printer tanlovi tasdiqlangach zakaz tugatiladi.',
      'en':
          'Select a printer after confirming. The order completes after the full report and printer selection are confirmed.',
      'ru':
          'После подтверждения выберите принтер. Заказ завершится после подтверждения полного отчета и принтера.',
    },
    'worker.guide.lamination.start.1': {
      'uz':
          'Ish boshlash uchun homashyolar qatorini oching va undagi majburiy homashyo QR kodlarini to‘liq tasdiqlang.',
      'en':
          'Open the materials section and confirm all required material QR codes.',
      'ru':
          'Откройте раздел сырья и подтвердите QR-коды всего обязательного сырья.',
    },
    'worker.guide.lamination.start.2': {
      'uz':
          'Oldingi bosqich QR qatori chiqsa, shu zakazning oldingi bosqichidan kelgan WIP QR kodini scan qiling.',
      'en':
          'If the previous-stage QR section appears, scan the WIP QR code from the previous stage of this order.',
      'ru':
          'Если появился QR предыдущего этапа, отсканируйте QR WIP с предыдущего этапа этого заказа.',
    },
    'worker.guide.lamination.start.3': {
      'uz':
          'Kerakli homashyo va oldingi bosqich QR tasdiqlanmaguncha Boshlash faol bo‘lmaydi.',
      'en':
          'Start stays disabled until the required materials and previous-stage QR are confirmed.',
      'ru':
          '«Начать» будет недоступна, пока не подтверждены сырье и QR предыдущего этапа.',
    },
    'worker.guide.lamination.pause.1': {
      'uz': 'Pauza tugmasini bosing. Pauza miqdori oynasi ochiladi.',
      'en': 'Tap Pause. The pause quantity form opens.',
      'ru': 'Нажмите «Пауза». Откроется форма количества паузы.',
    },
    'worker.guide.lamination.pause.2': {
      'uz':
          'Metraj (metr) va Og‘irlik (kg) maydonlarini hozirgi real qiymat bilan to‘ldiring. Pauzada Plyonkadan ortgan rulon ham, Jami chiqindi (atxot) ham kiritilmaydi. 0 qabul qilinmaydi.',
      'en':
          'Enter the current Length (m) and Weight (kg). Film leftovers and Total waste are not entered during a pause; zero is not accepted.',
      'ru':
          'Укажите текущие метраж (м) и вес (кг). Во время паузы остаток пленки и общие отходы не вводятся; ноль не принимается.',
    },
    'worker.guide.lamination.pause.3': {
      'uz':
          'Tasdiqlashdan keyin ishchi printerni tanlang. Printer tanlanmasa pauza yuborilmaydi.',
      'en':
          'Select the work printer after confirming. The pause is not sent without a printer.',
      'ru':
          'После подтверждения выберите рабочий принтер. Без принтера пауза не отправляется.',
    },
    'worker.guide.lamination.complete.1': {
      'uz':
          'Barcha rulonlar tugagach, oxirgi rulonda Tugatish tugmasini bosing. Bosmadan ortgan rulon va Plyonkadan ortgan rulon maydonlaridan kamida bittasini, shuningdek order bo‘yicha jami atxot miqdorini (Jami chiqindi), Metraj va Og‘irlikni bir marta kiriting.',
      'en':
          'After all rolls are finished, tap Complete on the last roll. Enter at least one print or film leftover roll, plus the order Total waste, Length, and Weight once.',
      'ru':
          'После завершения всех рулонов нажмите «Завершить» на последнем. Укажите хотя бы один остаток рулона печати или пленки, общие отходы, метраж и вес.',
    },
    'worker.guide.lamination.complete.2': {
      'uz':
          'Barcha qiymatlar haqiqiy va 0 dan katta bo‘lsa Tasdiqlashni bosing, keyin ishchi printerni tanlang.',
      'en':
          'When all values are valid and greater than zero, tap Confirm and select the work printer.',
      'ru':
          'Если все значения корректны и больше нуля, нажмите «Подтвердить» и выберите рабочий принтер.',
    },
    'worker.guide.lamination.complete.3': {
      'uz':
          'Bosma yoki plyonka qoldig‘i yo‘q bo‘lsa, to‘liq tugatish o‘tmaydi; sababli tugatish so‘rovini yuboring.',
      'en':
          'If there is no print or film leftover, full completion is rejected; send a completion request with a reason.',
      'ru':
          'Если нет остатка печати или пленки, полное завершение отклоняется; отправьте запрос с причиной.',
    },
    'worker.guide.cutting.start.1': {
      'uz':
          'Ish boshlash uchun homashyolar qatorida ko‘rsatilgan majburiy homashyo QR kodlarini to‘liq tasdiqlang.',
      'en':
          'Confirm all required material QR codes shown in the materials section before starting.',
      'ru':
          'Перед началом подтвердите все QR обязательного сырья из раздела материалов.',
    },
    'worker.guide.cutting.start.2': {
      'uz':
          'Oldingi bosqich QR qatori chiqsa, shu zakazga tegishli WIP QR kodini scan qiling.',
      'en':
          'If the previous-stage QR section appears, scan the WIP QR code for this order.',
      'ru':
          'Если появился QR предыдущего этапа, отсканируйте QR WIP этого заказа.',
    },
    'worker.guide.cutting.start.3': {
      'uz':
          'WIP nechta bo‘lakka bo‘linishi haqidagi blok chiqsa, undagi bo‘lak va kadr sonini ko‘rib oling. Shartlar to‘lgach Boshlashni bosing.',
      'en':
          'If the WIP split block appears, review the part and frame counts. Tap Start after all checks pass.',
      'ru':
          'Если появился блок разделения WIP, проверьте количество частей и кадров. После проверок нажмите «Начать».',
    },
    'worker.guide.cutting.pause.1': {
      'uz': 'Pauza tugmasini bosing. Pauza miqdori oynasi ochiladi.',
      'en': 'Tap Pause. The pause quantity form opens.',
      'ru': 'Нажмите «Пауза». Откроется форма количества паузы.',
    },
    'worker.guide.cutting.pause.2': {
      'uz':
          'Bosmachining chiqindisi, Laminatsiya chiqindisi, Tayyor mahsulot chetidan chiqqan chiqindi (uchalasi kg), Metraj va Og‘irlikni kiriting.',
      'en':
          'Enter print waste, lamination waste, edge waste (all in kg), Length, and Weight.',
      'ru':
          'Введите отходы печати, ламинации и кромки (все в кг), метраж и вес.',
    },
    'worker.guide.cutting.pause.3': {
      'uz':
          'Beshta miqdorning hammasi 0 dan katta bo‘lishi kerak. Tasdiqlashdan keyin ishchi printerni tanlang.',
      'en':
          'All five quantities must be greater than zero. Select the work printer after confirming.',
      'ru':
          'Все пять значений должны быть больше нуля. После подтверждения выберите рабочий принтер.',
    },
    'worker.guide.cutting.complete.1': {
      'uz':
          'Tugatish miqdorida Bosmachining chiqindisi, Laminatsiya chiqindisi va Tayyor mahsulot chetidan chiqqan chiqindini uchta alohida maydonga kiriting.',
      'en':
          'In the completion quantity form, enter print, lamination, and edge waste in their three separate fields.',
      'ru':
          'В форме завершения укажите отходы печати, ламинации и кромки в трех отдельных полях.',
    },
    'worker.guide.cutting.complete.2': {
      'uz':
          'Metraj va Og‘irlikni ham kiriting. Beshta miqdor to‘liq bo‘lgach Tasdiqlashni bosing va ishchi printerni tanlang.',
      'en':
          'Enter Length and Weight as well. When all five quantities are complete, tap Confirm and select the work printer.',
      'ru':
          'Также введите метраж и вес. После заполнения пяти значений нажмите «Подтвердить» и выберите принтер.',
    },
    'worker.guide.cutting.complete.3': {
      'uz':
          'Uchala chiqindi yoki Metraj va Og‘irlikdan biri yo‘q bo‘lsa, to‘liq tugatish qabul qilinmaydi.',
      'en':
          'Full completion is rejected if any of the three waste values, Length, or Weight is missing.',
      'ru':
          'Полное завершение отклоняется, если отсутствует любой из трех видов отходов, метраж или вес.',
    },
    'worker.guide.machine.start.1': {
      'uz':
          'Ish boshlash uchun homashyolar qatoridagi majburiy QR kodlarni tasdiqlang.',
      'en':
          'Confirm the required QR codes in the materials section before starting.',
      'ru': 'Перед началом подтвердите обязательные QR-коды в разделе сырья.',
    },
    'worker.guide.machine.start.2': {
      'uz':
          'Oldingi bosqich QR qatori chiqsa, shu zakazga tegishli WIP QR kodini scan qiling.',
      'en':
          'If the previous-stage QR section appears, scan the WIP QR code for this order.',
      'ru':
          'Если появился QR предыдущего этапа, отсканируйте QR WIP этого заказа.',
    },
    'worker.guide.machine.start.3': {
      'uz': 'Shartlar to‘lgach Boshlash tugmasini bosing.',
      'en': 'Tap Start after all checks pass.',
      'ru': 'После выполнения проверок нажмите «Начать».',
    },
    'worker.guide.machine.pause.1': {
      'uz':
          'Pauza tugmasini bosing va Pauza miqdori oynasidagi Metraj hamda Og‘irlikni kiriting.',
      'en': 'Tap Pause and enter Length and Weight in the pause quantity form.',
      'ru': 'Нажмите «Пауза» и введите метраж и вес в форме количества паузы.',
    },
    'worker.guide.machine.pause.2': {
      'uz':
          'Maydonlar 0 dan katta bo‘lgach Tasdiqlashni bosing, keyin ishchi printerni tanlang.',
      'en':
          'When the values are greater than zero, tap Confirm and select the work printer.',
      'ru':
          'После ввода значений больше нуля нажмите «Подтвердить» и выберите принтер.',
    },
    'worker.guide.machine.complete.1': {
      'uz':
          'Tugatish miqdori oynasidagi Metraj va Og‘irlikni haqiqiy qiymat bilan kiriting.',
      'en':
          'Enter the actual Length and Weight in the completion quantity form.',
      'ru': 'Введите фактические метраж и вес в форме количества завершения.',
    },
    'worker.guide.machine.complete.2': {
      'uz':
          'To‘liq qiymatlar bo‘lsa Tasdiqlashdan keyin ishchi printerni tanlang.',
      'en':
          'When the values are complete, tap Confirm and select the work printer.',
      'ru':
          'После ввода всех значений нажмите «Подтвердить» и выберите принтер.',
    },
    'worker.guide.machine.complete.3': {
      'uz':
          'Miqdor to‘liq bo‘lmasa, Izohga sababni yozib tugatish so‘rovini yuboring.',
      'en':
          'If the quantity is incomplete, enter the reason in Note and send a completion request.',
      'ru':
          'Если количество неполное, укажите причину в примечании и отправьте запрос на завершение.',
    },
    'qolip.nav.blocks': {
      'uz': 'Bloklarim',
      'en': 'Storage blocks',
      'ru': 'Мои блоки',
    },
    'qolip.nav.molds': {
      'uz': 'Qoliplar',
      'en': 'Molds',
      'ru': 'Формы',
    },
    'qolip.nav.ledger': {
      'uz': 'Qarz daftari',
      'en': 'Mold checkout ledger',
      'ru': 'Журнал выдачи форм',
    },
    'qolip.nav.transfer': {
      'uz': 'Joylashuv transferi',
      'en': 'Location transfer',
      'ru': 'Перемещение по ячейкам',
    },
    'qolip.nav.sequence': {
      'uz': 'Ketma-ketlik',
      'en': 'Sequence',
      'ru': 'Последовательность',
    },
    'qolip.action.add': {
      'uz': 'Qo‘shish',
      'en': 'Add',
      'ru': 'Добавить',
    },
    'qolip.action.edit': {
      'uz': 'Tahrirlash',
      'en': 'Edit',
      'ru': 'Изменить',
    },
    'qolip.action.delete': {
      'uz': 'O‘chirish',
      'en': 'Delete',
      'ru': 'Удалить',
    },
    'qolip.action.cancel': {
      'uz': 'Bekor qilish',
      'en': 'Cancel',
      'ru': 'Отмена',
    },
    'qolip.action.save': {
      'uz': 'Saqlash',
      'en': 'Save',
      'ru': 'Сохранить',
    },
    'qolip.action.continue': {
      'uz': 'Davom',
      'en': 'Continue',
      'ru': 'Продолжить',
    },
    'qolip.action.back': {
      'uz': 'Orqaga',
      'en': 'Back',
      'ru': 'Назад',
    },
    'qolip.action.retry': {
      'uz': 'Qayta urinish',
      'en': 'Try again',
      'ru': 'Повторить',
    },
    'qolip.action.return': {
      'uz': 'Qaytar',
      'en': 'Return',
      'ru': 'Вернуть',
    },
    'qolip.action.return_molds': {
      'uz': 'Qoliplarni qaytarib oldim',
      'en': 'Return molds',
      'ru': 'Вернуть формы',
    },
    'qolip.action.issue': {
      'uz': 'Berish',
      'en': 'Issue',
      'ru': 'Выдать',
    },
    'qolip.action.place': {
      'uz': 'Joylash',
      'en': 'Place',
      'ru': 'Разместить',
    },
    'qolip.action.move': {
      'uz': 'Ko‘chirish',
      'en': 'Move',
      'ru': 'Переместить',
    },
    'qolip.action.take': {
      'uz': 'Olish',
      'en': 'Take',
      'ru': 'Взять',
    },
    'qolip.action.select': {
      'uz': 'Tanlash',
      'en': 'Select',
      'ru': 'Выбрать',
    },
    'qolip.action.scan_qr': {
      'uz': 'QR scan',
      'en': 'Scan QR',
      'ru': 'Сканировать QR',
    },
    'qolip.action.confirm_selected': {
      'uz': 'Tanlangan qoliplarni tasdiqlash',
      'en': 'Confirm selected molds',
      'ru': 'Подтвердить выбранные формы',
    },
    'qolip.action.print_qr': {
      'uz': 'QR chiqarish',
      'en': 'Print QR',
      'ru': 'Печать QR',
    },
    'qolip.blocks.search': {
      'uz': 'Blok qidirish',
      'en': 'Search blocks',
      'ru': 'Поиск блоков',
    },
    'qolip.blocks.edit_title': {
      'uz': 'Blokni tahrirlash',
      'en': 'Edit block',
      'ru': 'Изменить блок',
    },
    'qolip.blocks.name': {
      'uz': 'Blok nomi',
      'en': 'Block name',
      'ru': 'Название блока',
    },
    'qolip.blocks.updated': {
      'uz': 'Blok tahrirlandi',
      'en': 'Block updated',
      'ru': 'Блок изменён',
    },
    'qolip.blocks.update_failed': {
      'uz': 'Blok tahrirlanmadi',
      'en': 'Could not update the block',
      'ru': 'Не удалось изменить блок',
    },
    'qolip.blocks.delete_title': {
      'uz': 'Blokni o‘chirasizmi?',
      'en': 'Delete block?',
      'ru': 'Удалить блок?',
    },
    'qolip.blocks.delete_message': {
      'uz': '{name} bloki butunlay o‘chiriladi.',
      'en': 'Block “{name}” will be permanently deleted.',
      'ru': 'Блок «{name}» будет удалён без возможности восстановления.',
    },
    'qolip.blocks.deleted': {
      'uz': 'Blok o‘chirildi',
      'en': 'Block deleted',
      'ru': 'Блок удалён',
    },
    'qolip.blocks.delete_failed': {
      'uz': 'Blok o‘chirilmadi',
      'en': 'Could not delete the block',
      'ru': 'Не удалось удалить блок',
    },
    'qolip.blocks.load_failed': {
      'uz': 'Bloklar yuklanmadi',
      'en': 'Could not load blocks',
      'ru': 'Не удалось загрузить блоки',
    },
    'qolip.blocks.empty': {
      'uz': 'Blok topilmadi',
      'en': 'No blocks found',
      'ru': 'Блоки не найдены',
    },
    'qolip.blocks.choose': {
      'uz': 'Blokni tanlang',
      'en': 'Select a block',
      'ru': 'Выберите блок',
    },
    'qolip.blocks.add': {
      'uz': 'Blok qo‘shish',
      'en': 'Add block',
      'ru': 'Добавить блок',
    },
    'qolip.blocks.warehouse': {
      'uz': 'Ombor',
      'en': 'Warehouse',
      'ru': 'Склад',
    },
    'qolip.products.add': {
      'uz': 'Qolip qo‘shish',
      'en': 'Add mold',
      'ru': 'Добавить форму',
    },
    'qolip.products.ledger': {
      'uz': 'Qarz daftari',
      'en': 'Checkout ledger',
      'ru': 'Журнал выдачи',
    },
    'qolip.products.delete_title': {
      'uz': 'Qoliplarni o‘chirasizmi?',
      'en': 'Delete molds?',
      'ru': 'Удалить формы?',
    },
    'qolip.products.delete_container_message': {
      'uz':
          '{products} ta mahsulotga biriktirilgan {molds} ta qolip o‘chiriladi.',
      'en': 'This will delete {molds} molds attached to {products} products.',
      'ru': 'Будут удалены {molds} форм, привязанных к {products} товарам.',
    },
    'qolip.products.delete_selected_message': {
      'uz': '{molds} ta tanlangan qolip o‘chiriladi.',
      'en': 'This will delete {molds} selected molds.',
      'ru': 'Будут удалены {molds} выбранных форм.',
    },
    'qolip.products.deleted': {
      'uz': '{count} ta qolip o‘chirildi',
      'en': '{count} molds deleted',
      'ru': 'Удалено форм: {count}',
    },
    'qolip.products.delete_failed': {
      'uz': 'Qoliplar o‘chirilmadi',
      'en': 'Could not delete the molds',
      'ru': 'Не удалось удалить формы',
    },
    'qolip.products.selection_cancel': {
      'uz': 'Tanlashni bekor qilish',
      'en': 'Cancel selection',
      'ru': 'Отменить выбор',
    },
    'qolip.products.selection_delete': {
      'uz': 'Tanlanganlarni o‘chirish',
      'en': 'Delete selected',
      'ru': 'Удалить выбранные',
    },
    'qolip.products.selection_print': {
      'uz': 'Tanlangan QR’larni chop etish',
      'en': 'Print selected QR codes',
      'ru': 'Печатать выбранные QR-коды',
    },
    'qolip.products.selection_summary': {
      'uz': '{total}/{selected} ta tanlandi',
      'en': '{selected} of {total} selected',
      'ru': 'Выбрано: {selected} из {total}',
    },
    'qolip.products.printed': {
      'uz': '{count} ta qolip QR chop etildi',
      'en': '{count} mold QR codes printed',
      'ru': 'QR-коды форм напечатаны: {count}',
    },
    'qolip.products.printed_partial': {
      'uz': '{success} ta QR chop etildi, {failed} tasi chop etilmadi',
      'en': '{success} QR codes printed, {failed} failed',
      'ru': 'Напечатано QR: {success}, с ошибкой: {failed}',
    },
    'qolip.products.qr_title': {
      'uz': 'Qolip QR',
      'en': 'Mold QR',
      'ru': 'QR формы',
    },
    'qolip.products.product_code': {
      'uz': 'Mahsulot kodi',
      'en': 'Product code',
      'ru': 'Код товара',
    },
    'qolip.products.size': {
      'uz': 'Razmer',
      'en': 'Size',
      'ru': 'Размер',
    },
    'qolip.products.customer': {
      'uz': 'Mijoz',
      'en': 'Customer',
      'ru': 'Клиент',
    },
    'qolip.products.qr_failed': {
      'uz': 'Qolip QR chop etilmadi',
      'en': 'Could not print the mold QR code',
      'ru': 'Не удалось напечатать QR формы',
    },
    'qolip.products.edit_title': {
      'uz': 'Qolipni tahrirlash',
      'en': 'Edit mold',
      'ru': 'Изменить форму',
    },
    'qolip.products.code': {
      'uz': 'Qolip code',
      'en': 'Mold code',
      'ru': 'Код формы',
    },
    'qolip.products.color': {
      'uz': 'Qolip rangi',
      'en': 'Mold color',
      'ru': 'Цвет формы',
    },
    'qolip.products.edit_failed': {
      'uz': 'Qolip tahrirlanmadi',
      'en': 'Could not update the mold',
      'ru': 'Не удалось изменить форму',
    },
    'qolip.products.search': {
      'uz': 'Mahsulot yoki qolip code',
      'en': 'Search by product or mold code',
      'ru': 'Поиск по товару или коду формы',
    },
    'qolip.products.empty': {
      'uz': 'Qolip topilmadi',
      'en': 'No molds found',
      'ru': 'Формы не найдены',
    },
    'qolip.products.search_empty': {
      'uz': 'Qidiruvda topilmadi',
      'en': 'No matching molds found',
      'ru': 'Совпадений не найдено',
    },
    'qolip.products.color_label': {
      'uz': 'Rang: {color}',
      'en': 'Color: {color}',
      'ru': 'Цвет: {color}',
    },
    'qolip.products.issued': {
      'uz': 'Ishchiga berilgan',
      'en': 'Issued to a worker',
      'ru': 'Выдано работнику',
    },
    'qolip.products.size_value': {
      'uz': '{size} razmer',
      'en': 'Size {size}',
      'ru': 'Размер {size}',
    },
    'qolip.products.count_in_use': {
      'uz': '{count} ta qolip • bittasi ishlatilmoqda',
      'en': '{count} molds • one is in use',
      'ru': '{count} форм • одна используется',
    },
    'qolip.products.mold_count': {
      'uz': '{count} ta qolip',
      'en': '{count} molds',
      'ru': '{count} форм',
    },
    'qolip.checkouts.title': {
      'uz': 'Qarz daftari',
      'en': 'Mold checkout ledger',
      'ru': 'Журнал выдачи форм',
    },
    'qolip.checkouts.search': {
      'uz': 'Qarzdan qidirish',
      'en': 'Search checkout records',
      'ru': 'Поиск по выдачам',
    },
    'qolip.checkouts.load_failed': {
      'uz': 'Qarz daftari yuklanmadi',
      'en': 'Could not load the checkout ledger',
      'ru': 'Не удалось загрузить журнал выдачи',
    },
    'qolip.checkouts.empty': {
      'uz': 'Qarzda qolip yo‘q',
      'en': 'No molds are currently checked out',
      'ru': 'Выданных форм нет',
    },
    'qolip.checkouts.search_empty': {
      'uz': 'Qidiruvda topilmadi',
      'en': 'No matching records found',
      'ru': 'Совпадений не найдено',
    },
    'qolip.checkouts.loading': {
      'uz': 'Qarz daftari yuklanmoqda',
      'en': 'Loading checkout ledger',
      'ru': 'Загрузка журнала выдачи',
    },
    'qolip.checkouts.return_to': {
      'uz': 'Qayerga qaytarasiz?',
      'en': 'Where should this be returned?',
      'ru': 'Куда вернуть?',
    },
    'qolip.checkouts.returned': {
      'uz': '{item} {cell} ga qaytdi',
      'en': '{item} was returned to {cell}',
      'ru': '{item} возвращено в ячейку {cell}',
    },
    'qolip.checkouts.return_failed': {
      'uz': 'Qolip qaytarilmadi',
      'en': 'The mold could not be returned',
      'ru': 'Не удалось вернуть форму',
    },
    'qolip.checkouts.draft_returned': {
      'uz': '{item} qoliplari qaytarildi',
      'en': 'Molds for {item} were returned',
      'ru': 'Формы для {item} возвращены',
    },
    'qolip.checkouts.draft_return_failed': {
      'uz': 'Qolip qaydi qaytarilmadi',
      'en': 'The mold checkout record could not be returned',
      'ru': 'Не удалось вернуть запись о выдаче формы',
    },
    'qolip.checkouts.draft': {
      'uz': 'Draft',
      'en': 'Draft',
      'ru': 'Черновик',
    },
    'qolip.checkouts.order': {
      'uz': 'Order: {id}',
      'en': 'Order: {id}',
      'ru': 'Заказ: {id}',
    },
    'qolip.checkouts.unknown_worker': {
      'uz': 'Noma’lum qolipchi',
      'en': 'Unknown worker',
      'ru': 'Неизвестный работник',
    },
    'qolip.checkouts.debt_type': {
      'uz': 'Qarz turi',
      'en': 'Checkout type',
      'ru': 'Тип выдачи',
    },
    'qolip.checkouts.order_draft': {
      'uz': 'Order drafti',
      'en': 'Order draft',
      'ru': 'Черновик заказа',
    },
    'qolip.checkouts.order_label': {
      'uz': 'Order',
      'en': 'Order',
      'ru': 'Заказ',
    },
    'qolip.checkouts.product': {
      'uz': 'Mahsulot',
      'en': 'Product',
      'ru': 'Товар',
    },
    'qolip.checkouts.item_code': {
      'uz': 'Item kodi',
      'en': 'Item code',
      'ru': 'Код позиции',
    },
    'qolip.checkouts.mold_codes': {
      'uz': 'Qolip kodlari',
      'en': 'Mold codes',
      'ru': 'Коды форм',
    },
    'qolip.checkouts.quantity': {
      'uz': 'Soni',
      'en': 'Quantity',
      'ru': 'Количество',
    },
    'qolip.checkouts.issued_at': {
      'uz': 'Berilgan vaqt',
      'en': 'Issued at',
      'ru': 'Время выдачи',
    },
    'qolip.checkouts.issued_to': {
      'uz': 'Kimga berilgan',
      'en': 'Issued to',
      'ru': 'Кому выдано',
    },
    'qolip.checkouts.mold_code': {
      'uz': 'Qolip kodi',
      'en': 'Mold code',
      'ru': 'Код формы',
    },
    'qolip.checkouts.size': {
      'uz': 'Razmer',
      'en': 'Size',
      'ru': 'Размер',
    },
    'qolip.checkouts.block': {
      'uz': 'Blok',
      'en': 'Block',
      'ru': 'Блок',
    },
    'qolip.checkouts.cell': {
      'uz': 'Joy',
      'en': 'Cell',
      'ru': 'Ячейка',
    },
    'qolip.checkouts.warehouse': {
      'uz': 'Ombor',
      'en': 'Warehouse',
      'ru': 'Склад',
    },
    'qolip.checkouts.order_id': {
      'uz': 'Order ID',
      'en': 'Order ID',
      'ru': 'ID заказа',
    },
    'qolip.checkouts.checkout_id': {
      'uz': 'Checkout ID',
      'en': 'Checkout ID',
      'ru': 'ID выдачи',
    },
    'qolip.transfer.title': {
      'uz': 'Joylashuv transferi',
      'en': 'Location transfer',
      'ru': 'Перемещение по ячейкам',
    },
    'qolip.transfer.heading': {
      'uz': 'Qolipni boshqa joyga ko‘chirish',
      'en': 'Move a mold to another location',
      'ru': 'Переместить форму в другую ячейку',
    },
    'qolip.transfer.description': {
      'uz':
          'Manba qolipni tanlang, keyin boriladigan blok va yacheykani belgilang.',
      'en':
          'Select the source mold, then choose the destination block and cell.',
      'ru': 'Выберите исходную форму, затем блок и ячейку назначения.',
    },
    'qolip.transfer.source_block': {
      'uz': 'Manba bloki',
      'en': 'Source block',
      'ru': 'Исходный блок',
    },
    'qolip.transfer.source_mold': {
      'uz': 'Ko‘chiriladigan qolip',
      'en': 'Mold to move',
      'ru': 'Форма для перемещения',
    },
    'qolip.transfer.target_block': {
      'uz': 'Boriladigan blok',
      'en': 'Destination block',
      'ru': 'Блок назначения',
    },
    'qolip.transfer.select_cell': {
      'uz': 'Yacheyka tanlash',
      'en': 'Select cell',
      'ru': 'Выбрать ячейку',
    },
    'qolip.transfer.cell': {
      'uz': 'Yacheyka: {cell}',
      'en': 'Cell: {cell}',
      'ru': 'Ячейка: {cell}',
    },
    'qolip.transfer.quantity': {
      'uz': 'Miqdor',
      'en': 'Quantity',
      'ru': 'Количество',
    },
    'qolip.transfer.max_quantity': {
      'uz': 'Maksimal {count} ta',
      'en': 'Maximum {count}',
      'ru': 'Максимум: {count}',
    },
    'qolip.transfer.move': {
      'uz': 'Joylashuvni ko‘chirish',
      'en': 'Move location',
      'ru': 'Переместить',
    },
    'qolip.transfer.moving': {
      'uz': 'Ko‘chirilmoqda...',
      'en': 'Moving...',
      'ru': 'Перемещение...',
    },
    'qolip.transfer.empty': {
      'uz': 'Blok mavjud emas',
      'en': 'No blocks available',
      'ru': 'Нет доступных блоков',
    },
    'qolip.transfer.source_required': {
      'uz': 'Avval ko‘chiriladigan qolipni tanlang',
      'en': 'Select a mold to move first',
      'ru': 'Сначала выберите форму для перемещения',
    },
    'qolip.transfer.cell_required': {
      'uz': 'Avval boriladigan yacheykani tanlang',
      'en': 'Select a destination cell first',
      'ru': 'Сначала выберите ячейку назначения',
    },
    'qolip.transfer.quantity_range': {
      'uz': 'Qolip soni 1 dan {max} gacha bo‘lishi kerak',
      'en': 'Quantity must be between 1 and {max}',
      'ru': 'Количество должно быть от 1 до {max}',
    },
    'qolip.transfer.invalid_cell': {
      'uz': 'Yacheyka noto‘g‘ri tanlangan',
      'en': 'The selected cell is invalid',
      'ru': 'Выбрана неверная ячейка',
    },
    'qolip.transfer.target_unconfirmed': {
      'uz': 'Server targetni tasdiqlamadi: {location}',
      'en': 'The server did not confirm the destination: {location}',
      'ru': 'Сервер не подтвердил назначение: {location}',
    },
    'qolip.transfer.moved': {
      'uz': '{item} {block} / {cell} ga ko‘chirildi',
      'en': '{item} was moved to {block} / {cell}',
      'ru': '{item} перемещено в {block} / {cell}',
    },
    'qolip.transfer.failed': {
      'uz': 'Ko‘chirish amalga oshmadi',
      'en': 'Could not move the mold',
      'ru': 'Не удалось переместить форму',
    },
    'qolip.cell_picker.title': {
      'uz': 'Joy tanlang',
      'en': 'Select a cell',
      'ru': 'Выберите ячейку',
    },
    'qolip.cell_picker.search_hint': {
      'uz': 'Masalan: A1, B3, C9',
      'en': 'For example: A1, B3, C9',
      'ru': 'Например: A1, B3, C9',
    },
    'qolip.cell_picker.no_match': {
      'uz': 'Mos joy topilmadi. A1 yoki B3 kabi yozing.',
      'en': 'No matching cells. Try a value such as A1 or B3.',
      'ru': 'Подходящие ячейки не найдены. Введите, например, A1 или B3.',
    },
    'qolip.cell_picker.select': {
      'uz': '{cell} — tanlash',
      'en': 'Select {cell}',
      'ru': 'Выбрать {cell}',
    },
    'qolip.cell_picker.other_matches': {
      'uz': 'Boshqa mos joylar',
      'en': 'Other matching cells',
      'ru': 'Другие подходящие ячейки',
    },
    'qolip.cell_picker.row': {
      'uz': 'Qator',
      'en': 'Row',
      'ru': 'Ряд',
    },
    'qolip.cell_picker.row_heading': {
      'uz': '{letter} qatori',
      'en': 'Row {letter}',
      'ru': 'Ряд {letter}',
    },
    'qolip.scanner.prompt.cell': {
      'uz': 'Yachayka QR kodini ramkaga keltiring',
      'en': 'Align the cell QR code within the frame',
      'ru': 'Поместите QR-код ячейки в рамку',
    },
    'qolip.scanner.prompt.mold': {
      'uz': 'Qolip QR kodini ramkaga keltiring',
      'en': 'Align the mold QR code within the frame',
      'ru': 'Поместите QR-код формы в рамку',
    },
    'qolip.scanner.prompt.universal': {
      'uz': 'Qolip yoki yachayka QR kodini ramkaga keltiring',
      'en': 'Align a mold or cell QR code within the frame',
      'ru': 'Поместите QR-код формы или ячейки в рамку',
    },
    'qolip.scanner.checking.cell': {
      'uz': 'Yachayka tekshirilmoqda...',
      'en': 'Checking cell...',
      'ru': 'Проверка ячейки...',
    },
    'qolip.scanner.checking.mold': {
      'uz': 'Qolip QR o‘qilmoqda...',
      'en': 'Reading mold QR code...',
      'ru': 'Чтение QR-кода формы...',
    },
    'qolip.scanner.checking.universal': {
      'uz': 'QR o‘qilmoqda...',
      'en': 'Reading QR code...',
      'ru': 'Чтение QR-кода...',
    },
    'qolip.scanner.title.cell': {
      'uz': 'Yachayka scan',
      'en': 'Scan cell QR',
      'ru': 'Сканировать QR ячейки',
    },
    'qolip.scanner.title.mold': {
      'uz': 'Qolip scan',
      'en': 'Scan mold QR',
      'ru': 'Сканировать QR формы',
    },
    'qolip.scanner.title.universal': {
      'uz': 'QR scan',
      'en': 'Scan QR',
      'ru': 'Сканировать QR',
    },
    'qolip.scanner.camera_failed': {
      'uz': 'Kamera ochilmadi',
      'en': 'Could not start the camera',
      'ru': 'Не удалось открыть камеру',
    },
    'qolip.scanner.camera_retry': {
      'uz': 'Kamera ochilmadi. Ruxsatlarni tekshirib qayta urinib ko‘ring.',
      'en': 'Could not start the camera. Check permissions and try again.',
      'ru':
          'Не удалось открыть камеру. Проверьте разрешения и повторите попытку.',
    },
    'qolip.scanner.not_found': {
      'uz': 'Bu QR yachayka uchun topilmadi.',
      'en': 'This QR code does not belong to a cell.',
      'ru': 'Этот QR-код не относится к ячейке.',
    },
    'qolip.scanner.empty': {
      'uz': 'Yachayka QR bo‘sh.',
      'en': 'The cell QR code is empty.',
      'ru': 'QR-код ячейки пуст.',
    },
    'qolip.scanner.check_failed': {
      'uz': 'Yachayka QR tekshirishda xatolik.',
      'en': 'Could not validate the cell QR code.',
      'ru': 'Ошибка проверки QR-кода ячейки.',
    },
    'qolip.scanner.unsupported': {
      'uz': 'Bu qurilmada QR scanner qo‘llab-quvvatlanmadi.',
      'en': 'QR scanning is not supported on this device.',
      'ru': 'Сканирование QR не поддерживается на этом устройстве.',
    },
    'qolip.scanner.unsupported_cell': {
      'uz': 'Bu qurilmada yachayka QR scanner qo‘llab-quvvatlanmadi.',
      'en': 'Cell QR scanning is not supported on this device.',
      'ru': 'Сканирование QR ячейки не поддерживается на этом устройстве.',
    },
    'qolip.scanner.flash_off': {
      'uz': 'Flash o‘chirish',
      'en': 'Turn flash off',
      'ru': 'Выключить вспышку',
    },
    'qolip.scanner.flash_on': {
      'uz': 'Flash yoqish',
      'en': 'Turn flash on',
      'ru': 'Включить вспышку',
    },
    'qolip.scanner.failed': {
      'uz': 'Scanner ishlamadi',
      'en': 'Scanner unavailable',
      'ru': 'Сканер недоступен',
    },
    'qolip.scanner.unavailable': {
      'uz': 'Scanner mavjud emas',
      'en': 'Scanner not available',
      'ru': 'Сканер недоступен',
    },
    'qolip.home.search': {
      'uz': 'Mahsulot qidirish',
      'en': 'Search products',
      'ru': 'Поиск товаров',
    },
    'qolip.home.load_failed': {
      'uz': 'Qoliplar yuklanmadi',
      'en': 'Could not load molds',
      'ru': 'Не удалось загрузить формы',
    },
    'qolip.home.cell_qr_printed': {
      'uz': '{cell} QR chop etildi: {payload}',
      'en': '{cell} QR code printed: {payload}',
      'ru': 'QR ячейки {cell} напечатан: {payload}',
    },
    'qolip.home.no_blocks_attached': {
      'uz': 'Block biriktirilmagan',
      'en': 'No blocks assigned',
      'ru': 'Блоки не назначены',
    },
    'qolip.home.no_blocks_added': {
      'uz': 'Blok qo‘shilmagan',
      'en': 'No blocks added',
      'ru': 'Блоки не добавлены',
    },
    'qolip.home.no_molds': {
      'uz': 'Bu blokda hali qolip yo‘q',
      'en': 'This block has no molds yet',
      'ru': 'В этом блоке пока нет форм',
    },
    'qolip.home.attach_hint': {
      'uz': 'Pastdagi Biriktirish tugmasi orqali qo‘shing',
      'en': 'Use the Attach button below to add one',
      'ru': 'Добавьте форму кнопкой «Привязать» ниже',
    },
    'qolip.home.unplaced': {
      'uz': 'Joylashmagan',
      'en': 'Unplaced',
      'ru': 'Не размещено',
    },
    'qolip.home.occupied_count': {
      'uz': '{count} ta joy band',
      'en': '{count} occupied cells',
      'ru': 'Занято ячеек: {count}',
    },
    'qolip.home.unplaced_count': {
      'uz': '{count} ta joylashmagan',
      'en': '{count} unplaced',
      'ru': 'Не размещено: {count}',
    },
    'qolip.home.cell': {
      'uz': 'Joy {cell}',
      'en': 'Cell {cell}',
      'ru': 'Ячейка {cell}',
    },
    'qolip.home.unplaced_molds': {
      'uz': 'Joylashmagan qolip ({count})',
      'en': 'Unplaced molds ({count})',
      'ru': 'Неразмещённые формы ({count})',
    },
    'qolip.home.move_from_other': {
      'uz': 'Boshqa joydan ko‘chirish ({count})',
      'en': 'Move from another cell ({count})',
      'ru': 'Переместить из другой ячейки ({count})',
    },
    'qolip.home.add_here': {
      'uz': 'Shu joyga qolip qo‘shish',
      'en': 'Add a mold to this cell',
      'ru': 'Добавить форму в эту ячейку',
    },
    'qolip.home.choose_unplaced': {
      'uz': 'Joylashmagan qolip tanlang',
      'en': 'Select an unplaced mold',
      'ru': 'Выберите неразмещённую форму',
    },
    'qolip.home.choose_move': {
      'uz': 'Ko‘chiriladigan qolip tanlang',
      'en': 'Select a mold to move',
      'ru': 'Выберите форму для перемещения',
    },
    'qolip.home.choose_worker': {
      'uz': 'Ishchini tanlang',
      'en': 'Select a worker',
      'ru': 'Выберите работника',
    },
    'qolip.home.worker_search': {
      'uz': 'Ishchi nomi bilan qidiring',
      'en': 'Search by worker name',
      'ru': 'Поиск по имени работника',
    },
    'qolip.home.mold_count': {
      'uz': 'Qolip soni',
      'en': 'Mold quantity',
      'ru': 'Количество форм',
    },
    'qolip.home.max_count': {
      'uz': 'Eng ko‘pi {count} ta',
      'en': 'Maximum {count}',
      'ru': 'Максимум: {count}',
    },
    'qolip.home.invalid_count': {
      'uz': 'Qolip soni noto‘g‘ri',
      'en': 'Enter a valid mold quantity',
      'ru': 'Введите корректное количество форм',
    },
    'qolip.home.only_count': {
      'uz': 'Joyda faqat {count} ta bor',
      'en': 'Only {count} available in this cell',
      'ru': 'В этой ячейке доступно только: {count}',
    },
    'qolip.home.issue_title': {
      'uz': 'Qolip berish',
      'en': 'Issue mold',
      'ru': 'Выдать форму',
    },
    'qolip.home.scan': {
      'uz': 'QR Scan',
      'en': 'Scan QR',
      'ru': 'Сканировать QR',
    },
    'qolip.home.attach': {
      'uz': 'Biriktirish',
      'en': 'Attach',
      'ru': 'Привязать',
    },
    'qolip.home.issue_confirm_title': {
      'uz': 'Qoliplarni berasizmi?',
      'en': 'Issue these molds?',
      'ru': 'Выдать эти формы?',
    },
    'qolip.home.issue_confirm_message': {
      'uz':
          '{count} ta tanlangan qolipni {worker}ga qarzga berasizmi? Har biridan 1 tadan beriladi.',
      'en':
          'Issue {count} selected molds to {worker}? One mold will be issued from each location.',
      'ru':
          'Выдать {count} выбранных форм работнику {worker}? Из каждой ячейки будет выдана одна форма.',
    },
    'qolip.home.issued_to': {
      'uz': '{count} ta qolip {worker}ga berildi',
      'en': '{count} molds issued to {worker}',
      'ru': '{count} форм выдано работнику {worker}',
    },
    'qolip.home.issued_partial': {
      'uz': '{success} ta qolip berildi, {failed} tasi berilmadi',
      'en': '{success} molds issued; {failed} could not be issued',
      'ru': 'Выдано форм: {success}; не выдано: {failed}',
    },
    'qolip.home.no_placed_for_issue': {
      'uz': 'Berish uchun joylashtirilgan qolip yo‘q',
      'en': 'No placed molds are available to issue',
      'ru': 'Нет размещённых форм для выдачи',
    },
    'qolip.home.issue_picker_title': {
      'uz': 'Beriladigan qolipni tanlang',
      'en': 'Select molds to issue',
      'ru': 'Выберите формы для выдачи',
    },
    'qolip.home.mold_code_or_product_search': {
      'uz': 'Qolip code yoki mahsulot nomi',
      'en': 'Search by mold code or product name',
      'ru': 'Поиск по коду формы или названию товара',
    },
    'qolip.home.qr_lookup_failed': {
      'uz': 'QR bo‘yicha qolip yoki yachayka topilmadi',
      'en': 'No mold or cell was found for this QR code',
      'ru': 'По этому QR-коду форма или ячейка не найдена',
    },
    'qolip.home.qr_check_failed': {
      'uz': 'QR tekshirish amalga oshmadi',
      'en': 'Could not validate the QR code',
      'ru': 'Не удалось проверить QR-код',
    },
    'qolip.home.cell_not_assigned': {
      'uz': 'Bu yachayka sizga biriktirilmagan',
      'en': 'This cell is not assigned to you',
      'ru': 'Эта ячейка вам не назначена',
    },
    'qolip.home.cell_title': {
      'uz': 'Yachayka {cell}',
      'en': 'Cell {cell}',
      'ru': 'Ячейка {cell}',
    },
    'qolip.home.add_mold': {
      'uz': 'Qolip kiritish',
      'en': 'Add mold',
      'ru': 'Добавить форму',
    },
    'qolip.home.empty_cell': {
      'uz': 'Qolip olish — yachayka bo‘sh',
      'en': 'Take mold — cell is empty',
      'ru': 'Взять форму — ячейка пуста',
    },
    'qolip.home.take_count': {
      'uz': 'Qolip olish ({count})',
      'en': 'Take mold ({count})',
      'ru': 'Взять форму ({count})',
    },
    'qolip.home.choose_mold_from_cell': {
      'uz': '{cell} dan qolip tanlang',
      'en': 'Select a mold from {cell}',
      'ru': 'Выберите форму из ячейки {cell}',
    },
    'qolip.home.not_in_cell': {
      'uz': 'Hozir yachaykaga joylashtirilmagan',
      'en': 'Not currently placed in a cell',
      'ru': 'Сейчас не размещено в ячейке',
    },
    'qolip.home.place_in_cell': {
      'uz': 'Yachaykaga joylash',
      'en': 'Place in a cell',
      'ru': 'Разместить в ячейке',
    },
    'qolip.home.place_in_other_cell': {
      'uz': 'Boshqa yachaykaga joylash',
      'en': 'Place in another cell',
      'ru': 'Разместить в другой ячейке',
    },
    'qolip.home.issue_to_worker': {
      'uz': 'Ishchiga berish',
      'en': 'Issue to worker',
      'ru': 'Выдать работнику',
    },
    'qolip.home.place_before_issue': {
      'uz': 'Ishchiga berishdan oldin qolipni yachaykaga joylang.',
      'en': 'Place the mold in a cell before issuing it to a worker.',
      'ru': 'Разместите форму в ячейке перед выдачей работнику.',
    },
    'qolip.home.choose_cell_method': {
      'uz': 'Yachaykani qanday tanlaysiz?',
      'en': 'How would you like to select the cell?',
      'ru': 'Как выбрать ячейку?',
    },
    'qolip.home.cell_qr_scan': {
      'uz': 'Yachayka QR scan',
      'en': 'Scan cell QR',
      'ru': 'Сканировать QR ячейки',
    },
    'qolip.home.select_from_list': {
      'uz': 'Ro‘yxatdan tanlash',
      'en': 'Select from list',
      'ru': 'Выбрать из списка',
    },
    'qolip.home.select_cell': {
      'uz': '{block}: yacheykani tanlang',
      'en': '{block}: select a cell',
      'ru': '{block}: выберите ячейку',
    },
    'qolip.home.moved_to': {
      'uz': '{item} {block} • {cell} ga joylandi',
      'en': '{item} was placed in {block} • {cell}',
      'ru': '{item} размещено в {block} • {cell}',
    },
    'qolip.home.place_failed': {
      'uz': 'Qolip joylashtirilmadi',
      'en': 'Could not place the mold',
      'ru': 'Не удалось разместить форму',
    },
    'qolip.home.block_select': {
      'uz': 'Blokni tanlang',
      'en': 'Select a block',
      'ru': 'Выберите блок',
    },
    'qolip.home.mold_count_stat': {
      'uz': '{count} ta qolip',
      'en': '{count} molds',
      'ru': '{count} форм',
    },
    'qolip.home.move': {
      'uz': 'Ko‘chirish',
      'en': 'Move',
      'ru': 'Переместить',
    },
    'qolip.home.take': {
      'uz': 'Olish',
      'en': 'Take',
      'ru': 'Взять',
    },
    'qolip.home.customer_unassigned': {
      'uz': 'Mijoz biriktirilmagan',
      'en': 'No customer assigned',
      'ru': 'Клиент не назначен',
    },
    'qolip.home.take_failed': {
      'uz': 'Qolip olish amalga oshmadi',
      'en': 'Could not issue the mold',
      'ru': 'Не удалось выдать форму',
    },
    'qolip.home.borrow': {
      'uz': 'Qarzga berish',
      'en': 'Issue on checkout',
      'ru': 'Выдать под ответственность',
    },
    'qolip.home.block_add_title': {
      'uz': 'Blok qo‘shish',
      'en': 'Add block',
      'ru': 'Добавить блок',
    },
    'qolip.home.mold_storage_attach': {
      'uz': 'Qolipni omborga biriktirish',
      'en': 'Add mold to storage',
      'ru': 'Добавить форму на склад',
    },
    'qolip.home.mold_select_title': {
      'uz': 'Qolip tanlang',
      'en': 'Select a mold',
      'ru': 'Выберите форму',
    },
    'qolip.home.ready_product_select_title': {
      'uz': 'Tayyor mahsulot tanlang',
      'en': 'Select a finished product',
      'ru': 'Выберите готовый товар',
    },
    'qolip.home.mold_code_customer_search': {
      'uz': 'Qolip code, mahsulot yoki customer nomi',
      'en': 'Search by mold code, product, or customer',
      'ru': 'Поиск по коду формы, товару или клиенту',
    },
    'qolip.home.product_customer_search': {
      'uz': 'Mahsulot yoki customer nomi bilan qidiring',
      'en': 'Search by product or customer',
      'ru': 'Поиск по товару или клиенту',
    },
    'qolip.home.qr_not_found': {
      'uz': 'Qolip QR topilmadi',
      'en': 'Mold QR code not found',
      'ru': 'QR формы не найден',
    },
    'qolip.home.size_invalid': {
      'uz': 'Razmerni to‘g‘ri kiriting',
      'en': 'Enter a valid size',
      'ru': 'Введите корректный размер',
    },
    'qolip.home.code_range': {
      'uz': 'Qolip code oxirgi qismi 1–100 oralig‘ida bo‘lishi kerak',
      'en': 'The last part of the mold code must be between 1 and 100',
      'ru': 'Последняя часть кода формы должна быть от 1 до 100',
    },
    'qolip.home.colors_required': {
      'uz': '{count} ta qolip uchun {count} ta rang tanlang',
      'en': 'Select {count} colors for {count} molds',
      'ru': 'Выберите {count} цвета для {count} форм',
    },
    'qolip.home.one_color': {
      'uz': 'Bitta qolip uchun bitta rang tanlang',
      'en': 'Select one color for a single mold',
      'ru': 'Для одной формы выберите один цвет',
    },
    'qolip.home.batch_response': {
      'uz': 'Qolip batch javobi to‘liq emas',
      'en': 'The mold batch response is incomplete',
      'ru': 'Неполный ответ по партии форм',
    },
    'qolip.home.save_failed': {
      'uz': 'Qoliplar saqlanmadi',
      'en': 'Could not save the molds',
      'ru': 'Не удалось сохранить формы',
    },
    'qolip.home.place_confirm_title': {
      'uz': 'Qoliplarni joylaysizmi?',
      'en': 'Place these molds?',
      'ru': 'Разместить эти формы?',
    },
    'qolip.home.place_confirm_message': {
      'uz':
          '{count} ta tanlangan qolipni {block} • {cell} yachaykaga joylaysizmi?',
      'en': 'Place {count} selected molds in cell {block} • {cell}?',
      'ru': 'Разместить {count} выбранных форм в ячейке {block} • {cell}?',
    },
    'qolip.home.saved_one': {
      'uz': '{code} {cell} ga joylandi',
      'en': '{code} was placed in {cell}',
      'ru': '{code} размещено в {cell}',
    },
    'qolip.home.saved_many': {
      'uz': '{count} ta qolip {cell} ga joylandi',
      'en': '{count} molds were placed in {cell}',
      'ru': '{count} форм размещено в ячейке {cell}',
    },
    'qolip.home.place_all_failed': {
      'uz': 'Qoliplar joylashtirilmadi',
      'en': 'Could not place the molds',
      'ru': 'Не удалось разместить формы',
    },
    'qolip.home.place_partial': {
      'uz': '{success} ta qolip joylandi, {failed} tasi joylanmadi',
      'en': '{success} molds placed; {failed} could not be placed',
      'ru': 'Размещено форм: {success}; не размещено: {failed}',
    },
    'qolip.home.qr_printed': {
      'uz': '{count} ta qolip QR chop etildi',
      'en': '{count} mold QR codes printed',
      'ru': 'Напечатано QR форм: {count}',
    },
    'qolip.home.qr_print_failed': {
      'uz': 'Qolip QR chop etilmadi',
      'en': 'Could not print the mold QR code',
      'ru': 'Не удалось напечатать QR формы',
    },
    'qolip.home.storage_attach': {
      'uz': 'Qolipni omborga biriktirish',
      'en': 'Add mold to storage',
      'ru': 'Добавить форму на склад',
    },
    'qolip.home.cell_attach': {
      'uz': 'Qolipni joyga qo‘shish',
      'en': 'Add mold to cell',
      'ru': 'Добавить форму в ячейку',
    },
    'qolip.home.qr_scan_tooltip': {
      'uz': 'Qolip QR scan',
      'en': 'Scan mold QR',
      'ru': 'Сканировать QR формы',
    },
    'qolip.home.location': {
      'uz': 'Joy',
      'en': 'Cell',
      'ru': 'Ячейка',
    },
    'qolip.home.code_or_product': {
      'uz': 'Qolip code / mahsulot',
      'en': 'Mold code / product',
      'ru': 'Код формы / товар',
    },
    'qolip.home.ready_product': {
      'uz': 'Tayyor mahsulot',
      'en': 'Finished product',
      'ru': 'Готовый товар',
    },
    'qolip.home.mold_code_or_product_hint': {
      'uz': 'Qolip code yoki mahsulot nomi',
      'en': 'Search by mold code or product name',
      'ru': 'Поиск по коду формы или названию товара',
    },
    'qolip.home.product_search_hint': {
      'uz': 'Mahsulot nomi bilan qidirish',
      'en': 'Search by product name',
      'ru': 'Поиск по названию товара',
    },
    'qolip.home.mold_code_label': {
      'uz': 'Qolip code',
      'en': 'Mold code',
      'ru': 'Код формы',
    },
    'qolip.home.size_label': {
      'uz': 'Razmeri',
      'en': 'Size',
      'ru': 'Размер',
    },
    'qolip.home.color_label': {
      'uz': 'Qolip rangi ({selected}/{total})',
      'en': 'Mold colors ({selected}/{total})',
      'ru': 'Цвета форм ({selected}/{total})',
    },
    'qolip.home.mold_label': {
      'uz': 'Qolip',
      'en': 'Mold',
      'ru': 'Форма',
    },
    'qolip.color.red': {
      'uz': 'Qizil',
      'en': 'Red',
      'ru': 'Красный',
    },
    'qolip.color.orange': {
      'uz': 'To‘q sariq',
      'en': 'Orange',
      'ru': 'Оранжевый',
    },
    'qolip.color.yellow': {
      'uz': 'Sariq',
      'en': 'Yellow',
      'ru': 'Жёлтый',
    },
    'qolip.color.green': {
      'uz': 'Yashil',
      'en': 'Green',
      'ru': 'Зелёный',
    },
    'qolip.color.cyan': {
      'uz': 'Moviy',
      'en': 'Cyan',
      'ru': 'Голубой',
    },
    'qolip.color.blue': {
      'uz': 'Ko‘k',
      'en': 'Blue',
      'ru': 'Синий',
    },
    'qolip.color.indigo': {
      'uz': 'To‘q ko‘k',
      'en': 'Indigo',
      'ru': 'Индиго',
    },
    'qolip.color.purple': {
      'uz': 'Binafsha',
      'en': 'Purple',
      'ru': 'Фиолетовый',
    },
    'qolip.color.pink': {
      'uz': 'Pushti',
      'en': 'Pink',
      'ru': 'Розовый',
    },
    'qolip.color.brown': {
      'uz': 'Jigarrang',
      'en': 'Brown',
      'ru': 'Коричневый',
    },
    'qolip.color.gold': {
      'uz': 'Tilla',
      'en': 'Gold',
      'ru': 'Золотой',
    },
    'qolip.color.gray': {
      'uz': 'Kulrang',
      'en': 'Gray',
      'ru': 'Серый',
    },
    'qolip.color.silver': {
      'uz': 'Matlak',
      'en': 'Silver',
      'ru': 'Серебристый',
    },
    'qolip.color.black': {
      'uz': 'Qora',
      'en': 'Black',
      'ru': 'Чёрный',
    },
    'qolip.color.white': {
      'uz': 'Oq',
      'en': 'White',
      'ru': 'Белый',
    },
    'qolip.error.insufficient_stock': {
      'uz': 'Joyda yetarli qolip qolmadi',
      'en': 'There are not enough molds in this cell',
      'ru': 'В этой ячейке недостаточно форм',
    },
    'qolip.error.location_not_found': {
      'uz': 'Qolip joyi topilmadi',
      'en': 'Mold location not found',
      'ru': 'Место формы не найдено',
    },
    'qolip.error.location_invalid': {
      'uz': 'Joy noto‘g‘ri tanlangan',
      'en': 'The selected location is invalid',
      'ru': 'Выбрано неверное место',
    },
    'qolip.error.checkout_not_found': {
      'uz': 'Berilgan qolip topilmadi',
      'en': 'The checked-out mold was not found',
      'ru': 'Выданная форма не найдена',
    },
    'qolip.error.checkout_not_returnable': {
      'uz': 'Bu qolipni qaytarib bo‘lmaydi',
      'en': 'This mold cannot be returned',
      'ru': 'Эту форму нельзя вернуть',
    },
    'qolip.error.checkout_required': {
      'uz': 'Qolip avval workerga qarzga berilishi kerak',
      'en': 'The mold must be checked out to a worker first',
      'ru': 'Сначала форму нужно выдать работнику',
    },
    'qolip.error.assigned_to_another': {
      'uz': 'Qolip boshqa workerga berilgan',
      'en': 'This mold is checked out to another worker',
      'ru': 'Форма выдана другому работнику',
    },
    'qolip.error.worker_required': {
      'uz': 'Ishchini tanlang',
      'en': 'Select a worker',
      'ru': 'Выберите работника',
    },
    'qolip.error.worker_not_found': {
      'uz': 'Ishchi topilmadi',
      'en': 'Worker not found',
      'ru': 'Работник не найден',
    },
    'qolip.error.quantity_required': {
      'uz': 'Qolip soni noto‘g‘ri',
      'en': 'Enter a valid mold quantity',
      'ru': 'Введите корректное количество форм',
    },
    'qolip.error.location_identity_mismatch': {
      'uz': 'Bu joyda boshqa qolip bor. Avval mavjud qolipni ko‘chiring',
      'en': 'Another mold is already in this location. Move it first',
      'ru': 'В этом месте уже есть другая форма. Сначала переместите её',
    },
    'qolip.error.in_use': {
      'uz': 'Qolip ishchiga berilgan yoki aktiv orderda ishlatilmoqda',
      'en': 'The mold is issued to a worker or used by an active order',
      'ru': 'Форма выдана работнику или используется в активном заказе',
    },
    'qolip.error.code_conflict': {
      'uz': 'Bu qolip code allaqachon mavjud',
      'en': 'This mold code already exists',
      'ru': 'Такой код формы уже существует',
    },
    'qolip.error.panton_limit': {
      'uz': 'Panton 1–100 band. Yangi Panton biriktirib bo‘lmaydi',
      'en': 'PANTONE numbers 1–100 are already in use',
      'ru': 'Номера PANTONE от 1 до 100 уже заняты',
    },
    'qolip.error.block_in_use': {
      'uz':
          'Blokda qolip yoki qaytarilmagan berish bor. Uni o‘chirib bo‘lmaydi',
      'en':
          'This block has molds or outstanding checkouts and cannot be deleted',
      'ru': 'В блоке есть формы или незакрытые выдачи. Его нельзя удалить',
    },
    'qolip.error.block_exists': {
      'uz': 'Bu nomdagi blok allaqachon mavjud',
      'en': 'A block with this name already exists',
      'ru': 'Блок с таким названием уже существует',
    },
    'qolip.error.block_not_found': {
      'uz': 'Blok topilmadi',
      'en': 'Block not found',
      'ru': 'Блок не найден',
    },
    'qolip.error.forbidden': {
      'uz': 'Bu amal uchun ruxsat yo‘q',
      'en': 'You do not have permission to perform this action',
      'ru': 'У вас нет разрешения на это действие',
    },
    'qolip.error.unauthorized': {
      'uz': 'Sessiya tugagan. Qayta kiring',
      'en': 'Your session has expired. Sign in again',
      'ru': 'Сессия завершена. Войдите снова',
    },
  };

  String productionText(
    String key, {
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    final translations = _productionTranslations[key];
    var value =
        translations?[locale.languageCode] ?? translations?['en'] ?? key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }

  String adminText(
    String key, {
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    final translations = adminTranslations['admin.$key'];
    var value =
        translations?[locale.languageCode] ?? translations?['en'] ?? key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }

  String productionCount(int count, {String kind = 'items'}) {
    if (isUzbek) {
      return '$count ta';
    }
    if (isRussian) {
      return switch (kind) {
        'molds' => '$count форм',
        'materials' => '$count материалов',
        _ => '$count шт.',
      };
    }
    final noun = switch (kind) {
      'molds' => count == 1 ? 'mold' : 'molds',
      'materials' => count == 1 ? 'material' : 'materials',
      _ => count == 1 ? 'item' : 'items',
    };
    return '$count $noun';
  }

  String qolipText(
    String key, {
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    return productionText('qolip.$key', values: values);
  }

  String qolipCount(int count) {
    if (isUzbek) {
      return '$count ta qolip';
    }
    return productionCount(count, kind: 'molds');
  }

  String qolipQuantityShort(int count) {
    if (isUzbek) {
      return '$count ta';
    }
    return qolipCount(count);
  }

  String qolipColorName(String raw) {
    final normalized = raw.trim().toUpperCase();
    final key = switch (normalized) {
      '#E53935' || 'QIZIL' => 'qolip.color.red',
      '#FB8C00' || 'TO‘Q SARIQ' || 'TO\'Q SARIQ' => 'qolip.color.orange',
      '#FDD835' || 'SARIQ' => 'qolip.color.yellow',
      '#43A047' || 'YASHIL' => 'qolip.color.green',
      '#00ACC1' || 'MOVIY' => 'qolip.color.cyan',
      '#1E88E5' || 'KO‘K' || 'KO\'K' => 'qolip.color.blue',
      '#3949AB' || 'TO‘Q KO‘K' || 'TO\'Q KO\'K' => 'qolip.color.indigo',
      '#8E24AA' || 'BINAFSHA' => 'qolip.color.purple',
      '#D81B60' || 'PUSHTI' => 'qolip.color.pink',
      '#6D4C41' || 'JIGARRANG' => 'qolip.color.brown',
      '#D4A72C' || 'TILLA' => 'qolip.color.gold',
      '#757575' || 'KULRANG' => 'qolip.color.gray',
      '#B7BCC2' || 'MATLAK' => 'qolip.color.silver',
      '#212121' || 'QORA' => 'qolip.color.black',
      '#FFFFFF' || 'OQ' => 'qolip.color.white',
      _ => '',
    };
    return key.isEmpty ? raw : productionText(key);
  }

  String qolipErrorText(String code, {String fallback = ''}) {
    final key = switch (code.trim().toLowerCase()) {
      'insufficient_stock' => 'qolip.error.insufficient_stock',
      'location_not_found' => 'qolip.error.location_not_found',
      'location_invalid' => 'qolip.error.location_invalid',
      'checkout_not_found' => 'qolip.error.checkout_not_found',
      'checkout_not_returnable' => 'qolip.error.checkout_not_returnable',
      'qolip_checkout_required' => 'qolip.error.checkout_required',
      'qolip_checkout_assigned_to_another_worker' =>
        'qolip.error.assigned_to_another',
      'worker_required' => 'qolip.error.worker_required',
      'worker_not_found' => 'qolip.error.worker_not_found',
      'quantity_required' => 'qolip.error.quantity_required',
      'location_identity_mismatch' => 'qolip.error.location_identity_mismatch',
      'qolip_in_use' => 'qolip.error.in_use',
      'qolip_code_conflict' => 'qolip.error.code_conflict',
      'panton_limit_exceeded' => 'qolip.error.panton_limit',
      'block_in_use' => 'qolip.error.block_in_use',
      'block_exists' => 'qolip.error.block_exists',
      'block_not_found' => 'qolip.error.block_not_found',
      'forbidden' => 'qolip.error.forbidden',
      'unauthorized' => 'qolip.error.unauthorized',
      _ when code.contains('insufficient_stock') =>
        'qolip.error.insufficient_stock',
      _ when code.contains('location_not_found') =>
        'qolip.error.location_not_found',
      _ => '',
    };
    return key.isEmpty ? fallback : productionText(key);
  }

  String productionErrorMessage(
    String code, {
    String fallback = '',
  }) {
    final key = switch (code.trim().toLowerCase()) {
      'qolip_scan_incomplete' => 'worker.error.scan_molds',
      'raw_material_rule_missing' => 'worker.error.rule_failed',
      'raw_material_rule_load_failed' => 'worker.error.rule_failed',
      'raw_materials_missing' => 'worker.error.no_materials',
      'raw_material_groups_incomplete' =>
        'worker.error.incomplete_material_groups',
      'raw_materials_not_at_apparatus' =>
        'worker.error.material_not_at_machine',
      'raw_material_scan_incomplete' => 'worker.error.scan_all_materials',
      'raw_material_group_scan_incomplete' =>
        'worker.error.scan_required_materials',
      'previous_stage_qr_required' => 'worker.error.scan_previous',
      'progress_qr_reprint' => 'worker.daily.reprint_failed',
      'progress_batch_correction_reason_required' =>
        'worker.daily.correction.required',
      'progress_batch_correction_locked' => 'worker.daily.correction_failed',
      'progress_batch_correction_conflict' => 'worker.daily.correction_failed',
      'progress_batch_correction_unchanged' => 'worker.daily.correction_failed',
      'progress_batch_correction_failed' => 'worker.daily.correction_failed',
      'paddons_list' => 'worker.paddon.load_failed',
      'paddon_not_found' => 'worker.paddon.not_found',
      'paddon_create' => 'worker.paddon.create_failed',
      'paddon_item_add' => 'worker.paddon.add_failed',
      'paddon_items_add' => 'worker.paddon.add_failed',
      'paddon_item_remove' => 'worker.paddon.remove_failed',
      'paddon_items_remove' => 'worker.paddon.remove_failed',
      'paddon_qr_print' => 'worker.paddon.print_failed',
      _ => '',
    };
    if (key.isEmpty) return fallback;
    return productionText(key);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (item) => item.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
