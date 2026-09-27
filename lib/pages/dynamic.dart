import 'dart:async';

import 'package:blt/apis/bilibili/dynamic.dart';
import 'package:blt/apis/bilibili/toview.dart';
import 'package:blt/apis/bilibili/user.dart' show UserInfo;
import 'package:blt/consts/assets.dart';
import 'package:blt/consts/color.dart';
import 'package:blt/models/video.dart' show MediaCardInfo;
import 'package:blt/pages/video_detail.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/loading.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DynamicPage extends StatefulWidget {
  final ValueNotifier<int> _tappedListener;

  const DynamicPage(this._tappedListener, {super.key});

  @override
  State<DynamicPage> createState() => _DynamicPageState();
}

final _dynamicAvatarMockUp = UserInfo(mid: -1, name: '全部动态', avatar: '');

class _DynamicPageState extends State<DynamicPage> {
  int _offset = 0;
  int? _selectedMid;
  int _loadSeq = 0;
  final List<UserInfo> _ups = [];
  late final VideoGridViewProvider _provider;
  final _upListScrollCtl = ScrollController();

  @override
  void initState() {
    super.initState();
    _provider = VideoGridViewProvider(onLoad: _onLoad);
    widget._tappedListener.addListener(_onRefresh);
    _fetchUpList();
  }

  @override
  void dispose() {
    widget._tappedListener.removeListener(_onRefresh);
    _provider.dispose();
    _upListScrollCtl.dispose();
    super.dispose();
  }

  Future<void> _fetchUpList() async {
    try {
      final portal = await getDynamicPortal();
      if (!mounted) return;
      setState(() {
        _ups.clear();
        _ups.add(_dynamicAvatarMockUp);
        _ups.addAll(portal.ups);
      });
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e);
    }
  }

  Future<void> _onRefresh() async {
    if (_selectedMid != null) {
      setState(() {
        _selectedMid = null;
      });
    }
    if (_upListScrollCtl.hasClients && _upListScrollCtl.offset != 0) {
      _upListScrollCtl.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.linear,
      );
    }
    await Future.wait([_fetchUpList(), _refreshVideos()]);
  }

  Future<(List<MediaCardInfo>, bool)> _onLoad({
    bool isFetchMore = false,
  }) async {
    if (!loginInfoNotifier.value.isLogin) {
      return (List<MediaCardInfo>.empty(growable: false), false);
    }

    // 丢弃过期请求：仅最新一次请求可以提交offset与数据
    final seq = ++_loadSeq;
    final resp = await listDynamic(offset: _offset, mid: _selectedMid);
    if (seq != _loadSeq) {
      return (List<MediaCardInfo>.empty(growable: false), false);
    }
    _offset = resp.offset;
    return (resp.medias, resp.hasMore);
  }

  void _onUpSelected(int? mid) {
    // “全部动态”用-1占位，实际请求时不传host_mid
    final selectedMid = (mid ?? 0) <= 0 ? null : mid;
    if (_selectedMid == selectedMid) {
      // 刷新视频
      _refreshVideos();
      return;
    }
    // 更换up主并刷新
    setState(() {
      _selectedMid = selectedMid;
    });
    _refreshVideos();
  }

  Future<void> _refreshVideos() async {
    _offset = 0;
    await _provider.refresh();
  }

  void _onVideoTapped(_, MediaCardInfo video) {
    Get.to(() => VideoDetailPageWrap(avid: video.avid));
  }

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放整体尺寸
    final ui = context.ui;
    return Row(
      children: [
        _buildUpSidebar(ui),
        Expanded(child: _buildVideoGrid()),
      ],
    );
  }

  Widget _buildUpSidebar(double ui) {
    return Container(
      width: 96 * ui,
      margin: EdgeInsets.fromLTRB(12 * ui, 12 * ui, 0, 12 * ui),
      padding: EdgeInsets.symmetric(vertical: 8 * ui, horizontal: 6 * ui),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20 * ui),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.08),
            blurRadius: 18 * ui,
            offset: Offset(0, 4 * ui),
          ),
        ],
      ),
      child: _buildUpListView(ui),
    );
  }

  Widget _buildUpListView(double ui) {
    if (_ups.isEmpty) {
      return const Center(child: SizedBox());
    }
    return ListView.builder(
      controller: _upListScrollCtl,
      itemCount: _ups.length,
      itemBuilder: (context, index) {
        final up = _ups[index];
        final avatar = up.mid <= 0
            ? CircleAvatar(
                radius: 20 * ui,
                child: Image.asset(Images.dynamicAvatar),
              )
            : BilibiliAvatar(up.avatar, radius: 20 * ui);
        return _SidebarAvatarItem(
          ui: ui,
          selected:
              (up.mid <= 0 && _selectedMid == null) || _selectedMid == up.mid,
          onTap: () => _onUpSelected(up.mid),
          label: up.name,
          child: avatar,
        );
      },
    );
  }

  Widget _buildVideoGrid() {
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

class _SidebarAvatarItem extends StatelessWidget {
  final double ui;
  final Widget child;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarAvatarItem({
    required this.ui,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4 * ui),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DpadFocusable(
          onSelect: onTap,
          builder: pinkFocusEffect(ui: ui, radius: 14 * ui),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 6 * ui),
            decoration: BoxDecoration(
              gradient: selected ? pinkGradient : null,
              borderRadius: BorderRadius.circular(14 * ui),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                SizedBox(height: 4 * ui),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2 * ui),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14 * ui,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
