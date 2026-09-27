import 'package:blt/utils/ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool autofocus;

  const ScrollText(this.text, {super.key, this.style, this.autofocus = false});

  @override
  State<ScrollText> createState() => _ScrollTextState();
}

class _ScrollTextState extends State<ScrollText> {
  late final ScrollController _scrollCtl;
  late final FocusNode _focusNode;
  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollCtl = ScrollController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: Scrollbar(
        controller: _scrollCtl,
        child: SingleChildScrollView(
          controller: _scrollCtl,
          child: Text(widget.text, style: widget.style),
        ),
      ),
    );
  }

  Future<void> _scrollBy(double delta) async {
    if (_scrolling || !_scrollCtl.hasClients) return;
    final target = (_scrollCtl.offset + delta).clamp(
      0.0,
      _scrollCtl.position.maxScrollExtent,
    );
    if (target == _scrollCtl.offset) return;
    _scrolling = true;
    try {
      await _scrollCtl.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.linear,
      );
    } catch (_) {
      // 页面销毁等情况下动画会被取消，忽略
    } finally {
      _scrolling = false;
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final step = 200 * context.ui;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          // 已到顶时不拦截，让焦点可以移动到其它控件
          if (!_scrollCtl.hasClients || _scrollCtl.offset <= 0) {
            return KeyEventResult.ignored;
          }
          _scrollBy(-step);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          // 已到底时不拦截，让焦点可以移动到其它控件
          if (!_scrollCtl.hasClients ||
              _scrollCtl.offset >= _scrollCtl.position.maxScrollExtent) {
            return KeyEventResult.ignored;
          }
          _scrollBy(step);
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
