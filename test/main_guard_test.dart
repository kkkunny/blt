import 'package:blt/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FlutterExceptionHandler? originalOnError;

  setUp(() {
    originalOnError = FlutterError.onError;
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  test('release 分支：未捕获 Flutter 异常触发全局提示且不向外抛', () {
    var fatal = 0;
    installFlutterErrorHandler(debug: false, onFatal: () => fatal++);

    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('boom')),
    );

    expect(fatal, 1);
  });

  test('debug 分支：链式保留既有处理，不触发全局提示', () {
    var previousCalled = 0;
    FlutterError.onError = (_) => previousCalled++;
    var fatal = 0;
    installFlutterErrorHandler(debug: true, onFatal: () => fatal++);

    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('boom')),
    );

    expect(previousCalled, 1);
    expect(fatal, 0);
  });
}
