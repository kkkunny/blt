import 'dart:math' as math;

import 'package:blt/consts/color.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 统一的粉色选中特效：粉色描边 + 粉色光晕（描边宽度恒定，避免选中时布局位移）
//
// [radius]、[borderWidth] 均由调用方按 ui 缩放传入；
// 描边宽度为空时按 2 * ui，且最小1逻辑像素，避免低分辨率下消失。
Widget buildPinkFocusEffect({
  required double ui,
  required double radius,
  required bool isFocused,
  required Widget child,
  double? borderWidth,
  Color unfocusedColor = Colors.transparent,
  Color? backgroundColor,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isFocused ? biliPink : unfocusedColor,
        width: math.max(1.0, borderWidth ?? 2 * ui),
      ),
      boxShadow: isFocused
          ? [
              BoxShadow(
                color: biliPink.withValues(alpha: 0.5),
                blurRadius: 18 * ui,
                spreadRadius: 3 * ui,
              ),
            ]
          : null,
    ),
    child: child,
  );
}

// 统一的粉色选中特效（DpadFocusable builder）
FocusEffectBuilder pinkFocusEffect({
  required double ui,
  required double radius,
  double? borderWidth,
  Color unfocusedColor = Colors.transparent,
  Color? backgroundColor,
}) {
  return (context, isFocused, child) => buildPinkFocusEffect(
    ui: ui,
    radius: radius,
    isFocused: isFocused,
    borderWidth: borderWidth,
    unfocusedColor: unfocusedColor,
    backgroundColor: backgroundColor,
    child: child ?? const SizedBox.shrink(),
  );
}

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

  const PinkButton({
    super.key,
    required this.ui,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: DpadFocusable(
        onSelect: onPressed,
        builder: pinkFocusEffect(ui: ui, radius: 28 * ui),
        child: Container(
          height: 56 * ui,
          padding: EdgeInsets.symmetric(horizontal: 30 * ui),
          decoration: BoxDecoration(
            gradient: pinkGradient,
            borderRadius: BorderRadius.circular(28 * ui),
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
