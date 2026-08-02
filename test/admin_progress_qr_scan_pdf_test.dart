import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../lib/src/core/api/mobile_api.dart';
import '../lib/src/features/admin/presentation/admin_progress_qr_scan_pdf.dart';

void main() {
  test('progress QR PDF keeps full batch, session, transfer and freeze data',
      () {
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
        'nodes': const [],
        'edges': const [],
      },
      'order_status': {
        'order_status': 'in_progress',
        'work_status': 'in_progress',
        'flow_status': 'in_progress',
        'total_wip_count': 2,
        'active_session_count': 1,
      },
      'queue_states': {
        'Rezka': {'order-1': 'in_progress'},
      },
      'logs': [
        {
          'event_id': 'event-transfer',
          'apparatus': 'Rezka',
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
            'from_apparatus': 'Rezka',
            'to_apparatus': 'Laminatsiya 1',
            'reason': 'apparatus_issue',
            'session_id': 'session-1',
            'progress_batch_id': 'batch-current',
            'material_barcodes': ['material-1'],
          },
          'freeze': {
            'request_id': 'freeze-1',
            'status': 'transitioned',
            'target_session_id': 'session-1',
            'target_apparatus': 'Rezka',
            'target_worker_role': 'worker',
            'target_worker_ref': 'worker-1',
            'target_worker_display_name': 'Rezka',
            'requested_at_unix': 1785665340,
            'transitioned_at_unix': 1785665341,
          },
        },
      ],
      'progress_batches': [_batchJson('batch-current', 'qr-current')],
      'run_sessions': [
        {
          'session_id': 'session-1',
          'apparatus': 'Rezka',
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

    final pdf = AdminProgressQrScanPdf.buildProgress(report);
    final source = utf8.decode(pdf);

    expect(source, startsWith('%PDF-1.4\n'));
    expect(source, contains('Admin QR report'));
    expect(source, contains('batch-current'));
    expect(source, contains('transfer-1'));
    expect(source, contains('freeze-1'));
    expect(source, contains('input_progress_qr_payload'));
    expect(source, endsWith('%%EOF\n'));
  });
}

Map<String, dynamic> _batchJson(String batchId, String qrPayload) {
  return {
    'batch_id': batchId,
    'session_id': 'session-1',
    'started_at_unix': 1785665340,
    'completed_at_unix': 0,
    'apparatus': 'Rezka',
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
    'current_apparatus': 'Rezka',
    'current_location': 'Rezka chiqim',
    'next_apparatus': 'Laminatsiya 1',
    'payload_json': {
      'input_progress_qr_payload': qrPayload,
      'gross_qty': 424,
    },
  };
}
