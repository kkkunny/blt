import 'dart:math';

import 'package:animated_infinite_scroll_pagination/animated_infinite_scroll_pagination.dart'
    hide AnimatedInfiniteScrollView;
import 'package:blt/consts/color.dart';
import 'package:blt/models/video.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/animated_infinite_scrollview.dart';
import 'package:blt/widgets/loading.dart';
import 'package:blt/widgets/video_card.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class _VideoGridViewController
    with AnimatedInfinitePaginationController<MediaCardInfo> {
  final bool Function() hasMore;
  final Future<void> Function({bool isFetchMore}) onLoad;

  _VideoGridViewController({required this.hasMore, required this.onLoad});

  @override
  get lastPage => !hasMore();

  @override
  bool areItemsTheSame(MediaCardInfo a, MediaCardInfo b) {
    return a.avid == b.avid;
  }

  @override
  Future<void> fetchData(int page) async => onLoad(isFetchMore: page > 1);

  void clear() {
    page = 1;
    total = 0;
    emptyList.postValue(false);
    items.postValue(const []);
  }
}

class VideoGridViewProvider {
  late final _ctl = _VideoGridViewController(
    hasMore: () => hasMore,
    onLoad: fetchData,
  );
  final List<MediaCardInfo> initVideos;
  Future<(List<MediaCardInfo>, bool)> Function({bool isFetchMore})? onLoad;
  late bool _hasMore = onLoad == null;
  final _refreshing = ValueNotifier(false);
  late final ScrollController _scrollCtl = ScrollController();
  bool _disposed = false;
  bool _fetching = false;
  int _generation = 0;
  // 最近一次发起的是"加载更多"还是首屏，重试时重跑同一次请求
  bool _lastFetchMore = false;

  VideoGridViewProvider({this.initVideos = const [], this.onLoad});

  void dispose() {
    _disposed = true;
    _refreshing.dispose();
    _scrollCtl.dispose();
  }

  List<MediaCardInfo> toList() => _ctl.items.value.map((e) => e.item).toList();

  operator [](int index) => _ctl.items.value[index].item;

  int get length => _ctl.total;

  bool get isEmpty => _ctl.total == 0;

  bool get isNotEmpty => _ctl.total != 0;

  set hasMore(v) => _hasMore = v;

  bool get hasMore => _hasMore;

  void addAll(Iterable<MediaCardInfo> iterable) {
    _ctl.emitState(PaginationSuccessState(iterable.toList()));
    _ctl.setTotal(_ctl.items.value.length);
  }

  void clear() => _ctl.clear();

  Future<void> refresh({saveInitData = true}) async {
    if (_disposed || _refreshing.value) return;

    _refreshing.value = true;
    // 使在途请求的结果失效，避免刷新后旧数据回填
    _generation++;
    try {
      if (_scrollCtl.hasClients && _scrollCtl.offset != 0) {
        await _scrollCtl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
      if (_disposed) return;
      clear();
      // 传入初始数据（可能为空，用于正确显示空数据状态）
      if (saveInitData) addAll(initVideos);
      await _fetchData(isFetchMore: false, generation: _generation);
    } catch (_) {
      // 滚动动画等异常不向上抛，避免未捕获异步异常
    } finally {
      if (!_disposed) _refreshing.value = false;
    }
  }

  Future<void> fetchData({bool isFetchMore = false}) async {
    if (_disposed || onLoad == null || _fetching) return;
    await _fetchData(isFetchMore: isFetchMore, generation: _generation);
  }

  // 重试上次失败的请求（首屏/加载更多分开），失败时不清空已有数据
  Future<void> retry() async {
    if (_disposed || onLoad == null || _fetching) return;
    await _fetchData(isFetchMore: _lastFetchMore, generation: _generation);
  }

  @visibleForTesting
  bool get debugRefreshing => _refreshing.value;

  @visibleForTesting
  Future<void> debugFetchPage(int page) => _ctl.fetchData(page);

  Future<void> _fetchData({
    required bool isFetchMore,
    required int generation,
  }) async {
    if (_disposed || onLoad == null) return;

    _fetching = true;
    _lastFetchMore = isFetchMore;
    try {
      _ctl.emitState(const PaginationLoadingState());

      final (newVideos, hasMore) = await onLoad!(isFetchMore: isFetchMore);
      if (_disposed || generation != _generation) return;
      _hasMore = hasMore;
      addAll(newVideos);
    } catch (_) {
      // 请求失败时结束 loading 状态，允许用户重试
      if (!_disposed && generation == _generation) {
        _ctl.emitState(const PaginationErrorState());
      }
    } finally {
      _fetching = false;
    }
  }
}

class VideoGridView<T> extends StatefulWidget {
  final VideoGridViewProvider provider;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final void Function(int index, MediaCardInfo item)? onItemTap;
  final void Function(int index, MediaCardInfo item)? onItemFocus;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final int? crossAxisCount; // 与maxCrossAxisExtent互斥
  final double? maxCrossAxisExtent; // 与crossAxisCount互斥
  final double? cardAspectRatio; // 卡片宽高比，默认videoCardAspectRatio
  final FocusEffectBuilder? videoFocusEffect; // 卡片选中特效
  final EdgeInsets? padding; // 列表内边距，默认根据间距计算
  final List<ItemMenuAction> itemMenuActions;
  final Widget? refreshWidget; // 刷新时展示的组件
  final Widget? noItemsWidget; // items为空时展示的组件
  final bool autoRefresh; // 挂载时是否自动加载首屏（页面自管数据时置 false）

  const VideoGridView({
    super.key,
    required this.provider,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.onItemTap,
    this.onItemFocus,
    this.mainAxisSpacing = 24.0,
    this.crossAxisSpacing = 24.0,
    this.crossAxisCount,
    this.maxCrossAxisExtent,
    this.cardAspectRatio,
    this.videoFocusEffect,
    this.padding,
    this.itemMenuActions = const [],
    this.refreshWidget,
    this.noItemsWidget,
    this.autoRefresh = true,
  });

  @override
  State<VideoGridView<T>> createState() => _VideoGridViewState<T>();
}

const _defaultMaxCrossAxisExtent = 600.0;

// 构建视频栅格代理。
//
// [SliverGridDelegate.childAspectRatio] 的语义是"交叉轴/主轴"：横向滚动时
// 交叉轴是高度，需要取倒数；纵向滚动时直接使用卡片宽高比。
// 卡片尺寸与间距按 [ui] 缩放，宽高比不缩放。
@visibleForTesting
SliverGridDelegate buildVideoGridDelegate({
  required Axis scrollDirection,
  required double ui,
  required double cardAspectRatio,
  int? crossAxisCount,
  double? maxCrossAxisExtent,
  double mainAxisSpacing = 24.0,
  double crossAxisSpacing = 24.0,
}) {
  final childAspectRatio = scrollDirection == Axis.horizontal
      ? 1 / cardAspectRatio
      : cardAspectRatio;
  final scaledMainAxisSpacing = mainAxisSpacing * ui;
  final scaledCrossAxisSpacing = crossAxisSpacing * ui;
  if (crossAxisCount != null) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: scaledMainAxisSpacing,
      crossAxisSpacing: scaledCrossAxisSpacing,
    );
  }
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: (maxCrossAxisExtent ?? _defaultMaxCrossAxisExtent) * ui,
    childAspectRatio: childAspectRatio,
    mainAxisSpacing: scaledMainAxisSpacing,
    crossAxisSpacing: scaledCrossAxisSpacing,
  );
}

class _VideoGridViewState<T> extends State<VideoGridView<T>> {
  int _focusIndex = 0;
  late final FocusNode _keyboardListenerFocusNode;

  @override
  void initState() {
    super.initState();
    _keyboardListenerFocusNode = FocusNode(canRequestFocus: false);
    if (widget.autoRefresh) widget.provider.refresh();
  }

  @override
  void dispose() {
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  bool _isFetchingMore = false;
  DateTime? _lastRefresh;

  void _onItemFocus(int index, MediaCardInfo item) {
    _focusIndex = index;
    widget.onItemFocus?.call(index, item);

    // 焦点在最后一行时拉取更多数据
    if (!widget.provider.hasMore) return;
    // 以1080p为基准缩放卡片尺寸
    final ui = context.ui;
    late int crossAxisCount;
    if (widget.crossAxisCount != null) {
      crossAxisCount = widget.crossAxisCount!;
    } else {
      // 优先使用组件实际尺寸，避免侧边栏等内容挤占宽度时列数估算错误
      final renderObject = context.findRenderObject();
      final mediaSize = MediaQuery.sizeOf(context);
      final crossAxisSize = widget.scrollDirection == Axis.horizontal
          ? (renderObject is RenderBox && renderObject.hasSize
                ? renderObject.size.height
                : mediaSize.height)
          : (renderObject is RenderBox && renderObject.hasSize
                ? renderObject.size.width
                : mediaSize.width);
      // 与SliverGridDelegateWithMaxCrossAxisExtent的列数计算保持一致（向上取整）
      crossAxisCount = max(
        (crossAxisSize /
                (((widget.maxCrossAxisExtent ?? _defaultMaxCrossAxisExtent) *
                        ui) +
                    widget.crossAxisSpacing * ui))
            .ceil(),
        1,
      );
    }
    final isLastRowOrLine =
        (index / crossAxisCount).toInt() ==
        ((max(widget.provider.length - 1, 0)) / crossAxisCount).toInt();
    if (!isLastRowOrLine) return;

    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!).inMilliseconds < 500) {
      return;
    }

    if (_isFetchingMore) return;
    _lastRefresh = now;
    _isFetchingMore = true;
    widget.provider.fetchData(isFetchMore: true).whenComplete(() {
      _isFetchingMore = false;
    });
  }

  Widget _itemBuilder(BuildContext context, int index, MediaCardInfo item) {
    return VideoCard(
      video: item,
      aspectRatio: widget.cardAspectRatio ?? videoCardAspectRatio,
      focusEffect: widget.videoFocusEffect,
      onTap: () => widget.onItemTap?.call(index, item),
      onFocus: () => _onItemFocus(index, item),
    );
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyUpEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.contextMenu:
        if (widget.itemMenuActions.isEmpty) break;
        final provider = widget.provider;
        if (provider.isEmpty) break;
        // 列表可能因刷新/换关键词变短，越界时回退到最后一个元素
        final index = _focusIndex.clamp(0, provider.length - 1);
        _onItemMenu(index, provider[index]);
        break;
    }
  }

  void _onItemMenu(int _, MediaCardInfo media) {
    if (widget.itemMenuActions.isEmpty) return;
    final ui = context.ui;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16 * ui)),
      ),
      builder: (_) {
        final actions = widget.itemMenuActions
            .asMap()
            .map(
              (index, item) => MapEntry(
                index,
                MaterialButton(
                  autofocus: index == 0,
                  onPressed: () {
                    Get.back();
                    item.action(media);
                  },
                  focusColor: biliPink.withValues(alpha: 0.15),
                  padding: EdgeInsets.symmetric(horizontal: 8 * ui),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14 * ui),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 40 * ui, color: biliPink),
                      SizedBox(height: 4 * ui),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 20 * ui,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .values
            .toList();
        return Padding(
          padding: EdgeInsets.all(16 * ui),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20 * ui),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.15),
                  blurRadius: 16 * ui,
                  offset: Offset(0, 4 * ui),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              vertical: 14 * ui,
              horizontal: 12 * ui,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: actions,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放卡片尺寸
    final ui = context.ui;
    final cardAspectRatio = widget.cardAspectRatio ?? videoCardAspectRatio;
    final gridDelegate = buildVideoGridDelegate(
      scrollDirection: widget.scrollDirection,
      ui: ui,
      cardAspectRatio: cardAspectRatio,
      crossAxisCount: widget.crossAxisCount,
      maxCrossAxisExtent: widget.maxCrossAxisExtent,
      mainAxisSpacing: widget.mainAxisSpacing,
      crossAxisSpacing: widget.crossAxisSpacing,
    );

    return KeyboardListener(
      focusNode: _keyboardListenerFocusNode,
      onKeyEvent: _onKey,
      child: ValueListenableBuilder(
        valueListenable: widget.provider._refreshing,
        builder: (context, loading, child) {
          return (loading && widget.refreshWidget != null)
              ? widget.refreshWidget!
              : child!;
        },
        child: AnimatedInfiniteScrollView<MediaCardInfo>(
          controller: widget.provider._ctl,
          scrollController: widget.provider._scrollCtl,
          options: AnimatedInfinitePaginationOptions(
            scrollDirection: widget.scrollDirection,
            gridDelegate: gridDelegate,
            itemBuilder: (context, MediaCardInfo item, int index) =>
                _itemBuilder(context, index, item),
            primary: widget.shrinkWrap,
            noItemsWidget: widget.noItemsWidget,
            // 失败重试重跑失败的那次请求，避免把已加载的多页结果一并清空
            errorWidget: buildErrorRetryWidget(widget.provider.retry),
            padding:
                widget.padding ??
                EdgeInsets.symmetric(
                  horizontal: widget.scrollDirection == Axis.horizontal
                      ? widget.mainAxisSpacing * ui
                      : widget.crossAxisSpacing * ui,
                  vertical: widget.scrollDirection == Axis.vertical
                      ? widget.mainAxisSpacing * ui
                      : widget.crossAxisSpacing * ui,
                ),
          ),
        ),
      ),
    );
  }
}

class ItemMenuAction {
  final String title;
  final IconData icon;
  final Function(MediaCardInfo media) action;

  ItemMenuAction({
    required this.title,
    required this.icon,
    required this.action,
  });
}
