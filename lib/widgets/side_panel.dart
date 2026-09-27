import 'package:blt/consts/color.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 未选中条目的文字颜色（与主侧边栏导航项一致）
const _unselectedTextColor = Color(0xFF4A4F5A);

// 白色圆角悬浮面板：主侧边栏与动态页 UP 列共用，保证两列观感一致。
//
// [width]、[radius] 为 1920x1080 设计单位，内部乘 [UiScale]。
// [margin]/[padding] 需由调用方按 ui 缩放后传入。
class SidePanel extends StatelessWidget {
  final Widget child;
  final double width;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const SidePanel({
    super.key,
    required this.child,
    this.width = 172,
    this.radius = 30,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: width * ui,
      margin: margin ?? EdgeInsets.fromLTRB(28 * ui, 28 * ui, 0, 28 * ui),
      padding:
          padding ?? EdgeInsets.symmetric(vertical: 24 * ui, horizontal: 12 * ui),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius * ui),
        boxShadow: [
          BoxShadow(
            color: biliPink.withValues(alpha: 0.18),
            blurRadius: 26 * ui,
            spreadRadius: 1 * ui,
          ),
        ],
      ),
      child: child,
    );
  }
}

// 侧栏条目：图标/头像 + 文字，选中粉色渐变托底，聚焦粉边 + 光晕。
//
// 尺寸默认值即主侧边栏导航项规格；动态页 UP 列按头像需要放大一档
// （height/radius/fontSize），不另做一套控件。
class SidePanelTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;
  final double width;
  final double height;
  final double radius;
  final double fontSize;
  final double spacing; // leading 与文字间距

  const SidePanelTile({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
    this.width = 116,
    this.height = 104,
    this.radius = 26,
    this.fontSize = 24,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DpadFocusable(
        autofocus: autofocus,
        onSelect: onTap,
        builder: pinkFocusEffect(ui: ui, radius: radius * ui),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width * ui,
          height: height * ui,
          decoration: BoxDecoration(
            gradient: selected ? pinkGradient : null,
            borderRadius: BorderRadius.circular(radius * ui),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: biliPink.withValues(alpha: 0.35),
                      blurRadius: 16 * ui,
                      spreadRadius: 1 * ui,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              SizedBox(height: spacing * ui),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2 * ui),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize * ui,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : _unselectedTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
