import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/apis/bilibili/user.dart';
import 'package:blt/consts/color.dart';
import 'package:blt/storages/auth.dart'
    show clearCookie, loginInfoNotifier, LoginInfo;
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/cache_future_builder.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:flutter/material.dart';

class UserInfoPage extends StatelessWidget {
  /// 点击当前Tab时触发刷新（值变化即重新拉取）
  final ValueNotifier<int>? refreshListener;

  const UserInfoPage({super.key, this.refreshListener});

  Future<MySelf?> _load() async {
    try {
      final info = await getMySelfInfo();
      loginInfoNotifier.value = LoginInfo.login(
        mid: info.mid,
        nickname: info.name,
        avatar: info.avatar,
      );
      return info;
    } on BilibiliError catch (e) {
      if (e == BilibiliError.notLoggedIn) await _logout();
    }
    return null;
  }

  Future<void> _logout() async {
    await clearCookie();
    loginInfoNotifier.value = LoginInfo.notLogin;
  }

  @override
  Widget build(BuildContext context) {
    // 以1080p为基准缩放整体尺寸
    final ui = context.ui;

    return ValueListenableBuilder<LoginInfo>(
      valueListenable: loginInfoNotifier,
      builder: (context, login, _) {
        if (!login.isLogin) {
          return const Center(child: Text('未登录'));
        }
        return _buildUserInfo(context, ui, login);
      },
    );
  }

  Widget _buildUserInfo(BuildContext context, double ui, LoginInfo login) {
    Widget content = CacheFutureBuilder(
      key: ValueKey(login.mid),
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: biliPink));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('加载失败，请稍后重试'));
        }
        final info = snapshot.data;
        if (info == null) {
          return const Center(child: Text('未登录'));
        }
        return Center(
          child: PinkPanel(
            ui: ui,
            padding: EdgeInsets.symmetric(
              horizontal: 80 * ui,
              vertical: 48 * ui,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(6 * ui),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: biliPink,
                      width: context.border(3),
                    ),
                  ),
                  child: BilibiliAvatar(info.avatar, radius: 80 * ui),
                ),
                SizedBox(width: 40 * ui),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: TextStyle(
                        fontSize: 36 * ui,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12 * ui),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * ui,
                        vertical: 4 * ui,
                      ),
                      decoration: BoxDecoration(
                        color: biliPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8 * ui),
                      ),
                      child: Text(
                        '等级 ${info.level}',
                        style: TextStyle(
                          fontSize: 20 * ui,
                          fontWeight: FontWeight.w600,
                          color: biliPink,
                        ),
                      ),
                    ),
                    SizedBox(height: 28 * ui),
                    PinkButton(
                      ui: ui,
                      label: '退出登录',
                      icon: Icons.logout_rounded,
                      onPressed: _logout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    final listener = refreshListener;
    if (listener == null) return content;
    return ValueListenableBuilder<int>(
      valueListenable: listener,
      builder: (context, value, _) =>
          KeyedSubtree(key: ValueKey(value), child: content),
    );
  }
}
