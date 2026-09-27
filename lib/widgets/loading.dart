import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:flutter/material.dart';

Widget buildLoadingStyle1() {
  return Builder(
    builder: (context) {
      final ui = context.ui;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/loading/loading1.gif",
              width: 216 * ui,
              height: 216 * ui,
            ),
            SizedBox(height: 16 * ui),
            Text(
              '加载中...',
              style: TextStyle(color: Colors.grey, fontSize: 16 * ui),
            ),
          ],
        ),
      );
    },
  );
}

Widget buildLoadingStyle3() {
  return Builder(
    builder: (context) {
      final ui = context.ui;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/loading/loading3.gif",
              width: 90 * ui,
              height: 90 * ui,
            ),
            SizedBox(height: 16 * ui),
            Text(
              '加载中...',
              style: TextStyle(color: Colors.grey, fontSize: 16 * ui),
            ),
          ],
        ),
      );
    },
  );
}

// 加载失败时的通用错误态（带重试按钮），可用于列表首屏与分页失败
Widget buildErrorRetryWidget(VoidCallback retry) {
  return Builder(
    builder: (context) {
      final ui = context.ui;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败，请稍后重试',
              style: TextStyle(fontSize: 24 * ui, color: Colors.grey.shade600),
            ),
            SizedBox(height: 20 * ui),
            PinkButton(
              ui: ui,
              label: '重试',
              icon: Icons.refresh_rounded,
              onPressed: retry,
            ),
          ],
        ),
      );
    },
  );
}

class LoadingWidget<T> extends StatefulWidget {
  final ValueNotifier<bool>? isLoading;
  final Future<T> Function() loader;
  final Widget Function(BuildContext, T) builder;
  final Widget loadingWidget;

  /// 加载失败时的自定义展示，默认展示"加载失败"与重试按钮
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;

  const LoadingWidget({
    super.key,
    required this.loader,
    required this.builder,
    required this.loadingWidget,
    this.isLoading,
    this.errorBuilder,
  });

  @override
  State<LoadingWidget<T>> createState() => _LoadingWidgetState<T>();
}

class _LoadingWidgetState<T> extends State<LoadingWidget<T>> {
  late final ValueNotifier<bool> _isLoading;
  T? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _isLoading = widget.isLoading ?? ValueNotifier(true);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    _error = null;
    _isLoading.value = true;
    try {
      final data = await widget.loader();
      // 加载过程中页面可能已被销毁
      if (!mounted) return;
      _data = data;
      _isLoading.value = false;
    } catch (e) {
      if (!mounted) return;
      _error = e;
      _isLoading.value = false;
    }
  }

  @override
  void dispose() {
    if (widget.isLoading == null) _isLoading.dispose();
    super.dispose();
  }

  Widget _buildError(BuildContext context) {
    final ui = context.ui;
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _load);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '加载失败，请稍后重试',
            style: TextStyle(fontSize: 24 * ui, color: Colors.grey.shade600),
          ),
          SizedBox(height: 20 * ui),
          PinkButton(
            ui: ui,
            label: '重试',
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) return widget.loadingWidget;
        if (_error != null) return _buildError(context);
        return widget.builder(context, _data as T);
      },
    );
  }
}
