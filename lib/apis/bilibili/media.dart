import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/models/pbs/dm.pb.dart';
import 'package:blt/models/video.dart' show Video;
import 'package:blt/storages/auth.dart' show loadCookie;
import 'package:blt/utils/json.dart';
import 'package:blt/utils/log.dart';
import 'package:dio/dio.dart';

import 'client.dart';
import 'dynamic.dart';

final _log = log('media');

class Quality {
  late final int id;
  late final String description;

  Quality({required this.id, required this.description});

  // 核心字段（清晰度 id）缺失时返回 null，调用方丢弃该项
  static Quality? fromJson(Map<String, dynamic> json) {
    final id = jsonInt(json['quality'], fallback: jsonInt(json['id']));
    if (id <= 0) return null;
    return Quality(id: id, description: jsonString(json['new_description']));
  }
}

class DashMediaData {
  final int quality;
  final String baseUrl;
  final List<String> backupUrls;

  const DashMediaData({
    required this.quality,
    required this.baseUrl,
    required this.backupUrls,
  });

  // 核心字段（播放地址）缺失时返回 null，调用方丢弃该项
  static DashMediaData? fromJson(Map<String, dynamic> json) {
    final baseUrl = jsonString(json['base_url']);
    if (baseUrl.isEmpty) return null;
    return DashMediaData(
      quality: jsonInt(json['id']),
      baseUrl: baseUrl,
      backupUrls: (jsonList(json['backup_url']) ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }
}

class DashData {
  final List<DashMediaData> video;
  final List<DashMediaData> audio;

  const DashData({this.video = const [], this.audio = const []});

  factory DashData.fromJson(Map<String, dynamic> json) {
    return DashData(
      video: (jsonList(json['video']) ?? const <dynamic>[])
          .map((item) => jsonMap(item))
          .whereType<Map<String, dynamic>>()
          .map(DashMediaData.fromJson)
          .whereType<DashMediaData>()
          .toList(),
      audio: (jsonList(json['audio']) ?? const <dynamic>[])
          .map((item) => jsonMap(item))
          .whereType<Map<String, dynamic>>()
          .map(DashMediaData.fromJson)
          .whereType<DashMediaData>()
          .toList(),
    );
  }
}

class GetVideoPlayURLResponse {
  late final int defaultQualityID;
  late final List<Quality> supportFormats;
  late final DashData dashData;

  GetVideoPlayURLResponse({
    required this.defaultQualityID,
    this.supportFormats = const [],
    this.dashData = const DashData(),
  });

  factory GetVideoPlayURLResponse.fromJson(Map<String, dynamic> json) {
    return GetVideoPlayURLResponse(
      defaultQualityID: jsonInt(json['quality']),
      supportFormats: (jsonList(json['support_formats']) ?? const <dynamic>[])
          .map((item) => jsonMap(item))
          .whereType<Map<String, dynamic>>()
          .map(Quality.fromJson)
          .whereType<Quality>()
          .toList(),
      dashData: DashData.fromJson(jsonMap(json['dash']) ?? const {}),
    );
  }
}

// 获取视频播放地址
Future<GetVideoPlayURLResponse> getVideoPlayURL({
  int? avid,
  String? bvid,
  required int cid,
}) async {
  Map<String, dynamic> queryParams = {'cid': cid, 'fnval': 16};
  if (avid != null) {
    queryParams['avid'] = avid;
  } else {
    queryParams['bvid'] = bvid;
  }
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/player/wbi/playurl',
    queries: queryParams,
  );
  _log.i('获取播放地址 aid=$avid bvid=$bvid cid=$cid');
  return GetVideoPlayURLResponse.fromJson(jsonMap(data) ?? const {});
}

// 获取视频信息
Future<Video> getVideoInfo({int? avid, String? bvid}) async {
  Map<String, dynamic> queryParams = {};
  if (avid != null) {
    queryParams['aid'] = avid;
  } else {
    queryParams['bvid'] = bvid;
  }
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/view',
    queries: queryParams,
  );
  final video = Video.fromJson(jsonMap(data) ?? const {});
  if (video == null) {
    throw const BilibiliError(-2, '视频信息不完整');
  }
  return video;
}

class ArchiveRelation {
  bool like;
  bool dislike;
  bool favorite;
  int coin;
  bool seasonFav;

  ArchiveRelation({
    this.like = false,
    this.dislike = false,
    this.favorite = false,
    this.coin = 0,
    this.seasonFav = false,
  });

  factory ArchiveRelation.fromJson(Map<String, dynamic> json) {
    return ArchiveRelation(
      like: jsonBool(json['like']),
      dislike: jsonBool(json['dislike']),
      favorite: jsonBool(json['favorite']),
      coin: jsonInt(json['coin']),
      seasonFav: jsonBool(json['season_fav']),
    );
  }
}

// 获取视频关系
Future<ArchiveRelation> getArchiveRelation({int? avid, String? bvid}) async {
  Map<String, dynamic> queryParams = {};
  if (avid != null) {
    queryParams['aid'] = avid;
  } else {
    queryParams['bvid'] = bvid;
  }
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/archive/relation',
    queries: queryParams,
  );
  return ArchiveRelation.fromJson(jsonMap(data) ?? const {});
}

// 获取弹幕
Future<DmSegMobileReply> getDanmaku(int cid, int segmentIndex) async {
  Map<String, dynamic> queryParams = {
    'type': 1,
    'oid': cid,
    'segment_index': segmentIndex,
  };
  final response = await bilibiliHttpClient.get(
    'https://api.bilibili.com/x/v2/dm/web/seg.so',
    queryParameters: queryParams,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = response.data;
  if (bytes is! List<int>) {
    throw const BilibiliError(-2, '弹幕响应格式异常');
  }
  try {
    return DmSegMobileReply.fromBuffer(bytes);
  } catch (_) {
    throw const BilibiliError(-2, '弹幕解析失败');
  }
}

// // 点赞
// // 该接口会报-403 账号异常,操作失败 https://github.com/SocialSisterYi/bilibili-API-collect/issues/1251
// Future<void> likeMedia({int? avid, String? bvid, required bool like}) async {
//   final csrf = (await loadCookie())
//       .firstWhere((c) => c.name == 'bili_jct')
//       .value;
//   Map<String, dynamic> body = {'like': like ? 1 : 2, 'csrf': csrf};
//   if (avid != null) {
//     body['aid'] = avid;
//   } else {
//     body['bvid'] = bvid;
//   }
//   await bilibiliRequest(
//     'POST',
//     'https://api.bilibili.com/x/web-interface/archive/like',
//     contentType: Headers.formUrlEncodedContentType,
//     body: body,
//   );
// }

// 点赞
Future<void> likeMedia(int avid, {required bool like}) async {
  final dynamicId = await avidToDynamicId(avid);

  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  await bilibiliRequest(
    'POST',
    "https://api.bilibili.com/x/dynamic/feed/dyn/thumb",
    contentType: Headers.jsonContentType,
    queries: {'csrf': csrf},
    body: {'dyn_id_str': dynamicId, 'up': like ? 1 : 2},
  );
}

// 投币
Future<void> insertCoin({
  int? avid,
  String? bvid,
  int count = 1,
  bool like = false,
}) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  Map<String, dynamic> body = {
    'multiply': count,
    'select_like': like ? 1 : 0,
    'csrf': csrf,
  };
  if (avid != null) {
    body['aid'] = avid;
  } else {
    body['bvid'] = bvid;
  }
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/web-interface/coin/add',
    contentType: Headers.formUrlEncodedContentType,
    body: body,
  );
}
