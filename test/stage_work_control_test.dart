import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('late upstream closing prompts only an unreported completed execution', () {
    for (final sourceClosed in [false, true]) {
      for (final missing in [false, true]) {
        for (final finished in [false, true]) {
          final control = AdminStageWorkControl.fromJson({
            'upstream_closed': sourceClosed, 'astatka_required': missing,
            'astatka_available': finished, 'report_session_id': 'session-2',
          });
          expect(control.needsReportPrompt, sourceClosed && missing && finished);
        }
      }
    }
  });
  test('legacy or sessionless controls cannot request astatka', () {
    expect(AdminStageWorkControl.fromJson({}).needsReportPrompt, isFalse);
    expect(const AdminStageWorkControl(upstreamClosed: true, astatkaAvailable: true,
        astatkaRequired: true).needsReportPrompt, isFalse);
    expect(AdminApparatusQueueOrderActionControl.fromJson({}).stageWork, isNull);
  });
  test('live equality includes report readiness and final machine', () {
    const first = AdminStageWorkControl(upstreamClosed: true, astatkaAvailable: true,
      astatkaRequired: true, reportSessionId: 's', lastApparatus: 'apparatus:test:a');
    const reported = AdminStageWorkControl(upstreamClosed: true, astatkaAvailable: true,
      reportSessionId: 's', lastApparatus: 'apparatus:test:b');
    expect(first, isNot(reported));
    expect(first.needsReportPrompt, isTrue);
    expect(reported.needsReportPrompt, isFalse);
  });
}
