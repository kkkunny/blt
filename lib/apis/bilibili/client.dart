import 'package:blt/apis/bilibili/error.dart';
import 'package:blt/storages/auth.dart' show loadCookie;
import 'package:blt/utils/json.dart';
import 'package:blt/utils/log.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final _log = log('bilibili');

final Dio bilibiliHttpClient = () {
  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Referer': 'https://www.bilibili.com/',
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
      },
    ),
  );

  // 日志打印
  if (!kReleaseMode) {
    client.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );
  }

  // cookie自动加载
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await loadCookie();
        if (cookies.isNotEmpty) {
          options.headers['Cookie'] = cookies.join('; ');
        }
        return handler.next(options);
      },
    ),
  );

  return client;
}();

Future<dynamic> bilibiliRequest<T>(
  String method,
  String url, {
  Map<String, dynamic>? queries,
  (bool, dynamic) Function(Response<dynamic>)? respHandler,
  String? contentType,
  Map<String, dynamic>? headers,
  Object? body,
}) async {
  final Response<dynamic> response;
  try {
    response = await bilibiliHttpClient.request(
      url,
      options: Options(
        method: method.toUpperCase(),
        contentType: contentType,
        headers: headers,
      ),
      queryParameters: queries,
      data: body,
    );
  } on DioException catch (e) {
    _log.w('请求失败 $method $url [${e.type.name}] ${e.message}');
    rethrow;
  }
  if (response.statusCode != 200) {
    _log.w('HTTP错误 $method $url status=${response.statusCode}');
    throw Exception(
      'http error, code=${response.statusCode}, msg=${response.data}',
    );
  }
  if (respHandler != null) {
    final (ok, respData) = respHandler(response);
    if (ok) return respData;
  }
  // 响应必须是 JSON 对象（风控/验证页会返回 HTML 文本）
  final respData = jsonMap(response.data);
  if (respData == null) {
    _log.w('响应格式异常 $method $url status=${response.statusCode}');
    throw const BilibiliError(-2, '响应格式异常');
  }
  // code 必须存在且为数字（含数字字符串）
  final rawCode = respData['code'];
  final code = rawCode is num
      ? rawCode.toInt()
      : (rawCode is String ? int.tryParse(rawCode.trim()) : null);
  if (code == null) {
    _log.w('响应缺少code $method $url');
    throw const BilibiliError(-2, '响应格式异常');
  }
  if (code != 0) {
    var message = jsonString(respData['message']).trim();
    if (message.isEmpty) message = jsonString(respData['msg']).trim();
    _log.w('业务错误 $method $url code=$code msg=$message');
    throw BilibiliError(code, message.isNotEmpty ? message : '未知错误');
  }
  return respData['data'];
}
