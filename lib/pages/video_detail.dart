import 'package:blt/apis/bilibili/media.dart'
    show getVideoInfo, getArchiveRelation, ArchiveRelation, likeMedia;
import 'package:blt/apis/bilibili/recommend.dart' show fetchRelatedVideos;
import 'package:blt/apis/bilibili/toview.dart';
import 'package:blt/apis/bilibili/user.dart'
    show
        UserRelation,
        getUserRelation,
        getUserFollowerCount,
        modifyUserRelation;
import 'package:blt/consts/bilibili.dart' show coverSizeRatio;
import 'package:blt/consts/color.dart';
import 'package:blt/consts/settings.dart';
import 'package:blt/icons/iconfont.dart';
import 'package:blt/models/video.dart';
import 'package:blt/pages/video_player.dart';
import 'package:blt/storages/auth.dart' show loginInfoNotifier;
import 'package:blt/storages/settings.dart';
import 'package:blt/utils/format.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/loading.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:blt/widgets/scroll_text.dart';
import 'package:blt/widgets/text.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:blt/widgets/video_card.dart';
import 'package:blt/widgets/video_grid_view.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// 相关推荐卡片与主页卡片使用同一规格（videoCardAspectRatio）

class VideoDetailPageWrap extends StatelessWidget {
  final int? avid;
  final String? bvid;
  final int? cid;

  const VideoDetailPageWrap({super.key, this.avid, this.bvid, this.cid});

  // up主粉丝数
  Future<int?> _fetchFollowerCount(int mid) async {
    try {
      return await getUserFollowerCount(mid);
    } catch (_) {
      return null;
    }
  }

  // up主关注状态
  Future<UserRelation> _fetchUserRelation(int mid) async {
    if (!loginInfoNotifier.value.isLogin) return const UserRelation();
    try {
      return await getUserRelation(mid);
    } catch (_) {
      return const UserRelation();
    }
  }

  Future<VideoDetailPageInput> _loadVideoInput() async {
    // 先并行发起视频信息、视频关系、相关推荐请求
    final videoFuture = getVideoInfo(avid: avid, bvid: bvid);
    final relationFuture = getArchiveRelation(
      avid: avid,
      bvid: bvid,
    ).onError((_, _) => ArchiveRelation());
    // 相关推荐失败不影响详情展示
    final relatedFuture = fetchRelatedVideos(
      avid: avid,
      bvid: bvid,
    ).onError((_, _) => <MediaCardInfo>[]);

    // 视频信息返回后立刻并行查询up主粉丝数与关注状态
    final video = await videoFuture;
    final userFuture = (
      _fetchFollowerCount(video.userMid),
      _fetchUserRelation(video.userMid),
    ).wait;

    final relation = await relationFuture;
    final relatedVideos = await relatedFuture;
    final (followerCount, userRelation) = await userFuture;

    return VideoDetailPageInput(
      video,
      relation,
      relatedVideos,
      followerCount: followerCount,
      userRelation: userRelation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingWidget(
        loader: _loadVideoInput,
        builder: (context, input) {
          return VideoDetailPage(
            video: input.video,
            cid: cid,
            relation: input.relation,
            relatedVideos: input.relatedVideos,
            followerCount: input.followerCount,
            userRelation: input.userRelation,
          );
        },
        loadingWidget: buildLoadingStyle1(),
      ),
    );
  }
}

class VideoDetailPageInput {
  final Video video;
  final ArchiveRelation relation;
  final List<MediaCardInfo> relatedVideos;
  final int? followerCount;
  final UserRelation userRelation;

  VideoDetailPageInput(
    this.video,
    this.relation,
    this.relatedVideos, {
    this.followerCount,
    this.userRelation = const UserRelation(),
  });
}

class VideoDetailPage extends StatefulWidget {
  final Video video;
  final int? cid;
  final ArchiveRelation relation;
  final List<MediaCardInfo> relatedVideos;
  final int? followerCount;
  final UserRelation userRelation;

  const VideoDetailPage({
    super.key,
    required this.video,
    this.cid,
    required this.relation,
    this.relatedVideos = const [],
    this.followerCount,
    this.userRelation = const UserRelation(),
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late final ValueNotifier<int> _currentEpisodeCid; // 当前分P
  late final VideoGridViewProvider _relatedVideosProvider; // 相关视频提供方
  late final ValueNotifier<bool> _like; // 点赞
  late final ValueNotifier<bool> _following; // 关注
  late final ValueNotifier<int?> _followerCount; // 粉丝数

  @override
  void initState() {
    super.initState();
    _currentEpisodeCid = ValueNotifier(widget.cid ?? widget.video.cid);
    _relatedVideosProvider = VideoGridViewProvider(
      initVideos: widget.relatedVideos,
    );
    _like = ValueNotifier(widget.relation.like);
    _following = ValueNotifier(widget.userRelation.following);
    _followerCount = ValueNotifier(widget.followerCount);
  }

  @override
  void dispose() {
    _like.dispose();
    _following.dispose();
    _followerCount.dispose();
    _relatedVideosProvider.dispose();
    _currentEpisodeCid.dispose();
    super.dispose();
  }

  Future<void> _onCoverTapped() async {
    final danmu = await Settings.getBool(Settings.pathDanmuSwitch) ?? true;
    final ha = await Settings.getBool(Settings.pathHASwitch) ?? true;
    final vo =
        VideoOutputDrivers.parse(
          await Settings.getString(Settings.pathVOSwitch) ??
              VideoOutputDrivers.gpu.value,
        ) ??
        VideoOutputDrivers.gpu;
    final hwdec =
        HardwareVideoDecoder.parse(
          await Settings.getString(Settings.pathHwdecSwitch) ??
              HardwareVideoDecoder.autoSafe.value,
        ) ??
        HardwareVideoDecoder.autoSafe;
    Get.to(
      () => VideoPlayerPage(
        video: widget.video,
        cid: _currentEpisodeCid.value,
        danmu: danmu,
        ha: ha,
        vo: vo,
        hwdec: hwdec,
      ),
    );
  }

  void _onVideoTapped(int _, MediaCardInfo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            VideoDetailPageWrap(avid: video.avid, cid: video.cid),
      ),
    );
    // Get.off(VideoDetailPageWrap(avid: video.avid, cid: video.cid));
  }

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放整体尺寸
    final ui = context.ui;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: pageBackgroundGradient),
        padding: EdgeInsets.fromLTRB(24 * ui, 14 * ui, 24 * ui, 10 * ui),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 42, child: _buildVideoHeader(ui)),
            SizedBox(height: 12 * ui),
            widget.video.episodes.length <= 1
                ? const Spacer(flex: 21)
                : Expanded(flex: 21, child: _buildEpisodes(ui)),
            SizedBox(height: 12 * ui),
            Expanded(flex: 30, child: _buildRelatedVideos(ui)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoHeader(double ui) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVideoPlayer(ui),
        SizedBox(width: 20 * ui),
        Expanded(child: _buildVideoInfo(ui)),
      ],
    );
  }

  Widget _buildVideoPlayer(double ui) {
    return DpadFocusable(
      autofocus: true,
      onSelect: _onCoverTapped,
      builder: (context, isFocused, _) {
        return buildPinkFocusEffect(
          ui: ui,
          radius: 20 * ui,
          borderWidth: 3 * ui,
          unfocusedColor: Colors.white,
          backgroundColor: Colors.white,
          isFocused: isFocused,
          child: Padding(
            padding: EdgeInsets.all(4 * ui),
            child: AspectRatio(
              aspectRatio: coverSizeRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16 * ui),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 封面加载时/失败时的底色
                    Container(color: Colors.black.withValues(alpha: 0.06)),
                    BilibiliNetworkImage(widget.video.cover),
                    // 播放按钮，选中时高亮
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final size = (constraints.maxHeight * 0.26).clamp(
                          40.0,
                          160.0,
                        );
                        return Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFocused
                                  ? null
                                  : Colors.black.withValues(alpha: 0.35),
                              gradient: isFocused ? pinkGradient : null,
                              border: Border.all(
                                color: Colors.white,
                                width: UiScale.border(4, ui),
                              ),
                              boxShadow: isFocused
                                  ? [
                                      BoxShadow(
                                        color: biliPink.withValues(alpha: 0.6),
                                        blurRadius: 24 * ui,
                                        spreadRadius: 4 * ui,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: size * 0.6,
                            ),
                          ),
                        );
                      },
                    ),
                    // 时长
                    Positioned(
                      right: 12 * ui,
                      bottom: 12 * ui,
                      child: CoverBadge(
                        ui: ui,
                        child: Text(
                          videoDurationString(widget.video.duration),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19 * ui,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoInfo(double ui) {
    return Container(
      padding: EdgeInsets.fromLTRB(22 * ui, 16 * ui, 22 * ui, 12 * ui),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            Colors.white.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24 * ui),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.08),
            blurRadius: 20 * ui,
            offset: Offset(0, 6 * ui),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 136 * ui, child: _buildTitle(ui)),
          const Spacer(flex: 1),
          SizedBox(height: 54 * ui, child: _buildRelations(ui)),
          const Spacer(flex: 1),
          SizedBox(height: 64 * ui, child: _buildDescription(ui)),
          const Spacer(flex: 2),
          Divider(height: 2 * ui, color: Colors.black.withValues(alpha: 0.05)),
          SizedBox(height: 102 * ui, child: _buildOtherInfo(ui)),
        ],
      ),
    );
  }

  Widget _buildTitle(double ui) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4 * ui),
      child: FixedLineAdaptiveText(
        widget.video.title,
        line: 2,
        lineHeight: 1.35,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRelations(double ui) {
    return ValueListenableBuilder(
      valueListenable: _like,
      builder: (context, like, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RelationAction(
            ui: ui,
            icon: Icons.thumb_up_rounded,
            label: amountString(widget.video.stat.likeCount),
            color: like ? biliPink : Colors.grey.shade500,
            onPressed: _onLikeTapped,
          ),
          _RelationAction(
            ui: ui,
            icon: Icons.thumb_down_rounded,
            iconScaleX: -1,
            label: amountString(widget.video.stat.dislikeCount),
            color: widget.relation.dislike ? biliPink : Colors.grey.shade500,
            onPressed: () => pushTooltipInfo(context, '暂不支持该功能！'),
          ),
          _RelationAction(
            ui: ui,
            iconFont: IconFont.coin,
            iconScale: 1.1,
            label: amountString(widget.video.stat.coinCount),
            color: widget.relation.coin > 0 ? biliPink : Colors.grey.shade500,
            onPressed: () => pushTooltipInfo(context, '暂不支持该功能！'),
          ),
          _RelationAction(
            ui: ui,
            icon: Icons.star_rounded,
            iconScale: 1.3,
            label: amountString(widget.video.stat.favoriteCount),
            color: widget.relation.favorite ? biliPink : Colors.grey.shade500,
            onPressed: () => pushTooltipInfo(context, '暂不支持该功能！'),
          ),
          _RelationAction(
            ui: ui,
            iconFont: IconFont.playlist,
            iconScale: 1.1,
            color: Colors.grey.shade500,
            onPressed: _onAddToViewTapped,
          ),
          _RelationAction(
            ui: ui,
            iconFont: IconFont.share,
            iconScale: 1.2,
            label: amountString(widget.video.stat.shareCount),
            color: Colors.grey.shade500,
            onPressed: () => pushTooltipInfo(context, '暂不支持该功能！'),
          ),
        ],
      ),
    );
  }

  Future<void> _onLikeTapped() async {
    try {
      await likeMedia(widget.video.avid, like: !widget.relation.like);
      if (!mounted) return;
      pushTooltipInfo(context, '${widget.relation.like ? '取消' : ''}点赞成功！');
      widget.relation.like = !widget.relation.like;
      _like.value = widget.relation.like;
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e);
    }
  }

  Future<void> _onAddToViewTapped() async {
    if (!loginInfoNotifier.value.isLogin) {
      pushTooltipInfo(context, '请先登录！');
      return;
    }

    try {
      await addToView(avid: widget.video.avid);
      if (!mounted) return;
      pushTooltipInfo(context, '已加入稍后再看：${widget.video.title}');
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e);
    }
  }

  Future<void> _onFollowTapped() async {
    if (!loginInfoNotifier.value.isLogin) {
      pushTooltipInfo(context, '请先登录！');
      return;
    }

    final follow = !_following.value;
    try {
      await modifyUserRelation(widget.video.userMid, follow: follow);
      if (!mounted) return;
      _following.value = follow;
      final count = _followerCount.value;
      if (count != null) {
        _followerCount.value = count + (follow ? 1 : -1);
      }
      pushTooltipInfo(context, follow ? '关注成功！' : '已取消关注！');
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e);
    }
  }

  Widget _buildDescription(double ui) {
    return DpadFocusable(
      onSelect: () => showDialog(
        context: context,
        builder: (context) => _buildCompleteDesc(ui),
      ),
      builder: pinkFocusEffect(ui: ui, radius: 12 * ui),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4 * ui),
        child: FixedLineAdaptiveText(
          widget.video.desc,
          line: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildOtherInfo(double ui) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4 * ui),
      child: Row(
        children: [
          BilibiliAvatar(widget.video.userAvatar, radius: 26 * ui),
          SizedBox(width: 14 * ui),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.video.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28 * ui,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * ui),
                    _UpBadge(ui: ui),
                  ],
                ),
                SizedBox(height: 6 * ui),
                ValueListenableBuilder(
                  valueListenable: _followerCount,
                  builder: (context, followerCount, _) {
                    final color = Colors.grey[600];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconFont.fensi, size: 30 * ui, color: color),
                        SizedBox(width: 6 * ui),
                        Flexible(
                          child: Text(
                            followerCount == null
                                ? 'UP 主'
                                : '${amountString(followerCount)}粉丝',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20 * ui, color: color),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * ui),
          ValueListenableBuilder(
            valueListenable: _following,
            builder: (context, following, _) => _FollowButton(
              ui: ui,
              following: following,
              onPressed: _onFollowTapped,
            ),
          ),
          SizedBox(width: 20 * ui),
          Expanded(
            child: Text(
              '发布于 ${datetimeString(widget.video.publishTime)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 20 * ui, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteDesc(double ui) {
    return AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20 * ui),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        height: MediaQuery.of(context).size.height / 2,
        child: ScrollText(
          widget.video.desc,
          autofocus: true,
          style: TextStyle(fontSize: 20 * ui),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            '关闭',
            style: TextStyle(fontSize: 20 * ui, color: biliPink),
          ),
        ),
      ],
    );
  }

  void _onEpisodeTapped(Episode episode) {
    if (episode.cid == _currentEpisodeCid.value) return;
    _currentEpisodeCid.value = episode.cid;
  }

  Widget _buildEpisodes(double ui) {
    return PinkPanel(
      ui: ui,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinkSectionHeader(
            ui: ui,
            icon: Container(
              padding: EdgeInsets.all(6 * ui),
              decoration: BoxDecoration(
                gradient: pinkGradient,
                borderRadius: BorderRadius.circular(10 * ui),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18 * ui,
              ),
            ),
            title: '分P',
          ),
          SizedBox(height: 10 * ui),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _currentEpisodeCid,
              builder: (context, cid, _) => ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.video.episodes.length,
                separatorBuilder: (context, index) => SizedBox(width: 12 * ui),
                itemBuilder: (context, index) {
                  final episode = widget.video.episodes[index];
                  return _EpisodeCard(
                    ui: ui,
                    episode: episode,
                    selected: episode.cid == cid,
                    onPressed: () => _onEpisodeTapped(episode),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedVideos(double ui) {
    return PinkPanel(
      ui: ui,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinkSectionHeader(
            ui: ui,
            icon: Icon(
              Icons.local_fire_department_rounded,
              color: biliPink,
              size: 40 * ui,
            ),
            title: '相关推荐',
          ),
          SizedBox(height: 4 * ui),
          Expanded(
            child: VideoGridView(
              provider: _relatedVideosProvider,
              scrollDirection: Axis.horizontal,
              onItemTap: _onVideoTapped,
              crossAxisCount: 1,
              videoFocusEffect: pinkFocusEffect(
                ui: ui,
                radius: 12 * ui,
                borderWidth: 2 * ui,
              ),
              padding: EdgeInsets.symmetric(horizontal: 4 * ui),
              noItemsWidget: Center(
                child: Text(
                  '暂无相关推荐',
                  style: TextStyle(
                    fontSize: 20 * ui,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
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
            ),
          ),
        ],
      ),
    );
  }
}

// 操作按钮（图标+文案）
class _RelationAction extends StatelessWidget {
  final double ui;
  final IconData? icon;
  final IconData? iconFont;
  final double iconScale;
  final double iconScaleX;
  final String? label;
  final Color color;
  final VoidCallback onPressed;

  const _RelationAction({
    required this.ui,
    this.icon,
    this.iconFont,
    this.iconScale = 1,
    this.iconScaleX = 1,
    this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      iconFont ?? icon,
      size: 36 * ui * iconScale,
      color: color,
    );
    if (iconScaleX != 1) {
      iconWidget = Transform.scale(scaleX: iconScaleX, child: iconWidget);
    }

    return DpadFocusable(
      onSelect: onPressed,
      builder: pinkFocusEffect(ui: ui, radius: 12 * ui),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          if (label != null) ...[
            SizedBox(width: 8 * ui),
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24 * ui,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// UP主标签
class _UpBadge extends StatelessWidget {
  final double ui;

  const _UpBadge({required this.ui});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * ui, vertical: 4 * ui),
      decoration: BoxDecoration(
        color: biliPink.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8 * ui),
      ),
      child: Text(
        'UP主',
        style: TextStyle(
          fontSize: 18 * ui,
          fontWeight: FontWeight.w600,
          color: biliPink,
        ),
      ),
    );
  }
}

// 关注按钮
class _FollowButton extends StatelessWidget {
  final double ui;
  final bool following;
  final VoidCallback onPressed;

  const _FollowButton({
    required this.ui,
    required this.following,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onSelect: onPressed,
      builder: pinkFocusEffect(ui: ui, radius: 28 * ui),
      child: Container(
        height: 56 * ui,
        padding: EdgeInsets.symmetric(horizontal: 30 * ui),
        decoration: BoxDecoration(
          gradient: following ? null : pinkGradient,
          color: following ? Colors.grey.shade200 : null,
          borderRadius: BorderRadius.circular(28 * ui),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!following) ...[
              Icon(Icons.add_rounded, color: Colors.white, size: 26 * ui),
              SizedBox(width: 4 * ui),
            ],
            Text(
              following ? '已关注' : '关注',
              style: TextStyle(
                fontSize: 24 * ui,
                fontWeight: FontWeight.w600,
                color: following ? Colors.grey.shade700 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 分P卡片
class _EpisodeCard extends StatelessWidget {
  final double ui;
  final Episode episode;
  final bool selected;
  final VoidCallback onPressed;

  const _EpisodeCard({
    required this.ui,
    required this.episode,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : Colors.black87;

    return DpadFocusable(
      onSelect: onPressed,
      builder: pinkFocusEffect(
        ui: ui,
        radius: 14 * ui,
        unfocusedColor: Colors.white,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: selected
              ? pinkGradient
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFFFF0F6)],
                ),
          borderRadius: BorderRadius.circular(14 * ui),
          boxShadow: [
            BoxShadow(
              color: biliPink.withValues(alpha: selected ? 0.32 : 0.08),
              blurRadius: selected ? 14 * ui : 8 * ui,
              offset: Offset(0, 4 * ui),
            ),
          ],
        ),
        child: SizedBox(
          width: 190 * ui,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * ui,
              vertical: 12 * ui,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) ...[
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20 * ui,
                      ),
                      SizedBox(width: 2 * ui),
                    ],
                    Text(
                      'P${episode.index}',
                      style: TextStyle(
                        fontSize: 22 * ui,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : biliPink,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * ui),
                Flexible(
                  child: Text(
                    episode.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19 * ui,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                SizedBox(height: 6 * ui),
                Text(
                  videoDurationString(episode.duration),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16 * ui,
                    color: selected ? Colors.white70 : Colors.grey[600],
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
