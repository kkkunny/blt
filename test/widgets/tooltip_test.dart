import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 挂载页面并取得一个可用的 BuildContext
Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    UiScale(
      factor: 1,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('预期内错误（业务码）走普通错误提示', (tester) async {
    final context = await _pumpContext(tester);

    showAppError(context, const BilibiliError(-101, '账号未登录'));
    await tester.pump();

    expect(find.text('错误：账号未登录'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.action, isNull);
  });

  testWidgets('预期外错误（响应格式异常）走重提示且展示更久', (tester) async {
    final context = await _pumpContext(tester);

    showAppError(context, const BilibiliError(-2, '响应格式异常'));
    await tester.pump();

    expect(find.text('错误：响应格式异常'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 10));
  });

  testWidgets('未知异常降级为未知错误，不展示 e.toString()', (tester) async {
    final context = await _pumpContext(tester);

    showAppError(context, StateError('raw detail'));
    await tester.pump();

    expect(find.text('错误：未知的错误'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('网络错误映射为可读文案且可挂重试', (tester) async {
    final context = await _pumpContext(tester);
    var retried = 0;

    showAppError(
      context,
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
      onRetry: () => retried++,
    );
    await tester.pumpAndSettle();

    expect(find.text('错误：网络异常，请检查网络后重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets('requestWithTooltip 成功提示成功文案，失败走统一错误入口', (tester) async {
    final context = await _pumpContext(tester);

    await requestWithTooltip(
      context,
      request: () async {},
      successText: '操作成功',
    );
    await tester.pump();
    expect(find.text('提示：操作成功'), findsOneWidget);

    await requestWithTooltip(
      context,
      request: () async {
        throw const BilibiliError(-412, '');
      },
      successText: '操作成功',
    );
    await tester.pump();
    expect(find.text('错误：请求被拦截，请稍后重试'), findsOneWidget);
  });

  testWidgets('tooltipNetFetch 失败时提示且继续抛出异常', (tester) async {
    final context = await _pumpContext(tester);

    await expectLater(
      tooltipNetFetch(context, () async => throw StateError('boom')),
      throwsA(isA<StateError>()),
    );
    await tester.pump();
    expect(find.text('错误：未知的错误'), findsOneWidget);
  });
}
