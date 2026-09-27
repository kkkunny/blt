import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('加载失败展示错误与重试按钮，重试成功后展示数据', (tester) async {
    var shouldThrow = true;
    await tester.pumpWidget(
      UiScale(
        factor: 1,
        child: MaterialApp(
          home: LoadingWidget<String>(
            loader: () async {
              if (shouldThrow) throw Exception('boom');
              return 'ok';
            },
            loadingWidget: const Text('loading'),
            builder: (context, data) => Text(data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    shouldThrow = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('ok'), findsOneWidget);
  });
}
