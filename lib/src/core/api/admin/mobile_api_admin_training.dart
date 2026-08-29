part of '../mobile_api.dart';

const _trainingInputApparatus = 'training-input:bosma';
const _trainingRezkaInputApparatus = 'training-input:laminatsiya';

final _trainingOrderNumberPattern = RegExp(
  r'^T-(\d{1,4})$',
  caseSensitive: false,
);
final Set<String> _testModeTrainingInputBatchGeneratedOrderIds = {};
final Set<String> _testModeTrainingInputBatchSetClosedOrderIds = {};
int _testModeTrainingInputBatchSequence = 0;

extension MobileApiAdminTrainingWorkspace on MobileApi {}
