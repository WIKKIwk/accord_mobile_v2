part of '../mobile_api.dart';

final List<QolipLocationEntry> _testModeQolipLocations = [];
final Map<String, QolipProduct> _testModeQolipSpecs = {};
final Map<String, String> _testModeFirstQolipCodes = {};
final List<QolipCheckoutEntry> _testModeQolipCheckouts = [];
final List<QolipBlock> _testModeQolipBlocks = [
  const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
  const QolipBlock(name: 'B', warehouse: 'Qolip ombori'),
];

extension MobileApiQolip on MobileApi {}
