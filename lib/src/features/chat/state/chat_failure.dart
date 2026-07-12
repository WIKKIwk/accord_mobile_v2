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
