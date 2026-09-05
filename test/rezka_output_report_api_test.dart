import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const frame = {
    'produced_qty': 120.0,
    'gross_qty': 12.0,
    'bobina_kg': 0.5,
    'diameter': 45.0
  };
  final slot = {
    'frame_index': 2,
    'batch_id': 'roll-2',
    'qr_payload': 'QR-2',
    'input': frame
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'rezka-worker';
  });
  tearDown(() {
    AppSession.instance.token = null;
  });

  test(
      'single roll save carries cycle and slot and restores authoritative fields',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode({
            'states': {'order-1': 'in_progress'},
            'session': {
              'session_id': 'run-1',
              'payload_json': {
                'rezka_output_cycle': 'cycle-1',
                'rezka_output_report': [slot],
              }
            },
            'prints': [],
            'progress_batches': [],
          }),
          200);
    });
    final result = await http.runWithClient(
        () => MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: 'apparatus:default:asset-010',
              orderId: 'order-1',
              action: 'roll_complete',
              rezkaOutputCycle: 'cycle-1',
              rezkaRecordFrameIndex: 2,
              rezkaFrames: [frame],
            ),
        () => client);
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['rezka_record_frame_index'], 2);
    expect(body['rezka_output_cycle'], 'cycle-1');
    expect(body['rezka_frames'], [frame]);
    expect(result.printJobs, isEmpty);
    expect(result.rezkaOutputReport!.frameAt(0), isNull);
    expect(result.rezkaOutputReport!.frameAt(1)!.qrPayload, 'QR-2');
    expect(result.rezkaOutputReport!.frameAt(1)!.input, frame);
  });

  test('individual issue sends only note and restores a locked slot without QR',
      () async {
    const issue = {'issue_note': 'Kadr yirtilgan'};
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['rezka_record_frame_index'], 2);
      expect(body['rezka_output_cycle'], 'cycle-1');
      expect(body['rezka_frames'], [issue]);
      return http.Response(
          jsonEncode({
            'states': {'order-1': 'in_progress'},
            'session': {
              'session_id': 'run-1',
              'payload_json': {
                'rezka_output_cycle': 'cycle-1',
                'rezka_output_report': [
                  {
                    'frame_index': 2,
                    'batch_id': '',
                    'qr_payload': '',
                    'input': issue,
                  }
                ],
              }
            },
            'prints': [],
            'progress_batches': [],
          }),
          200);
    });
    final result = await http.runWithClient(
        () => MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: 'apparatus:default:asset-010',
              orderId: 'order-1',
              action: 'roll_complete',
              rezkaOutputCycle: 'cycle-1',
              rezkaRecordFrameIndex: 2,
              rezkaFrames: [issue],
            ),
        () => client);
    final saved = result.rezkaOutputReport!.frameAt(1)!;
    expect(saved.isIssue, isTrue);
    expect(saved.issueNote, 'Kadr yirtilgan');
    expect(saved.batchId, isEmpty);
    expect(saved.qrPayload, isEmpty);
    expect(result.printJobs, isEmpty);
    expect(result.progressBatches, isEmpty);
  });

  test('report accepts multiple issues but rejects issue and QR hybrid', () {
    final issueSlot = {
      'frame_index': 1,
      'batch_id': '',
      'qr_payload': '',
      'input': {'issue_note': 'Kadr yirtilgan'},
    };
    final report = AdminRezkaOutputReport.tryFromJson({
      'cycle_id': 'cycle-1',
      'frames': [
        issueSlot,
        {...issueSlot, 'frame_index': 2}
      ],
    });
    expect(report!.frames, hasLength(2));
    expect(report.frames.every((frame) => frame.isIssue), isTrue);
    for (final malformed in [
      {...issueSlot, 'batch_id': 'healthy-roll', 'qr_payload': 'healthy-QR'},
      {
        ...issueSlot,
        'input': {'issue_note': '   '}
      },
      {
        ...issueSlot,
        'input': {'issue_note': 7}
      },
    ]) {
      expect(
          AdminRezkaOutputReport.tryFromJson({
            'cycle_id': 'cycle-1',
            'frames': [malformed],
          }),
          isNull);
    }
  });

  test('completion sends the same cycle without single-roll marker', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['rezka_output_cycle'], 'cycle-1');
      expect(body.containsKey('rezka_record_frame_index'), isFalse);
      expect(body['rezka_frames'], hasLength(2));
      return http.Response(
          jsonEncode({
            'states': {'order-1': 'completed'},
            'prints': []
          }),
          200);
    });
    await http.runWithClient(
        () => MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: 'apparatus:default:asset-010',
              orderId: 'order-1',
              action: 'complete',
              rezkaOutputCycle: 'cycle-1',
              rezkaFrames: [frame, frame],
              totalWaste: 1,
            ),
        () => client);
  });

  test(
      'report rejects duplicate slot or batch identities and accepts empty cycle',
      () {
    expect(
        AdminRezkaOutputReport.tryFromJson(
                {'cycle_id': 'cycle-1', 'frames': []})!
            .frames,
        isEmpty);
    expect(
        AdminRezkaOutputReport.tryFromJson({
          'cycle_id': 'cycle-1',
          'frames': [slot, slot]
        }),
        isNull);
    expect(
        AdminRezkaOutputReport.tryFromJson({
          'cycle_id': 'cycle-1',
          'frames': [
            slot,
            {...slot, 'frame_index': 3}
          ]
        }),
        isNull);
    expect(
        AdminRezkaOutputReport.tryFromJson({
          'cycle_id': '',
          'frames': [slot]
        }),
        isNull);
  });
}
