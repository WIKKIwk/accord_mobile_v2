import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_passport.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_pdf.dart';

void main() {
  const apparatusNamesById = {
    'apparatus:default:asset-010': 'Rezka',
    'apparatus:default:asset-007': 'Laminatsiya 1',
  };

  test('progress QR PDF is a human-readable product passport', () {
    final report = AdminProgressQrReport.fromJson({
      'scanned_batch': _batchJson('batch-old', 'qr-old'),
      'current_batch': _batchJson('batch-current', 'qr-current'),
      'is_stale': true,
      'stale_reason': 'superseded_by_new_qr',
      'order': {
        'id': 'order-1',
        'product_code': 'product-1',
        'title': '90 гр сочная курица',
        'order_number': '9993',
        'customer_name': 'Accord',
        'roll_count': 12,
        'width_mm': 650,
        'order_kg': 500,
        'base_length': 574908.5345345345,
        'nodes': const [],
        'edges': const [],
      },
      'order_status': {
        'order_status': 'in_progress',
        'work_status': 'in_progress',
        'flow_status': 'in_progress',
      },
      'queue_states': {
        'apparatus:default:asset-010': {'order-1': 'in_progress'},
      },
      'logs': [
        {
          'event_id': 'event-transfer',
          'apparatus': 'apparatus:default:asset-010',
          'order_id': 'order-1',
          'action': 'resume',
          'from_state': 'paused',
          'to_state': 'in_progress',
          'actor_role': 'worker',
          'actor_ref': 'worker-1',
          'actor_display_name': 'Rezka',
          'created_at_unix': 1785665340,
          'transfer': {
            'transfer_id': 'transfer-1',
            'from_apparatus': 'apparatus:default:asset-010',
            'to_apparatus': 'apparatus:default:asset-007',
            'reason': 'apparatus_issue',
            'session_id': 'session-1',
            'progress_batch_id': 'batch-current',
            'material_barcodes': ['material-1'],
          },
          'freeze': {
            'request_id': 'freeze-1',
            'status': 'transitioned',
            'target_session_id': 'session-1',
            'target_apparatus': 'apparatus:default:asset-010',
            'target_worker_role': 'worker',
            'target_worker_ref': 'worker-1',
            'target_worker_display_name': 'Rezka',
            'requested_at_unix': 1785665340,
            'transitioned_at_unix': 1785665341,
          },
        },
      ],
      'corrections': [
        {
          'batch_id': 'batch-current',
          'previous_revision': 1,
          'new_revision': 2,
          'reason': 'Tarozida qayta o‘lchandi',
          'actor': {
            'role': 'admin',
            'ref_': 'admin-1',
            'display_name': 'Bosh admin',
          },
          'old_values': {'produced_qty': 425, 'uom': 'm'},
          'new_values': {'produced_qty': 424, 'uom': 'm'},
          'created_at_unix': 1785665350,
        },
      ],
      'progress_batches': [_batchJson('batch-current', 'qr-current')],
      'run_sessions': [
        {
          'session_id': 'session-1',
          'apparatus': 'apparatus:default:asset-010',
          'order_id': 'order-1',
          'status': 'active',
          'worker_role': 'worker',
          'worker_ref': 'worker-1',
          'worker_display_name': 'Rezka',
          'started_at_unix': 1785665340,
          'updated_at_unix': 1785665341,
          'payload_json': {'input_progress_qr_payload': 'qr-old'},
        },
      ],
      'active_sessions': const [],
      'opened_by': {
        'actor_role': 'worker',
        'actor_ref': 'worker-1',
        'actor_display_name': 'Rezka',
        'opened_at_unix': 1785665340,
      },
    });

    final pdf = AdminProgressQrScanPdf.buildProgress(
      report,
      apparatusNamesById: apparatusNamesById,
    );
    final source = utf8.decode(pdf);
    final passport = buildProgressQrPassport(
      report,
      apparatusNamesById: apparatusNamesById,
    ).toPlainText();

    expect(
      passport,
      '''MAHSULOT PASPORTI
Zakaz 9993 • 90 гр сочная курица
Holati: Keyingi bosqichni kutmoqda
Eslatma: skan qilingan QR oldingi bosqichniki. Quyida mahsulotning hozirgi holati berilgan.

BUYURTMA REJASI
Mijoz: Accord
Rejadagi rulonlar: 12 ta
Mahsulot eni: 650 mm
Rejadagi og‘irlik: 500 kg
Rejadagi metraj: 574 908.53 metr

ISHLAB CHIQARISH BOSQICHLARI
1. Rezka (hozirgi bosqich)
Holati: Keyingi bosqichni kutmoqda
Bajargan: Rezka
Boshlangan: 02.08.2026 15:09
Natija: 424 m
Babina og‘irligi: 5 kg
Keyingi bosqich: Laminatsiya 1

TAHRIRLAR
1. Rezka
Tahrir qilgan: Bosh admin
Vaqt: 02.08.2026 15:09
Sabab: Tarozida qayta o‘lchandi
Ishlab chiqarilgan miqdor: 425 m → 424 m

MUAMMOLAR VA O‘ZGARISHLAR
1. Rezka → Laminatsiya 1: Aparatdagi nosozlik sababli boshqa apparatga o‘tkazilgan
Vaqt: 02.08.2026 15:09''',
    );
    expect(passport, isNot(contains('Qisqa xulosa')));
    expect(passport, isNot(contains('Mahsulot natijasi')));
    expect(passport, isNot(contains('Kimlar ishlagan')));
    expect(passport, isNot(contains('Ish ketma-ketligi')));
    expect(passport, isNot(contains('Bobina')));

    expect(source, startsWith('%PDF-1.4\n'));
    expect(source, contains('Mahsulot pasporti'));
    expect(source, contains('Rejadagi metraj: 574 908.53 metr'));
    expect(source, contains('Natija: 424 m'));
    expect(source, contains('Babina og\'irligi: 5 kg'));
    expect(source, contains('Tahrir qilgan: Bosh admin'));
    expect(source, contains('Sabab: Tarozida qayta o\'lchandi'));
    expect(source, contains('Ishlab chiqarilgan miqdor: 425 m -> 424 m'));
    expect(source, isNot(contains('batch-current')));
    expect(source, isNot(contains('transfer-1')));
    expect(source, isNot(contains('freeze-1')));
    expect(source, isNot(contains('input_progress_qr_payload')));
    expect(source, endsWith('%%EOF\n'));
  });
}

Map<String, dynamic> _batchJson(String batchId, String qrPayload) {
  return {
    'batch_id': batchId,
    'session_id': 'session-1',
    'started_at_unix': 1785665340,
    'completed_at_unix': 0,
    'apparatus': 'apparatus:default:asset-010',
    'order_id': 'order-1',
    'action': 'pause',
    'status': 'paused',
    'produced_qty': 424,
    'uom': 'm',
    'qr_payload': qrPayload,
    'label_item_code': 'product-1',
    'label_item_name': '90 гр сочная курица',
    'executor_name': 'Rezka',
    'worker_role': 'worker',
    'worker_ref': 'worker-1',
    'worker_display_name': 'Rezka',
    'wip_status': 'waiting',
    'status_detail': {
      'work_status': 'paused',
      'wip_status': 'waiting',
      'flow_status': 'waiting_next_stage',
      'stock_status': '',
    },
    'current_apparatus': 'apparatus:default:asset-010',
    'current_apparatus_key': 'apparatus:default:asset-010',
    'current_location': 'Rezka chiqim',
    'next_apparatus': 'apparatus:default:asset-007',
    'bobina_kg': 5,
    'payload_json': {
      'input_progress_qr_payload': qrPayload,
      'gross_qty': 424,
    },
  };
}
