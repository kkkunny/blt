import 'package:blt/utils/json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jsonMap', () {
    test('Map 原样返回，非字符串 key 转为字符串', () {
      expect(jsonMap({'a': 1}), {'a': 1});
      expect(jsonMap(<dynamic, dynamic>{1: 'x'}), {'1': 'x'});
    });

    test('非 Map 返回 null', () {
      expect(jsonMap(null), isNull);
      expect(jsonMap('x'), isNull);
      expect(jsonMap(1), isNull);
      expect(jsonMap([1]), isNull);
    });
  });

  group('jsonList', () {
    test('List 原样返回', () {
      expect(jsonList([1, 2]), [1, 2]);
      expect(jsonList(const []), isEmpty);
    });

    test('非 List 返回 null', () {
      expect(jsonList(null), isNull);
      expect(jsonList('x'), isNull);
      expect(jsonList({'a': 1}), isNull);
    });
  });

  group('jsonInt', () {
    test('int/num 原样转换', () {
      expect(jsonInt(42), 42);
      expect(jsonInt(42.9), 42);
    });

    test('数字字符串解析（含浮点字符串）', () {
      expect(jsonInt('42'), 42);
      expect(jsonInt(' 42 '), 42);
      expect(jsonInt('42.9'), 42);
      expect(jsonInt('-101'), -101);
    });

    test('非法值返回 fallback', () {
      expect(jsonInt(null), 0);
      expect(jsonInt(''), 0);
      expect(jsonInt('abc'), 0);
      expect(jsonInt('abc', fallback: -2), -2);
      expect(jsonInt(true), 0);
      expect(jsonInt([1]), 0);
    });
  });

  group('jsonString', () {
    test('String 原样返回', () {
      expect(jsonString('x'), 'x');
      expect(jsonString(''), '');
    });

    test('非 String 返回 fallback', () {
      expect(jsonString(null), '');
      expect(jsonString(1), '');
      expect(jsonString(true), '');
      expect(jsonString(null, fallback: '未知'), '未知');
    });
  });

  group('jsonBool', () {
    test('bool 原样返回', () {
      expect(jsonBool(true), true);
      expect(jsonBool(false), false);
    });

    test('num 按非 0 转换', () {
      expect(jsonBool(1), true);
      expect(jsonBool(2), true);
      expect(jsonBool(0), false);
    });

    test('非法值返回 fallback', () {
      expect(jsonBool(null), false);
      expect(jsonBool('true'), false);
      expect(jsonBool('true', fallback: true), true);
    });
  });
}
