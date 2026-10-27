import 'dart:math';

final _qolipReworkRandom = Random.secure();

/// An idempotency key shared by retries of one send or return operation.
String newQolipReworkRequestId() {
  final randomHex = StringBuffer();
  // Draw 128 random bits a byte at a time. This also works on JavaScript,
  // where shifting `1 << 32` produces zero instead of a valid random bound.
  for (var index = 0; index < 16; index++) {
    randomHex.write(
      _qolipReworkRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
    );
  }
  return 'qolip-rework-${DateTime.now().toUtc().microsecondsSinceEpoch}-$randomHex';
}
