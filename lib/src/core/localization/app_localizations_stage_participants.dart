part of 'app_localizations.dart';

extension AppLocalizationsStageParticipants on AppLocalizations {
  String stageParticipantsText(String key) => switch (key) {
        'hint' => _t(
            'Ishtirokchilarni ko‘rish uchun apparatni bosib turing',
            'Press and hold a machine to see participants',
            'Удерживайте аппарат, чтобы увидеть участников',
            'شرکاء دیکھنے کے لیے مشین کو دبا کر رکھیں'),
        'title' => _t('Ishtirokchilar', 'Participants', 'Участники', 'شرکاء'),
        'empty' => _t(
            'Bu bosqichda hali ishtirokchilar qayd etilmagan',
            'No participants have been recorded for this stage',
            'На этом этапе участники ещё не зарегистрированы',
            'اس مرحلے کے لیے ابھی کوئی شرکاء درج نہیں ہوئے'),
        'error' => _t(
            'Ishtirokchilarni yuklab bo‘lmadi',
            'Could not load participants',
            'Не удалось загрузить участников',
            'شرکاء لوڈ نہیں ہو سکے'),
        'scope_changed' => _t(
            'Hisob yoki ruxsatlar o‘zgardi. Oynani qayta oching',
            'The account or permissions changed. Reopen this sheet',
            'Учётная запись или права изменились. Откройте окно снова',
            'اکاؤنٹ یا اجازتیں بدل گئی ہیں۔ دوبارہ کھولیں'),
        'unknown' => _t('Nomi ko‘rsatilmagan', 'Name unavailable',
            'Имя не указано', 'نام دستیاب نہیں'),
        'started' => _t('Boshlagan', 'Started', 'Начал работу', 'کام شروع کیا'),
        'working' => _t('Ishlayapti', 'Working', 'Работает', 'کام کر رہا ہے'),
        'paused' => _t('Pauzada', 'Paused', 'На паузе', 'وقفے پر'),
        'stopped' => _t('To‘xtatilgan', 'Stopped', 'Остановлен', 'روک دیا گیا'),
        'participated' =>
          _t('Qatnashgan', 'Participated', 'Участвовал', 'حصہ لیا'),
        _ => key,
      };
}
