import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/utils/errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dioException(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
);

void main() {
  group('errorMessage', () {
    test('BilibiliError 优先展示服务端 message', () {
      expect(errorMessage(const BilibiliError(-101, '账号未登录')), '账号未登录');
    });

    test('BilibiliError message 为空时使用内置映射', () {
      expect(errorMessage(const BilibiliError(-412, '')), '请求被拦截，请稍后重试');
      expect(errorMessage(const BilibiliError(-2, '')), '服务响应异常，请稍后重试');
    });

    test('未知 BilibiliError 码且 message 为空时回退', () {
      expect(errorMessage(const BilibiliError(99999, '')), '未知的错误');
    });

    test('DioException 按类型映射文案', () {
      expect(errorMessage(_dioException(DioExceptionType.connectionTimeout)), '请求超时，请重试');
      expect(errorMessage(_dioException(DioExceptionType.receiveTimeout)), '请求超时，请重试');
      expect(
        errorMessage(_dioException(DioExceptionType.transformTimeout)),
        '请求超时，请重试',
      );
      expect(errorMessage(_dioException(DioExceptionType.connectionError)), '网络异常，请检查网络后重试');
      expect(errorMessage(_dioException(DioExceptionType.badResponse)), '服务暂时不可用，请稍后重试');
      expect(errorMessage(_dioException(DioExceptionType.cancel)), '请求已取消');
    });

    test('未知异常回退为未知错误（不暴露 e.toString()）', () {
      expect(errorMessage(StateError('bad')), '未知的错误');
      expect(errorMessage('raw'), '未知的错误');
    });
  });

  group('errorCategory', () {
    test('网络类/业务码属于预期内问题', () {
      expect(
        errorCategory(_dioException(DioExceptionType.connectionError)),
        ErrorCategory.expected,
      );
      expect(errorCategory(const BilibiliError(-101, '未登录')), ErrorCategory.expected);
      expect(errorCategory(const BilibiliError(-400, '请求错误')), ErrorCategory.expected);
    });

    test('响应格式异常与未知异常属于预期外问题', () {
      expect(errorCategory(const BilibiliError(-2, '响应格式异常')), ErrorCategory.unexpected);
      expect(errorCategory(StateError('bad')), ErrorCategory.unexpected);
    });
  });

  group('BilibiliError.toString', () {
    test('包含完整 code 与 message', () {
      final text = const BilibiliError(-101, '账号未登录').toString();
      expect(text, contains('-101'));
      expect(text, contains('账号未登录'));
    });
  });
}
