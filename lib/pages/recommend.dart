import 'dart:async';

import 'package:blt/apis/bilibili/recommend.dart';
import 'package:blt/apis/bilibili/toview.dart';
import 'package:blt/consts/assets.dart';
import 'package:blt/models/video.dart' show MediaCardInfo;
import 'package:blt/pages/video_detail.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/widgets/loading.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RecommendPage extends StatefulWidget {
  final ValueNotifier<int> _tappedListener;

  const RecommendPage(this._tappedListener, {super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
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
    // 请求成功后提交页码，失败时下次重试同一页
    final nextPage = _page + 1;
    final videos = await listRecommendVideos(
      page: nextPage,
      count: _pageVideoCount,
      removeAvids: _provider.toList().map((e) => e.avid).toList(),
    );
    _page = nextPage;
    return (videos, true);
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
          title: '稍后再看',
          icon: Icons.playlist_add_rounded,
          action: (media) {
            if (!loginInfoNotifier.value.isLogin) return;

            requestWithTooltip(
              context,
              request: () => addToView(avid: media.avid),
              successText: '已加入稍后再看：${media.title}',
            );
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
