import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/storages/auth.dart' show loadCookie;
import 'package:blt/utils/json.dart';
import 'package:dio/dio.dart' show Headers;

class UserInfo {
  final int mid;
  final String name;
  final String avatar;

  UserInfo({required this.mid, required this.name, required this.avatar});

  // 核心字段（mid）缺失时返回 null，调用方丢弃该项
  static UserInfo? fromJson(Map<String, dynamic> json) {
    final mid = jsonInt(json['mid']);
    if (mid <= 0) return null;
    return UserInfo(
      mid: mid,
      name: jsonString(json['uname']),
      avatar: jsonString(json['face']),
    );
  }
}

class MySelf extends UserInfo {
  final int level;
  final int money;

  MySelf({
    required super.mid,
    required super.name,
    required super.avatar,
    required this.level,
    required this.money,
  });

  // 核心字段（mid）缺失时返回 null，由调用方转为可读错误
  static MySelf? fromJson(Map<String, dynamic> json) {
    final mid = jsonInt(json['mid']);
    if (mid <= 0) return null;
    final levelInfo = jsonMap(json['level_info']) ?? const <String, dynamic>{};
    return MySelf(
      mid: mid,
      name: jsonString(json['uname']),
      avatar: jsonString(json['face']),
      level: jsonInt(levelInfo['current_level']),
      money: jsonInt(json['money']),
    );
  }
}

Future<MySelf> getMySelfInfo() async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/nav',
  );
  final info = MySelf.fromJson(jsonMap(data) ?? const {});
  if (info == null) {
    throw const BilibiliError(-2, '用户信息不完整');
  }
  return info;
}

// 用户关系属性
class UserRelation {
  final int attribute; // 0：未关注 2：已关注 6：已互粉 128：已拉黑

  const UserRelation({this.attribute = 0});

  factory UserRelation.fromJson(Map<String, dynamic> json) {
    return UserRelation(attribute: jsonInt(json['attribute']));
  }

  // 是否已关注
  bool get following => attribute == 2 || attribute == 6;
}

// 查询用户与自己关系（需要登陆）
Future<UserRelation> getUserRelation(int mid) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/relation',
    queries: {'fid': mid},
  );
  final map = jsonMap(data);
  if (map == null) return const UserRelation();
  return UserRelation.fromJson(map);
}

// 查询用户粉丝数
Future<int> getUserFollowerCount(int mid) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/relation/stat',
    queries: {'vmid': mid},
  );
  return jsonInt(jsonMap(data)?['follower']);
}

// 关注/取关（需要登陆）
Future<void> modifyUserRelation(int mid, {required bool follow}) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/relation/modify',
    contentType: Headers.formUrlEncodedContentType,
    body: {'fid': mid, 'act': follow ? 1 : 2, 're_src': 14, 'csrf': csrf},
  );
}
