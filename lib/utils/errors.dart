// 错误文案与呈现强度的统一映射
//
// 页面只通过 showAppError 展示错误，文案与分类都在这里集中处理，
// 避免各页面重复 `e is BilibiliError ? e.message : '未知的错误'` 这类判断。

import 'package:blt/apis/bilibili/error.dart';
import 'package:dio/dio.dart';

// 错误的呈现强度：预期内的问题轻提示，预期外的问题重提示
enum ErrorCategory {
  expected, // 预期内、可重试、需要用户感知
  unexpected, // 预期外、无法解决
}

// 内置错误码文案（B 站 message 为空时兜底）
const _bilibiliCodeMessages = <int, String>{
  -2: '服务响应异常，请稍后重试',
  -101: '账号未登录，请先登录',
  -102: '账号被封禁',
  -111: 'csrf 校验失败，请重新登录',
  -400: '请求错误',
  -403: '没有访问权限',
  -404: '内容不存在',
  -412: '请求被拦截，请稍后重试',
};

// 错误 → 用户可读文案
String errorMessage(Object error) {
  if (error is BilibiliError) {
    if (error.message.isNotEmpty) return error.message;
    return _bilibiliCodeMessages[error.code] ?? '未知的错误';
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return '请求超时，请重试';
      case DioExceptionType.connectionError:
        return '网络异常，请检查网络后重试';
      case DioExceptionType.badResponse:
        return '服务暂时不可用，请稍后重试';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return '网络异常，请检查网络后重试';
    }
  }
  return '未知的错误';
}

// 错误 → 呈现强度
ErrorCategory errorCategory(Object error) {
  if (error is DioException) {
    // 网络类/HTTP 错误属于可重试问题
    return ErrorCategory.expected;
  }
  if (error is BilibiliError) {
    // -2 为响应格式异常，属于预期外问题
    return error.code == -2 ? ErrorCategory.unexpected : ErrorCategory.expected;
  }
  return ErrorCategory.unexpected;
}
