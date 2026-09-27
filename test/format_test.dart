import 'package:blt/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromVideoDurationString', () {
    test('分:秒', () {
      expect(
        fromVideoDurationString('3:05'),
        const Duration(minutes: 3, seconds: 5),
      );
    });

    test('时:分:秒（1小时以上视频）', () {
      expect(
        fromVideoDurationString('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('纯秒数', () {
      expect(fromVideoDurationString('75'), const Duration(seconds: 75));
    });

    test('空字符串返回0', () {
      expect(fromVideoDurationString(''), Duration.zero);
    });

    test('非法格式返回0而不是抛异常', () {
      expect(fromVideoDurationString('abc'), Duration.zero);
      expect(fromVideoDurationString('1:2:3:4'), Duration.zero);
      expect(fromVideoDurationString(':'), Duration.zero);
    });
  });

  group('amountString', () {
    test('一万整不显示为千', () {
      expect(amountString(10000), '1.0万');
    });

    test('一亿整不显示为万', () {
      expect(amountString(100000000), '1.0亿');
    });

    test('常规数量', () {
      expect(amountString(999), '999');
      expect(amountString(1234), '1.2千');
      expect(amountString(12345), '1.2万');
    });
  });
}
