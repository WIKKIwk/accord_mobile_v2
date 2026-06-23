import 'dart:async';

class RetryAfterCountdown {
  RetryAfterCountdown({required this.onChanged});

  final void Function() onChanged;
  Timer? _timer;
  int _seconds = 0;

  int get seconds => _seconds;

  void set(int seconds) {
    _timer?.cancel();
    _seconds = seconds > 0 ? seconds : 0;
    if (_seconds <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        _seconds = 0;
        onChanged();
        return;
      }
      _seconds -= 1;
      onChanged();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
