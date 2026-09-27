import 'package:blt/utils/errors.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:flutter/material.dart';

void pushTooltipInfo(
  BuildContext context,
  String text, {
  Duration duration = const Duration(milliseconds: 500),
}) {
  final ui = context.ui;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.black45,
        content: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 24 * ui,
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10 * ui),
                child: Text(
                  '提示：$text',
                  style: TextStyle(color: Colors.white, fontSize: 20 * ui),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
      ),
    );
}

void pushTooltipWarning(
  BuildContext context,
  String text, {
  Duration duration = const Duration(milliseconds: 500),
}) {
  final ui = context.ui;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.yellow.withValues(alpha: 0.8),
        content: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.black,
              size: 24 * ui,
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10 * ui),
                child: Text(
                  '警告：$text',
                  style: TextStyle(color: Colors.white, fontSize: 20 * ui),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
      ),
    );
}

void pushTooltipError(
  BuildContext context,
  String text, {
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onRetry,
}) {
  final ui = context.ui;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.withValues(alpha: 0.6),
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 24 * ui,
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10 * ui),
                child: Text(
                  '错误：$text',
                  style: TextStyle(color: Colors.white, fontSize: 20 * ui),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: '重试',
                textColor: Colors.white,
                onPressed: onRetry,
              ),
        duration: duration,
      ),
    );
}

// 预期外/无法解决的问题，展示更久以便用户感知
void pushTooltipFatal(
  BuildContext context,
  String text, {
  Duration duration = const Duration(seconds: 10),
}) {
  final ui = context.ui;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade900.withValues(alpha: 0.9),
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 24 * ui,
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10 * ui),
                child: Text(
                  '错误：$text',
                  style: TextStyle(color: Colors.white, fontSize: 20 * ui),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
      ),
    );
}

// 统一的错误展示入口：文案与呈现强度由 lib/utils/errors.dart 决定
void showAppError(BuildContext context, Object error, {VoidCallback? onRetry}) {
  final message = errorMessage(error);
  if (errorCategory(error) == ErrorCategory.unexpected) {
    pushTooltipFatal(context, message);
  } else {
    pushTooltipError(context, message, onRetry: onRetry);
  }
}

Future<T> tooltipNetFetch<T>(
  BuildContext context,
  Future<T> Function() fetch,
) async {
  try {
    return await fetch();
  } catch (e) {
    if (!context.mounted) {
      rethrow;
    }
    showAppError(context, e);
    rethrow;
  }
}

// 执行网络请求，成功后提示成功文案，失败时提示错误信息
Future<void> requestWithTooltip(
  BuildContext context, {
  required Future<void> Function() request,
  required String successText,
}) async {
  try {
    await request();
    if (!context.mounted) return;
    pushTooltipInfo(context, successText);
  } catch (e) {
    if (!context.mounted) return;
    showAppError(context, e);
  }
}
