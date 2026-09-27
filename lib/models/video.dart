import 'package:blt/utils/format.dart' show fromVideoDurationString;
import 'package:blt/utils/json.dart';

enum MediaType {
  unknown,
  video, // 视频
  live, // 直播
  ogv, // 边栏
}

MediaType _mediaType(String value) {
  switch (value) {
    case 'av':
      return MediaType.video;
    case 'live':
      return MediaType.live;
    case 'ogv':
      return MediaType.ogv;
    default:
      return MediaType.unknown;
  }
}

DateTime _time(int seconds) {
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * Duration.millisecondsPerSecond,
  );
}

// 播放进度
class PlayProgress {
  final int progress; // 播放时长秒数

  PlayProgress(this.progress);

  factory PlayProgress.fromJson(Map<String, dynamic> json) {
    return PlayProgress(jsonInt(json['progress']));
  }

  bool finished() => progress < 0;

  Duration duration() => Duration(seconds: progress);
}

// 媒体卡片信息
class MediaCardInfo {
  final MediaType type;
  final int avid;
  final String bvid;
  final int? cid;
  final String title;
  final String cover;
  final Duration duration;
  final PlayProgress? progress;
  final Stat? stat;
  final int userMid;
  final String userName;
  final String userAvatar;
  final DateTime publishTime;

  MediaCardInfo({
    required this.type,
    required this.avid,
    required this.bvid,
    this.cid,
    required this.title,
    required this.cover,
    required this.duration,
    this.progress,
    this.stat,
    required this.userMid,
    required this.userName,
    required this.userAvatar,
    required this.publishTime,
  });

  // 核心字段（avid/标题）缺失或非法时返回 null，调用方丢弃该项
  static MediaCardInfo? _build({
    required MediaType type,
    required int avid,
    required String bvid,
    int? cid,
    required String title,
    required String cover,
    required Duration duration,
    PlayProgress? progress,
    Stat? stat,
    required int userMid,
    required String userName,
    required String userAvatar,
    required DateTime publishTime,
  }) {
    if (avid <= 0 || title.isEmpty) return null;
    return MediaCardInfo(
      type: type,
      avid: avid,
      bvid: bvid,
      cid: cid,
      title: title,
      cover: cover,
      duration: duration,
      progress: progress,
      stat: stat,
      userMid: userMid,
      userName: userName,
      userAvatar: userAvatar,
      publishTime: publishTime,
    );
  }

  static MediaCardInfo? fromJson(Map<String, dynamic> json) {
    final owner = jsonMap(json['owner']) ?? const <String, dynamic>{};
    return _build(
      type: _mediaType(jsonString(json['goto'])),
      avid: jsonInt(json['aid'], fallback: jsonInt(json['id'])),
      bvid: jsonString(json['bvid']),
      cid: json['cid'] == null ? null : jsonInt(json['cid']),
      title: jsonString(json['title']),
      cover: jsonString(json['pic']),
      duration: Duration(seconds: jsonInt(json['duration'])),
      progress: json['progress'] == null ? null : PlayProgress.fromJson(json),
      stat: Stat.fromJson(jsonMap(json['stat']) ?? const {}),
      userMid: jsonInt(owner['mid']),
      userName: jsonString(owner['name']),
      userAvatar: jsonString(owner['face']),
      publishTime: _time(jsonInt(json['pubdate'])),
    );
  }

  static MediaCardInfo? fromToViewJson(Map<String, dynamic> json) {
    final owner = jsonMap(json['owner']) ?? const <String, dynamic>{};
    return _build(
      type: MediaType.video,
      avid: jsonInt(json['aid']),
      bvid: jsonString(json['bvid']),
      cid: json['cid'] == null ? null : jsonInt(json['cid']),
      title: jsonString(json['title']),
      cover: jsonString(json['pic']),
      duration: Duration(seconds: jsonInt(json['duration'])),
      progress: json['progress'] == null ? null : PlayProgress.fromJson(json),
      stat: Stat.fromJson(jsonMap(json['stat']) ?? const {}),
      userMid: jsonInt(owner['mid']),
      userName: jsonString(owner['name']),
      userAvatar: jsonString(owner['face']),
      publishTime: _time(jsonInt(json['pubdate'])),
    );
  }

  static MediaCardInfo? fromHistoryJson(Map<String, dynamic> json) {
    final history = jsonMap(json['history']) ?? const <String, dynamic>{};
    return _build(
      type: _mediaType(jsonString(json['goto'])),
      avid: jsonInt(history['oid']),
      bvid: jsonString(history['bvid']),
      cid: history['cid'] == null ? null : jsonInt(history['cid']),
      title: jsonString(json['title']),
      cover: jsonString(json['cover']),
      duration: Duration(seconds: jsonInt(json['duration'])),
      progress: json['progress'] == null ? null : PlayProgress.fromJson(json),
      userMid: jsonInt(json['author_mid']),
      userName: jsonString(json['author_name']),
      userAvatar: jsonString(json['author_face']),
      publishTime: _time(jsonInt(json['view_at'])),
    );
  }

  static MediaCardInfo? fromDynamicJson(Map<String, dynamic> json) {
    final moduleDynamic = jsonMap(
      jsonMap(json['modules'])?['module_dynamic'],
    );
    final archive = jsonMap(moduleDynamic?['major'])?['archive'];
    final archiveMap = jsonMap(archive) ?? const <String, dynamic>{};
    final author = jsonMap(jsonMap(json['modules'])?['module_author']) ??
        const <String, dynamic>{};
    return _build(
      type: MediaType.video,
      avid: jsonInt(archiveMap['aid']),
      bvid: jsonString(archiveMap['bvid']),
      title: jsonString(archiveMap['title']),
      cover: jsonString(archiveMap['cover']),
      duration: fromVideoDurationString(
        jsonString(archiveMap['duration_text']),
      ),
      userMid: jsonInt(author['mid']),
      userName: jsonString(author['name']),
      userAvatar: jsonString(author['face']),
      publishTime: _time(jsonInt(author['pub_ts'])),
    );
  }

  static MediaCardInfo? fromSearchJson(Map<String, dynamic> json) {
    var title = jsonString(json['title']);
    final exp = RegExp(r'<em class=".*?">(.+?)</em>');
    title = title.replaceAllMapped(exp, (match) => '${match[1]}');
    final pic = jsonString(json['pic']);
    return _build(
      type: jsonString(json['type']) == 'video'
          ? MediaType.video
          : MediaType.unknown,
      avid: jsonInt(json['aid'], fallback: jsonInt(json['id'])),
      bvid: jsonString(json['bvid']),
      // 搜索接口不返回cid（id字段是aid），留空由详情页从视频信息中获取
      title: title,
      cover: pic.isEmpty
          ? ''
          : (pic.startsWith('https:') ? pic : 'https:$pic'),
      duration: fromVideoDurationString(jsonString(json['duration'])),
      userMid: jsonInt(json['mid']),
      userName: jsonString(json['author']),
      userAvatar: jsonString(json['upic']),
      publishTime: _time(jsonInt(json['pubdate'])),
    );
  }
}

// 统计信息
class Stat {
  final int viewCount;
  final int favoriteCount;
  final int likeCount;
  final int dislikeCount;
  final int coinCount;
  final int shareCount;
  final int commentCount; // 评论数

  Stat({
    required this.viewCount,
    required this.favoriteCount,
    required this.likeCount,
    required this.dislikeCount,
    required this.coinCount,
    required this.shareCount,
    this.commentCount = 0,
  });

  factory Stat.fromJson(Map<String, dynamic> json) {
    return Stat(
      viewCount: jsonInt(json['view']),
      favoriteCount: jsonInt(json['favorite']),
      likeCount: jsonInt(json['like']),
      dislikeCount: jsonInt(json['dislike']),
      coinCount: jsonInt(json['coin']),
      shareCount: jsonInt(json['share']),
      commentCount: jsonInt(json['reply']),
    );
  }
}

// 剧集信息
class Episode {
  final int index; // 从1开始
  final int cid;
  final String title;
  final Duration duration;

  const Episode({
    required this.index,
    required this.cid,
    required this.title,
    required this.duration,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      index: jsonInt(json['page'], fallback: 1),
      cid: jsonInt(json['cid']),
      title: jsonString(json['part']),
      duration: Duration(seconds: jsonInt(json['duration'])),
    );
  }
}

// 视频信息
class Video {
  final int avid;
  final String bvid;
  final String title;
  final String cover;
  final String desc;
  final Duration duration;
  final Stat stat;
  final int userMid;
  final String userName;
  final String userAvatar;
  final DateTime publishTime;
  final int cid; // 分P起始位置
  final List<Episode> episodes; // 分P

  Video({
    required this.avid,
    required this.bvid,
    required this.title,
    required this.cover,
    required this.desc,
    required this.duration,
    required this.stat,
    required this.userMid,
    required this.userName,
    required this.userAvatar,
    required this.publishTime,
    required this.cid,
    required this.episodes,
  });

  // 核心字段（aid/标题）缺失时返回 null，由调用方转为可读错误
  static Video? fromJson(Map<String, dynamic> json) {
    final avid = jsonInt(json['aid']);
    final title = jsonString(json['title']);
    if (avid <= 0 || title.isEmpty) return null;
    final episodes =
        (jsonList(json['pages']) ?? const <dynamic>[])
            .map((e) => jsonMap(e))
            .whereType<Map<String, dynamic>>()
            .map(Episode.fromJson)
            .toList();
    episodes.sort((a, b) => a.index.compareTo(b.index));
    final owner = jsonMap(json['owner']) ?? const <String, dynamic>{};
    // cid 缺失时回退到第一个分P，保证可播放
    var cid = jsonInt(json['cid']);
    if (cid <= 0 && episodes.isNotEmpty) cid = episodes.first.cid;
    return Video(
      avid: avid,
      bvid: jsonString(json['bvid']),
      title: title,
      cover: jsonString(json['pic']),
      desc: jsonString(json['desc']),
      duration: Duration(seconds: jsonInt(json['duration'])),
      stat: Stat.fromJson(jsonMap(json['stat']) ?? const {}),
      userMid: jsonInt(owner['mid']),
      userName: jsonString(owner['name']),
      userAvatar: jsonString(owner['face']),
      publishTime: _time(jsonInt(json['pubdate'])),
      cid: cid,
      episodes: episodes,
    );
  }
}
