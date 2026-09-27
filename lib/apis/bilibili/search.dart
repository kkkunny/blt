import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/models/video.dart';
import 'package:blt/utils/json.dart';

// 搜索视频
Future<List<MediaCardInfo>> searchVideos(String keyword, {int page = 1}) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/wbi/search/type',
    queries: {'search_type': 'video', 'keyword': keyword, 'page': page},
  );
  return (jsonList(jsonMap(data)?['result']) ?? const <dynamic>[])
      .map((item) => jsonMap(item))
      .whereType<Map<String, dynamic>>()
      .map(MediaCardInfo.fromSearchJson)
      .whereType<MediaCardInfo>()
      .toList();
}
