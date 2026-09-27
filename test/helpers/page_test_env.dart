import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 页面测试通用环境：重置登录状态与本地存储
void setupPageTestEnv() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    loginInfoNotifier.value = LoginInfo.notLogin;
  });
  tearDown(() {
    loginInfoNotifier.value = LoginInfo.notLogin;
  });
}

// mock HTTP 适配器（挂在全局客户端上，页面无需改造即可被驱动）
DioAdapter mockHttp() => DioAdapter(dio: bilibiliHttpClient);

// 视频卡片响应 fixture（推荐/相关视频等接口共用字段）
Map<String, dynamic> feedVideoJson({
  int aid = 170001,
  String title = '测试视频',
  String goto = 'av',
}) => {
  'goto': goto,
  'aid': aid,
  'bvid': 'BV$aid',
  'cid': 279786,
  'title': title,
  'pic': 'https://example.invalid/cover.jpg',
  'duration': 3723,
  'stat': {'view': 1000, 'like': 20},
  'owner': {
    'mid': 123,
    'name': '测试UP主',
    'face': 'https://example.invalid/avatar.jpg',
  },
  'pubdate': 1700000000,
};

// 挂载页面宿主：与 app 一致的 UiScale 环境 + 1080p 视口
Future<void> pumpPage(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UiScale(
      factor: UiScale.factorFor(size),
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    ),
  );
}

// 等待异步请求完成并渲染（避免 pumpAndSettle 被加载动画卡住）
Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

// 选中 DpadFocusable：先让最近的可聚焦节点获得焦点，再发送遥控器确认键
Future<void> selectFocusable(WidgetTester tester, Finder descendant) async {
  final focusFinder = find
      .ancestor(of: descendant, matching: find.byType(Focus))
      .first;
  tester.widget<Focus>(focusFinder).focusNode?.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}
