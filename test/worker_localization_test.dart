import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker queue blocking reasons are localized without sync fallbacks',
      () {
    const keys = {
      'apparatus_busy': 'worker.waiting.apparatus_busy',
      'print_preflight_active': 'worker.waiting.print_preflight_active',
      'print_preflight_other_order_active':
          'worker.waiting.print_preflight_other_order_active',
      'previous_stage_not_configured':
          'worker.error.previous_stage_not_configured',
      'raw_material_assignment_required':
          'worker.error.incomplete_material_groups',
      'waiting_sequence': 'worker.waiting.sequence',
      'waiting_previous_stage': 'worker.waiting.previous_short',
      'waiting_opening_wip': 'worker.waiting.opening_wip',
      'order_frozen': 'worker.freeze.active',
      'order_freeze_requested': 'worker.freeze.requested',
    };
    for (final language in ['uz', 'en', 'ru']) {
      final l10n = AppLocalizations(Locale(language));
      for (final entry in keys.entries) {
        final message = l10n.productionErrorMessage(entry.key);
        expect(message, isNotEmpty, reason: '$language: ${entry.key}');
        expect(message, l10n.productionText(entry.value));
        expect(message, isNot(entry.value));
        expect(message, isNot(l10n.productionText('worker.error.sync')));
      }
      final fallback = l10n.productionText('worker.queue.action_unavailable');
      expect(fallback, isNot('worker.queue.action_unavailable'));
      expect(l10n.productionErrorMessage('future_reason', fallback: fallback),
          fallback);
    }
  });

  test('another order preflight does not ask this worker to record its result', () {
    for (final language in ['uz', 'en', 'ru']) {
      final l10n = AppLocalizations(Locale(language));
      expect(
        l10n.productionErrorMessage('print_preflight_other_order_active'),
        isNot(l10n.productionErrorMessage('print_preflight_active')),
      );
    }
    final l10n = AppLocalizations(const Locale('uz'));
    final message =
        l10n.productionErrorMessage('print_preflight_other_order_active');
    expect(message, contains('boshqa buyurtma'));
    expect(message, isNot(contains('Natijani belgilang')));
  });

  test('worker production text follows the selected locale', () {
    final uzbek = AppLocalizations(const Locale('uz'));
    final english = AppLocalizations(const Locale('en'));
    final russian = AppLocalizations(const Locale('ru'));

    expect(uzbek.productionText('worker.action.start'), 'Boshlash');
    expect(english.productionText('worker.action.start'), 'Start');
    expect(russian.productionText('worker.action.start'), 'Начать');
    expect(uzbek.productionText('worker.action.merge'), 'Rulon ulash');
    expect(
      uzbek.productionText(
        'worker.merge_state.current',
        values: const {'batch': 'wip-b'},
      ),
      'Hozir wip-b ishlanmoqda.',
    );
    expect(
      uzbek.productionText('worker.merge_state.title'),
      'Rulonlar ulandi',
    );
    expect(
      uzbek.productionText(
        'worker.notice.merge_complete',
        values: const {'next': '2-rulon', 'current': '1-rulon'},
      ),
      '2-rulon 1-rulonning davomiga ulandi.',
    );
    expect(
      uzbek.productionText(
        'worker.merge_state.count',
        values: const {'count': 3},
      ),
      'Jami 3 ta rulon biriktirilgan.',
    );
    expect(
      uzbek.productionErrorMessage('merge_input_same'),
      'Bu WIP hozir ishlatilmoqda. Boshqa WIPni scan qiling',
    );
    expect(
      uzbek.productionErrorMessage('merge_input_frame_count_mismatch'),
      'Merge qilinmadi: scan qilingan WIPning kadr soni joriy rulon bilan bir xil emas. Bir xil kadrli WIPni scan qiling',
    );
    expect(
      uzbek.productionText(
        'worker.error.merge_input_frame_count_mismatch_detail',
        values: const {'active': 2, 'scanned': 1},
      ),
      'Merge qilinmadi: joriy rulon 2 kadr, scan qilingan WIP 1 kadr. Bir xil kadrli WIPni scan qiling',
    );
    expect(
      uzbek.productionErrorMessage('rezka_frame_count_mismatch'),
      'Tugatish yuborilmadi: kiritilgan kadrlar soni Rezka rulonlari soniga mos emas. Oynani yangilang va qayta kiriting',
    );
    expect(
      english.productionText('worker.action.complete'),
      'Complete job',
    );
    expect(
      english.productionText(
        'worker.queue.apparatus_count',
        values: {'count': 2},
      ),
      '2 machines',
    );
    expect(
      english.productionText('worker.qr.report.product_passport'),
      'Product passport',
    );
  });
}
