import 'package:blt/apis/bilibili/auth.dart';
import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/apis/bilibili/user.dart' show getMySelfInfo;
import 'package:blt/consts/assets.dart';
import 'package:blt/storages/auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _onAppInit();

    if (!mounted) return;
    Get.offAllNamed('/home');
  }

  static Future<void> _onAppInit() async {
    try {
      await _checkLogin();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> _checkLogin() async {
    final cookies = await loadCookie();
    if (cookies.isEmpty) {
      return;
    }

    try {
      // 获取用户信息
      final info = await getMySelfInfo();
      loginInfoNotifier.value = LoginInfo.login(
        mid: info.mid,
        nickname: info.name,
        avatar: info.avatar,
      );
    } on BilibiliError catch (e) {
      if (e == BilibiliError.notLoggedIn) {
        await clearCookie();
        return;
      }
    } catch (e) {
      return;
    }

    try {
      // 刷新cookie
      final oldRefreshToken = await loadRefreshToken();
      if (oldRefreshToken == null) return;

      final resp = await isNeedRefreshCookie();
      if (!resp.needRefresh) return;

      final correspondPath = generateCorrespondPath(resp.timestamp);
      final refreshCsrf = await getRefreshCsrf(correspondPath);
      final (newCookies, newRefreshToken) = await refreshCookie(
        refreshCsrf,
        oldRefreshToken,
      );
      await saveCookie(newCookies, refreshToken: newRefreshToken);
      await confirmRefreshCookie(oldRefreshToken);
    } catch (e) {
      // 刷新cookie失败不影响使用
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          Images.splash,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
      ),
    );
  }
}
