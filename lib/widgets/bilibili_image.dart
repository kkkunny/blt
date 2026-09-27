import 'package:blt/apis/bilibili/client.dart' show bilibiliHttpClient;
import 'package:blt/consts/assets.dart';
import 'package:blt/consts/bilibili.dart' show coverSizeRatio;
import 'package:blt/utils/log.dart';
import 'package:cached_network_image/cached_network_image.dart'
    show
        CachedNetworkImage,
        CachedNetworkImageProvider,
        LoadingErrorWidgetBuilder,
        PlaceholderWidgetBuilder;
import 'package:flutter/material.dart';

final _log = log('image');

// bilibili网络图片提供方，带上了header
class BilibiliNetworkImageProvider extends CachedNetworkImageProvider {
  BilibiliNetworkImageProvider(super.url)
    : super(headers: bilibiliHttpClient.options.headers.cast<String, String>());
}

// bilibili网络图片，带上了header。
//
// 加载中/失败都有兜底样式：图片请求失败时不冒泡未捕获异常。
class BilibiliNetworkImage extends CachedNetworkImage {
  BilibiliNetworkImage(
    String url, {
    super.key,
    PlaceholderWidgetBuilder? placeholder,
    LoadingErrorWidgetBuilder? errorWidget,
  }) : super(
         imageUrl: url,
         fit: BoxFit.cover,
         httpHeaders: bilibiliHttpClient.options.headers.cast<String, String>(),
         placeholder: placeholder ?? _defaultPlaceholder,
         errorWidget: errorWidget ?? _defaultErrorWidget,
       );

  static Widget _defaultPlaceholder(BuildContext context, String url) {
    return Container(color: Colors.black.withValues(alpha: 0.04));
  }

  static Widget _defaultErrorWidget(
    BuildContext context,
    String url,
    Object error,
  ) {
    _log.w('图片加载失败 $url (${error.runtimeType})');
    return Container(color: Colors.black.withValues(alpha: 0.04));
  }
}

// bilibili媒体缩略图，固定了纵横比
class BilibiliMediaThumbnail extends StatelessWidget {
  final String url;

  const BilibiliMediaThumbnail(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: coverSizeRatio,
      child: BilibiliNetworkImage(url),
    );
  }
}

// bilibili头像，带上了header和默认头像
class BilibiliAvatar extends CircleAvatar {
  BilibiliAvatar(
    String? url, {
    super.key,
    super.radius,
    void Function(Object, StackTrace?)? onError,
  }) : super(
         backgroundImage: AssetImage(Images.noface),
         foregroundImage: url == null
             ? null
             : BilibiliNetworkImageProvider(url),
         onForegroundImageError: url == null
             ? null
             : (onError ?? _defaultAvatarError),
       );

  static void _defaultAvatarError(Object error, StackTrace? stackTrace) {
    _log.w('头像加载失败 (${error.runtimeType})');
  }
}
