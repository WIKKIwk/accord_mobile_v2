import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';

String openedOrderEditErrorReason(Object error) {
  if (error is! MobileApiException) {
    return 'Tahrirlash vaqtida kutilmagan xato yuz berdi. '
        'Buyurtmani qayta ochib holatini tekshiring. Muammo takrorlansa, '
        'mas’ul administratorga buyurtma raqamini yuboring.';
  }
  if (error.statusCode == 401) {
    return 'Kirish sessiyasi tugagan. Hisobingizga qayta kiring.';
  }
  if (error.statusCode == 403) {
    return 'Hisobingizda buyurtmani tahrirlash huquqi yo‘q. '
        'Mas’ul administratordan ruxsatlarni tekshirishni so‘rang.';
  }
  if ((error.statusCode ?? 0) >= 500) {
    return 'Server buyurtma ma’lumotlarini tekshira yoki saqlay olmadi. '
        'Bu kiritgan ma’lumotlaringizdagi xato emas. Buyurtmani qayta '
        'ochib holatini tekshiring; muammo takrorlansa, mas’ul '
        'administratorga buyurtma raqamini yuboring.';
  }
  // The shared API formatter adds an operation prefix and an HTTP suffix.
  // Keep this presentation change local to opened-order editing.
  final reason = error.message
      .replaceFirst(RegExp(r'^So‘ralgan amal bajarilmadi:\s*'), '')
      .replaceFirst(RegExp(r'\s*\(HTTP \d+\)$'), '')
      .trim();
  // Also explain the legacy server response during a rolling update.
  if (reason ==
      'Buyurtmaning asl Calculate ma’lumotlari saqlanmagan: tahrirlash mumkin emas') {
    return 'Bu buyurtmaning dastlabki Calculate hisob-kitobi bazada '
        'saqlanmagan va unga mos yagona shablon aniqlanmadi. Bu hozir '
        'kiritgan ma’lumotlaringizdagi xato emas. Hisob-kitobni taxmin '
        'qilib o‘zgartirmaslik uchun tahrirlash bloklandi. Mas’ul '
        'administratorga buyurtma raqamini yuboring.';
  }
  if (reason.isEmpty || reason == 'So‘ralgan amal bajarilmadi') {
    return 'Server tahrirlash so‘rovini bajarmadi, lekin sababini '
        'yubormadi. Mas’ul administratorga buyurtma raqamini yuboring.';
  }
  return reason;
}

Future<void> showOpenedOrderEditErrorDialog(
  BuildContext context, {
  required Object error,
  required String orderNumber,
  bool saving = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(
        saving ? 'Saqlash tasdiqlanmadi' : 'Buyurtmani tahrirlash ochilmadi',
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (orderNumber.trim().isNotEmpty) ...[
            Text('Buyurtma №${orderNumber.trim()}'),
            const SizedBox(height: 12),
          ],
          Text('Sabab', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(openedOrderEditErrorReason(error)),
          if (saving) ...[
            const SizedBox(height: 12),
            const Text(
                'Kiritgan ma’lumotlaringiz shu oynada saqlanib turibdi.'),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tushunarli'),
        ),
      ],
    ),
  );
}
