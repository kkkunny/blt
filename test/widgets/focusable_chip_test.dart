import 'package:blt/widgets/focusable_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

void main() {
  setupPageTestEnv();

  testWidgets('点击胶囊触发回调', (tester) async {
    var tapped = 0;
    await pumpPage(
      tester,
      FocusableChip(label: '关键词', onTap: () => tapped++),
    );

    await tester.tap(find.text('关键词'));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('禁用时不可聚焦且点击不触发', (tester) async {
    var tapped = 0;
    await pumpPage(
      tester,
      FocusableChip(label: '关键词', enabled: false, onTap: () => tapped++),
    );

    await tester.tap(find.text('关键词'));
    await tester.pump();
    expect(tapped, 0);

    final focus = tester.widget<Focus>(
      find
          .ancestor(of: find.text('关键词'), matching: find.byType(Focus))
          .first,
    );
    expect(focus.canRequestFocus, isFalse);
  });

  testWidgets('聚焦后按确认键触发回调', (tester) async {
    var tapped = 0;
    await pumpPage(
      tester,
      FocusableChip(label: '关键词', autofocus: true, onTap: () => tapped++),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('选中态用粉色渐变托底，未选中态没有渐变', (tester) async {
    await pumpPage(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FocusableChip(label: '未选中', onTap: () {}),
          FocusableChip(label: '选中', selected: true, onTap: () {}),
        ],
      ),
    );

    BoxDecoration? decorationOf(String label) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return container.decoration as BoxDecoration?;
    }

    expect(decorationOf('未选中')?.gradient, isNull);
    expect(decorationOf('选中')?.gradient, isNotNull);
  });
}
