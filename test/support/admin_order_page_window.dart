import 'package:flutter_test/flutter_test.dart';

String activeOrderSequenceWindowId(WidgetTester tester) {
  final viewport = tester.widget(find.byWidgetPredicate(
    (widget) =>
        widget.runtimeType.toString() == '_AdminOrderPageViewport' &&
        (widget as dynamic).window.request.view == 'sequence',
  ));
  return (viewport as dynamic).window.liveId as String;
}
