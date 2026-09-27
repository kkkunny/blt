import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/apis/bilibili/user.dart';
import 'package:blt/models/video.dart';
import 'package:blt/utils/json.dart';

import 'client.dart';

// 稿件id转动态id
Future<String> avidToDynamicId(int avid) async {
  final data = await bilibiliRequest(
    'GET',
    "https://api.bilibili.com/x/polymer/web-dynamic/v1/detail",
    queries: {'rid': avid, 'type': 8},
  );
  final idStr = jsonString(jsonMap(jsonMap(data)?['item'])?['id_str']);
  if (idStr.isEmpty) {
    throw const BilibiliError(-2, '动态id获取失败');
  }
  return idStr;
}

class GetDynamicPortalResponse {
  final List<UserInfo> ups;

  GetDynamicPortalResponse({required this.ups});

  factory GetDynamicPortalResponse.fromJson(Map<String, dynamic> json) {
    final items = jsonList(jsonMap(json['up_list'])?['items']);
    return GetDynamicPortalResponse(
      ups: (items ?? const <dynamic>[])
          .map((e) => jsonMap(e))
          .whereType<Map<String, dynamic>>()
          .map(UserInfo.fromJson)
          .whereType<UserInfo>()
          .toList(),
    );
  }
}

// 获取动态门户
Future<GetDynamicPortalResponse> getDynamicPortal() async {
  final Map<String, dynamic> queries = {'up_list_more': 1};
  final data = await bilibiliRequest(
    'GET',
    "https://api.bilibili.com/x/polymer/web-dynamic/v1/portal",
    queries: queries,
  );
  return GetDynamicPortalResponse.fromJson(jsonMap(data) ?? const {});
}

class ListDynamicResponse {
  final bool hasMore;
  final List<MediaCardInfo> medias;
  final int offset;

  ListDynamicResponse({
    required this.hasMore,
    required this.medias,
    required this.offset,
  });

  factory ListDynamicResponse.fromJson(Map<String, dynamic> json) {
    return ListDynamicResponse(
      hasMore: jsonBool(json['has_more']),
      medias: (jsonList(json['items']) ?? const <dynamic>[])
          .map((e) => jsonMap(e))
          .whereType<Map<String, dynamic>>()
          .map(MediaCardInfo.fromDynamicJson)
          .whereType<MediaCardInfo>()
          .toList(),
      // 最后一页时offset可能为空串
      offset: jsonInt(json['offset']),
    );
  }
}

// 拉取动态
Future<ListDynamicResponse> listDynamic({int offset = 0, int? mid}) async {
  final Map<String, dynamic> queries = {'type': 'video'};
  if (offset > 0) {
    queries['offset'] = offset;
  }
  if (mid != null) {
    queries['host_mid'] = mid;
  }
  final data = await bilibiliRequest(
    'GET',
    "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all",
    queries: queries,
  );
  return ListDynamicResponse.fromJson(jsonMap(data) ?? const {});
}
