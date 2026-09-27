import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/custom_setting_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => UiScale(
  factor: 1,
  child: MaterialApp(home: Scaffold(body: child)),
);

Future<void> _select(WidgetTester tester, Finder finder) async {
  Focus.of(tester.element(finder)).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('开关设置项：选中后切换', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      _wrap(
        CustomSettingsSwitchTile(
          leading: const Icon(Icons.abc),
          title: '测试开关',
          value: false,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await _select(tester, find.text('测试开关'));
    expect(changed, isTrue);
  });

  testWidgets('下拉设置项：展示当前值并可切换', (tester) async {
    int? changed;
    await tester.pumpWidget(
      _wrap(
        CustomSettingsDropdownTile<int>(
          leading: const Icon(Icons.abc),
          title: '测试下拉',
          value: 1,
          items: const [1, 2, 3],
          onChanged: (v) => changed = v,
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);

    await _select(tester, find.text('测试下拉'));
    expect(find.text('3'), findsOneWidget);

    await _select(tester, find.text('3'));
    expect(changed, 3);
  });
}
