import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reports route coverage for every scanner surface in the app.
final RouteObserver<ModalRoute<dynamic>> reliableScannerRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

final ReliableScannerCoordinator _appScannerCoordinator =
    ReliableScannerCoordinator();

enum ReliableScannerPhase {
  idle,
  starting,
  recovering,
  running,
  stopping,
  suspended,
  error,
  disposed,
}

abstract interface class ReliableScannerDriver {
  bool get isRunning;

  bool get hasCameraPermission;

  Object? get error;

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}

class ReliableScannerCoordinator {
  final LinkedHashSet<ReliableScannerSession> _sessions =
      LinkedHashSet<ReliableScannerSession>.identity();
  final Queue<_ScannerReconcileRequest> _requests =
      Queue<_ScannerReconcileRequest>();
  ReliableScannerSession? _owner;
  int _priority = 0;
  bool _draining = false;
  Completer<void>? _idleCompleter;

  Future<void> get settled => _idleCompleter?.future ?? Future<void>.value();

  Future<void> reconcile(
    ReliableScannerSession session, {
    bool promote = false,
  }) {
    _sessions.add(session);
    if (promote) {
      session._priority = ++_priority;
    }

    final request = _ScannerReconcileRequest(session);
    _requests.add(request);
    _idleCompleter ??= Completer<void>();
    _startDrain();
    return request.completed;
  }

  void _startDrain() {
    if (_draining) {
      return;
    }
    _draining = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    while (_requests.isNotEmpty) {
      final batch = <_ScannerReconcileRequest>[];
      while (_requests.isNotEmpty) {
        batch.add(_requests.removeFirst());
      }

      try {
        await _reconcileNow();
      } catch (error, stackTrace) {
        for (final request in batch) {
          try {
            request.session._recordCoordinatorError(error);
          } catch (_) {
            // Reporting scanner failure must not block later camera sessions.
          }
        }
        try {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'reliable mobile scanner',
              context: ErrorDescription('while reconciling camera ownership'),
            ),
          );
        } catch (_) {
          // Test bindings and custom FlutterError handlers may rethrow.
        }
      }

      for (final request in batch) {
        request.complete();
      }
    }

    _draining = false;
    final idleCompleter = _idleCompleter;
    _idleCompleter = null;
    if (idleCompleter != null && !idleCompleter.isCompleted) {
      idleCompleter.complete();
    }
  }

  Future<void> _reconcileNow() async {
    ReliableScannerSession? desired;
    for (final session in _sessions) {
      if (!session._shouldRun) {
        continue;
      }
      if (desired == null || session._priority > desired._priority) {
        desired = session;
      }
    }

    final previousOwner = _owner;
    if (previousOwner != null && previousOwner != desired) {
      await previousOwner._stopDriver();
      _owner = null;
    }

    // The mobile_scanner platform is shared by every controller. A retired
    // controller must not be disposed while another controller owns that
    // platform session: older plugin versions would tear down the active
    // controller's camera from the retired controller's dispose call.
    if (_owner == null) {
      final disposedSessions = _sessions
          .where((session) => session._disposed)
          .toList(growable: false);
      for (final session in disposedSessions) {
        await session._disposeDriver();
        _sessions.remove(session);
      }
    }

    if (desired == null || desired._disposed) {
      for (final session in _sessions) {
        if (!session._disposed && session.phase != ReliableScannerPhase.error) {
          session._setPhase(ReliableScannerPhase.suspended);
        }
      }
      return;
    }

    for (final session in _sessions) {
      if (session != desired &&
          !session._disposed &&
          session.phase != ReliableScannerPhase.error) {
        session._setPhase(ReliableScannerPhase.suspended);
      }
    }

    _owner = desired;
    final started = await desired._startDriver(
      forceRestart: desired._forceRestart,
    );
    desired._forceRestart = false;
    if (!started && _owner == desired) {
      _owner = null;
    }
  }
}

class _ScannerReconcileRequest {
  _ScannerReconcileRequest(this.session);

  final ReliableScannerSession session;
  final Completer<void> _completer = Completer<void>();

  Future<void> get completed => _completer.future;

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class ReliableScannerSession implements Listenable {
  static const Duration _startTimeout = Duration(seconds: 8);
  static const Duration _releaseTimeout = Duration(seconds: 4);

  ReliableScannerSession({
    Size? cameraResolution,
    CameraLensType lensType = CameraLensType.any,
    DetectionSpeed detectionSpeed = DetectionSpeed.normal,
    int detectionTimeoutMs = 250,
    CameraFacing facing = CameraFacing.back,
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
    bool returnImage = false,
    bool torchEnabled = false,
    bool invertImage = false,
    bool autoZoom = false,
    double? initialZoom,
  }) : this._(
          controller: MobileScannerController(
            autoStart: false,
            cameraResolution: cameraResolution,
            lensType: lensType,
            detectionSpeed: detectionSpeed,
            detectionTimeoutMs: detectionTimeoutMs,
            facing: facing,
            formats: formats,
            returnImage: returnImage,
            torchEnabled: torchEnabled,
            invertImage: invertImage,
            autoZoom: autoZoom,
            initialZoom: initialZoom,
          ),
          coordinator: _appScannerCoordinator,
        );

  @visibleForTesting
  ReliableScannerSession.testing({
    required ReliableScannerDriver driver,
    required ReliableScannerCoordinator coordinator,
  }) : this._(
          driver: driver,
          coordinator: coordinator,
        );

  ReliableScannerSession._({
    MobileScannerController? controller,
    ReliableScannerDriver? driver,
    required ReliableScannerCoordinator coordinator,
  })  : assert(controller != null || driver != null),
        _controller = controller,
        _driver = driver ?? _MobileScannerDriver(controller!),
        _coordinator = coordinator;

  final MobileScannerController? _controller;
  final ReliableScannerDriver _driver;
  final ReliableScannerCoordinator _coordinator;
  final _ReliableScannerNotifier _notifier = _ReliableScannerNotifier();

  ReliableScannerPhase _phase = ReliableScannerPhase.idle;
  Object? _lastError;
  bool _attached = false;
  bool _routeVisible = true;
  bool _appResumed = true;
  bool _requested = true;
  bool _disposed = false;
  bool _driverDisposed = false;
  bool _listenersDisposed = false;
  bool _forceRestart = false;
  bool _detectionRecoveryInFlight = false;
  int _priority = 0;
  int _recoveryCount = 0;

  MobileScannerController get controller {
    final controller = _controller;
    if (controller == null) {
      throw StateError('A testing scanner session has no mobile controller.');
    }
    return controller;
  }

  ReliableScannerPhase get phase => _phase;

  Object? get lastError => _lastError;

  int get recoveryCount => _recoveryCount;

  Future<void> get settled => _coordinator.settled;

  bool get _shouldRun =>
      !_disposed && _attached && _routeVisible && _appResumed && _requested;

  Future<void> attach() {
    if (_disposed) {
      return Future<void>.value();
    }
    _attached = true;
    return _coordinator.reconcile(this, promote: true);
  }

  Future<void> detach() {
    if (_disposed) {
      return _coordinator.settled;
    }
    _attached = false;
    return _coordinator.reconcile(this);
  }

  Future<void> setRouteVisible(bool visible) {
    if (_disposed || _routeVisible == visible) {
      return Future<void>.value();
    }
    _routeVisible = visible;
    if (visible) {
      _forceRestart = true;
    }
    return _coordinator.reconcile(this, promote: visible);
  }

  Future<void> setAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_disposed || _appResumed == resumed) {
      return Future<void>.value();
    }
    _appResumed = resumed;
    if (resumed) {
      _forceRestart = true;
    }
    return _coordinator.reconcile(this, promote: resumed);
  }

  Future<bool> start({bool forceRestart = false}) async {
    if (_disposed) {
      return false;
    }
    _requested = true;
    _forceRestart = _forceRestart || forceRestart;
    await _coordinator.reconcile(this, promote: true);
    return _phase == ReliableScannerPhase.running;
  }

  Future<void> stop() {
    if (_disposed) {
      return _coordinator.settled;
    }
    _requested = false;
    return _coordinator.reconcile(this);
  }

  Future<bool> retry() => start(forceRestart: true);

  void handleDetectionError(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }

    _lastError = error;
    try {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'reliable mobile scanner',
          context: ErrorDescription('while decoding a camera frame'),
        ),
      );
    } catch (_) {
      // Error reporting must not prevent the camera recovery attempt.
    }

    if (_detectionRecoveryInFlight) {
      return;
    }
    _detectionRecoveryInFlight = true;
    unawaited(_recoverAfterDetectionError());
  }

  Future<void> _recoverAfterDetectionError() async {
    try {
      await retry();
    } finally {
      _detectionRecoveryInFlight = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      await _coordinator.settled;
      return;
    }
    _disposed = true;
    _requested = false;
    await _coordinator.reconcile(this);
    _notifier.dispose();
    _listenersDisposed = true;
  }

  Future<bool> _startDriver({required bool forceRestart}) async {
    if (_disposed || !_shouldRun) {
      return false;
    }
    if (_driver.isRunning && !forceRestart) {
      _lastError = null;
      _setPhase(ReliableScannerPhase.running);
      return true;
    }

    Object? startError;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      if (_disposed || !_shouldRun) {
        return false;
      }
      if ((forceRestart && _driver.isRunning) || attempt > 0) {
        await _safeStopDriver();
      }
      _setPhase(
        attempt == 0
            ? ReliableScannerPhase.starting
            : ReliableScannerPhase.recovering,
      );
      try {
        final startOperation = _driver.start();
        if (_driver.hasCameraPermission) {
          await startOperation.timeout(_startTimeout);
        } else {
          // Permission prompts are user-driven and must not be timed out.
          await startOperation;
        }
        if (_driver.isRunning) {
          _lastError = null;
          _setPhase(ReliableScannerPhase.running);
          return true;
        }
        startError = _driver.error ??
            StateError('Scanner start completed without a running camera.');
      } catch (error) {
        startError = error;
      }
      if (attempt == 0) {
        _recoveryCount += 1;
      }
    }

    _lastError = startError ?? StateError('Scanner failed to start.');
    _setPhase(ReliableScannerPhase.error);
    return false;
  }

  Future<void> _stopDriver() async {
    if (_driverDisposed) {
      return;
    }
    _setPhase(ReliableScannerPhase.stopping);
    await _safeStopDriver();
    if (!_disposed && _phase != ReliableScannerPhase.error) {
      _setPhase(ReliableScannerPhase.suspended);
    }
  }

  Future<void> _safeStopDriver() async {
    try {
      await _driver.stop().timeout(_releaseTimeout);
    } catch (error) {
      _lastError = error;
    }
  }

  Future<void> _disposeDriver() async {
    if (_driverDisposed) {
      return;
    }
    _driverDisposed = true;
    try {
      await _driver.dispose().timeout(_releaseTimeout);
    } catch (error) {
      _lastError = error;
    }
    _setPhase(ReliableScannerPhase.disposed);
  }

  void _recordCoordinatorError(Object error) {
    _lastError = error;
    _setPhase(ReliableScannerPhase.error);
  }

  void _setPhase(ReliableScannerPhase next) {
    if (_phase == next) {
      return;
    }
    _phase = next;
    if (!_listenersDisposed) {
      _notifier.emit();
    }
  }

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);
}

class _ReliableScannerNotifier extends ChangeNotifier {
  void emit() => notifyListeners();
}

class _MobileScannerDriver implements ReliableScannerDriver {
  const _MobileScannerDriver(this.controller);

  final MobileScannerController controller;

  @override
  Object? get error => controller.value.error;

  @override
  bool get hasCameraPermission => controller.value.hasCameraPermission;

  @override
  bool get isRunning => controller.value.isRunning;

  @override
  Future<void> dispose() => controller.dispose();

  @override
  Future<void> start() => controller.start();

  @override
  Future<void> stop() => controller.stop();
}

class ReliableScannerLifecycle extends StatefulWidget {
  const ReliableScannerLifecycle({
    super.key,
    required this.session,
    required this.child,
    this.routeObserver,
  });

  final ReliableScannerSession session;
  final Widget child;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;

  @override
  State<ReliableScannerLifecycle> createState() =>
      _ReliableScannerLifecycleState();
}

class _ReliableScannerLifecycleState extends State<ReliableScannerLifecycle>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;

  RouteObserver<ModalRoute<dynamic>> get _observer =>
      widget.routeObserver ?? reliableScannerRouteObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      widget.session.setAppLifecycleState(
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      ),
    );
    // MobileScannerController.start() explicitly waits for the scanner widget
    // to attach. Register ownership now so a dropped post-frame callback can
    // never leave a visible scanner permanently idle.
    unawaited(widget.session.attach());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      final previousRoute = _route;
      if (previousRoute != null) {
        _observer.unsubscribe(this);
      }
      _route = route;
      if (route != null) {
        _observer.subscribe(this, route);
      }
    }
    unawaited(widget.session.setRouteVisible(route?.isCurrent ?? true));
  }

  @override
  void didUpdateWidget(covariant ReliableScannerLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session &&
        oldWidget.routeObserver == widget.routeObserver) {
      return;
    }
    if (oldWidget.routeObserver != widget.routeObserver && _route != null) {
      (oldWidget.routeObserver ?? reliableScannerRouteObserver)
          .unsubscribe(this);
      _observer.subscribe(this, _route!);
    }
    if (oldWidget.session != widget.session) {
      unawaited(oldWidget.session.detach());
      unawaited(
        widget.session.setAppLifecycleState(
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
        ),
      );
      unawaited(widget.session.setRouteVisible(_route?.isCurrent ?? true));
      unawaited(widget.session.attach());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.session.setAppLifecycleState(state));
  }

  @override
  void didPush() {
    unawaited(widget.session.setRouteVisible(true));
  }

  @override
  void didPushNext() {
    unawaited(widget.session.setRouteVisible(false));
  }

  @override
  void didPopNext() {
    unawaited(widget.session.setRouteVisible(true));
  }

  @override
  void didPop() {
    unawaited(widget.session.setRouteVisible(false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) {
      _observer.unsubscribe(this);
    }
    unawaited(widget.session.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ReliableMobileScanner extends StatelessWidget {
  const ReliableMobileScanner({
    super.key,
    required this.session,
    this.onDetect,
    this.onDetectError,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.overlayBuilder,
    this.placeholderBuilder,
    this.scanWindow,
    this.scanWindowUpdateThreshold = 0,
    this.tapToFocus = false,
  });

  final ReliableScannerSession session;
  final void Function(BarcodeCapture barcodes)? onDetect;
  final void Function(Object error, StackTrace stackTrace)? onDetectError;
  final BoxFit fit;
  final Widget Function(BuildContext, MobileScannerException)? errorBuilder;
  final LayoutWidgetBuilder? overlayBuilder;
  final WidgetBuilder? placeholderBuilder;
  final Rect? scanWindow;
  final double scanWindowUpdateThreshold;
  final bool tapToFocus;

  @override
  Widget build(BuildContext context) {
    return ReliableScannerLifecycle(
      session: session,
      child: MobileScanner(
        controller: session.controller,
        onDetect: onDetect,
        onDetectError: onDetectError ?? session.handleDetectionError,
        fit: fit,
        errorBuilder: errorBuilder,
        overlayBuilder: overlayBuilder,
        placeholderBuilder: placeholderBuilder,
        scanWindow: scanWindow,
        scanWindowUpdateThreshold: scanWindowUpdateThreshold,
        useAppLifecycleState: false,
        tapToFocus: tapToFocus,
      ),
    );
  }
}
