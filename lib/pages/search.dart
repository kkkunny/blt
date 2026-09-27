import 'dart:async';

import 'package:blt/apis/bilibili/search.dart';
import 'package:blt/apis/bilibili/toview.dart';
import 'package:blt/consts/assets.dart';
import 'package:blt/consts/color.dart';
import 'package:blt/models/video.dart' show MediaCardInfo;
import 'package:blt/pages/video_detail.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/loading.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchKeyword = "";
  int _page = 0;
  int _searchSeq = 0;
  late final VideoGridViewProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = VideoGridViewProvider(onLoad: _onLoad);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<(List<MediaCardInfo>, bool)> _onLoad({
    bool isFetchMore = false,
  }) async {
    if (!loginInfoNotifier.value.isLogin || !isFetchMore) {
      return (List<MediaCardInfo>.empty(growable: false), false);
    }

    // 先占位页码，避免请求期间并发触发时重复请求同一页
    final page = _page + 1;
    _page = page;
    final seq = _searchSeq;
    final keyword = _searchKeyword;

    final videos = await searchVideos(keyword, page: page);
    // 搜索关键词已更换时丢弃过期结果
    if (seq != _searchSeq || keyword != _searchKeyword) {
      return (List<MediaCardInfo>.empty(growable: false), false);
    }
    return (videos, videos.isNotEmpty);
  }

  void _onVideoTapped(_, MediaCardInfo video) {
    Get.to(() => VideoDetailPageWrap(avid: video.avid, cid: video.cid));
  }

  Future<void> _onSearch(String input) async {
    if (!loginInfoNotifier.value.isLogin) {
      return;
    }

    final seq = ++_searchSeq;
    _searchKeyword = input;
    _page = 0;
    try {
      final (videos, _) = await _onLoad(isFetchMore: true);
      if (!mounted || seq != _searchSeq) return;

      _provider.clear();
      _provider.addAll(videos);
      _provider.hasMore = videos.isNotEmpty;
    } catch (e) {
      // 搜索失败时给出提示，避免未捕获异步异常
      if (!mounted || seq != _searchSeq) return;
      showAppError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放整体尺寸
    final ui = context.ui;
    final radius = 28 * ui;

    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width / 3,
          height: 56 * ui,
          margin: EdgeInsets.only(top: 16 * ui),
          child: TextField(
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(fontSize: 20 * ui, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 28 * ui,
                color: biliPink,
              ),
              hintText: '请输入搜索内容',
              hintStyle: TextStyle(
                fontSize: 20 * ui,
                color: Colors.grey.shade500,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                borderSide: BorderSide(color: biliPink, width: 2 * ui),
              ),
            ),
            onSubmitted: (text) {
              if (text.isEmpty) {
                return;
              }
              // 提交后收起键盘，避免键盘浮层遮挡结果
              FocusManager.instance.primaryFocus?.unfocus();
              unawaited(_onSearch(text));
            },
          ),
        ),
        Expanded(
          child: VideoGridView(
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
          ),
        ),
      ],
    );
  }
}
