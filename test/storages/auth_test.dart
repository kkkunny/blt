import 'dart:io';

import 'package:blt/storages/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('saveCookie/loadCookie', () {
    test('保存后可完整读回', () async {
      await saveCookie([Cookie('SESSDATA', 'abc'), Cookie('bili_jct', 'xyz')]);

      final cookies = await loadCookie();
      expect(cookies.map((c) => '${c.name}=${c.value}'), [
        'SESSDATA=abc',
        'bili_jct=xyz',
      ]);
    });

    test('未保存时返回空列表', () async {
      expect(await loadCookie(), isEmpty);
    });

    test('单条损坏的 cookie 被跳过，不影响其它 cookie', () async {
      SharedPreferences.setMockInitialValues({
        'bilibili_cookie': 'SESSDATA=abc; bad cookie value; bili_jct=xyz',
      });

      final cookies = await loadCookie();
      expect(cookies.map((c) => '${c.name}=${c.value}'), [
        'SESSDATA=abc',
        'bili_jct=xyz',
      ]);
    });

    test('refreshToken 为空串时不写入', () async {
      await saveCookie([Cookie('a', '1')], refreshToken: '');
      expect(await loadRefreshToken(), isNull);
    });
  });

  group('loadRefreshToken', () {
    test('保存后可读回', () async {
      await saveCookie([Cookie('a', '1')], refreshToken: 'rt-1');
      expect(await loadRefreshToken(), 'rt-1');
    });
  });

  group('clearCookie', () {
    test('默认同时清除 refreshToken', () async {
      await saveCookie([Cookie('a', '1')], refreshToken: 'rt-1');
      await clearCookie();

      expect(await loadCookie(), isEmpty);
      expect(await loadRefreshToken(), isNull);
    });

    test('可保留 refreshToken', () async {
      await saveCookie([Cookie('a', '1')], refreshToken: 'rt-1');
      await clearCookie(withRefreshToken: false);

      expect(await loadCookie(), isEmpty);
      expect(await loadRefreshToken(), 'rt-1');
    });
  });
}
