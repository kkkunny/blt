import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:blt/consts/color.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 播放进度条：粉色进度 + 左右拖动预览 + 时间标签。
// 只接收播放状态值，具体的 seek 行为由 onPositionChanged 回调给页面。
class FocusProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration>? onPositionChanged;

  const FocusProgressBar({
    super.key,
    required this.position,
    required this.duration,
    this.buffered = Duration.zero,
    this.onPositionChanged,
  });

  @override
  State<FocusProgressBar> createState() => _FocusProgressBarState();
}

class _FocusProgressBarState extends State<FocusProgressBar> {
  late final FocusScopeNode _focusScopeNode;
  late final ValueNotifier<Duration?> _dragPosition = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode();
  }

  @override
  void dispose() {
    _dragPosition.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  Duration _clamp(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    if (value > widget.duration) return widget.duration;
    return value;
  }

  // 时间文案：0:06 / 1:03:20
  String _timeString(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
    }
    return '$minutes:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final total = widget.duration;
    return FocusScope(
      node: _focusScopeNode,
      onFocusChange: (_) => _dragPosition.value = null,
      onKeyEvent: _onKeyEvent,
      child: DpadFocusable(
        builder: FocusEffects.glow(
          glowColor: biliPink,
          blurRadius: 20 * ui,
          spreadRadius: 2 * ui,
          borderRadius: BorderRadius.circular(12 * ui),
        ),
        child: ValueListenableBuilder<Duration?>(
          valueListenable: _dragPosition,
          builder: (context, drag, _) {
            final current = _clamp(drag ?? widget.position);
            final buffered = _clamp(widget.buffered);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressBar(
                  progress: current,
                  buffered: buffered,
                  total: total,
                  barHeight: 8 * ui,
                  thumbRadius: 12 * ui,
                  thumbGlowRadius: 28 * ui,
                  thumbColor: Colors.white,
                  thumbGlowColor: biliPink.withValues(alpha: 0.5),
                  progressBarColor: biliPink,
                  bufferedBarColor: Colors.white.withValues(alpha: 0.40),
                  baseBarColor: Colors.white.withValues(alpha: 0.24),
                  timeLabelLocation: TimeLabelLocation.none,
                ),
                SizedBox(height: 6 * ui),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TimeLabel(ui: ui, text: _timeString(current)),
                    _TimeLabel(ui: ui, text: _timeString(total)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent value) {
    if (value is KeyDownEvent || value is KeyRepeatEvent) {
      switch (value.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.arrowRight:
          if (widget.duration <= Duration.zero) {
            return KeyEventResult.handled;
          }
          final step = widget.duration ~/ 100;
          final direction = value.logicalKey == LogicalKeyboardKey.arrowRight
              ? 1
              : -1;
          final target =
              (_dragPosition.value ?? widget.position) + step * direction;
          _dragPosition.value = _clamp(target);
          // 拦截左右键，避免冒泡到默认焦点遍历导致焦点被移走
          return KeyEventResult.handled;
      }
    } else if (value is KeyUpEvent) {
      switch (value.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.arrowRight:
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          FocusScope.of(context).nextFocus();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          final target = _dragPosition.value;
          if (target == null || target == widget.position) {
            break;
          }
          widget.onPositionChanged?.call(target);
          _dragPosition.value = null;
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}

// 时间标签
class _TimeLabel extends StatelessWidget {
  final double ui;
  final String text;

  const _TimeLabel({required this.ui, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 28 * ui,
        color: Colors.white,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 6 * ui,
          ),
        ],
      ),
    );
  }
}
