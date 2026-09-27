import 'package:blt/pages/dynamic.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../helpers/page_test_env.dart';

const _portalUrl = 'https://api.bilibili.com/x/polymer/web-dynamic/v1/portal';
const _feedUrl =
    'https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all';

// 动态门户：全部动态之外还有两个 UP 主
Map<String, dynamic> _portalJson() => {
  'code': 0,
  'data': {
    'up_list': {
      'items': [
        {'mid': 100, 'uname': 'UP主A', 'face': 'https://example.invalid/a.jpg'},
        {'mid': 200, 'uname': 'UP主B', 'face': 'https://example.invalid/b.jpg'},
      ],
    },
  },
};

Map<String, dynamic> _feedJson({String title = '动态视频A'}) => {
  'code': 0,
  'data': {
    'has_more': false,
    'offset': '',
    'items': [
      {
        'modules': {
          'module_author': {
            'mid': 100,
            'name': 'UP主A',
            'face': 'https://example.invalid/a.jpg',
            'pub_ts': 1700000000,
          },
          'module_dynamic': {
            'major': {
              'archive': {
                'aid': 170001,
                'bvid': 'BV170001',
                'title': title,
                'cover': 'https://example.invalid/cover.jpg',
                'duration_text': '01:00',
              },
            },
          },
        },
      },
    ],
  },
};

void main() {
  setupPageTestEnv();

  late DioAdapter adapter;

  // UP 列条目内的文字（视频卡片上也有 UP 主名，需要限定在条目内）
  Finder tileText(String label) => find.descendant(
    of: find.byType(SidePanelTile),
    matching: find.text(label),
  );

  // 条目可见色块的尺寸：外层是聚焦特效容器（3ui 描边会被算作内边距），
  // 头像（CircleAvatar）内部也有 AnimatedContainer，因此取第 2 个
  Finder tileBox(Finder tile) => find
      .descendant(of: tile, matching: find.byType(AnimatedContainer))
      .at(1);

  setUp(() {
    loginInfoNotifier.value = LoginInfo.login(
      mid: 1,
      nickname: '测试用户',
      avatar: 'https://example.invalid/me.jpg',
    );
    // DioAdapter 会替换 dio 的 httpClientAdapter，两个接口必须挂在同一个实例上
    adapter = mockHttp();
    adapter.onGet(_portalUrl, (server) => server.reply(200, _portalJson()));
  });

  Future<void> pumpDynamicPage(WidgetTester tester) async {
    final tapped = ValueNotifier(0);
    addTearDown(tapped.dispose);
    await pumpPage(tester, DynamicPage(tapped));
    await flush(tester);
  }

  testWidgets('UP 列使用统一面板与放大一档的条目', (tester) async {
    adapter.onGet(_feedUrl, (server) => server.reply(200, _feedJson()));
    await pumpDynamicPage(tester);

    expect(find.text('全部动态'), findsOneWidget);
    expect(tileText('UP主A'), findsOneWidget);
    expect(tileText('UP主B'), findsOneWidget);
    expect(find.text('动态视频A'), findsOneWidget);

    // 面板：左留白 20ui，上下 28ui 与主侧边栏对齐
    final panel = tester.widget<SidePanel>(find.byType(SidePanel));
    expect(panel.margin, const EdgeInsets.fromLTRB(20, 28, 0, 28));
    expect(tester.getSize(find.byType(SidePanel)).width, 172 + 20);

    // 条目：116x112ui，头像直径 56ui
    final tiles = find.byType(SidePanelTile);
    expect(tiles, findsNWidgets(3));
    for (final element in tiles.evaluate()) {
      expect(
        tester.getSize(tileBox(find.byWidget(element.widget))),
        const Size(116, 112),
      );
    }
    expect(
      tester.widget<BilibiliAvatar>(find.byType(BilibiliAvatar).first).radius,
      28,
    );
  });

  testWidgets('选择 UP 主后按 host_mid 拉取动态，切换回全部动态则不带', (tester) async {
    final queries = <Map<String, String>>[];
    adapter.onGet(
      _feedUrl,
      (server) => server.replyCallback(200, (options) {
        queries.add(options.uri.queryParameters);
        return _feedJson();
      }),
    );
    await pumpDynamicPage(tester);
    expect(queries, hasLength(1));
    expect(queries.last.containsKey('host_mid'), isFalse);

    await tester.tap(tileText('UP主B'));
    await flush(tester);
    expect(queries.last['host_mid'], '200');

    await tester.tap(tileText('全部动态'));
    await flush(tester);
    expect(queries.last.containsKey('host_mid'), isFalse);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1920, 1080),
    Size(3840, 2160),
    Size(1024, 768),
    Size(2560, 1080),
  ]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()} 下无布局溢出', (
      tester,
    ) async {
      adapter.onGet(_feedUrl, (server) => server.reply(200, _feedJson()));
      final tapped = ValueNotifier(0);
      addTearDown(tapped.dispose);
      await pumpPage(tester, DynamicPage(tapped), size: size);
      await flush(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
