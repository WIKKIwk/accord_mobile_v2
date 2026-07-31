import '../../../app/app_router.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/logic/production_map_pechat_rules.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';
import 'package:flutter/material.dart';

class AparatchiWorkInstructionsScreen extends StatelessWidget {
  const AparatchiWorkInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apparatus = _assignedApparatus(
      AppSession.instance.profile?.assignedApparatus ?? const <String>[],
    );
    return AppShell(
      title: 'App yo‘riqnomasi',
      subtitle: 'Zakazni appda to‘g‘ri yuritish tartibi',
      nativeTopBar: true,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.apparatusWorkInstructions,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      bottom: const AparatchiDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: apparatus.isEmpty
            ? const _NoAssignedApparatus()
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.viewPaddingOf(context).bottom + 120,
                ),
                children: [
                  const _GuideIntro(),
                  const SizedBox(height: 12),
                  const _GuideSectionCard(
                    title: 'Kuzatishdan zakazni ochish',
                    items: [
                      'Yo‘riqnomadan chiqish uchun yuqoridagi ← tugmasini bosing. Siz Kuzatish sahifasiga qaytasiz.',
                      'Kuzatish sahifasini chap drawerdagi Kuzatish bandi orqali ham ochasiz.',
                      'Kuzatishda apparat nomi yozilgan tabni bosing. Sizga biriktirilgan apparatlarda zakaz kartasi shu yerda chiqadi.',
                      'Agar Zakaz yo‘q yozuvi chiqsa, hozir bu apparatga faol zakaz berilmagan. Boshlash uchun karta chiqishini kuting.',
                      'Zakaz kartasi chiqqanda uning ustiga bosing. Keyingi ekranda mahsulot, metraj va og‘irlikni tekshiring.',
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _GuideSectionCard(
                    title: 'Ekrandagi holatlar va tugmalar',
                    items: [
                      'Kutmoqda holatidagi zakazda shartlar bajarilgach Boshlash chiqadi. Navbatda oldinda boshqa zakaz bo‘lsa, siznikini boshlay olmaysiz.',
                      'Jarayonda holatida Pauza va Tugatish tugmalari chiqadi.',
                      'Pauzada holatida faqat Davom ettirish chiqadi. U bosilganda forma ochilmaydi: zakaz yana Jarayonda holatiga o‘tadi.',
                      'Admin buyurtmani muzlatishni so‘rasa, avval Pauza qiling. Muzlatilgan zakazni admin aktiv qilmaguncha davom ettirib bo‘lmaydi.',
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final item in apparatus) ...[
                    _ApparatusGuideCard(
                      guide: _ApparatusGuide.forApparatus(item),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

List<String> _assignedApparatus(Iterable<String> values) {
  final seen = <String>{};
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .where((value) => seen.add(value.toLowerCase()))
      .toList(growable: false);
}

class _GuideIntro extends StatelessWidget {
  const _GuideIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Bu yo‘riqnoma appdagi zakazni yuritish uchun. Pastda faqat sizga '
          'biriktirilgan apparatlar uchun ekrandagi tasdiqlar va tugatish '
          'formasi tushuntirilgan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _NoAssignedApparatus extends StatelessWidget {
  const _NoAssignedApparatus();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sizga aparat biriktirilmagan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Admin profilingizga aparat biriktirgandan keyin app yo‘riqnomasi shu yerda ko‘rinadi.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApparatusGuideCard extends StatelessWidget {
  const _ApparatusGuideCard({required this.guide});

  final _ApparatusGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guide.apparatus,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              guide.kindLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _GuideSection(
              title: '1. Boshlashdan oldingi ekrandagi tasdiqlar',
              items: guide.startChecks,
            ),
            const SizedBox(height: 16),
            _GuideSection(
              title: '2. Pauza qilish',
              items: guide.pauseSteps,
            ),
            const SizedBox(height: 16),
            _GuideSection(
              title: '3. Tugatish tartibi',
              items: guide.completionFields,
            ),
            const SizedBox(height: 16),
            const _GuideSection(
              title: '4. To‘liq bo‘lmagan tugatish',
              items: [
                'Tugatish miqdorida 0 yoki to‘liq bo‘lmagan hisobot bo‘lsa, Izoh maydonidagi 0 yoki noodatiy tugatish sababi yozilmasa Tasdiqlash qabul qilinmaydi.',
                'Sabab yozib Tasdiqlashni bossangiz, app Tugatish so‘rovi adminga yuborildi xabarini chiqaradi. Bu to‘liq tugatish emas, admin ko‘radigan so‘rov.',
                'Pauza formasida izoh bilan chetlab o‘tish yo‘q: chiqarilgan maydonlarning har biri 0 dan katta, haqiqiy son bo‘lishi kerak.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSectionCard extends StatelessWidget {
  const _GuideSectionCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _GuideSection(title: title, items: items),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${index + 1}. ${items[index]}',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.32),
            ),
          ),
      ],
    );
  }
}

class _ApparatusGuide {
  const _ApparatusGuide({
    required this.apparatus,
    required this.kindLabel,
    required this.startChecks,
    required this.pauseSteps,
    required this.completionFields,
  });

  final String apparatus;
  final String kindLabel;
  final List<String> startChecks;
  final List<String> pauseSteps;
  final List<String> completionFields;

  factory _ApparatusGuide.forApparatus(String apparatus) {
    final colorCount = productionMapPechatColorCount(apparatus);
    if (productionMapIsPechatApparatus(apparatus)) {
      return _ApparatusGuide(
        apparatus: apparatus,
        kindLabel: colorCount == null
            ? 'Flexo bosma uchun app yo‘riqnomasi'
            : '$colorCount ta rangli bosma uchun app yo‘riqnomasi',
        startChecks: const [
          'Ish boshlash uchun homashyolar qatorini oching. Sarlavhadagi son barcha majburiy homashyo QR kodi tasdiqlanganda to‘ladi.',
          'Qoliplar qatorini oching va talab qilingan qoliplarning hammasini QR orqali tasdiqlang. Qoliplar soni to‘lmaguncha Boshlash faol bo‘lmaydi.',
          'Oldingi bosqich QR qatori chiqsa, shu zakazning oldingi bosqichidan kelgan WIP QR kodini scan qiling.',
          'Homashyo, qolip va oldingi bosqich talablari to‘lgandan keyin Boshlash tugmasini bosing.',
        ],
        pauseSteps: const [
          'Pauza tugmasini bosing. Pauza miqdori oynasi ochiladi.',
          'Jami chiqindi (kg), Metraj (metr) va Og‘irlik (kg) maydonlarining uchalasiga hozirgi real miqdorni kiriting. 0 qabul qilinmaydi.',
          'Tasdiqlashni bosing, keyin chiqadigan printer tanlash oynasidan ishchi printerni tanlang. Printer tanlanmasa pauza yuborilmaydi.',
        ],
        completionFields: const [
          'Tugatish tugmasini bosing. Tugatish miqdori oynasida Tayyor mahsulot uchun Metraj va Og‘irlik, Qaytim va chiqindi uchun Jami chiqindi maydonlarini real qiymat bilan to‘ldiring.',
          'Qaytarilgan bo‘yoq tugmasini bosing. Rasxot va Astatka tablarining har birida kamida 3 ta qiymat kiriting yoki qaytarilgan bo‘yoq rasmini yuklang.',
          'Tasdiqlashdan keyin printer tanlang. To‘liq hisobot va printer tanlovi tasdiqlangach zakaz tugatiladi.',
        ],
      );
    }
    if (productionMapIsLaminatsiyaApparatus(apparatus)) {
      return _ApparatusGuide(
        apparatus: apparatus,
        kindLabel: 'Laminatsiya uchun app yo‘riqnomasi',
        startChecks: const [
          'Ish boshlash uchun homashyolar qatorini oching va undagi majburiy homashyo QR kodlarini to‘liq tasdiqlang.',
          'Oldingi bosqich QR qatori chiqsa, shu zakazning oldingi bosqichidan kelgan WIP QR kodini scan qiling.',
          'Kerakli homashyo va oldingi bosqich QR tasdiqlanmaguncha Boshlash faol bo‘lmaydi.',
        ],
        pauseSteps: const [
          'Pauza tugmasini bosing. Pauza miqdori oynasi ochiladi.',
          'Plyonkadan ortgan rulon, Jami chiqindi (kg), Metraj (metr) va Og‘irlik (kg) maydonlarini hozirgi real qiymat bilan to‘ldiring. 0 qabul qilinmaydi.',
          'Tasdiqlashdan keyin ishchi printerni tanlang. Printer tanlanmasa pauza yuborilmaydi.',
        ],
        completionFields: const [
          'Tugatish miqdorida Bosmadan ortgan rulon va Plyonkadan ortgan rulon maydonlaridan kamida bittasini, shuningdek Jami chiqindi, Metraj va Og‘irlikni kiriting.',
          'Barcha qiymatlar haqiqiy va 0 dan katta bo‘lsa Tasdiqlashni bosing, keyin ishchi printerni tanlang.',
          'Bosma yoki plyonka qoldig‘i yo‘q bo‘lsa, to‘liq tugatish o‘tmaydi; sababli tugatish so‘rovini yuboring.',
        ],
      );
    }
    if (productionMapIsRezkaApparatus(apparatus)) {
      return _ApparatusGuide(
        apparatus: apparatus,
        kindLabel: 'Rezka uchun app yo‘riqnomasi',
        startChecks: const [
          'Ish boshlash uchun homashyolar qatorida ko‘rsatilgan majburiy homashyo QR kodlarini to‘liq tasdiqlang.',
          'Oldingi bosqich QR qatori chiqsa, shu zakazga tegishli WIP QR kodini scan qiling.',
          'WIP nechta bo‘lakka bo‘linishi haqidagi blok chiqsa, undagi bo‘lak va kadr sonini ko‘rib oling. Shartlar to‘lgach Boshlashni bosing.',
        ],
        pauseSteps: const [
          'Pauza tugmasini bosing. Pauza miqdori oynasi ochiladi.',
          'Bosmachining chiqindisi, Laminatsiya chiqindisi, Tayyor mahsulot chetidan chiqqan chiqindi (uchalasi kg), Metraj va Og‘irlikni kiriting.',
          'Beshta miqdorning hammasi 0 dan katta bo‘lishi kerak. Tasdiqlashdan keyin ishchi printerni tanlang.',
        ],
        completionFields: const [
          'Tugatish miqdorida Bosmachining chiqindisi, Laminatsiya chiqindisi va Tayyor mahsulot chetidan chiqqan chiqindini uchta alohida maydonga kiriting.',
          'Metraj va Og‘irlikni ham kiriting. Beshta miqdor to‘liq bo‘lgach Tasdiqlashni bosing va ishchi printerni tanlang.',
          'Uchala chiqindi yoki Metraj va Og‘irlikdan biri yo‘q bo‘lsa, to‘liq tugatish qabul qilinmaydi.',
        ],
      );
    }
    return _ApparatusGuide(
      apparatus: apparatus,
      kindLabel: 'Ushbu apparat uchun app yo‘riqnomasi',
      startChecks: const [
        'Ish boshlash uchun homashyolar qatoridagi majburiy QR kodlarni tasdiqlang.',
        'Oldingi bosqich QR qatori chiqsa, shu zakazga tegishli WIP QR kodini scan qiling.',
        'Shartlar to‘lgach Boshlash tugmasini bosing.',
      ],
      pauseSteps: const [
        'Pauza tugmasini bosing va Pauza miqdori oynasidagi Metraj hamda Og‘irlikni kiriting.',
        'Maydonlar 0 dan katta bo‘lgach Tasdiqlashni bosing, keyin ishchi printerni tanlang.',
      ],
      completionFields: const [
        'Tugatish miqdori oynasidagi Metraj va Og‘irlikni haqiqiy qiymat bilan kiriting.',
        'To‘liq qiymatlar bo‘lsa Tasdiqlashdan keyin ishchi printerni tanlang.',
        'Miqdor to‘liq bo‘lmasa, Izohga sababni yozib tugatish so‘rovini yuboring.',
      ],
    );
  }
}
