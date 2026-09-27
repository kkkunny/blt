import 'package:blt/consts/color.dart';
import 'package:blt/widgets/side_panel.dart';
import 'package:blt/widgets/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

void _noop() {}

// 在组件内的 AnimatedContainer 装饰里查找满足条件的 BoxDecoration
// （条目自身带渐变，聚焦特效层带描边，两者需要区分）
BoxDecoration _decorationWhere(
  WidgetTester tester,
  Finder parent,
  bool Function(BoxDecoration decoration) predicate,
) {
  final containers = find.descendant(
    of: parent,
    matching: find.byType(AnimatedContainer),
  );
  for (final element in containers.evaluate()) {
    final decoration = (element.widget as AnimatedContainer).decoration;
    if (decoration is BoxDecoration && predicate(decoration)) {
      return decoration;
    }
  }
  fail('未找到匹配的 BoxDecoration');
}

// 条目可见色块的尺寸：外层聚焦特效容器的 3ui 描边会被算作内边距，
// 因此取内层（条目自身）的 AnimatedContainer 来度量
Finder _tileBox(Finder tile) =>
    find.descendant(of: tile, matching: find.byType(AnimatedContainer)).last;

void main() {
  testWidgets('SidePanel 使用与主侧边栏一致的面板规格', (tester) async {
    await pumpPage(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SidePanel(child: SizedBox.expand()),
      ),
    );

    final panelContainer = find
        .descendant(
          of: find.byType(SidePanel),
          matching: find.byType(Container),
        )
        .first;
    final panel = tester.widget<Container>(panelContainer);
    expect(panel.margin, const EdgeInsets.fromLTRB(28, 28, 0, 28));
    expect(panel.padding, const EdgeInsets.symmetric(vertical: 24, horizontal: 12));

    final decoration = panel.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, BorderRadius.circular(30));
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.first.color, biliPink.withValues(alpha: 0.18));
    expect(decoration.boxShadow!.first.blurRadius, 26);

    // 外框含 28ui 左边距：面板本体 172ui 宽，上下留白 28ui 与主侧边栏对齐
    expect(tester.getSize(find.byType(SidePanel)), const Size(172 + 28, 1080));
  });

  testWidgets('SidePanelTile 默认条目规格与选中态', (tester) async {
    var taps = 0;
    await pumpPage(
      tester,
      Center(
        child: SidePanelTile(
          leading: const Icon(Icons.abc),
          label: '测试项',
          selected: true,
          onTap: () => taps++,
        ),
      ),
    );

    final tile = find.byType(SidePanelTile);
    expect(tester.getSize(_tileBox(tile)), const Size(116, 104));

    final decoration = _decorationWhere(
      tester,
      tile,
      (d) => d.gradient != null,
    );
    expect(decoration.gradient, pinkGradient);
    expect(decoration.borderRadius, BorderRadius.circular(26));
    expect(decoration.boxShadow, hasLength(1));

    final text = tester.widget<Text>(find.text('测试项'));
    expect(text.style!.fontSize, 24);
    expect(text.style!.fontWeight, FontWeight.w700);
    expect(text.style!.color, Colors.white);

    await tester.tap(tile);
    expect(taps, 1);
  });

  testWidgets('SidePanelTile 未选中无渐变，聚焦时粉色描边', (tester) async {
    await pumpPage(
      tester,
      Center(
        child: SidePanelTile(
          leading: const Icon(Icons.abc),
          label: '测试项',
          selected: false,
          onTap: _noop,
        ),
      ),
    );

    final tile = find.byType(SidePanelTile);
    expect(find.byType(AnimatedScale), findsNothing);

    final unfocused = _decorationWhere(tester, tile, (d) => d.border != null);
    expect(unfocused.border!.top.color, Colors.transparent);
    expect(unfocused.gradient, isNull);

    Focus.of(tester.element(find.text('测试项'))).requestFocus();
    await tester.pump();

    final focused = _decorationWhere(tester, tile, (d) => d.border != null);
    expect(focused.border!.top.color, biliPink);
    expect(focused.border!.top.width, 3);
  });

  testWidgets('SidePanelTile 支持放大一档的 UP 列规格', (tester) async {
    await pumpPage(
      tester,
      Center(
        child: SidePanelTile(
          leading: const SizedBox(width: 56, height: 56),
          label: '测试UP',
          selected: true,
          onTap: _noop,
          height: 112,
          radius: 28,
          fontSize: 22,
        ),
      ),
    );

    final tile = find.byType(SidePanelTile);
    expect(tester.getSize(_tileBox(tile)), const Size(116, 112));
    expect(_decorationWhere(tester, tile, (d) => d.gradient != null).borderRadius, BorderRadius.circular(28));
    expect(tester.widget<Text>(find.text('测试UP')).style!.fontSize, 22);
  });

  testWidgets('Sidebar 复用统一面板与条目规格', (tester) async {
    await pumpPage(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: Sidebar(
          avatar: const SizedBox(width: 92, height: 92),
          onAvatarTap: _noop,
          items: const [
            SidebarItemData(
              icon: Icons.abc,
              label: '入口A',
              selected: true,
              autofocus: true,
              onTap: _noop,
            ),
            SidebarItemData(
              icon: Icons.abc,
              label: '入口B',
              selected: false,
              onTap: _noop,
            ),
          ],
        ),
      ),
    );

    expect(find.text('入口A'), findsOneWidget);
    expect(find.text('入口B'), findsOneWidget);

    final tiles = find.byType(SidePanelTile);
    expect(tiles, findsNWidgets(2));
    for (final element in tiles.evaluate()) {
      expect(
        tester.getSize(_tileBox(find.byWidget(element.widget))),
        const Size(116, 104),
      );
    }
    expect(tester.getSize(find.byType(SidePanel)).width, 172 + 28);
  });
}
