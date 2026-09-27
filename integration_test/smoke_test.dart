// 真机/模拟器冒烟：启动 → 首页 → 搜索 → 详情 → 播放页 → 返回。
//
// HTTP 全部在进程内 mock，不依赖真实 B 站接口，保证 CI 确定性。
// 运行方式：flutter test integration_test/smoke_test.dart -d <device>

import 'dart:typed_data';

import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/main.dart' as app;
import 'package:blt/models/pbs/dm.pb.dart';
import 'package:blt/pages/video_player.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/widgets/video_card.dart';
import 'package:dio/dio.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:integration_test/integration_test.dart';

const _rcmdUrl =
    'https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd';
const _searchUrl =
    'https://api.bilibili.com/x/web-interface/wbi/search/type';
const _viewUrl = 'https://api.bilibili.com/x/web-interface/view';
const _relationUrl = 'https://api.bilibili.com/x/relation';
const _followerUrl = 'https://api.bilibili.com/x/relation/stat';
const _relatedUrl =
    'https://api.bilibili.com/x/web-interface/archive/related';
const _playUrl = 'https://api.bilibili.com/x/player/wbi/playurl';
const _playerV2Url = 'https://api.bilibili.com/x/player/v2';
const _dmSegUrl = 'https://api.bilibili.com/x/v2/dm/web/seg.so';
const _navUrl = 'https://api.bilibili.com/x/web-interface/nav';
const _clickUrl =
    'https://api.bilibili.com/x/click-interface/click/web/h5';
const _heartbeatUrl =
    'https://api.bilibili.com/x/click-interface/web/heartbeat';
const _historyReportUrl = 'https://api.bilibili.com/x/v2/history/report';

Map<String, dynamic> _feedItem(String title) => {
  'goto': 'av',
  'aid': 170001,
  'bvid': 'BV17x411w7KC',
  'cid': 279786,
  'title': title,
  'pic': 'https://example.invalid/cover.jpg',
  'duration': 100,
  'stat': {'view': 1000, 'like': 20},
  'owner': {
    'mid': 123,
    'name': '测试UP主',
    'face': 'https://example.invalid/avatar.jpg',
  },
  'pubdate': 1700000000,
};

void _mockAll(DioAdapter adapter) {
  adapter.onGet(
    _rcmdUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'item': [_feedItem('首页推荐视频')],
      },
    }),
  );
  adapter.onGet(
    _searchUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'result': [
          {
            'type': 'video',
            'aid': 170001,
            'bvid': 'BV17x411w7KC',
            'title': '搜索视频',
            'pic': 'https://example.invalid/cover.jpg',
            'duration': '01:40',
            'mid': 123,
            'author': '测试UP主',
            'upic': 'https://example.invalid/face.jpg',
            'pubdate': 1700000000,
          },
        ],
      },
    }),
  );
  adapter.onGet(
    _viewUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'aid': 170001,
        'bvid': 'BV17x411w7KC',
        'title': '搜索视频',
        'pic': 'https://example.invalid/cover.jpg',
        'desc': '简介',
        'duration': 100,
        'cid': 279786,
        'owner': {'mid': 123, 'name': '测试UP主', 'face': 'avatar.jpg'},
        'stat': {'view': 1000, 'like': 20},
        'pubdate': 1700000000,
        'pages': [
          {'page': 1, 'cid': 279786, 'part': 'P1', 'duration': 100},
        ],
      },
    }),
  );
  adapter.onGet(
    _relationUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {'attribute': 2},
    }),
  );
  adapter.onGet(
    _followerUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {'follower': 12345},
    }),
  );
  adapter.onGet(
    _relatedUrl,
    (server) => server.reply(200, {'code': 0, 'data': []}),
  );
  adapter.onGet(
    _playerV2Url,
    (server) => server.reply(200, {
      'code': 0,
      'data': {'last_play_cid': 0, 'last_play_time': 0, 'online_count': 1},
    }),
  );
  adapter.onGet(
    _playUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'quality': 80,
        'support_formats': [
          {'quality': 80, 'new_description': '1080P'},
        ],
        'dash': {
          'video': [
            {'id': 32, 'base_url': 'https://example.invalid/v.m4s'},
          ],
          'audio': [
            {'id': 30280, 'base_url': 'https://example.invalid/a.m4s'},
          ],
        },
      },
    }),
  );
  // 弹幕：空 protobuf（合法且无内容）
  adapter.onGet(
    _dmSegUrl,
    (server) => server.reply(
      200,
      Uint8List.fromList(DmSegMobileReply().writeToBuffer()),
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    ),
  );
  adapter.onGet(
    _navUrl,
    (server) => server.reply(200, {
      'code': 0,
      'data': {
        'mid': 123,
        'uname': '测试用户',
        'face': 'avatar.jpg',
        'level_info': {'current_level': 6},
      },
    }),
  );
  for (final url in [_clickUrl, _heartbeatUrl, _historyReportUrl]) {
    adapter.onPost(
      url,
      data: Matchers.any,
      (server) => server.reply(200, {'code': 0, 'data': {}}),
    );
  }
}

// 轮询等待目标出现（避免 pumpAndSettle 被无限动画卡住）
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('等待超时：$finder');
}

// 轮询等待目标消失
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('等待超时（未消失）：$finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('启动 → 首页 → 搜索 → 详情 → 播放页 → 返回', (tester) async {
    final adapter = DioAdapter(dio: bilibiliHttpClient);
    _mockAll(adapter);

    // 真实启动流程（MediaKit、显示模式、文件日志、路由）
    app.main();

    // splash → 首页
    await _pumpUntil(tester, find.text('首页'));

    // 模拟已登录，进入搜索
    loginInfoNotifier.value = LoginInfo.login(
      mid: 123,
      nickname: '测试用户',
      avatar: 'https://example.invalid/avatar.jpg',
    );
    await tester.pump();

    await tester.tap(find.text('搜索'));
    await _pumpUntil(tester, find.text('请输入搜索内容'));

    await tester.enterText(find.byType(TextField), '测试');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _pumpUntil(tester, find.text('搜索视频'));

    // 进入详情（触发卡片选中回调，等价于遥控器确认键）
    tester.widget<VideoCard>(find.byType(VideoCard).first).onTap?.call();
    // 粉丝数只出现在详情页，作为进入详情的标志
    await _pumpUntil(tester, find.text('1.2万粉丝'));

    // 打开播放页（选中封面播放区）
    final playFocusable = find
        .ancestor(
          of: find.byIcon(Icons.play_arrow_rounded),
          matching: find.byType(DpadFocusable),
        )
        .first;
    tester.widget<DpadFocusable>(playFocusable).onSelect?.call();
    await _pumpUntil(tester, find.byType(VideoPlayerPage));

    // 返回详情：播放页为"连按两次返回退出"设计
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.binding.handlePopRoute();
    await _pumpUntilGone(tester, find.byType(VideoPlayerPage));
    await _pumpUntil(tester, find.text('搜索视频'));

    // 卸载应用树，停止播放器/图片等后台工作，避免测试结束后的原生回调噪声
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
  });
}
