import 'package:blt/consts/color.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 未选中/禁用时的文字颜色（与侧边栏未选中条目一致）
const _chipTextColor = Color(0xFF4A4F5A);

// 可聚焦胶囊：搜索历史 / 热门搜索 / 结果筛选共用。
//
// 未选中底色为浅粉 [focusableSurfaceColor]，选中为粉色渐变，
// 聚焦为白底 + 粉边 + 光晕（焦点态与选中态可区分）；禁用时灰化且不参与焦点。
class FocusableChip extends StatelessWidget {
  final String label;
  final Widget? leading;
  final bool selected;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onTap;
  final double height; // 设计尺寸（1920x1080 基准）
  final double fontSize;
  final double radius;
  final EdgeInsets padding;

  const FocusableChip({
    super.key,
    required this.label,
    this.leading,
    this.selected = false,
    this.enabled = true,
    this.autofocus = false,
    required this.onTap,
    this.height = 64,
    this.fontSize = 24,
    this.radius = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 28),
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final scaledRadius = radius * ui;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: DpadFocusable(
        enabled: enabled,
        autofocus: autofocus,
        onSelect: onTap,
        builder: (context, isFocused, _) => buildPinkFocusEffect(
          ui: ui,
          radius: scaledRadius,
          isFocused: isFocused,
          backgroundColor: !enabled
              ? Colors.grey.withValues(alpha: 0.12)
              : (selected ? Colors.transparent : focusableSurfaceColor),
          focusedBackgroundColor: Colors.white,
          scale: 1.04,
          child: Container(
            height: height * ui,
            padding: padding * ui,
            decoration: BoxDecoration(
              // 选中且未聚焦时用粉色渐变托底，聚焦时让位给白底 + 粉边
              gradient: selected && !isFocused ? pinkGradient : null,
              borderRadius: BorderRadius.circular(scaledRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: 8 * ui),
                ],
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize * ui,
                    fontWeight: selected && !isFocused
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: _textColor(isFocused),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _textColor(bool isFocused) {
    if (!enabled) return Colors.grey.shade500;
    if (selected && !isFocused) return Colors.white;
    return _chipTextColor;
  }
}
