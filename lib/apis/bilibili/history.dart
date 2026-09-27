import 'package:blt/models/video.dart' show MediaCardInfo;
import 'package:blt/storages/auth.dart' show loadCookie, loginInfoNotifier;
import 'package:blt/utils/json.dart';
import 'package:dio/dio.dart';

import 'client.dart';

class MediaPlayInfo {
  final int lastPlayCid;
  final Duration lastPlayTime;
  final int onlineCount; // 当前在线人数

  MediaPlayInfo({
    required this.lastPlayCid,
    required this.lastPlayTime,
    required this.onlineCount,
  });

  factory MediaPlayInfo.fromJson(Map<String, dynamic> json) {
    return MediaPlayInfo(
      lastPlayCid: jsonInt(json['last_play_cid']),
      lastPlayTime: Duration(milliseconds: jsonInt(json['last_play_time'])),
      onlineCount: jsonInt(json['online_count']),
    );
  }
}

// 获取播放信息
Future<MediaPlayInfo> getMediaPlayInfo({
  int? avid,
  String? bvid,
  required int cid,
}) async {
  Map<String, dynamic> queryParams = {'cid': cid};
  if (avid != null) {
    queryParams['aid'] = avid;
  } else {
    queryParams['bvid'] = bvid;
  }
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/player/v2',
    queries: queryParams,
  );
  return MediaPlayInfo.fromJson(jsonMap(data) ?? const {});
}

// 上报播放开始
Future<void> reportPlayStart(int? avid, int cid) async {
  final Map<String, dynamic> body = {'aid': avid, 'cid': cid};
  if (loginInfoNotifier.value.isLogin) {
    final csrf = (await loadCookie())
        .firstWhere((c) => c.name == 'bili_jct')
        .value;
    body['mid'] = loginInfoNotifier.value.mid;
    body['csrf'] = csrf;
  }
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/click-interface/click/web/h5',
    contentType: Headers.formUrlEncodedContentType,
    body: body,
  );
}

// 上报播放进度
Future<void> reportPlayProgress(int? avid, int cid, Duration progress) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  Map<String, dynamic> queryParams = {
    'aid': avid,
    'cid': cid,
    'csrf': csrf,
    'progress': progress.inSeconds,
  };
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/v2/history/report',
    queries: queryParams,
  );
}

// 播放心跳
Future<void> reportPlayHeartbeat({
  int? avid,
  String? bvid,
  required int cid,
  required Duration progress,
}) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  Map<String, dynamic> body = {
    'mid': loginInfoNotifier.value.mid,
    'cid': cid,
    'csrf': csrf,
    'played_time': progress.inSeconds,
  };
  if (avid != null) {
    body['aid'] = avid;
  } else {
    body['bvid'] = bvid;
  }
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/click-interface/web/heartbeat',
    contentType: Headers.formUrlEncodedContentType,
    body: body,
  );
}

class HistoryCursor {
  final int max;
  final DateTime viewAt;
  final String business;

  HistoryCursor({
    required this.max,
    required this.viewAt,
    required this.business,
  });

  factory HistoryCursor.fromJson(Map<String, dynamic> json) {
    return HistoryCursor(
      max: jsonInt(json['max']),
      viewAt: DateTime.fromMillisecondsSinceEpoch(
        jsonInt(json['view_at']) * Duration.millisecondsPerSecond,
      ),
      business: jsonString(json['business']),
    );
  }
}

// 历史记录
Future<(HistoryCursor, List<MediaCardInfo>)> listHistory({
  HistoryCursor? cursor,
  int count = 20,
}) async {
  Map<String, dynamic> queries = {'type': 'archive', 'ps': count};
  if (cursor != null) {
    queries['max'] = cursor.max;
    queries['view_at'] =
        (cursor.viewAt.millisecondsSinceEpoch / Duration.millisecondsPerSecond)
            .toInt();
    queries['business'] = cursor.business;
  }
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/history/cursor',
    queries: queries,
  );
  final nextCursor = HistoryCursor.fromJson(
    jsonMap(jsonMap(data)?['cursor']) ?? const {},
  );
  final videos = (jsonList(jsonMap(data)?['list']) ?? const <dynamic>[])
      .map((e) => jsonMap(e))
      .whereType<Map<String, dynamic>>()
      .map(MediaCardInfo.fromHistoryJson)
      .whereType<MediaCardInfo>()
      .toList();
  return (nextCursor, videos);
}

// 删除记录
Future<void> deleteHistory(int avid) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/v2/history/delete',
    contentType: Headers.formUrlEncodedContentType,
    body: {'kid': 'archive_$avid', 'csrf': csrf},
  );
}
