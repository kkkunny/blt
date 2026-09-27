import 'package:blt/consts/color.dart';
import 'package:blt/consts/settings.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/player_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required double ui, required Widget child}) => UiScale(
  factor: ui,
  child: MaterialApp(home: Scaffold(body: child)),
);

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<PlayerBarAction> _actions(List<String> taps) => [
  PlayerBarAction(
    kind: PlayerControlKind.prevEpisode,
    icon: Icons.skip_previous_rounded,
    label: '上一集',
    iconSize: 58,
    enabled: false,
    onSelect: () => taps.add('prev'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.playPause,
    icon: Icons.play_arrow_rounded,
    label: '播放',
    primary: true,
    onSelect: () => taps.add('play'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.nextEpisode,
    icon: Icons.skip_next_rounded,
    label: '下一集',
    iconSize: 58,
    enabled: true,
    onSelect: () => taps.add('next'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.quality,
    icon: Icons.high_quality_outlined,
    label: '清晰度',
    value: '720P 高清',
    dividerBefore: true,
    onSelect: () => taps.add('quality'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.rate,
    icon: Icons.speed_rounded,
    label: '倍速',
    value: '1.0x',
    onSelect: () => taps.add('rate'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.audio,
    icon: Icons.music_note_rounded,
    label: '音轨',
    value: '默认',
    onSelect: () => taps.add('audio'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.danmaku,
    icon: Icons.chat_bubble_outline_rounded,
    label: '弹幕',
    value: '开',
    onSelect: () => taps.add('danmaku'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.aspect,
    icon: Icons.aspect_ratio_rounded,
    label: '画面比例',
    value: '适应',
    dividerBefore: true,
    onSelect: () => taps.add('aspect'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.loop,
    icon: Icons.loop_rounded,
    label: '循环播放',
    value: '不循环',
    onSelect: () => taps.add('loop'),
  ),
  PlayerBarAction(
    kind: PlayerControlKind.moreSettings,
    icon: Icons.more_horiz_rounded,
    label: '更多设置',
    onSelect: () => taps.add('more'),
  ),
];

List<PlayerPanelRow> _panelRows(List<String> taps) => [
  PlayerPanelRow.item(
    kind: PlayerControlKind.quality,
    icon: Icons.high_quality_outlined,
    label: '画质·清晰度',
    value: '720P 高清',
    onSelect: () => taps.add('panel-quality'),
  ),
  PlayerPanelRow.item(
    kind: PlayerControlKind.rate,
    icon: Icons.speed_rounded,
    label: '播放倍速',
    value: '1.0x',
    onSelect: () => taps.add('panel-rate'),
  ),
  PlayerPanelRow.item(
    kind: PlayerControlKind.audio,
    icon: Icons.music_note_rounded,
    label: '音轨',
    value: '默认',
    onSelect: () => taps.add('panel-audio'),
  ),
  PlayerPanelRow.toggle(
    kind: PlayerControlKind.danmaku,
    icon: Icons.chat_bubble_outline_rounded,
    label: '弹幕',
    switchValue: true,
    onSelect: () => taps.add('panel-danmaku'),
  ),
  const PlayerPanelRow.divider(),
  PlayerPanelRow.item(
    kind: PlayerControlKind.danmakuSettings,
    icon: Icons.settings_rounded,
    label: '弹幕设置',
    onSelect: () => taps.add('panel-danmaku-settings'),
  ),
  PlayerPanelRow.item(
    kind: PlayerControlKind.aspect,
    icon: Icons.aspect_ratio_rounded,
    label: '画面比例',
    value: '适应',
    onSelect: () => taps.add('panel-aspect'),
  ),
  PlayerPanelRow.item(
    kind: PlayerControlKind.loop,
    icon: Icons.loop_rounded,
    label: '循环播放',
    value: '不循环',
    onSelect: () => taps.add('panel-loop'),
  ),
  const PlayerPanelRow.divider(),
  PlayerPanelRow.item(
    kind: PlayerControlKind.moreSettings,
    icon: Icons.more_horiz_rounded,
    label: '更多设置',
    onSelect: () => taps.add('panel-more'),
  ),
];

Widget _layer({
  required ValueNotifier<bool> panelVisible,
  required List<String> taps,
  bool playing = false,
  bool visible = true,
  String title = '测试视频标题',
}) => PlayerControlLayer(
  title: title,
  uploader: '测试UP主',
  avatar: 'https://example.invalid/avatar.jpg',
  visible: visible,
  panelVisible: panelVisible,
  progressBar: const SizedBox(height: 60),
  playing: playing,
  actions: _actions(taps),
  panelRows: _panelRows(taps),
);

Finder _barItem(PlayerControlKind kind, String label) => find.descendant(
  of: find.byKey(ValueKey('bar-${kind.name}')),
  matching: find.text(label),
);

Finder _panelItem(int index, String label) => find.descendant(
  of: find.byKey(ValueKey('panel-${_panelKinds[index].name}-$index')),
  matching: find.text(label),
);

const _panelKinds = [
  PlayerControlKind.quality,
  PlayerControlKind.rate,
  PlayerControlKind.audio,
  PlayerControlKind.danmaku,
  PlayerControlKind.danmakuSettings,
  PlayerControlKind.aspect,
  PlayerControlKind.loop,
  PlayerControlKind.moreSettings,
];

FocusNode _focusOf(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder));

Future<void> _select(WidgetTester tester, Finder finder) async {
  _focusOf(tester, finder).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

void main() {
  testWidgets('底栏展示控件与当前值', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: []),
      ),
    );

    expect(_barItem(PlayerControlKind.prevEpisode, '上一集'), findsOneWidget);
    expect(_barItem(PlayerControlKind.playPause, '播放'), findsOneWidget);
    expect(_barItem(PlayerControlKind.nextEpisode, '下一集'), findsOneWidget);
    expect(_barItem(PlayerControlKind.quality, '清晰度'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar-quality')),
        matching: find.text('720P 高清'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar-rate')),
        matching: find.text('1.0x'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar-aspect')),
        matching: find.text('适应'),
      ),
      findsOneWidget,
    );
    expect(_barItem(PlayerControlKind.moreSettings, '更多设置'), findsOneWidget);
  });

  testWidgets('上一集/下一集使用更大的图标尺寸', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: []),
      ),
    );

    Icon iconOf(PlayerControlKind kind) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(ValueKey('bar-${kind.name}')),
        matching: find.byType(Icon),
      ),
    );
    expect(iconOf(PlayerControlKind.prevEpisode).size, 58);
    expect(iconOf(PlayerControlKind.nextEpisode).size, 58);
    expect(iconOf(PlayerControlKind.quality).size, 44);
  });

  testWidgets('底栏控件聚焦时焦点框包含图标、标题与副标题', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: []),
      ),
    );

    final root = find.byKey(const ValueKey('bar-quality'));
    final label = find.descendant(of: root, matching: find.text('清晰度'));
    final value = find.descendant(of: root, matching: find.text('720P 高清'));
    final icon = find.descendant(of: root, matching: find.byType(Icon));
    // 最近一层 AnimatedContainer 即 buildPinkFocusEffect 的焦点框
    final effect = find
        .ancestor(of: label, matching: find.byType(AnimatedContainer))
        .first;

    BoxDecoration decorationOf() =>
        tester.widget<AnimatedContainer>(effect).decoration! as BoxDecoration;

    // 未聚焦时无粉色描边
    expect(decorationOf().border!.top.color, Colors.transparent);

    _focusOf(tester, label).requestFocus();
    await tester.pump();

    expect(decorationOf().border!.top.color, biliPink);
    final effectRect = tester.getRect(effect);
    for (final inner in [icon, label, value]) {
      final rect = tester.getRect(inner);
      expect(
        effectRect.left <= rect.left &&
            effectRect.top <= rect.top &&
            effectRect.right >= rect.right &&
            effectRect.bottom >= rect.bottom,
        isTrue,
        reason: '焦点框 $effectRect 未包住 $rect',
      );
    }
  });

  testWidgets('底栏控件图标与文字纵向对齐', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: []),
      ),
    );

    double topOf(PlayerControlKind kind, String text) => tester
        .getRect(
          find.descendant(
            of: find.byKey(ValueKey('bar-${kind.name}')),
            matching: find.text(text),
          ),
        )
        .top;
    double iconCenterOf(PlayerControlKind kind) => tester
        .getRect(
          find.descendant(
            of: find.byKey(ValueKey('bar-${kind.name}')),
            matching: find.byType(Icon),
          ),
        )
        .center
        .dy;

    const labeled = <(PlayerControlKind, String)>[
      (PlayerControlKind.prevEpisode, '上一集'),
      (PlayerControlKind.nextEpisode, '下一集'),
      (PlayerControlKind.quality, '清晰度'),
      (PlayerControlKind.rate, '倍速'),
      (PlayerControlKind.audio, '音轨'),
      (PlayerControlKind.danmaku, '弹幕'),
      (PlayerControlKind.aspect, '画面比例'),
      (PlayerControlKind.loop, '循环播放'),
      (PlayerControlKind.moreSettings, '更多设置'),
    ];
    const valued = <(PlayerControlKind, String)>[
      (PlayerControlKind.quality, '720P 高清'),
      (PlayerControlKind.rate, '1.0x'),
      (PlayerControlKind.audio, '默认'),
      (PlayerControlKind.danmaku, '开'),
      (PlayerControlKind.aspect, '适应'),
      (PlayerControlKind.loop, '不循环'),
    ];

    final iconCenters = [for (final (kind, _) in labeled) iconCenterOf(kind)];
    final labelTops = [for (final (kind, label) in labeled) topOf(kind, label)];
    final valueTops = [for (final (kind, value) in valued) topOf(kind, value)];

    for (final center in iconCenters) {
      expect(center, closeTo(iconCenters.first, 0.01));
    }
    for (final top in labelTops) {
      expect(top, closeTo(labelTops.first, 0.01));
    }
    for (final top in valueTops) {
      expect(top, closeTo(valueTops.first, 0.01));
    }
  });

  testWidgets('设置面板覆盖标题栏，标题排版不变', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    // 85 个全角字符：标题在关闭面板时就是两行
    const title =
        '很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题'
        '很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题很长的视频标题';
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);

    // 单行高度基准
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: [], title: '短标题'),
      ),
    );
    final singleLine = tester.getRect(find.text('短标题')).height;

    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: [], title: title),
      ),
    );

    final closed = tester.getRect(find.text(title));
    expect(closed.height, closeTo(singleLine * 2, 1), reason: '标题前提是两行');

    panelVisible.value = true;
    await tester.pump();

    final open = tester.getRect(find.text(title));
    expect(open.left, closeTo(closed.left, 0.01));
    expect(open.top, closeTo(closed.top, 0.01));
    expect(open.width, closeTo(closed.width, 0.01));
    expect(open.height, closeTo(closed.height, 0.01));

    // 面板覆盖在标题上方：两者水平区间有重叠，而不是把标题挤窄
    final panelRect = tester.getRect(find.byType(PlayerSettingsPanel));
    expect(open.right, greaterThan(panelRect.left));
  });

  testWidgets('选中底栏控件触发回调', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: taps),
      ),
    );

    await _select(tester, _barItem(PlayerControlKind.rate, '倍速'));
    expect(taps, contains('rate'));

    await _select(tester, _barItem(PlayerControlKind.danmaku, '弹幕'));
    expect(taps, contains('danmaku'));
  });

  testWidgets('播放按钮展示播放/暂停图标', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: taps, playing: true),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar-playPause')),
        matching: find.byIcon(Icons.pause_rounded),
      ),
      findsOneWidget,
    );
    await _select(tester, _barItem(PlayerControlKind.playPause, '播放'));
    expect(taps, contains('play'));
  });

  testWidgets('面板默认隐藏，展开后聚焦第一行', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(false);
    addTearDown(panelVisible.dispose);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: taps),
      ),
    );

    // 未展开时面板不在控件树中
    expect(find.byKey(const ValueKey('panel-rate-1')), findsNothing);

    // 选中「更多设置」后由页面展开面板，面板聚焦第一行
    await _select(tester, _barItem(PlayerControlKind.moreSettings, '更多设置'));
    expect(taps, contains('more'));

    panelVisible.value = true;
    await tester.pump();
    await tester.pump();
    expect(_focusOf(tester, _panelItem(0, '画质·清晰度')).hasFocus, isTrue);
  });

  testWidgets('面板开关行选中触发切换', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(true);
    addTearDown(panelVisible.dispose);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: taps),
      ),
    );
    await tester.pump();

    await _select(tester, _panelItem(3, '弹幕'));
    expect(taps, contains('panel-danmaku'));
  });

  testWidgets('面板行按左键收起面板并把焦点还给更多设置', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(true);
    addTearDown(panelVisible.dispose);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: taps),
      ),
    );
    await tester.pump();

    final node = _focusOf(tester, _panelItem(2, '音轨'));
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();

    expect(panelVisible.value, isFalse);
    expect(
      _focusOf(
        tester,
        _barItem(PlayerControlKind.moreSettings, '更多设置'),
      ).hasFocus,
      isTrue,
    );
  });

  testWidgets('面板行之间上下键移动焦点', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(true);
    addTearDown(panelVisible.dispose);
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: []),
      ),
    );
    await tester.pump();

    _focusOf(tester, _panelItem(0, '画质·清晰度')).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(_focusOf(tester, _panelItem(1, '播放倍速')).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(_focusOf(tester, _panelItem(0, '画质·清晰度')).hasFocus, isTrue);
  });

  testWidgets('面板最后一行按下键收起面板', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    final panelVisible = ValueNotifier(true);
    addTearDown(panelVisible.dispose);
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: _layer(panelVisible: panelVisible, taps: []),
      ),
    );
    await tester.pump();

    _focusOf(tester, _panelItem(7, '更多设置')).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(panelVisible.value, isFalse);
  });

  for (final (name, size) in [
    ('720p', const Size(1280, 720)),
    ('1080p', const Size(1920, 1080)),
    ('4K', const Size(3840, 2160)),
  ]) {
    testWidgets('控件层在$name下无溢出', (tester) async {
      _setScreen(tester, size);
      final panelVisible = ValueNotifier(true);
      addTearDown(panelVisible.dispose);
      await tester.pumpWidget(
        _host(
          ui: UiScale.factorFor(size),
          child: _layer(panelVisible: panelVisible, taps: []),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('选择弹窗展示当前值并可切换', (tester) async {
    _setScreen(tester, const Size(1920, 1080));
    PlayerAspectMode? selected;
    await tester.pumpWidget(
      _host(
        ui: 1,
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                selected = await showPlayerPicker<PlayerAspectMode>(
                  context: context,
                  title: '画面比例',
                  options: PlayerAspectMode.values,
                  current: PlayerAspectMode.fit,
                  labelOf: (mode) => mode.description,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('适应'), findsOneWidget);
    expect(find.text('裁剪'), findsOneWidget);

    await _select(tester, find.text('裁剪'));
    await tester.pumpAndSettle();
    expect(selected, PlayerAspectMode.cover);
  });
}
