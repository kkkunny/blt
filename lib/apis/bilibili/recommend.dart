import 'package:blt/models/video.dart' show MediaCardInfo, MediaType;
import 'package:blt/utils/json.dart';

import 'client.dart';

// 获取推荐视频
Future<List<MediaCardInfo>> listRecommendVideos({
  int freshType = 4,
  int count = 30,
  int page = 1,
  List<int> removeAvids = const [],
}) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd',
    queries: {
      'fresh_type': freshType,
      'ps': count,
      'fresh_idx': page,
      'last_show_list': removeAvids.map((v) => 'av_$v').join(','),
    },
  );
  final List<MediaCardInfo> videos = [];
  for (final item in jsonList(jsonMap(data)?['item']) ?? const <dynamic>[]) {
    // 过滤掉非视频媒体与坏数据
    final media = MediaCardInfo.fromJson(jsonMap(item) ?? const {});
    if (media == null || media.type != MediaType.video) {
      continue;
    }
    videos.add(media);
  }
  return videos;
}

// 获取相关视频
Future<List<MediaCardInfo>> fetchRelatedVideos({
  int? avid,
  String? bvid,
}) async {
  Map<String, dynamic> queryParams = {};
  if (avid != null) {
    queryParams['aid'] = avid;
  } else {
    queryParams['bvid'] = bvid;
  }
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/archive/related',
    queries: queryParams,
  );
  final List<MediaCardInfo> videos = [];
  for (final item in jsonList(data) ?? const <dynamic>[]) {
    final media = MediaCardInfo.fromJson(jsonMap(item) ?? const {});
    if (media == null) continue;
    videos.add(media);
  }
  return videos;
}
