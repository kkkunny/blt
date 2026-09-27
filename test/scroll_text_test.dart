import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/scroll_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('方向键滚动文本，到顶后归零', (tester) async {
    await tester.pumpWidget(
      UiScale(
        factor: 1,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: ScrollText('很长的描述文本' * 200, autofocus: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
  });
}
