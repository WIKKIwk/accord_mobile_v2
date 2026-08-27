import 'package:accord_mobile_v2/src/core/scanner/reliable_mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanner follows app and route visibility lifecycle', () async {
    final events = <String>[];
    final coordinator = ReliableScannerCoordinator();
    final driver = _FakeScannerDriver('scanner', events);
    final session = ReliableScannerSession.testing(
      driver: driver,
      coordinator: coordinator,
    );

    await session.attach();
    expect(session.phase, ReliableScannerPhase.running);

    await session.setAppLifecycleState(AppLifecycleState.inactive);
    expect(session.phase, ReliableScannerPhase.suspended);

    await session.setAppLifecycleState(AppLifecycleState.resumed);
    expect(session.phase, ReliableScannerPhase.running);

    await session.setRouteVisible(false);
    expect(session.phase, ReliableScannerPhase.suspended);

    await session.setRouteVisible(true);
    expect(session.phase, ReliableScannerPhase.running);

    await session.detach();

    expect(
      events,
      <String>[
        'scanner:start',
        'scanner:stop',
        'scanner:start',
        'scanner:stop',
        'scanner:start',
        'scanner:stop',
      ],
    );
  });

  test('new scanner waits until the previous camera owner stops', () async {
    final events = <String>[];
    final coordinator = ReliableScannerCoordinator();
    final first = ReliableScannerSession.testing(
      driver: _FakeScannerDriver('first', events),
      coordinator: coordinator,
    );
    final second = ReliableScannerSession.testing(
      driver: _FakeScannerDriver('second', events),
      coordinator: coordinator,
    );

    await first.attach();
    await second.attach();

    expect(first.phase, ReliableScannerPhase.suspended);
    expect(second.phase, ReliableScannerPhase.running);
    expect(
      events,
      <String>[
        'first:start',
        'first:stop',
        'second:start',
      ],
    );
  });

  test('silent native start failure is recovered once', () async {
    final events = <String>[];
    final driver = _FakeScannerDriver(
      'scanner',
      events,
      failedStarts: 1,
    );
    final session = ReliableScannerSession.testing(
      driver: driver,
      coordinator: ReliableScannerCoordinator(),
    );

    await session.attach();

    expect(session.phase, ReliableScannerPhase.running);
    expect(session.recoveryCount, 1);
    expect(
      events,
      <String>[
        'scanner:start-failed',
        'scanner:stop',
        'scanner:start',
      ],
    );
  });

  test('repeated native start failure becomes a visible error state', () async {
    final events = <String>[];
    final driver = _FakeScannerDriver(
      'scanner',
      events,
      failedStarts: 2,
    );
    final session = ReliableScannerSession.testing(
      driver: driver,
      coordinator: ReliableScannerCoordinator(),
    );

    await session.attach();

    expect(session.phase, ReliableScannerPhase.error);
    expect(session.lastError, isA<StateError>());
    expect(session.recoveryCount, 1);
  });

  test('disposed owner releases native camera before next scanner starts',
      () async {
    final events = <String>[];
    final coordinator = ReliableScannerCoordinator();
    final first = ReliableScannerSession.testing(
      driver: _FakeScannerDriver('first', events),
      coordinator: coordinator,
    );
    final second = ReliableScannerSession.testing(
      driver: _FakeScannerDriver('second', events),
      coordinator: coordinator,
    );

    await first.attach();
    final disposeFuture = first.dispose();
    final secondAttachFuture = second.attach();
    await Future.wait(<Future<void>>[disposeFuture, secondAttachFuture]);

    expect(
      events,
      <String>[
        'first:start',
        'first:stop',
        'first:dispose',
        'second:start',
      ],
    );
  });

  test('late disposal cannot tear down the active scanner', () async {
    final events = <String>[];
    final platform = _SharedScannerPlatform();
    final coordinator = ReliableScannerCoordinator();
    final firstDriver = _SharedScannerDriver('first', events, platform);
    final secondDriver = _SharedScannerDriver('second', events, platform);
    final first = ReliableScannerSession.testing(
      driver: firstDriver,
      coordinator: coordinator,
    );
    final second = ReliableScannerSession.testing(
      driver: secondDriver,
      coordinator: coordinator,
    );

    await first.attach();
    await first.setRouteVisible(false);
    await second.attach();

    expect(secondDriver.isRunning, isTrue);

    await first.dispose();

    expect(secondDriver.isRunning, isTrue);
    expect(events, isNot(contains('first:dispose-active-second')));

    await second.dispose();

    expect(events, containsAll(<String>['first:dispose', 'second:dispose']));
  });

  test('detection errors trigger one scanner recovery', () async {
    final events = <String>[];
    final session = ReliableScannerSession.testing(
      driver: _FakeScannerDriver('scanner', events),
      coordinator: ReliableScannerCoordinator(),
    );

    await session.attach();
    session.handleDetectionError(
        StateError('frame failed'), StackTrace.current);
    await session.settled;

    expect(session.phase, ReliableScannerPhase.running);
    expect(
      events,
      <String>['scanner:start', 'scanner:stop', 'scanner:start'],
    );
  });

  testWidgets('route coverage suspends scanner and pop resumes it',
      (tester) async {
    final events = <String>[];
    final observer = RouteObserver<ModalRoute<dynamic>>();
    final session = ReliableScannerSession.testing(
      driver: _FakeScannerDriver('scanner', events),
      coordinator: ReliableScannerCoordinator(),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: <Widget>[
                ReliableScannerLifecycle(
                  session: session,
                  routeObserver: observer,
                  child: const SizedBox(key: ValueKey('scanner')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('next')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await coordinatorSettled(session);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await coordinatorSettled(session);

    Navigator.of(tester.element(find.text('next'))).pop();
    await tester.pumpAndSettle();
    await coordinatorSettled(session);

    expect(
      events,
      <String>[
        'scanner:start',
        'scanner:stop',
        'scanner:start',
      ],
    );
  });
}

Future<void> coordinatorSettled(ReliableScannerSession session) async {
  await session.settled;
}

class _FakeScannerDriver implements ReliableScannerDriver {
  _FakeScannerDriver(
    this.name,
    this.events, {
    this.failedStarts = 0,
  });

  final String name;
  final List<String> events;
  int failedStarts;

  bool _disposed = false;
  bool _running = false;
  Object? _lastError;

  @override
  Object? get error => _lastError;

  @override
  bool get hasCameraPermission => true;

  @override
  bool get isRunning => _running;

  @override
  Future<void> dispose() async {
    _disposed = true;
    _running = false;
    events.add('$name:dispose');
  }

  @override
  Future<void> start() async {
    if (_disposed) {
      throw StateError('$name is disposed');
    }
    if (failedStarts > 0) {
      failedStarts -= 1;
      _running = false;
      _lastError = StateError('$name failed to start');
      events.add('$name:start-failed');
      return;
    }
    _lastError = null;
    _running = true;
    events.add('$name:start');
  }

  @override
  Future<void> stop() async {
    _running = false;
    events.add('$name:stop');
  }
}

class _SharedScannerPlatform {
  String? activeOwner;
}

class _SharedScannerDriver implements ReliableScannerDriver {
  _SharedScannerDriver(this.name, this.events, this.platform);

  final String name;
  final List<String> events;
  final _SharedScannerPlatform platform;
  bool _disposed = false;

  @override
  Object? get error => null;

  @override
  bool get hasCameraPermission => true;

  @override
  bool get isRunning => !_disposed && platform.activeOwner == name;

  @override
  Future<void> dispose() async {
    _disposed = true;
    final activeOwner = platform.activeOwner;
    if (activeOwner != null && activeOwner != name) {
      events.add('$name:dispose-active-$activeOwner');
    } else {
      events.add('$name:dispose');
    }
    platform.activeOwner = null;
  }

  @override
  Future<void> start() async {
    if (_disposed) {
      throw StateError('$name is disposed');
    }
    platform.activeOwner = name;
    events.add('$name:start');
  }

  @override
  Future<void> stop() async {
    if (platform.activeOwner == name) {
      platform.activeOwner = null;
    }
    events.add('$name:stop');
  }
}
