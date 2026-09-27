import 'package:blt/models/video.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/video_card.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaCardInfo _fakeVideo() => MediaCardInfo(
  type: MediaType.video,
  avid: 1,
  bvid: 'BV1',
  title: '测试视频标题测试视频标题测试视频标题',
  cover: 'https://example.invalid/cover.jpg',
  duration: const Duration(minutes: 3, seconds: 20),
  userMid: 1,
  userName: '测试UP主',
  userAvatar: 'https://example.invalid/avatar.jpg',
  publishTime: DateTime(2026, 1, 1),
);

Widget _host({required double ui, required Widget child}) => UiScale(
  factor: ui,
  child: MaterialApp(home: Scaffold(body: child)),
);

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('相关推荐（横向单行）与主页（纵向栅格）卡片宽高比一致', (tester) async {
    _setScreen(tester, const Size(1920, 1080));

    // 主页：纵向栅格
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: VideoGridView(
          provider: VideoGridViewProvider(initVideos: [_fakeVideo()]),
        ),
      ),
    );
    final homeCard = tester.getSize(find.byType(VideoCard).first);
    final homeCover = tester.getSize(find.byType(BilibiliMediaThumbnail).first);

    // 相关推荐：横向栅格，单行
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: SizedBox(
          height: 300,
          child: VideoGridView(
            provider: VideoGridViewProvider(initVideos: [_fakeVideo()]),
            scrollDirection: Axis.horizontal,
            crossAxisCount: 1,
          ),
        ),
      ),
    );
    final relatedCard = tester.getSize(find.byType(VideoCard).first);
    final relatedCover = tester.getSize(
      find.byType(BilibiliMediaThumbnail).first,
    );

    expect(
      homeCard.width / homeCard.height,
      closeTo(videoCardAspectRatio, 1e-6),
    );
    expect(
      relatedCard.width / relatedCard.height,
      closeTo(videoCardAspectRatio, 1e-6),
    );
    // 封面固定16:9，且只被3ui的焦点描边内缩
    for (final (card, cover) in [
      (homeCard, homeCover),
      (relatedCard, relatedCover),
    ]) {
      expect(cover.width, closeTo(card.width - 6, 1e-6));
      expect(cover.width / cover.height, closeTo(16 / 9, 1e-6));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('封面角标随卡片宽度缩放，窄卡片角标同比缩小', (tester) async {
    _setScreen(tester, const Size(1920, 1080));

    Future<double> upNameFontSize(double width, {double ui = 1}) async {
      await tester.pumpWidget(
        _host(
          ui: ui,
          child: Center(
            child: SizedBox(
              width: width,
              height: width / videoCardAspectRatio,
              child: VideoCard(video: _fakeVideo()),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('测试UP主'));
      return text.style!.fontSize!;
    }

    // 主页卡片宽度（约551）与相关推荐卡片宽度（约323）
    final home = await upNameFontSize(550);
    final related = await upNameFontSize(323);
    // 大卡片角标不跟着放大，保持基准字号
    final huge = await upNameFontSize(1200);

    expect(home, closeTo(24, 1e-6));
    expect(related / home, closeTo(0.7, 0.02));
    expect(huge, closeTo(24, 1e-6));

    // 缩放下角标仍按"卡片宽度 / 该 ui 的设计宽度"缩放（720p 主页卡片约275）
    final halfHome = await upNameFontSize(275, ui: 0.5);
    final halfRelated = await upNameFontSize(161, ui: 0.5);
    expect(halfHome, closeTo(12, 1e-6));
    expect(halfRelated / halfHome, closeTo(0.7, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('卡片内部尺寸随 ui 等比缩放', (tester) async {
    _setScreen(tester, const Size(1920, 1080));

    Future<TextStyle> titleStyleAt(double ui) async {
      await tester.pumpWidget(
        _host(
          ui: ui,
          child: Center(
            child: SizedBox(
              width: 462 * ui,
              height: 385 * ui,
              child: VideoCard(video: _fakeVideo()),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('测试视频标题测试视频标题测试视频标题'));
      return text.style!;
    }

    final base = await titleStyleAt(1);
    final scaled = await titleStyleAt(0.667);

    expect(scaled.fontSize! / base.fontSize!, closeTo(0.667, 1e-2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('卡片被压扁时标题字号不会超过卡片宽度比例', (tester) async {
    _setScreen(tester, const Size(1920, 1080));

    // 与卡片宽度挂钩的上限：宽度 * 0.065
    const width = 282.0;
    const height = 269.0;
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: VideoCard(video: _fakeVideo(), aspectRatio: 1.05),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('测试视频标题测试视频标题测试视频标题'));
    expect(text.style!.fontSize!, lessThanOrEqualTo(width * 0.065 + 1e-6));
    expect(tester.takeException(), isNull);
  });
}
