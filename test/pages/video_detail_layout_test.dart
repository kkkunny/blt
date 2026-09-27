import 'package:blt/apis/bilibili/media.dart' show ArchiveRelation;
import 'package:blt/consts/bilibili.dart' show coverSizeRatio;
import 'package:blt/icons/iconfont.dart';
import 'package:blt/models/video.dart';
import 'package:blt/pages/video_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/page_test_env.dart';

Video _fakeVideo() => Video(
  avid: 170001,
  bvid: 'BV1',
  title: '测试视频标题',
  cover: 'https://example.invalid/cover.jpg',
  desc: '测试视频简介，内容比较长，用来验证简介区域的排版效果。',
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
    Episode(
      index: 2,
      cid: 2,
      title: 'P2',
      duration: Duration(minutes: 5, seconds: 10),
    ),
  ],
);

List<MediaCardInfo> _relatedVideos() => List.generate(
  3,
  (i) => MediaCardInfo(
    type: MediaType.video,
    avid: 1000 + i,
    bvid: 'BV$i',
    cid: 1,
    title: '相关推荐视频标题$i',
    cover: 'https://example.invalid/cover$i.jpg',
    duration: Duration(minutes: 8 + i, seconds: 20),
    stat: Stat(
      viewCount: 12345 + i,
      favoriteCount: 10,
      likeCount: 20,
      dislikeCount: 1,
      coinCount: 5,
      shareCount: 2,
    ),
    userMid: 100 + i,
    userName: '推荐UP主$i',
    userAvatar: 'https://example.invalid/avatar$i.jpg',
    publishTime: DateTime(2026, 2, 1 + i),
  ),
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  Size size = const Size(1920, 1080),
}) async {
  await pumpPage(
    tester,
    VideoDetailPage(
      video: _fakeVideo(),
      relation: ArchiveRelation(),
      followerCount: 12345,
      relatedVideos: _relatedVideos(),
    ),
    size: size,
  );
  await flush(tester);
}

void main() {
  setupPageTestEnv();

  testWidgets('播放卡与卡片封面统一为 16:9', (tester) async {
    await _pumpDetail(tester);

    final ratioFinders = find.byWidgetPredicate(
      (widget) => widget is AspectRatio && widget.aspectRatio == coverSizeRatio,
    );
    // 播放卡 + 3 张相关推荐卡片封面
    expect(ratioFinders, findsNWidgets(4));

    // 树序第一个是播放卡，明显大于相关推荐卡片封面
    final playerSize = tester.getSize(ratioFinders.at(0));
    expect(playerSize.width / playerSize.height, closeTo(16 / 9, 1e-6));
    final relatedSize = tester.getSize(ratioFinders.at(1));
    expect(playerSize.width, greaterThan(relatedSize.width * 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('6 个操作按钮均为可聚焦胶囊', (tester) async {
    await _pumpDetail(tester);

    for (final icon in [
      Icons.thumb_up_rounded,
      Icons.thumb_down_rounded,
      IconFont.coin,
      Icons.star_rounded,
      IconFont.playlist,
      IconFont.share,
    ]) {
      final finder = find.byIcon(icon);
      expect(finder, findsOneWidget);
      expect(
        find.ancestor(of: finder, matching: find.byType(Focus)),
        findsWidgets,
        reason: '$icon 应当可聚焦',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('简介可展开完整弹窗并关闭', (tester) async {
    await _pumpDetail(tester);

    await selectFocusable(tester, find.textContaining('测试视频简介'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('视频简介'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);

    await selectFocusable(tester, find.text('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('视频简介'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('720p/1080p/4K/4:3 下详情页无溢出', (tester) async {
    for (final size in const [
      Size(1280, 720),
      Size(1920, 1080),
      Size(3840, 2160),
      Size(1600, 1200),
      Size(2560, 1080),
    ]) {
      await _pumpDetail(tester, size: size);
      expect(tester.takeException(), isNull, reason: '$size 下不应溢出');
    }
  });

  testWidgets('720p/4K 下简介弹窗无溢出', (tester) async {
    for (final size in const [Size(1280, 720), Size(3840, 2160)]) {
      await _pumpDetail(tester, size: size);
      await selectFocusable(tester, find.textContaining('测试视频简介'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('视频简介'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size 下弹窗不应溢出');

      await selectFocusable(tester, find.text('关闭'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('视频简介'), findsNothing);
    }
  });
}
