import 'package:blt/widgets/pink_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

void main() {
  setupPageTestEnv();

  Container buttonContainer(WidgetTester tester) => tester.widget<Container>(
    find
        .ancestor(of: find.text('搜索'), matching: find.byType(Container))
        .first,
  );

  testWidgets('默认高度 56ui、圆角为高度一半', (tester) async {
    await pumpPage(tester, PinkButton(ui: 1, label: '搜索', onPressed: () {}));

    final container = buttonContainer(tester);
    expect(container.constraints?.maxHeight, 56);
    final decoration = container.decoration! as BoxDecoration;
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft.x,
      28,
    );
  });

  testWidgets('可配置高度，圆角跟随高度', (tester) async {
    await pumpPage(
      tester,
      PinkButton(ui: 1, label: '搜索', height: 72, onPressed: () {}),
    );

    final container = buttonContainer(tester);
    expect(container.constraints?.maxHeight, 72);
    final decoration = container.decoration! as BoxDecoration;
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft.x,
      36,
    );
  });
}
