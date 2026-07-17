import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/api/mobile_api.dart';

bool isTransientChatFailure(Object error) {
  if (error is TimeoutException || error is http.ClientException) {
    return true;
  }
  if (error is! MobileApiException) {
    return false;
  }
  final status = error.statusCode;
  return status == 408 || status == 429 || (status != null && status >= 500);
}

String chatFailureMessage(Object error) {
  if (error is TimeoutException || error is http.ClientException) {
    return 'Ulanish uzildi. Internetni tekshirib, qayta yuboring.';
  }
  if (error is MobileApiException) {
    return switch (error.code) {
      'authentication_required' =>
        'Sessiya muddati tugagan. Qayta kirib ko‘ring.',
      'chat_forbidden' => 'Bu suhbatga xabar yuborish ruxsati yo‘q.',
      'chat_not_found' => 'Suhbat topilmadi. Chatlar ro‘yxatini yangilang.',
      'chat_input_invalid' => 'Xabar bo‘sh yoki juda uzun.',
      'chat_state_conflict' =>
        'Bu media avval yuborilgan yoki endi yuborib bo‘lmaydi.',
      'chat_media_too_large' =>
        'Rasm 15 MiB, video esa 2 GiB dan oshmasligi kerak.',
      'chat_media_input_invalid' ||
      'invalid_media_content' =>
        'Media fayl formati yaroqsiz yoki qo‘llab-quvvatlanmaydi.',
      'video_duration_too_long' =>
        'Video 10 daqiqa (600 soniya)dan oshmasligi kerak.',
      'video_resolution_too_large' =>
        'Video o‘lchami 1920×1080 dan oshmasligi kerak.',
      'video_frame_rate_too_high' =>
        'Video tezligi 60 FPS dan oshmasligi kerak.',
      'processed_video_too_large' =>
        'Qayta ishlangan video 1 GiB dan oshib ketdi.',
      'chat_media_forbidden' => 'Bu suhbatga media yuborish ruxsati yo‘q.',
      'chat_media_state_conflict' =>
        'Media yuklash holati o‘zgargan. Qayta urinib ko‘ring.',
      'processor_unavailable' ||
      'chat_media_unavailable' =>
        'Media qayta ishlash xizmati hozir mavjud emas.',
      'media_processing_failed' ||
      'chat_media_processing_failed' =>
        'Media fayl qayta ishlanmadi. Qayta urinib ko‘ring.',
      'chat_media_storage_failed' ||
      'chat_media_store_failed' =>
        'Media serverda saqlanmadi. Qayta urinib ko‘ring.',
      'chat_unavailable' ||
      'chat_store_failed' =>
        'Chat serveri vaqtincha javob bermayapti.',
      _ when error.statusCode == 429 =>
        'Juda ko‘p urinish bo‘ldi. Birozdan keyin qayta yuboring.',
      _ when error.statusCode != null && error.statusCode! >= 500 =>
        'Server xatosi. Xabar saqlandi, qayta yuborishingiz mumkin.',
      _ => error.message,
    };
  }
  return 'Xabar yuborilmadi. Qayta urinib ko‘ring.';
}

String chatMediaFailureMessage(Object error) {
  if (error is StateError &&
      error.message.toString().contains('chat_media_local_file_missing')) {
    return 'Vaqtinchalik media fayl topilmadi. Faylni qayta tanlang.';
  }
  if (error is TimeoutException &&
      error.message?.contains('chat_media_processing_timeout') == true) {
    return 'Media qayta ishlanishi juda uzoq davom etdi. Qayta urinib ko‘ring.';
  }
  if (error is StateError &&
      error.message.toString().contains(
            'chat_media_chunk_configuration_invalid',
          )) {
    return 'Video yuklash ma’lumoti yaroqsiz. Qayta urinib ko‘ring.';
  }
  return chatFailureMessage(error);
}
