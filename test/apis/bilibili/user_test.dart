import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/apis/bilibili/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioAdapter _mock() => DioAdapter(dio: bilibiliHttpClient);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserInfo.fromJson', () {
    test('mid 缺失/非法（核心字段）时返回 null', () {
      expect(UserInfo.fromJson({'uname': 'x'}), isNull);
      expect(UserInfo.fromJson({'mid': 0, 'uname': 'x'}), isNull);
      expect(UserInfo.fromJson({'mid': 'bad', 'uname': 'x'}), isNull);
    });

    test('次要字段类型错时降级默认值', () {
      final info = UserInfo.fromJson({'mid': '123', 'uname': 1, 'face': null});
      expect(info!.mid, 123);
      expect(info.name, '');
      expect(info.avatar, '');
    });
  });

  group('MySelf.fromJson', () {
    test('level_info 链路缺失时等级降级 0', () {
      final info = MySelf.fromJson({
        'mid': 123,
        'uname': 'me',
        'level_info': null,
      });
      expect(info!.level, 0);
    });

    test('level_info 类型错时不崩溃', () {
      final info = MySelf.fromJson({
        'mid': 123,
        'level_info': 'bad',
      });
      expect(info!.level, 0);
    });
  });

  group('getMySelfInfo', () {
    const url = 'https://api.bilibili.com/x/web-interface/nav';

    test('正常解析用户信息', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {
            'mid': 123,
            'uname': 'me',
            'face': 'avatar.jpg',
            'level_info': {'current_level': 6},
            'money': 100,
          },
        }),
      );

      final info = await getMySelfInfo();
      expect(info.mid, 123);
      expect(info.level, 6);
      expect(info.money, 100);
    });

    test('用户信息不完整时抛 BilibiliError 而不是崩溃', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'uname': 'me'},
        }),
      );

      await expectLater(
        getMySelfInfo(),
        throwsA(isA<BilibiliError>().having((e) => e.code, 'code', -2)),
      );
    });
  });

  group('UserRelation.fromJson', () {
    test('attribute 类型错时降级未关注', () {
      final relation = UserRelation.fromJson({'attribute': 'bad'});
      expect(relation.attribute, 0);
      expect(relation.following, false);
    });

    test('已关注/互粉判定', () {
      expect(UserRelation.fromJson({'attribute': 2}).following, true);
      expect(UserRelation.fromJson({'attribute': 6}).following, true);
      expect(UserRelation.fromJson({'attribute': 128}).following, false);
    });
  });

  group('getUserRelation', () {
    const url = 'https://api.bilibili.com/x/relation';

    test('data 非 Map 时返回默认关系', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {'code': 0, 'data': null}),
      );

      final relation = await getUserRelation(123);
      expect(relation.attribute, 0);
    });
  });

  group('getUserFollowerCount', () {
    const url = 'https://api.bilibili.com/x/relation/stat';

    test('粉丝数字符串解析', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'follower': '12345'},
        }),
      );

      expect(await getUserFollowerCount(123), 12345);
    });

    test('粉丝数类型错时返回 0', () async {
      final adapter = _mock();
      adapter.onGet(
        url,
        (server) => server.reply(200, {
          'code': 0,
          'data': {'follower': 'bad'},
        }),
      );

      expect(await getUserFollowerCount(123), 0);
    });
  });
}
