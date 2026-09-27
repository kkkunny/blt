import 'dart:math' as math;

import 'package:blt/consts/color.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 统一的粉色选中特效：粉色描边 + 粉色光晕（描边宽度恒定，避免选中时布局位移）
//
// [radius]、[borderWidth] 均由调用方按 ui 缩放传入；
// 描边宽度为空时按 3 * ui，且最小1逻辑像素，避免低分辨率下消失。
//
// [focusedBackgroundColor] 用于切换选中态底色（例如浅灰底 -> 白底）；
// [scale] > 1 时选中项会轻微放大（Transform 不影响布局），用来强化焦点位置。
// 光晕只绘制在元素外侧，不会污染透明底控件的内部。
Widget buildPinkFocusEffect({
  required double ui,
  required double radius,
  required bool isFocused,
  required Widget child,
  double? borderWidth,
  Color unfocusedColor = Colors.transparent,
  Color? backgroundColor,
  Color? focusedBackgroundColor,
  double scale = 1.0,
}) {
  final effect = AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      color: isFocused
          ? (focusedBackgroundColor ?? backgroundColor)
          : backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isFocused ? biliPink : unfocusedColor,
        width: math.max(1.0, borderWidth ?? 3 * ui),
      ),
    ),
    child: child,
  );
  final halo = _FocusHalo(
    ui: ui,
    radius: radius,
    isFocused: isFocused,
    child: effect,
  );
  if (scale == 1.0) return halo;
  return AnimatedScale(
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOut,
    scale: isFocused ? scale : 1.0,
    child: halo,
  );
}

// 焦点光晕：用"描边 + 模糊"绘制在元素外侧。
//
// 不用 BoxShadow 是因为它会把光晕填充到元素内部，
// 透明底控件（设置项、侧边栏图标等）会被染成一片粉色；
// 描边路径只覆盖边框附近，内部保持干净。
class _FocusHalo extends StatelessWidget {
  final double ui;
  final double radius;
  final bool isFocused;
  final Widget child;

  const _FocusHalo({
    required this.ui,
    required this.radius,
    required this.isFocused,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isFocused ? 1 : 0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (context, progress, child) => CustomPaint(
        painter: _FocusHaloPainter(
          progress: progress,
          ui: ui,
          radius: radius,
        ),
        child: child,
      ),
      child: child,
    );
  }
}

class _FocusHaloPainter extends CustomPainter {
  final double progress;
  final double ui;
  final double radius;

  const _FocusHaloPainter({
    required this.progress,
    required this.ui,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    // 光晕半径与元素尺寸挂钩：小卡片用小的光晕，才能画在列表视口的留白内不被裁掉；
    // 10~16ui 的上下限保证按钮等小控件也有足够明显的聚焦光晕。
    final halo = (size.shortestSide * 0.025).clamp(10 * ui, 16 * ui);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    // 近处强光，勾出焦点轮廓（可见范围约等于 halo）
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * halo
        ..color = biliPink.withValues(alpha: 0.5 * progress)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.35 * halo),
    );
    // 远处柔光，让选中项"浮"起来
    canvas.drawRRect(
      rrect.inflate(0.5 * halo),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * halo
        ..color = biliPink.withValues(alpha: 0.16 * progress)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.8 * halo),
    );
  }

  @override
  bool shouldRepaint(_FocusHaloPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ui != ui ||
      oldDelegate.radius != radius;
}

// 统一的粉色选中特效（DpadFocusable builder）
FocusEffectBuilder pinkFocusEffect({
  required double ui,
  required double radius,
  double? borderWidth,
  Color unfocusedColor = Colors.transparent,
  Color? backgroundColor,
  Color? focusedBackgroundColor,
  double scale = 1.0,
}) {
  return (context, isFocused, child) => buildPinkFocusEffect(
    ui: ui,
    radius: radius,
    isFocused: isFocused,
    borderWidth: borderWidth,
    unfocusedColor: unfocusedColor,
    backgroundColor: backgroundColor,
    focusedBackgroundColor: focusedBackgroundColor,
    scale: scale,
    child: child ?? const SizedBox.shrink(),
  );
}

// 可聚焦的小控件底色（浅粉，与页面粉色主题呼应），焦点态由 focusedBackgroundColor 切到白色
const focusableSurfaceColor = Color(0xFFFFF0F6);

// 白色半透明圆角面板
class PinkPanel extends StatelessWidget {
  final double ui;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const PinkPanel({
    super.key,
    required this.ui,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding:
          padding ?? EdgeInsets.fromLTRB(16 * ui, 10 * ui, 16 * ui, 10 * ui),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20 * ui),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.06),
            blurRadius: 16 * ui,
            offset: Offset(0, 4 * ui),
          ),
        ],
      ),
      child: child,
    );
  }
}

// 面板标题（图标 + 文字）
class PinkSectionHeader extends StatelessWidget {
  final double ui;
  final Widget icon;
  final String title;

  const PinkSectionHeader({
    super.key,
    required this.ui,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        SizedBox(width: 8 * ui),
        Text(
          title,
          style: TextStyle(
            fontSize: 26 * ui,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// 粉色渐变胶囊按钮
class PinkButton extends StatelessWidget {
  final double ui;
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final double height; // 设计尺寸，圆角默认取高度一半
  final bool autofocus;

  const PinkButton({
    super.key,
    required this.ui,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 56,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = height / 2 * ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: DpadFocusable(
        autofocus: autofocus,
        onSelect: onPressed,
        builder: pinkFocusEffect(ui: ui, radius: radius, scale: 1.04),
        child: Container(
          height: height * ui,
          padding: EdgeInsets.symmetric(horizontal: 30 * ui),
          decoration: BoxDecoration(
            gradient: pinkGradient,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 26 * ui),
                SizedBox(width: 4 * ui),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 24 * ui,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
