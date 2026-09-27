import 'package:blt/apis/bilibili/media.dart' show ArchiveRelation;
import 'package:blt/icons/iconfont.dart';
import 'package:blt/models/video.dart';
import 'package:blt/pages/video_detail.dart';
import 'package:blt/storages/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/page_test_env.dart';

const _dynamicDetailUrl =
    'https://api.bilibili.com/x/polymer/web-dynamic/v1/detail';
const _thumbUrl = 'https://api.bilibili.com/x/dynamic/feed/dyn/thumb';
const _toViewAddUrl = 'https://api.bilibili.com/x/v2/history/toview/add';
const _relationModifyUrl = 'https://api.bilibili.com/x/relation/modify';

Video _fakeVideo() => Video(
  avid: 170001,
  bvid: 'BV1',
  title: '测试视频标题',
  cover: 'https://example.invalid/cover.jpg',
  desc: '测试视频简介',
  duration: const Duration(minutes: 3, seconds: 20),
  stat: Stat(
    viewCount: 1000,
    favoriteCount: 10,
    likeCount: 20,
    dislikeCount: 1,
    coinCount: 5,
    shareCount: 2,
  ),
  userMid: 1,
  userName: '测试UP主',
  userAvatar: 'https://example.invalid/avatar.jpg',
  publishTime: DateTime(2026, 1, 1),
  cid: 1,
  episodes: const [
    Episode(
      index: 1,
      cid: 1,
      title: 'P1',
      duration: Duration(minutes: 3, seconds: 20),
    ),
  ],
);

Future<void> _pumpDetail(WidgetTester tester) async {
  await pumpPage(
    tester,
    VideoDetailPage(
      video: _fakeVideo(),
      relation: ArchiveRelation(),
      followerCount: 10,
    ),
  );
  await flush(tester);
}

void _login() {
  loginInfoNotifier.value = LoginInfo.login(
    mid: 1,
    nickname: '测试用户',
    avatar: 'https://example.invalid/avatar.jpg',
  );
}

void main() {
  setupPageTestEnv();

  group('点赞', () {
    testWidgets('成功时提示点赞成功', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = mockHttp();
      adapter.onGet(
        _dynamicDetailUrl,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'item': {'id_str': '901234567890123456'},
          },
        }),
      );
      adapter.onPost(
        _thumbUrl,
        data: Matchers.any,
        (server) => server.reply(200, {'code': 0, 'data': {}}),
      );

      await _pumpDetail(tester);
      await selectFocusable(tester, find.byIcon(Icons.thumb_up_rounded));
      await flush(tester);

      expect(find.text('提示：点赞成功！'), findsOneWidget);
    });

    testWidgets('失败时展示统一错误提示而不是崩溃', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = mockHttp();
      adapter.onGet(
        _dynamicDetailUrl,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'item': {'id_str': '901234567890123456'},
          },
        }),
      );
      adapter.onPost(
        _thumbUrl,
        data: Matchers.any,
        (server) => server.reply(200, {'code': -403, 'message': '账号异常'}),
      );

      await _pumpDetail(tester);
      await selectFocusable(tester, find.byIcon(Icons.thumb_up_rounded));
      await flush(tester);

      expect(find.text('错误：账号异常'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('稍后再看', () {
    testWidgets('未登录时提示先登录且不发请求', (tester) async {
      var requested = false;
      final adapter = mockHttp();
      adapter.onPost(
        _toViewAddUrl,
        data: Matchers.any,
        (server) => server.replyCallback(200, (options) {
          requested = true;
          return {'code': 0, 'data': {}};
        }),
      );

      await _pumpDetail(tester);
      await selectFocusable(tester, find.byIcon(IconFont.playlist));
      await flush(tester);

      expect(find.text('提示：请先登录！'), findsOneWidget);
      expect(requested, false);
    });

    testWidgets('登录后成功加入稍后再看', (tester) async {
      _login();
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = mockHttp();
      adapter.onPost(
        _toViewAddUrl,
        data: Matchers.any,
        (server) => server.reply(200, {'code': 0, 'data': {}}),
      );

      await _pumpDetail(tester);
      await selectFocusable(tester, find.byIcon(IconFont.playlist));
      await flush(tester);

      expect(find.text('提示：已加入稍后再看：测试视频标题'), findsOneWidget);
    });
  });

  group('关注', () {
    testWidgets('登录后关注成功并更新按钮状态', (tester) async {
      _login();
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'bili_jct=csrf-token',
      });
      final adapter = mockHttp();
      adapter.onPost(
        _relationModifyUrl,
        data: Matchers.any,
        (server) => server.reply(200, {'code': 0, 'data': {}}),
      );

      await _pumpDetail(tester);
      expect(find.text('关注'), findsOneWidget);

      await selectFocusable(tester, find.text('关注'));
      await flush(tester);

      expect(find.text('提示：关注成功！'), findsOneWidget);
      expect(find.text('已关注'), findsOneWidget);
    });

    testWidgets('未登录时提示先登录', (tester) async {
      await _pumpDetail(tester);
      await selectFocusable(tester, find.text('关注'));
      await flush(tester);

      expect(find.text('提示：请先登录！'), findsOneWidget);
    });
  });
}
