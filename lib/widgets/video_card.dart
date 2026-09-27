import 'package:blt/consts/color.dart';
import 'package:blt/icons/iconfont.dart';
import 'package:blt/models/video.dart';
import 'package:blt/utils/format.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:blt/widgets/text.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 卡片宽高比属于卡片规格（封面16:9 + 两行标题），与内容结构绑定；
// 调整卡片内部结构时必须同步修改，不要在页面里传入手调值。
const videoCardAspectRatio = 1.3;

// 封面角标的尺寸基准宽度：1080p 四列栅格下的卡片宽度。
// 角标（up主/播放量/时长）按 卡片实际宽度 / 该基准 缩放，
// 窄卡片（如详情页相关推荐）角标同比缩小，避免在封面上喧宾夺主。
const videoCardOverlayBaseWidth = 462.0;

// 角标缩放的上下限：上限 1.0 保证大卡片角标不会跟着一起变大
const _overlayMinScale = 0.70;
const _overlayMaxScale = 1.0;

class VideoCard extends StatelessWidget {
  final MediaCardInfo video;
  final void Function()? onTap;
  final void Function()? onFocus;
  final double aspectRatio; // 卡片宽高比
  final FocusEffectBuilder? focusEffect; // 选中特效，默认粉色描边+光晕

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.onFocus,
    this.aspectRatio = videoCardAspectRatio,
    this.focusEffect,
  });

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放整体尺寸
    final ui = context.ui;
    final radius = 18 * ui;

    return DpadFocusable(
      builder:
          focusEffect ??
          pinkFocusEffect(
            ui: ui,
            radius: radius,
            borderWidth: 3 * ui,
            unfocusedColor: Colors.white,
            backgroundColor: Colors.white,
            scale: 1.03,
          ),
      onSelect: onTap,
      onFocus: onFocus,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2 * ui),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 角标与卡片宽度挂钩，窄卡片的悬浮组件同比缩小；
              // 基准宽度按 ui 归一化，保证 720p/4K 下观感一致
              final overlayScale =
                  (constraints.maxWidth / (videoCardOverlayBaseWidth * ui))
                      .clamp(_overlayMinScale, _overlayMaxScale);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(ui, overlayScale),
                  ?_buildProgress(ui),
                  _buildTitle(ui),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget? _buildProgress(double ui) {
    if (video.progress == null) return null;
    final progressRatio =
        video.progress!.duration().inSeconds / video.duration.inSeconds;
    if (progressRatio < 0.01) return null;
    return LinearProgressIndicator(
      value: progressRatio,
      minHeight: 4 * ui,
      color: biliPink,
      backgroundColor: Colors.grey.shade300,
    );
  }

  Widget _buildCover(double ui, double scale) {
    final badgePadding = EdgeInsets.symmetric(
      horizontal: 8 * ui * scale,
      vertical: 4 * ui * scale,
    );
    final edgeX = 12 * ui * scale;
    final edgeY = 10 * ui * scale;

    return Stack(
      children: [
        BilibiliMediaThumbnail(video.cover),
        // 上下渐变遮罩，保证封面角标可读
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.32),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.32),
                  ],
                  stops: const [0, 0.25, 0.7, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: edgeY,
          left: edgeX,
          child: CoverBadge(
            ui: ui,
            scale: scale,
            padding: EdgeInsets.symmetric(
              horizontal: 8 * ui * scale,
              vertical: 3 * ui * scale,
            ),
            child: Row(
              children: [
                BilibiliAvatar(video.userAvatar, radius: 22 * ui * scale),
                SizedBox(width: 8 * ui * scale),
                Text(
                  video.userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24 * ui * scale,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        ?video.progress != null && video.progress!.finished()
            ? Positioned(
                top: edgeY,
                right: edgeX,
                child: CoverBadge(
                  ui: ui,
                  scale: scale,
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * ui * scale,
                    vertical: 3 * ui * scale,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        IconFont.done_1,
                        size: 30 * ui * scale,
                        color: Colors.green,
                      ),
                      SizedBox(width: 6 * ui * scale),
                      Text(
                        "已看完",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 24 * ui * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        ?video.stat == null
            ? null
            : Positioned(
                bottom: edgeY,
                left: edgeX,
                child: CoverBadge(
                  ui: ui,
                  scale: scale,
                  padding: badgePadding,
                  child: Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline_sharp,
                        size: 30 * ui * scale,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6 * ui * scale),
                      Text(
                        amountString(video.stat!.viewCount),
                        style: TextStyle(
                          fontSize: 24 * ui * scale,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        Positioned(
          bottom: edgeY,
          right: edgeX,
          child: CoverBadge(
            ui: ui,
            scale: scale,
            padding: badgePadding,
            child: Row(
              children: [
                Icon(
                  Icons.access_time_sharp,
                  size: 30 * ui * scale,
                  color: Colors.white,
                ),
                SizedBox(width: 6 * ui * scale),
                Text(
                  videoDurationString(video.duration),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24 * ui * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(double ui) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 与卡片宽度成比例，保证不同分辨率下观感一致
          final padding = (constraints.maxWidth * 0.02).clamp(6 * ui, 16 * ui);
          return Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(padding, padding, padding, padding),
            child: FixedLineAdaptiveText(
              video.title,
              line: 2,
              lineHeight: 1.4,
              // 字号与卡片宽度挂钩，避免卡片过窄时标题被撑得过大
              maxFontSize: constraints.maxWidth * 0.065,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}

// 封面上带黑色背景的角标
class CoverBadge extends StatelessWidget {
  final double ui;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double scale; // 随卡片宽度缩放的系数

  const CoverBadge({
    super.key,
    required this.ui,
    required this.child,
    this.padding,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: 10 * ui * scale,
            vertical: 5 * ui * scale,
          ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8 * ui * scale),
      ),
      child: child,
    );
  }
}
