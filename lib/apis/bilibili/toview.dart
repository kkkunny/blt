import 'package:blt/models/video.dart' show MediaCardInfo;
import 'package:blt/storages/auth.dart' show loadCookie;
import 'package:blt/utils/json.dart';
import 'package:dio/dio.dart' show Headers;

import 'client.dart';

// 获取稍后再看列表
Future<List<MediaCardInfo>> listToView({int count = 30, int page = 1}) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/v2/history/toview/web',
    queries: {'pn': page, 'ps': count, 'viewed': 0, 'asc': false},
  );
  return (jsonList(jsonMap(data)?['list']) ?? const <dynamic>[])
      .map((item) => jsonMap(item))
      .whereType<Map<String, dynamic>>()
      .map(MediaCardInfo.fromToViewJson)
      .whereType<MediaCardInfo>()
      .toList();
}

// 添加到稍后再看
Future<void> addToView({int? avid, String? bvid}) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  Map<String, dynamic> body = {'csrf': csrf};
  if (avid != null) {
    body['aid'] = avid;
  } else {
    body['bvid'] = bvid;
  }
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/v2/history/toview/add',
    contentType: Headers.formUrlEncodedContentType,
    body: body,
  );
}

// 从稍后再看中删除
Future<void> deleteToView(int avid) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  await bilibiliRequest(
    'POST',
    'https://api.bilibili.com/x/v2/history/toview/del',
    contentType: Headers.formUrlEncodedContentType,
    body: {'aid': avid, 'csrf': csrf},
  );
}
