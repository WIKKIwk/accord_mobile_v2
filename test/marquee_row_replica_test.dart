import 'package:accord_mobile_v2/src/core/widgets/display/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// _SequenceOrderRow dagi layout'ning soddalashtirilgan nusxasi:
// Stack[Positioned cover, Padding(Row[badge, Expanded(Column[title, sub]), drag, info])]
Widget buildRow(int index, String title, String subtitle) {
  return Padding(
    key: ValueKey('seq-$index'),
    padding: EdgeInsets.only(bottom: index < 9 ? 8 : 0),
    child: Material(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 64,
            child: ColoredBox(color: Colors.grey),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(64 + 12, 8, 4, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 45),
              child: Row(
                children: [
                  CircleAvatar(child: Text('${index + 1}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (!constraints.maxWidth.isFinite) {
                              return const Text('unbounded');
                            }
                            return Row(
                              children: [
                                const Flexible(
                                  flex: 0,
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: '0073'),
                                      TextSpan(text: ' • '),
                                    ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    softWrap: false,
                                  ),
                                ),
                                Expanded(
                                  child: OverflowMarqueeText(
                                    text: title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        OverflowMarqueeText(
                          text: subtitle,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                  const IconButton(
                    onPressed: null,
                    icon: Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('replica sequence rows with marquee do not crash', (tester) async {
    const titles = [
      'Xotluch sochnay juda uzun nomli zakaz matni davomi bor ekan',
      'Sardor semechka qovurilgan pista aralashmasi maxsus buyurtma',
      'Simba semechka katta qadoqdagi maxsus nashr toza qogoz',
      'Element mix myau qizil qalampirli chips maxsus retseptura',
      'Grenki telyatina adjika bilan dudlangan pishloq qoshilgan',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReorderableListView.builder(
            key: const ValueKey('sequence-list-test'),
            padding: const EdgeInsets.all(12),
            buildDefaultDragHandles: false,
            itemCount: titles.length,
            onReorderItem: (a, b) {},
            itemBuilder: (context, index) => buildRow(
              index,
              titles[index],
              'Toshkent sardor simba savdo markazi • 4 ta aparat maqsad',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 3));
    final dynamic err = tester.takeException();
    expect(err, isNull, reason: 'replica crashed: $err');
    expect(find.textContaining('Xotluch'), findsOneWidget);
  });
}
