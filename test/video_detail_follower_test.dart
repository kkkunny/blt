import 'package:blt/apis/bilibili/media.dart' show ArchiveRelation;
import 'package:blt/icons/iconfont.dart';
import 'package:blt/models/video.dart';
import 'package:blt/pages/video_detail.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Video _fakeVideo() => Video(
  avid: 1,
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

Widget _host(Widget child, double factor) =>
    UiScale(factor: factor, child: MaterialApp(home: child));

Future<void> _pumpDetail(
  WidgetTester tester, {
  int? followerCount,
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _host(
      VideoDetailPage(
        video: _fakeVideo(),
        relation: ArchiveRelation(),
        followerCount: followerCount,
      ),
      UiScale.factorFor(size),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('粉丝数以 icon + 文本展示', (tester) async {
    await _pumpDetail(tester, followerCount: 12345);

    expect(find.byIcon(IconFont.fensi), findsOneWidget);
    expect(find.text('1.2万粉丝'), findsOneWidget);
  });

  testWidgets('粉丝数未知时展示占位文案并保留 icon', (tester) async {
    await _pumpDetail(tester);

    expect(find.byIcon(IconFont.fensi), findsOneWidget);
    expect(find.text('UP 主'), findsOneWidget);
  });

  testWidgets('720p/1080p/4K 下粉丝数区域无溢出', (tester) async {
    for (final size in const [
      Size(1280, 720),
      Size(1920, 1080),
      Size(3840, 2160),
    ]) {
      await _pumpDetail(tester, followerCount: 12345678, size: size);
      expect(tester.takeException(), isNull, reason: '$size 下不应溢出');
    }
  });
}
