// 本地日志：统一格式（时间/级别/tag/消息），debug 全量、release 仅 warning+。
//
// 日志只保存在本地（应用文档目录，滚动保留），不上传任何数据。
// 使用方式：在模块内缓存实例，例如 `final _log = log('bilibili');`

import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

const _logFileName = 'blt.log';
const _maxLogFileBytes = 2 * 1024 * 1024; // 单文件 2MB
const _maxLogBackups = 3; // 保留 3 个历史文件

final List<LogOutput> _outputs = [ConsoleOutput()];

// 初始化文件日志（应用启动时调用一次），失败时仅保留控制台输出
Future<void> initFileLogging({Directory? directory}) async {
  try {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    _outputs.removeWhere((output) => output is RollingFileOutput);
    _outputs.add(RollingFileOutput(File('${dir.path}/$_logFileName')));
  } catch (_) {
    // 文件日志不可用时不影响控制台日志
  }
}

// 带 tag 的日志工厂
Logger log(String tag) => Logger(
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  level: kReleaseMode ? Level.warning : Level.trace,
  printer: TagPrinter(tag),
  output: MultiOutput(List.of(_outputs)),
);

// 格式：[时间] [级别] [tag] 消息，错误与堆栈跟随
class TagPrinter extends LogPrinter {
  static const _levelNames = {
    Level.trace: 'TRACE',
    Level.debug: 'DEBUG',
    Level.info: 'INFO',
    Level.warning: 'WARN',
    Level.error: 'ERROR',
    Level.fatal: 'FATAL',
  };

  final String tag;

  TagPrinter(this.tag);

  @override
  List<String> log(LogEvent event) {
    final time = event.time;
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
    final level = _levelNames[event.level] ?? event.level.name.toUpperCase();

    final lines = <String>['[$timestamp] [$level] [$tag] ${event.message}'];
    if (event.error != null) {
      lines.add('    error: ${event.error}');
    }
    if (event.stackTrace != null) {
      lines.add('    stack: ${event.stackTrace}');
    }
    return lines;
  }
}

// 写入文件并在超过上限时滚动（file.log.1 ~ file.log.N）
class RollingFileOutput extends LogOutput {
  final File file;
  final int maxBytes;
  final int backups;

  RollingFileOutput(
    this.file, {
    this.maxBytes = _maxLogFileBytes,
    this.backups = _maxLogBackups,
  });

  @override
  void output(OutputEvent event) {
    try {
      final text = '${event.lines.join('\n')}\n';
      if (file.existsSync() && file.lengthSync() + text.length > maxBytes) {
        _rotate();
      }
      file.writeAsStringSync(text, mode: FileMode.append, flush: true);
    } catch (_) {
      // 日志写入失败不影响主流程
    }
  }

  void _rotate() {
    final oldest = File('${file.path}.$backups');
    if (oldest.existsSync()) oldest.deleteSync();
    for (var i = backups - 1; i >= 1; i--) {
      final source = File('${file.path}.$i');
      if (source.existsSync()) {
        source.renameSync('${file.path}.${i + 1}');
      }
    }
    if (file.existsSync()) {
      file.renameSync('${file.path}.1');
    }
  }
}
