import 'dart:io';

import 'package:blt/utils/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('blt_log_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('TagPrinter 输出时间/级别/tag/消息', () {
    final printer = TagPrinter('api');
    final lines = printer.log(
      LogEvent(Level.warning, '请求失败', time: DateTime(2026, 9, 26, 10, 30, 5)),
    );

    expect(lines.first, '[2026-09-26 10:30:05] [WARN] [api] 请求失败');
  });

  test('TagPrinter 附带错误与堆栈', () {
    final printer = TagPrinter('api');
    final lines = printer.log(
      LogEvent(
        Level.error,
        '异常',
        error: StateError('boom'),
        stackTrace: StackTrace.fromString('stack-line'),
      ),
    );

    expect(lines.any((line) => line.contains('error: Bad state: boom')), true);
    expect(lines.any((line) => line.contains('stack: stack-line')), true);
  });

  test('log(tag) 写入文件并可读回', () async {
    await initFileLogging(directory: tempDir);
    log('test-tag').i('hello 日志');
    // Logger 输出为异步调度，等待事件队列冲刷
    await pumpEventQueue();

    final file = File('${tempDir.path}/blt.log');
    expect(file.existsSync(), true);
    final content = file.readAsStringSync();
    expect(content, contains('[INFO] [test-tag] hello 日志'));
  });

  test('RollingFileOutput 超过上限时滚动并限制备份数', () {
    final file = File('${tempDir.path}/roll.log');
    final output = RollingFileOutput(file, maxBytes: 50, backups: 2);

    for (var i = 0; i < 10; i++) {
      output.output(
        OutputEvent(LogEvent(Level.info, ''), ['line-$i-xxxxxxxxxxxxxxxx']),
      );
    }

    expect(file.existsSync(), true);
    expect(File('${file.path}.1').existsSync(), true);
    expect(File('${file.path}.2').existsSync(), true);
    // 只保留 backups 个备份
    expect(File('${file.path}.3').existsSync(), false);
  });

  test('文件不可写时不抛异常', () {
    // 用一个非法路径触发写入失败
    final output = RollingFileOutput(File('${tempDir.path}/no-such-dir/x/y.log'));
    expect(
      () => output.output(OutputEvent(LogEvent(Level.info, ''), ['x'])),
      returnsNormally,
    );
  });
}
