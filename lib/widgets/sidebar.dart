import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:blt/widgets/side_panel.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

// 未选中导航项的图标颜色
const _unselectedIconColor = Color(0xFF5A6270);

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
  final Widget avatar;
  final VoidCallback onAvatarTap;
  final List<SidebarItemData> items;
  final SidebarItemData? footer;

  const Sidebar({
    super.key,
    required this.avatar,
    required this.onAvatarTap,
    required this.items,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return SidePanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SidebarAvatar(onTap: onAvatarTap, child: avatar),
          ...items.map((item) => _SidebarTab(item: item)),
          if (footer != null) _SidebarTab(item: footer!),
        ],
      ),
    );
  }
}

// 头像入口（点击登录/双击退出由外部处理）
class _SidebarAvatar extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SidebarAvatar({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
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

// 侧边栏导航项（图标+文字，选中时粉色渐变托底），尺寸复用统一的面板条目
class _SidebarTab extends StatelessWidget {
  final SidebarItemData item;

  const _SidebarTab({required this.item});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return SidePanelTile(
      leading: Icon(
        item.icon,
        size: 48 * ui,
        color: item.selected ? Colors.white : _unselectedIconColor,
      ),
      label: item.label,
      selected: item.selected,
      autofocus: item.autofocus,
      onTap: item.onTap,
    );
  }
}
