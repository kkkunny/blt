import 'dart:async';

import 'package:blt/apis/bilibili/toview.dart';
import 'package:blt/consts/assets.dart';
import 'package:blt/models/video.dart' show MediaCardInfo;
import 'package:blt/pages/video_detail.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/widgets/loading.dart' show buildLoadingStyle1;
import 'package:blt/widgets/tooltip.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ToViewPage extends StatefulWidget {
  final ValueNotifier<int> _tappedListener;

  const ToViewPage(this._tappedListener, {super.key});

  @override
  State<ToViewPage> createState() => _ToViewPageState();
}

class _ToViewPageState extends State<ToViewPage> {
  int _page = 0;
  final _pageVideoCount = 20;
  late final VideoGridViewProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = VideoGridViewProvider(onLoad: _onLoad);
    widget._tappedListener.addListener(_onRefresh);
  }

  @override
  void dispose() {
    widget._tappedListener.removeListener(_onRefresh);
    _provider.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    _page = 0;
    await _provider.refresh();
  }

  Future<(List<MediaCardInfo>, bool)> _onLoad({
    bool isFetchMore = false,
  }) async {
    if (!loginInfoNotifier.value.isLogin) {
      return (List<MediaCardInfo>.empty(growable: false), false);
    }

    // 请求成功后提交页码，失败时下次重试同一页
    final nextPage = _page + 1;
    final videos = await listToView(page: nextPage, count: _pageVideoCount);
    _page = nextPage;
    return (videos, videos.length >= _pageVideoCount);
  }

  Future<void> _refreshFromData(List<MediaCardInfo> medias) async {
    _provider.clear();
    _provider.addAll(medias);
  }

  void _onVideoTapped(_, MediaCardInfo video) {
    Get.to(() => VideoDetailPageWrap(avid: video.avid, cid: video.cid));
  }

  @override
  Widget build(BuildContext context) {
    return VideoGridView(
      provider: _provider,
      onItemTap: _onVideoTapped,
      itemMenuActions: [
        ItemMenuAction(
          title: '移除',
          icon: Icons.playlist_remove_rounded,
          action: (media) async {
            if (!loginInfoNotifier.value.isLogin) return;

            try {
              await deleteToView(media.avid);
            } catch (e) {
              if (!context.mounted) return;
              showAppError(context, e);
              return;
            }
            if (!context.mounted) return;
            pushTooltipInfo(context, '已从稍后再看中移除：${media.title}');
            final newVideos = _provider.toList();
            newVideos.removeWhere((video) => video.avid == media.avid);
            _refreshFromData(newVideos);
          },
        ),
      ],
      refreshWidget: buildLoadingStyle1(),
      noItemsWidget: FractionallySizedBox(
        widthFactor: 0.2,
        child: Image.asset(Images.empty, fit: BoxFit.contain),
      ),
    );
  }
}
