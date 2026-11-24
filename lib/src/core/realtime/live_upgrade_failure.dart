/// Browser WebSockets hide the HTTP status of a rejected upgrade.
class LiveUpgradeFailure implements Exception {
  const LiveUpgradeFailure(this.status);
  final int? status;

  @override
  String toString() =>
      'WebSocket upgrade failed (${status ?? 'unknown status'})';
}
