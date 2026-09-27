import 'dart:async';

import 'package:blt/consts/color.dart';
import 'package:blt/pages/pages.dart';
import 'package:blt/pages/splash.dart';
import 'package:blt/utils/log.dart';
import 'package:blt/utils/scroll_behavior.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

final _log = log('main');

// 全局导航 key：供无 BuildContext 的全局错误提示定位 Overlay
final navigatorKey = GlobalKey<NavigatorState>();

// 安装 Flutter 未捕获异常兜底：记录日志，debug 保留既有处理（红屏/测试框架捕获），release 提示用户
void installFlutterErrorHandler({
  required void Function() onFatal,
  bool debug = kDebugMode,
}) {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _log.e(
      '未捕获的Flutter异常',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (debug) {
      // 链式传递，避免覆盖测试框架/调试环境的既有处理
      (previousOnError ?? FlutterError.presentError)(details);
    } else {
      onFatal();
    }
  };
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      // 初始化播放器
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();

      // 初始化本地文件日志（失败仅控制台输出）
      await initFileLogging();

      installFlutterErrorHandler(onFatal: _showGlobalFatal);

      // 设置所支持的最高刷新率
      await FlutterDisplayMode.setHighRefreshRate();

      // 开启app
      runApp(const BltApp());
    },
    (error, stack) {
      _log.e('未捕获的异步异常', error: error, stackTrace: stack);
      if (!kDebugMode) _showGlobalFatal();
    },
  );
}

void _showGlobalFatal() {
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  pushTooltipFatal(context, '发生未知错误');
}

class BltApp extends StatelessWidget {
  const BltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BLT',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        canvasColor: lightPink,
        scaffoldBackgroundColor: lightPink,
        applyElevationOverlayColor: true,
        focusColor: biliPink.withValues(alpha: 0.15),
        hoverColor: biliPink.withValues(alpha: 0.15),
        highlightColor: biliPink,
      ),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const SplashPage()),
        GetPage(name: '/home', page: () => const Page()),
      ],
      debugShowCheckedModeBanner: false,
      scrollBehavior: NoThumbScrollBehavior().copyWith(scrollbars: false),
      builder: (context, child) =>
          UiScaleScope(child: child ?? const SizedBox()),
    );
  }
}
