import 'package:flutter/foundation.dart';

abstract final class QolipDataRevision {
  QolipDataRevision._();

  static final ValueNotifier<int> locations = ValueNotifier<int>(0);

  static void notifyLocationsChanged() {
    locations.value++;
  }
}
