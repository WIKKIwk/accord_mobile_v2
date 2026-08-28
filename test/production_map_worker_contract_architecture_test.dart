import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker UI renders backend controls without queue policy derivation',
      () {
    final source = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_read_only_helpers.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      '_ReadOnlyOrderDetailUiState _readOnlyOrderDetailUiState(',
    );
    final end = source.indexOf(
      'ProductionMapNode? _rezkaNodeForStation(',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final helper = source.substring(start, end);

    expect(helper, isNot(contains('apparatusQueueOrderStateFromRaw')));
    expect(helper, isNot(contains('productionMapPreviousWorkStageStation')));
    expect(helper, isNot(contains('productionMapOrderReadyForStation')));
    expect(helper, isNot(contains('_progressBatchMatchesPreviousStage')));
    expect(helper, isNot(contains('_progressBatchCanFeedStation')));
    expect(helper, contains("queueActionControl.allows('resume')"));
    expect(helper, contains('interaction?.startMaterialsMode'));
    expect(helper, contains('interaction?.materialIntakeAllowed'));
    expect(helper, contains('interaction?.previousWipMode'));
    expect(helper, contains('interaction?.openingWipMode'));
    expect(helper, contains('interaction?.qolipMode'));
  });

  test('Opening WIP Start keeps the exact selected batch and QR contract', () {
    final source = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_read_only_helpers.dart',
    ).readAsStringSync();
    final prepareStart = source.indexOf(
      '_PreparedReadOnlyQueueAction? _prepareReadOnlyQueueAction(',
    );
    final prepareEnd = source.indexOf(
      '_ReadOnlyOrderDetailUiState _readOnlyOrderDetailUiState(',
      prepareStart,
    );
    expect(prepareStart, greaterThanOrEqualTo(0));
    expect(prepareEnd, greaterThan(prepareStart));
    final prepare = source.substring(prepareStart, prepareEnd);

    expect(prepare, contains('startInputOpeningWipBatch?.batchId'));
    expect(prepare, contains('startInputOpeningWipBatch?.qrPayload'));
    expect(prepare, isNot(contains('AdminProgressBatch(')));

    final requestStart = source.indexOf(
      '_ReadOnlyQueueActionRequest _readOnlyQueueActionRequest(',
    );
    final requestEnd = source.indexOf(
      'String? _queueActionStartBlockReason(',
      requestStart,
    );
    expect(requestStart, greaterThanOrEqualTo(0));
    expect(requestEnd, greaterThan(requestStart));
    final request = source.substring(requestStart, requestEnd);

    expect(request, contains('prepared.startInputBatchId'));
    expect(request, contains('prepared.startInputQrPayload'));
  });

  test('Opening WIP worker scan uses the preloaded apparatus-scoped list', () {
    final source = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_read_only_sheet.dart',
    ).readAsStringSync();
    final lookupStart = source.indexOf('bool _acceptOpeningWipQr(');
    final lookupEnd = source.indexOf(
      'bool _acceptProgressBatch(',
      lookupStart,
    );
    expect(lookupStart, greaterThanOrEqualTo(0));
    expect(lookupEnd, greaterThan(lookupStart));
    final lookup = source.substring(lookupStart, lookupEnd);

    expect(lookup, contains('_availableOpeningWipBatches'));
    expect(lookup, contains('_matchingOpeningWipBatch('));
    expect(lookup, isNot(contains('MobileApi.instance')));

    final preloadStart = source.indexOf(
      'Future<void> _loadInputProgressBatches()',
    );
    final preloadEnd = source.indexOf(
      'Future<List<AdminProgressBatch>> _fetchInputProgressBatches(',
      preloadStart,
    );
    expect(preloadStart, greaterThanOrEqualTo(0));
    expect(preloadEnd, greaterThan(preloadStart));
    final preload = source.substring(preloadStart, preloadEnd);
    expect(preload, contains('adminOpeningWipCandidates('));
  });

  test('worker start scanner validates preloaded QR data locally', () {
    final source = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_read_only_sheet.dart',
    ).readAsStringSync();
    final scanStart = source.indexOf('Future<void> _handleQuickScan(');
    final scanEnd = source.indexOf(
      'bool _quickScanErrorAllowsRetry(',
      scanStart,
    );
    expect(scanStart, greaterThanOrEqualTo(0));
    expect(scanEnd, greaterThan(scanStart));
    final scan = source.substring(scanStart, scanEnd);

    expect(scan, contains('_startAssignments'));
    expect(scan, contains('_requiredQolips'));
    expect(scan, contains('_availableInputProgressBatches'));
    expect(scan, isNot(contains('adminProgressQrLookup(')));
    expect(scan, isNot(contains('adminValidateProductionMapQolipDetails(')));
    expect(scan, isNot(contains('adminLookupOpeningWip(')));
    expect(scan, isNot(contains('_fetchMaterialAssignments(')));
  });

  test('worker QR switching uses backend controls instead of topology or WIP',
      () {
    final screenSource = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_screen.dart',
    ).readAsStringSync();
    final screenStart = screenSource.indexOf(
      'Future<void> _handleWorkerFabQr(String qrPayload)',
    );
    final screenEnd = screenSource.indexOf(
      'Future<AdminProgressBatch?> _laminatsiyaWorkerHandoffBatch(',
      screenStart,
    );
    expect(screenStart, greaterThanOrEqualTo(0));
    expect(screenEnd, greaterThan(screenStart));
    final qrSwitch = screenSource.substring(screenStart, screenEnd);

    expect(qrSwitch, isNot(contains('productionMapPreviousWorkStageStation')));
    expect(qrSwitch, isNot(contains('apparatusQueueOrderStateFromRaw')));
    expect(qrSwitch, contains("targetControl?.allows('start')"));

    final sheetSource = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_read_only_sheet.dart',
    ).readAsStringSync();
    final switchStart = sheetSource.indexOf(
      'Future<bool> _confirmAndSwitchToScannedOrder(',
    );
    final switchEnd = sheetSource.indexOf(
      'Future<void> _runInitialPauseFlow()',
      switchStart,
    );
    expect(switchStart, greaterThanOrEqualTo(0));
    expect(switchEnd, greaterThan(switchStart));
    final sheetSwitch = sheetSource.substring(switchStart, switchEnd);

    expect(sheetSwitch, isNot(contains("batch.action")));
    expect(sheetSwitch, isNot(contains("batch.status")));
    expect(sheetSwitch, isNot(contains("batch.nextApparatus")));
    expect(sheetSwitch, contains("targetControl?.allows('start')"));
  });

  test('test mode exposes a narrow server-contract fixture', () {
    final source = File(
      'lib/src/core/api/admin/mobile_api_admin.dart',
    ).readAsStringSync();
    final start = source.indexOf('_testModeQueueActionControls()');
    final end = source.indexOf(
      'bool _testModeProductionMapIsVisibleQueueOrder(',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final fakeServer = source.substring(start, end);

    expect(fakeServer, isNot(contains('productionMapOrderReadyForStation')));
    expect(fakeServer, isNot(contains('_testModeTrainingPreviousStage')));
    expect(fakeServer, isNot(contains('_testModeProgressBatchesByQr')));
    expect(fakeServer, isNot(contains('_testModeRawMaterialRules')));
    expect(fakeServer, contains('_testModeQueueActionControlFixtures'));
    expect(fakeServer, isNot(contains('_testModeApparatusSequences')));
    expect(fakeServer, isNot(contains('_testModeApparatusQueueStates')));
    expect(fakeServer, isNot(contains('_testModeVisibleOrderIdsByApparatus')));
    expect(fakeServer, isNot(contains('_testModeRequeuedOrderIds')));
    expect(fakeServer, isNot(contains('readyPendingOrderId')));
    expect(fakeServer, isNot(contains('allowedActions.add(')));
  });

  test('worker sends the selected pause action unchanged', () {
    final source = File(
      'lib/src/features/admin/presentation/'
      'admin_production_map_orders_read_only_sheet.dart',
    ).readAsStringSync();

    expect(source, contains("_runProgressAction('pause')"));
    expect(
      source,
      isNot(
        contains(
          "_runProgressAction(widget.workerMode ? 'detach_roll' : 'pause')",
        ),
      ),
    );
  });
}
