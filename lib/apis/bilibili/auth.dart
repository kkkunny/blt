import 'dart:convert';
import 'dart:io' show Cookie;
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/utils/json.dart';
import 'package:blt/utils/log.dart';
import 'package:convert/convert.dart' as convert;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

import 'client.dart';
import 'error.dart';

final _log = log('auth');

// 二维码
class QR {
  final String key;
  final String url;
  final Duration expire;

  QR({
    required this.key,
    required this.url,
    this.expire = const Duration(minutes: 3),
  });

  // 核心字段（qrcode_key/url）缺失时抛错，避免生成无法登录的二维码
  factory QR.fromJson(Map<String, dynamic> json) {
    final key = jsonString(json['qrcode_key']);
    final url = jsonString(json['url']);
    if (key.isEmpty || url.isEmpty) {
      throw const BilibiliError(-2, '二维码数据不完整');
    }
    return QR(key: key, url: url);
  }
}

// 创建二维码
Future<QR> createQR() async {
  final data = await bilibiliRequest(
    'GET',
    'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
  );
  return QR.fromJson(jsonMap(data) ?? const {});
}

// 二维码状态
enum QRState {
  waiting, // 等待扫码
  scanned, // 已扫码，等待确认
  confirmed, // 已确认，成功登陆
  expired, // 已过期
  error, // 错误
}

// 二维码状态查询结果
class QRStatus {
  final QRState state;
  final String? refreshToken;
  late List<Cookie> cookies;

  QRStatus({required this.state, this.refreshToken, this.cookies = const []});

  factory QRStatus.fromJson(Map<String, dynamic> json) {
    switch (jsonInt(json['code'], fallback: -1)) {
      case 0:
        return QRStatus(
          state: QRState.confirmed,
          refreshToken: jsonString(json['refresh_token']),
        );
      case 86038:
        return QRStatus(state: QRState.expired);
      case 86090:
        return QRStatus(state: QRState.scanned);
      case 86101:
        return QRStatus(state: QRState.waiting);
      default:
        throw BilibiliError(
          jsonInt(json['code'], fallback: -2),
          jsonString(json['message'], fallback: '二维码状态异常'),
        );
    }
  }
}

// 检查二维码状态
Future<QRStatus> checkQRStatus(String key) async {
  Headers? respHeaders;
  final data = await bilibiliRequest(
    'GET',
    'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
    queries: {'qrcode_key': key},
    respHandler: (response) {
      respHeaders = response.headers;
      return (false, null);
    },
  );
  var qrStatus = QRStatus.fromJson(jsonMap(data) ?? const {});
  if (qrStatus.state == QRState.confirmed) {
    _log.i('二维码已确认，登录成功');
    final cookies = respHeaders?['set-cookie'];
    final cookieList = <Cookie>[];
    for (final raw in cookies ?? const <String>[]) {
      try {
        cookieList.add(Cookie.fromSetCookieValue(raw));
      } catch (_) {
        // 单条Cookie损坏时跳过，避免影响其它Cookie
      }
    }
    final (buvid3, buvid4) = await getBuvids();
    cookieList.addAll([Cookie('buvid3', buvid3), Cookie('buvid4', buvid4)]);
    qrStatus.cookies = cookieList;
  }
  return qrStatus;
}

// 获取 buvid3 / buvid4
Future<(String, String)> getBuvids() async {
  final data = await bilibiliRequest(
    'GET',
    'https://api.bilibili.com/x/frontend/finger/spi',
  );
  final map = jsonMap(data) ?? const <String, dynamic>{};
  return (jsonString(map['b_3']), jsonString(map['b_4']));
}

class CookieStatus {
  final bool refresh;
  final int timestamp;

  CookieStatus({required this.refresh, required this.timestamp});

  factory CookieStatus.fromJson(Map<String, dynamic> json) {
    return CookieStatus(
      refresh: jsonBool(json['refresh']),
      timestamp: jsonInt(json['timestamp']),
    );
  }
}

class IsNeedRefreshCookieResponse {
  final bool needRefresh;
  final int timestamp;

  IsNeedRefreshCookieResponse({
    required this.needRefresh,
    required this.timestamp,
  });

  factory IsNeedRefreshCookieResponse.fromJson(Map<String, dynamic> json) {
    return IsNeedRefreshCookieResponse(
      needRefresh: jsonBool(json['refresh']),
      timestamp: jsonInt(json['timestamp']),
    );
  }
}

// 是否需要刷新cookie
Future<IsNeedRefreshCookieResponse> isNeedRefreshCookie() async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  final data = await bilibiliRequest(
    'GET',
    'https://passport.bilibili.com/x/passport-login/web/cookie/info',
    queries: {'csrf': csrf},
  );
  return IsNeedRefreshCookieResponse.fromJson(jsonMap(data) ?? const {});
}

const _publicKeyPEM = """
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDLgd2OAkcGVtoE3ThUREbio0Eg
Uc/prcajMKXvkCKFCWhJYJcLkcM2DKKcSeFpD/j6Boy538YXnR6VhcuUJOhH2x71
nzPjfdTcqMz7djHum0qSZA0AyCBDABUqCrfNgCiJ00Ra7GmRj+YCK1NJEuewlb40
JNrRuoEUXpabUzGB8QIDAQAB
-----END PUBLIC KEY-----
""";

// 生成CorrespondPath
String generateCorrespondPath(int ts) {
  final RSAPublicKey pubKey = CryptoUtils.rsaPublicKeyFromPem(_publicKeyPEM);
  final oaep = OAEPEncoding.withSHA256(RSAEngine());
  oaep.init(
    true,
    ParametersWithRandom(
      PublicKeyParameter<RSAPublicKey>(pubKey),
      _secureRandom(),
    ),
  );
  final msgBytes = Uint8List.fromList(utf8.encode('refresh_$ts'));
  final cipherBytes = oaep.process(msgBytes);
  return convert.hex.encode(cipherBytes);
}

// 提供加密所需的安全随机源
SecureRandom _secureRandom() {
  final rnd = Random.secure();
  final seed = Uint8List(32);
  for (var i = 0; i < seed.length; i++) {
    seed[i] = rnd.nextInt(256);
  }
  final fortuna = FortunaRandom();
  fortuna.seed(KeyParameter(seed));
  return fortuna;
}

// 获取refresh_csrf
Future<String> getRefreshCsrf(String correspondPath) async {
  final resp = await bilibiliHttpClient.get(
    'https://www.bilibili.com/correspond/1/$correspondPath',
    options: Options(responseType: ResponseType.plain),
  );
  final doc = HtmlXPath.html(resp.data);
  final refreshCsrf = doc.query("//div[@id='1-name']").nodes.firstOrNull?.text;
  if (refreshCsrf == null || refreshCsrf.isEmpty) {
    _log.w('refresh_csrf 获取失败');
    throw const BilibiliError(-2, '刷新凭据获取失败');
  }
  return refreshCsrf;
}

// 刷新cookie
Future<(List<Cookie>, String)> refreshCookie(
  String refreshCsrf,
  String refreshToken,
) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  Headers? respHeaders;
  final data = await bilibiliRequest(
    'POST',
    'https://passport.bilibili.com/x/passport-login/web/cookie/refresh',
    contentType: Headers.formUrlEncodedContentType,
    body: {
      'csrf': csrf,
      'refresh_csrf': refreshCsrf,
      'source': 'main_web',
      'refresh_token': refreshToken,
    },
    respHandler: (response) {
      respHeaders = response.headers;
      return (false, null);
    },
  );
  final setCookies = respHeaders?['set-cookie'] ?? const <String>[];
  final cookies = <Cookie>[];
  for (final raw in setCookies) {
    try {
      cookies.add(Cookie.fromSetCookieValue(raw));
    } catch (_) {
      // 单条Cookie损坏时跳过，避免影响其它Cookie
    }
  }
  if (cookies.isEmpty) {
    throw const BilibiliError(-2, 'cookie刷新失败');
  }
  final newRefreshToken = jsonString(jsonMap(data)?['refresh_token']);
  if (newRefreshToken.isEmpty) {
    throw const BilibiliError(-2, 'cookie刷新响应不完整');
  }
  _log.i('cookie 刷新成功');
  return (cookies, newRefreshToken);
}

// 确认刷新cookie
Future<void> confirmRefreshCookie(String oldRefreshToken) async {
  final csrf = (await loadCookie())
      .firstWhere((c) => c.name == 'bili_jct')
      .value;
  await bilibiliRequest(
    'POST',
    'https://passport.bilibili.com/x/passport-login/web/confirm/refresh',
    contentType: Headers.formUrlEncodedContentType,
    body: {'csrf': csrf, 'refresh_token': oldRefreshToken},
  );
}

// // APP 签名
// Map<String, dynamic> appSign(
//   Map<String, dynamic> params,
//   String appKey,
//   String appSec,
// ) {
//   params = Map.from(params);
//   params['appkey'] = appKey;
//   final sortParams = SplayTreeMap<String, dynamic>.from(
//     params,
//     (key1, key2) => key1.compareTo(key2),
//   );
//   final query = Uri.encodeFull(
//     sortParams.keys
//         .map((String key) {
//           return '$key=${sortParams[key]}';
//         })
//         .join('&'),
//   );
//   final sign = crypto.md5.convert(utf8.encode(query + appSec)).toString();
//   params['sign'] = sign;
//   return params;
// }
