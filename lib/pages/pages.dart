import 'package:blt/consts/color.dart';
import 'package:blt/icons/iconfont.dart';
import 'package:blt/pages/dynamic.dart';
import 'package:blt/pages/history.dart';
import 'package:blt/pages/qr_login.dart';
import 'package:blt/pages/recommend.dart';
import 'package:blt/pages/search.dart';
import 'package:blt/pages/setting.dart';
import 'package:blt/pages/to_view.dart';
import 'package:blt/pages/user_info.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/sidebar.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lazy_indexed_stack/flutter_lazy_indexed_stack.dart';
import 'package:get/get.dart';

class _PageItem {
  final IconData icon;
  final String label;
  late final Widget child;

  late final bool homePage; // 是否是首页
  late final bool needLogin; // 是否需要登陆

  final onTappedListener = ValueNotifier(0);

  _PageItem({
    required this.icon,
    required this.label,
    required Widget Function(ValueNotifier<int>) child,
    this.homePage = false,
    this.needLogin = false,
  }) {
    this.child = child(onTappedListener);
  }

  void dispose() {
    onTappedListener.dispose();
  }
}

class Page extends StatefulWidget {
  const Page({super.key});

  @override
  State<Page> createState() => _PageState();
}

class _PageState extends State<Page> {
  late final List<_PageItem> _tabs;
  late ValueNotifier<int> _currentPageIndex;
  late List<FocusNode> _pageFocusNodes;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _PageItem(
        icon: Icons.account_circle_rounded,
        label: '我的',
        child: (listener) => UserInfoPage(refreshListener: listener),
        needLogin: true,
      ),
      _PageItem(
        icon: IconFont.search,
        label: '搜索',
        child: (listener) => SearchPage(tappedListener: listener),
      ),
      _PageItem(
        icon: IconFont.history,
        label: '历史',
        child: (listener) => HistoryPage(listener),
        needLogin: true,
      ),
      _PageItem(
        icon: IconFont.trends,
        label: '动态',
        child: (listener) => DynamicPage(listener),
        needLogin: true,
      ),
      _PageItem(
        icon: IconFont.playlist,
        label: '稍后再看',
        child: (listener) => ToViewPage(listener),
        needLogin: true,
      ),
      _PageItem(
        icon: Icons.home_rounded,
        label: '首页',
        child: (listener) => RecommendPage(listener),
        homePage: true,
      ),
    ];
    _pageFocusNodes = _tabs.map((e) => FocusNode()).toList();
    _currentPageIndex = ValueNotifier(_tabs.lastIndexWhere((e) => e.homePage));
  }

  @override
  void dispose() {
    _currentPageIndex.dispose();
    for (var node in _pageFocusNodes) {
      node.dispose();
    }
    for (var tab in _tabs) {
      tab.dispose();
    }
    super.dispose();
  }

  _onTabTapped(_PageItem tab) {
    // 检查登陆，否则弹窗提醒登陆
    if (tab.needLogin && !loginInfoNotifier.value.isLogin) {
      pushTooltipInfo(
        context,
        "请先点击屏幕左上的默认头像进行登录！",
        duration: Duration(seconds: 2),
      );
      return;
    }

    final index = _tabs.indexOf(tab);
    if (_currentPageIndex.value != index) {
      _currentPageIndex.value = index;
    } else {
      tab.onTappedListener.value = DateTime.now().microsecondsSinceEpoch;
    }
  }

  DateTime _lastTapAvatarTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _onAvatarTapped() async {
    if (!loginInfoNotifier.value.isLogin) {
      showQrLoginDialog(context);
      return;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastTapAvatarTime);
    if (diff < Duration(milliseconds: 600)) {
      await _onDoublePressAvatar();
    } else {
      pushTooltipInfo(context, "再次点击头像退出当前账号！");
    }
    _lastTapAvatarTime = now;
  }

  Future<void> _onDoublePressAvatar() async {
    if (!loginInfoNotifier.value.isLogin) return;
    // 先清除持久化信息，失败则保持登录状态，避免状态不一致
    try {
      await clearCookie();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    loginInfoNotifier.value = LoginInfo.notLogin;
    pushTooltipInfo(context, "已退出当前账号！");
  }

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放整体尺寸
    final ui = context.ui;

    return Scaffold(
      // TV 场景键盘以浮层出现，不压缩布局（避免侧边栏在键盘弹出时溢出）
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(gradient: pageBackgroundGradient),
        child: Row(
          children: [
            ValueListenableBuilder(
              valueListenable: _currentPageIndex,
              builder: (context, index, _) => Sidebar(
                onAvatarTap: _onAvatarTapped,
                avatar: ListenableBuilder(
                  listenable: loginInfoNotifier,
                  builder: (context, child) => BilibiliAvatar(
                    loginInfoNotifier.value.avatar,
                    radius: 46 * ui,
                  ),
                ),
                items: [
                  for (var i = 0; i < _tabs.length; i++)
                    SidebarItemData(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: i == index,
                      autofocus: i == index,
                      onTap: () => _onTabTapped(_tabs[i]),
                    ),
                ],
                footer: SidebarItemData(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  selected: false,
                  onTap: () => Get.to(() => const SettingPage()),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _currentPageIndex,
                builder: (context, index, _) {
                  return ValueListenableBuilder<LoginInfo>(
                    valueListenable: loginInfoNotifier,
                    builder: (context, login, _) => LazyIndexedStack(
                      // 登录状态变化时重建页面，避免残留在上一个账号的数据
                      key: ValueKey(login.mid),
                      index: index,
                      children: _tabs.map((tab) => tab.child).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
