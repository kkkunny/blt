import 'package:blt/consts/color.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 未选中导航项的图标颜色
const _unselectedIconColor = Color(0xFF5A6270);

// 未选中导航项的文字颜色
const _unselectedTextColor = Color(0xFF4A4F5A);

// 侧边栏导航项数据
class SidebarItemData {
  final IconData icon;
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  const SidebarItemData({
    required this.icon,
    required this.label,
    required this.selected,
    this.autofocus = false,
    required this.onTap,
  });
}

// 左侧悬浮导航面板（对齐UI概念图：白色圆角面板 + 图标文字 + 选中粉色渐变块）
class Sidebar extends StatelessWidget {
  final double ui;
  final Widget avatar;
  final VoidCallback onAvatarTap;
  final List<SidebarItemData> items;
  final SidebarItemData? footer;

  const Sidebar({
    super.key,
    required this.ui,
    required this.avatar,
    required this.onAvatarTap,
    required this.items,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172 * ui,
      margin: EdgeInsets.fromLTRB(28 * ui, 28 * ui, 0, 28 * ui),
      padding: EdgeInsets.symmetric(vertical: 24 * ui, horizontal: 12 * ui),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30 * ui),
        boxShadow: [
          BoxShadow(
            color: biliPink.withValues(alpha: 0.18),
            blurRadius: 26 * ui,
            spreadRadius: 1 * ui,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SidebarAvatar(ui: ui, onTap: onAvatarTap, child: avatar),
          ...items.map((item) => _SidebarTab(ui: ui, item: item)),
          if (footer != null) _SidebarTab(ui: ui, item: footer!),
        ],
      ),
    );
  }
}

// 头像入口（点击登录/双击退出由外部处理）
class _SidebarAvatar extends StatelessWidget {
  final double ui;
  final Widget child;
  final VoidCallback onTap;

  const _SidebarAvatar({
    required this.ui,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DpadFocusable(
        onSelect: onTap,
        builder: pinkFocusEffect(ui: ui, radius: 46 * ui),
        child: child,
      ),
    );
  }
}

// 侧边栏导航项（图标+文字，选中时粉色渐变托底）
class _SidebarTab extends StatelessWidget {
  final double ui;
  final SidebarItemData item;

  const _SidebarTab({required this.ui, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: DpadFocusable(
        autofocus: item.autofocus,
        onSelect: item.onTap,
        builder: pinkFocusEffect(ui: ui, radius: 26 * ui),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 116 * ui,
          height: 104 * ui,
          decoration: BoxDecoration(
            gradient: item.selected ? pinkGradient : null,
            borderRadius: BorderRadius.circular(26 * ui),
            boxShadow: item.selected
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
              Icon(
                item.icon,
                size: 48 * ui,
                color: item.selected ? Colors.white : _unselectedIconColor,
              ),
              SizedBox(height: 4 * ui),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24 * ui,
                  fontWeight: FontWeight.w600,
                  color: item.selected ? Colors.white : _unselectedTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
