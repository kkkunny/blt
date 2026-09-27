import 'package:blt/utils/comparable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComparableExtends.clamp', () {
    test('区间内原样返回', () {
      expect('b'.clamp('a', 'c'), 'b');
    });

    test('低于下界返回下界', () {
      expect('a'.clamp('b', 'd'), 'b');
    });

    test('高于上界返回上界', () {
      expect('z'.clamp('b', 'd'), 'd');
    });

    test('边界值原样返回', () {
      expect('b'.clamp('b', 'd'), 'b');
      expect('d'.clamp('b', 'd'), 'd');
    });

    test('DateTime 同样适用', () {
      final min = DateTime(2024);
      final max = DateTime(2026);
      expect(DateTime(2023).clamp(min, max), min);
      expect(DateTime(2025).clamp(min, max), DateTime(2025));
      expect(DateTime(2027).clamp(min, max), max);
    });
  });
}
