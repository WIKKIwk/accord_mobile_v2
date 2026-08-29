import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

part 'reliable_mobile_scanner_declarations_part_01.dart';
part 'reliable_mobile_scanner_declarations_part_02.dart';
part 'reliable_mobile_scanner_models_part_03.dart';

/// Reports route coverage for every scanner surface in the app.
final RouteObserver<ModalRoute<dynamic>> reliableScannerRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

final ReliableScannerCoordinator _appScannerCoordinator =
    ReliableScannerCoordinator();
