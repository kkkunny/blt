import 'package:blt/apis/bilibili/client.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/consts/search.dart';
import 'package:blt/models/video.dart';
import 'package:blt/utils/json.dart';

// 搜索结果：视频列表 + 总数/总页数（用于结果头部与翻页判断）
class SearchResult {
  final List<MediaCardInfo> videos;
  final int total;
  final int pages;

  SearchResult({
    required this.videos,
    required this.total,
    required this.pages,
  });
}

// 搜索视频
Future<SearchResult> searchVideos(
  String keyword, {
  int page = 1,
  SearchOrder order = SearchOrder.totalrank,
  SearchDuration duration = SearchDuration.all,
}) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/wbi/search/type',
    queries: {
      'search_type': 'video',
      'keyword': keyword,
      'page': page,
      'order': order.value,
      'duration': duration.value,
    },
  );
  final map = jsonMap(data) ?? const <String, dynamic>{};
  final videos = (jsonList(map['result']) ?? const <dynamic>[])
      .map((item) => jsonMap(item))
      .whereType<Map<String, dynamic>>()
      .map(MediaCardInfo.fromSearchJson)
      .whereType<MediaCardInfo>()
      .toList();
  return SearchResult(
    videos: videos,
    total: jsonInt(map['numResults']),
    pages: jsonInt(map['numPages']),
  );
}

// 热门搜索关键词
Future<List<String>> searchHotWords({int limit = 10}) async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/web-interface/wbi/search/square',
    queries: {'limit': limit},
  );
  final list =
      jsonList(jsonMap(jsonMap(data)?['trending'])?['list']) ??
      const <dynamic>[];
  return _uniqueWords(list, 'keyword', fallbackKey: 'show_name');
}

// 搜索建议关键词（最多10条）
Future<List<String>> searchSuggest(String term) async {
  final root = jsonMap(
    await bilibiliRequest(
      'GET',
      'https://s.search.bilibili.com/main/suggest',
      queries: {'term': term, 'main_ver': 'v1'},
      // 该接口的负载在根级 result 而不是 data，需要拿到完整响应自行校验 code
      respHandler: (response) => (true, jsonMap(response.data)),
    ),
  );
  final code = jsonInt(root?['code'], fallback: -2);
  if (code != 0) {
    throw BilibiliError(
      code,
      jsonString(root?['message'], fallback: '搜索建议获取失败'),
    );
  }
  final tags =
      jsonList(jsonMap(jsonMap(root)?['result'])?['tag']) ?? const <dynamic>[];
  return _uniqueWords(tags, 'value');
}

// 从接口项中提取关键词：去空白、去重、跳过空值
List<String> _uniqueWords(
  List<dynamic> items,
  String key, {
  String? fallbackKey,
}) {
  final words = <String>[];
  for (final item in items) {
    final map = jsonMap(item);
    if (map == null) continue;
    var word = jsonString(map[key]).trim();
    if (word.isEmpty && fallbackKey != null) {
      word = jsonString(map[fallbackKey]).trim();
    }
    if (word.isEmpty || words.contains(word)) continue;
    words.add(word);
  }
  return words;
}
