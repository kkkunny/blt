import 'package:blt/widgets/bilibili_danmaku_wall.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('弹幕墙未就绪时控制器操作均为空操作', () {
    final controller = BilibiliDanmakuWallController(true);
    expect(controller.enabled, isTrue);

    // 弹幕墙（DanmakuScreen）尚未创建时不应抛异常
    controller.clear();
    controller.wait(const Duration(seconds: 1));
    controller.pause();
    controller.resume();
    controller.addDanmaku(DanmakuContentItem('测试弹幕'));

    controller.enabled = false;
    expect(controller.enabled, isFalse);
    controller.dispose();
  });
}
