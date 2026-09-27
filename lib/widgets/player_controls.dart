import 'package:blt/consts/color.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/bilibili_image.dart';
import 'package:blt/widgets/pink_style.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 播放页控件种类，用于底栏项与设置面板行的焦点映射
enum PlayerControlKind {
  prevEpisode,
  playPause,
  nextEpisode,
  quality,
  rate,
  audio,
  danmaku,
  danmakuSettings,
  aspect,
  loop,
  moreSettings,
}

// 底部控制栏的一个控件
class PlayerBarAction {
  final PlayerControlKind kind;
  final IconData icon;
  final String label;
  final String? value;
  final bool enabled;
  final bool primary; // 播放/暂停大圆钮
  final bool dividerBefore;

  /// 图标设计基准尺寸（1080p），组件内按 ui 缩放
  final double iconSize;
  final VoidCallback onSelect;

  const PlayerBarAction({
    required this.kind,
    required this.icon,
    required this.label,
    this.value,
    this.enabled = true,
    this.primary = false,
    this.dividerBefore = false,
    this.iconSize = 44,
    required this.onSelect,
  });
}

// 右侧设置面板的一行
class PlayerPanelRow {
  final bool divider;
  final PlayerControlKind? kind;
  final IconData? icon;
  final String? label;
  final String? value;
  final bool enabled;
  final bool isSwitch;
  final bool switchValue;
  final VoidCallback? onSelect;

  const PlayerPanelRow.divider()
    : divider = true,
      kind = null,
      icon = null,
      label = null,
      value = null,
      enabled = true,
      isSwitch = false,
      switchValue = false,
      onSelect = null;

  const PlayerPanelRow.item({
    required this.kind,
    required this.icon,
    required this.label,
    this.value,
    this.enabled = true,
    required VoidCallback this.onSelect,
  }) : divider = false,
       isSwitch = false,
       switchValue = false;

  const PlayerPanelRow.toggle({
    required this.kind,
    required this.icon,
    required this.label,
    required this.switchValue,
    this.enabled = true,
    required VoidCallback this.onSelect,
  }) : divider = false,
       value = null,
       isSwitch = true;
}

// 播放页可聚焦控件：粉色焦点特效 + 确认键回调。
// 支持外部传入 FocusNode，便于控件层做确定性的焦点切换。
class PlayerFocusable extends StatefulWidget {
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final VoidCallback? onSelect;

  /// 额外的按键处理，返回 handled 时不再触发选中
  final KeyEventResult Function(KeyEvent event)? onKeyEvent;
  final Widget Function(BuildContext context, bool focused) builder;

  const PlayerFocusable({
    super.key,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.onSelect,
    this.onKeyEvent,
    required this.builder,
  });

  @override
  State<PlayerFocusable> createState() => _PlayerFocusableState();
}

class _PlayerFocusableState extends State<PlayerFocusable> {
  late FocusNode _node;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.focusNode);
  }

  @override
  void didUpdateWidget(covariant PlayerFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detach();
      _attach(widget.focusNode);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach(FocusNode? node) {
    _node = node ?? FocusNode();
    _ownsNode = node == null;
    _node.addListener(_onFocusChanged);
  }

  void _detach() {
    _node.removeListener(_onFocusChanged);
    if (_ownsNode) _node.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      canRequestFocus: widget.enabled,
      onKeyEvent: (node, event) {
        final custom = widget.onKeyEvent?.call(event);
        if (custom != null && custom != KeyEventResult.ignored) {
          return custom;
        }
        if (event is KeyDownEvent &&
            widget.enabled &&
            _isSelectKey(event.logicalKey)) {
          widget.onSelect?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onSelect : null,
        child: widget.builder(context, _node.hasFocus),
      ),
    );
  }
}

// 顶部标题栏：标题 + UP主（背景渐变由控件层统一绘制）
class PlayerTitleBar extends StatelessWidget {
  final String title;
  final String uploader;
  final String avatar;

  const PlayerTitleBar({
    super.key,
    required this.title,
    required this.uploader,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(40 * ui, 26 * ui, 40 * ui, 40 * ui),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 38 * ui,
              fontWeight: FontWeight.w900,
              height: 1.25,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 8 * ui,
                ),
              ],
            ),
          ),
          if (uploader.isNotEmpty) ...[
            SizedBox(height: 14 * ui),
            Row(
              children: [
                BilibiliAvatar(avatar, radius: 24 * ui),
                SizedBox(width: 12 * ui),
                Flexible(
                  child: Text(
                    uploader,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 28 * ui,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// 底栏普通控件（图标 + 名称 + 当前值），焦点框包住整块内容（含标题与副标题）。
//
// 图标槽与副标题槽固定高度，保证「上一集/下一集/更多设置」这类没有副标题的
// 按钮与其它按钮等高：Row 居中排列时图标、标题、副标题才能逐行对齐。
class PlayerControlButton extends StatelessWidget {
  /// 图标槽高度（1080p 设计基准）：按上一集/下一集的 58 图标 + 10 预留
  static const double _iconSlotHeight = 68;

  /// 副标题槽高度（1080p 设计基准）：无当前值时也占位
  static const double _valueSlotHeight = 32;

  final PlayerBarAction action;
  final FocusNode? focusNode;

  const PlayerControlButton({super.key, required this.action, this.focusNode});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final mainColor = action.enabled ? Colors.white : Colors.white38;
    final iconSize = action.iconSize * ui;
    return PlayerFocusable(
      focusNode: focusNode,
      enabled: action.enabled,
      onSelect: action.onSelect,
      builder: (context, focused) => buildPinkFocusEffect(
        ui: ui,
        radius: 16 * ui,
        isFocused: focused,
        borderWidth: 3 * ui,
        focusedBackgroundColor: biliPink.withValues(alpha: 0.16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * ui, vertical: 8 * ui),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _iconSlotHeight * ui,
                child: Center(
                  child: Icon(action.icon, size: iconSize, color: mainColor),
                ),
              ),
              SizedBox(height: 8 * ui),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28 * ui,
                  fontWeight: FontWeight.w500,
                  color: mainColor,
                ),
              ),
              SizedBox(height: 4 * ui),
              SizedBox(
                height: _valueSlotHeight * ui,
                child: action.value == null
                    ? null
                    : Center(
                        child: Text(
                          action.value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24 * ui,
                            color: !action.enabled
                                ? Colors.white24
                                : focused
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 底栏播放/暂停大圆钮
class PlayerPrimaryButton extends StatelessWidget {
  final PlayerBarAction action;
  final FocusNode? focusNode;
  final bool playing;

  const PlayerPrimaryButton({
    super.key,
    required this.action,
    this.focusNode,
    required this.playing,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return PlayerFocusable(
      focusNode: focusNode,
      enabled: action.enabled,
      onSelect: action.onSelect,
      builder: (context, focused) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 112 * ui,
            height: 112 * ui,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: pinkGradient,
              border: Border.all(
                color: Colors.white.withValues(alpha: focused ? 1 : 0.45),
                width: context.border(focused ? 4 : 3),
              ),
              boxShadow: [
                BoxShadow(
                  color: biliPink.withValues(alpha: focused ? 0.85 : 0.55),
                  blurRadius: (focused ? 34 : 22) * ui,
                  spreadRadius: (focused ? 6 : 3) * ui,
                ),
              ],
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 56 * ui,
            ),
          ),
          SizedBox(height: 8 * ui),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 28 * ui,
              fontWeight: FontWeight.w500,
              color: action.enabled ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

// 右侧设置面板：占满顶部到下边栏之间的高度
class PlayerSettingsPanel extends StatelessWidget {
  final List<Widget> children;

  const PlayerSettingsPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: 484 * ui,
      padding: EdgeInsets.symmetric(vertical: 16 * ui, horizontal: 8 * ui),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20 * ui),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: context.border(1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24 * ui,
            offset: Offset(0, 8 * ui),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// 设置面板的一行
class PlayerPanelTile extends StatelessWidget {
  final PlayerPanelRow row;
  final FocusNode? focusNode;
  final KeyEventResult Function(KeyEvent event)? onKeyEvent;

  const PlayerPanelTile({
    super.key,
    required this.row,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    if (row.divider) {
      return Divider(
        height: 26 * ui,
        indent: 20 * ui,
        endIndent: 20 * ui,
        color: Colors.white.withValues(alpha: 0.14),
      );
    }

    final mainColor = row.enabled ? Colors.white : Colors.white38;
    return PlayerFocusable(
      focusNode: focusNode,
      enabled: row.enabled,
      onSelect: row.onSelect,
      onKeyEvent: onKeyEvent,
      builder: (context, focused) => buildPinkFocusEffect(
        ui: ui,
        radius: 14 * ui,
        isFocused: focused,
        borderWidth: 3 * ui,
        backgroundColor: focused
            ? biliPink.withValues(alpha: 0.14)
            : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22 * ui, vertical: 16 * ui),
          child: Row(
            children: [
              Icon(row.icon, size: 34 * ui, color: mainColor),
              SizedBox(width: 18 * ui),
              Expanded(
                child: Text(
                  row.label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 28 * ui, color: mainColor),
                ),
              ),
              if (row.isSwitch)
                _PlayerSwitch(ui: ui, value: row.switchValue)
              else ...[
                if (row.value != null)
                  Text(
                    row.value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26 * ui,
                      color: row.enabled
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.white24,
                    ),
                  ),
                SizedBox(width: 8 * ui),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 30 * ui,
                  color: row.enabled ? Colors.white70 : Colors.white24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 面板开关（沿用设置页的粉色开关视觉）
class _PlayerSwitch extends StatelessWidget {
  final double ui;
  final bool value;

  const _PlayerSwitch({required this.ui, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 68 * ui,
      height: 38 * ui,
      padding: EdgeInsets.all(3 * ui),
      decoration: BoxDecoration(
        color: value ? biliPink : Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(19 * ui),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 32 * ui,
          height: 32 * ui,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// 播放页控件层：顶部标题 + 右侧设置面板 + 底部控制栏
class PlayerControlLayer extends StatefulWidget {
  final String title;
  final String uploader;
  final String avatar;

  /// 控制层是否显示（由页面控制）
  final bool visible;

  /// 设置面板是否展开（由页面控制，选择「更多设置」展开、返回键收起）
  final ValueNotifier<bool> panelVisible;
  final Widget progressBar;
  final bool playing;
  final List<PlayerBarAction> actions;
  final List<PlayerPanelRow> panelRows;

  const PlayerControlLayer({
    super.key,
    required this.title,
    required this.uploader,
    required this.avatar,
    required this.visible,
    required this.panelVisible,
    required this.progressBar,
    required this.playing,
    required this.actions,
    required this.panelRows,
  });

  @override
  State<PlayerControlLayer> createState() => _PlayerControlLayerState();
}

class _PlayerControlLayerState extends State<PlayerControlLayer> {
  final _primaryNode = FocusNode(debugLabel: 'player-primary');
  final Map<PlayerControlKind, FocusNode> _barNodes = {};
  final List<FocusNode> _panelNodes = [];

  @override
  void initState() {
    super.initState();
    _syncNodes();
    widget.panelVisible.addListener(_onPanelVisibilityChanged);
    if (widget.visible) {
      _focusNode(_primaryNode);
    }
  }

  @override
  void didUpdateWidget(covariant PlayerControlLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.panelVisible != widget.panelVisible) {
      oldWidget.panelVisible.removeListener(_onPanelVisibilityChanged);
      widget.panelVisible.addListener(_onPanelVisibilityChanged);
    }
    _syncNodes();
    if (!oldWidget.visible && widget.visible) {
      if (widget.panelVisible.value) {
        _focusPanelFirst();
      } else {
        _focusNode(_primaryNode);
      }
    }
  }

  @override
  void dispose() {
    widget.panelVisible.removeListener(_onPanelVisibilityChanged);
    _primaryNode.dispose();
    for (final node in _barNodes.values) {
      node.dispose();
    }
    for (final node in _panelNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // 底栏与面板行共用同一批节点：结构变化时增删，避免每次重建导致焦点丢失
  void _syncNodes() {
    final removed = <FocusNode>[];
    final kinds = widget.actions
        .where((e) => !e.primary)
        .map((e) => e.kind)
        .toSet();
    _barNodes.removeWhere((kind, node) {
      if (kinds.contains(kind)) return false;
      removed.add(node);
      return true;
    });
    for (final kind in kinds) {
      _barNodes.putIfAbsent(
        kind,
        () => FocusNode(debugLabel: 'player-bar-${kind.name}'),
      );
    }

    final rowCount = widget.panelRows.where((row) => !row.divider).length;
    while (_panelNodes.length < rowCount) {
      _panelNodes.add(
        FocusNode(debugLabel: 'player-panel-${_panelNodes.length}'),
      );
    }
    while (_panelNodes.length > rowCount) {
      removed.add(_panelNodes.removeLast());
    }

    // 节点可能仍被上一帧的控件引用，延迟到本帧重建后再释放
    if (removed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in removed) {
          node.dispose();
        }
      });
    }
  }

  void _focusNode(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      node.requestFocus();
    });
  }

  void _focusPanelFirst() {
    // 面板可见性变更后需要等本帧重建（ExcludeFocus 解除）再判断节点可聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final node in _panelNodes) {
        if (node.canRequestFocus) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  void _onPanelVisibilityChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.panelVisible.value) {
      _focusPanelFirst();
    } else if (widget.visible) {
      final moreNode = _barNodes[PlayerControlKind.moreSettings];
      if (moreNode != null) _focusNode(moreNode);
    }
  }

  void _closePanel() {
    widget.panelVisible.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final panelVisible = widget.panelVisible.value;
    return FocusScope(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 顶部渐变遮罩，保证标题在亮色画面上可读
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 260 * ui,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // 标题始终按全宽排版：设置面板是覆盖层，不挤压标题的宽度与行数
                PlayerTitleBar(
                  title: widget.title,
                  uploader: widget.uploader,
                  avatar: widget.avatar,
                ),
                // 设置面板覆盖在标题与画面上方（占据下边栏以上的右侧区域）
                if (panelVisible)
                  Positioned(
                    top: 28 * ui,
                    right: 40 * ui,
                    bottom: 12 * ui,
                    child: PlayerSettingsPanel(children: _buildPanelRows(ui)),
                  ),
              ],
            ),
          ),
          _buildBottomArea(ui),
        ],
      ),
    );
  }

  List<Widget> _buildPanelRows(double ui) {
    final lastIndex = widget.panelRows.where((row) => !row.divider).length - 1;
    final rows = <Widget>[];
    var index = 0;
    for (final row in widget.panelRows) {
      if (row.divider) {
        rows.add(PlayerPanelTile(row: row, key: ValueKey(rows.length)));
        continue;
      }
      final rowIndex = index++;
      final isLast = rowIndex == lastIndex;
      // 面板高度由外层撑满，行在各自槽位内居中，行距随可用高度自适应
      rows.add(
        Expanded(
          child: Center(
            child: PlayerPanelTile(
              key: ValueKey('panel-${row.kind!.name}-$rowIndex'),
              row: row,
              focusNode: _panelNodes[rowIndex],
              onKeyEvent: (event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.arrowLeft ||
                    (key == LogicalKeyboardKey.arrowDown && isLast)) {
                  _closePanel();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildBottomArea(double ui) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(40 * ui, 24 * ui, 40 * ui, 16 * ui),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.progressBar,
          SizedBox(height: 12 * ui),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _buildBarChildren(ui),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBarChildren(double ui) {
    final children = <Widget>[];
    for (final action in widget.actions) {
      if (action.dividerBefore) {
        children.add(
          Container(
            width: context.border(1),
            height: 84 * ui,
            margin: EdgeInsets.symmetric(horizontal: 6 * ui),
            color: Colors.white.withValues(alpha: 0.25),
          ),
        );
      }
      if (action.primary) {
        children.add(
          PlayerPrimaryButton(
            key: ValueKey('bar-${action.kind.name}'),
            action: action,
            focusNode: _primaryNode,
            playing: widget.playing,
          ),
        );
        continue;
      }
      children.add(
        PlayerControlButton(
          key: ValueKey('bar-${action.kind.name}'),
          action: action,
          focusNode: _barNodes[action.kind],
        ),
      );
    }
    return children;
  }
}

// 播放页选择弹窗（深色玻璃 + 粉色焦点，结构与设置页选择弹窗一致）
Future<T?> showPlayerPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T current,
  required String Function(T value) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (context) => _PlayerPickerSheet<T>(
      title: title,
      options: options,
      current: current,
      labelOf: labelOf,
    ),
  );
}

class _PlayerPickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T current;
  final String Function(T value) labelOf;

  const _PlayerPickerSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16 * ui),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1F).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20 * ui),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: context.border(1),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: 12 * ui),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24 * ui, 6 * ui, 24 * ui, 12 * ui),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24 * ui,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 560 * ui),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in options)
                      DpadFocusable(
                        autofocus: item == current,
                        onSelect: () => Navigator.of(context).pop(item),
                        builder: pinkFocusEffect(ui: ui, radius: 14 * ui),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 26 * ui,
                            vertical: 16 * ui,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  labelOf(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 28 * ui,
                                    fontWeight: item == current
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: item == current
                                        ? biliPink
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              if (item == current)
                                Icon(
                                  Icons.check_rounded,
                                  size: 34 * ui,
                                  color: biliPink,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
