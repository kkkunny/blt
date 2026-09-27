# AGENTS.md — BLT (第三方哔哩哔哩 Android TV 客户端)

## Project overview
Flutter third-party Bilibili client targeting **Android TV only** (dpad/focus-based navigation). No iOS/web/desktop support.

## Key commands

```bash
# Install dependencies
flutter pub get

# Static analysis (used in CI for PRs to master)
make analyse                # runs: flutter analyze --no-fatal-infos

# Generate protobuf Dart files from .proto definitions
make gen_protobuf           # runs: protoc --dart_out=. lib/models/pbs/dm.proto

# Generate icon font Dart code + .ttf from remote iconfont CSS
make gen_icons              # runs: dart run iconfont_convert --config iconfont.yaml

# Build release APK (split by ABI)
flutter build apk --split-per-abi

# Run the UI/layout tests
flutter test
```

**Code generation**: after modifying `lib/models/pbs/dm.proto`, run `make gen_protobuf`. After modifying `iconfont.yaml`, run `make gen_icons`.

## Architecture

```
lib/
├── apis/bilibili/     # API layer — HTTP client (Dio), auth, media, recommend, etc.
├── pages/             # Top-level pages (recommend, video_player, video_detail, search, user, etc.)
├── widgets/           # Reusable widgets (video_card, video_grid_view, danmaku_wall, etc.)
├── models/            # Data models + protobuf (.proto & generated .pb.dart)
├── storages/          # Persistence (auth via shared_preferences, settings)
├── utils/             # Small helpers
├── consts/            # Constants (colors, asset paths, Bilibili API constants, settings keys)
├── icons/             # Generated icon font Dart code (do not edit directly)
└── main.dart           # App entrypoint — initializes MediaKit, high refresh rate, GetMaterialApp
```

**Routing**: GetX (`GetMaterialApp`, `Get.to()`, `GetPage`). Two routes: `/` (splash) and `/home` (main tab shell).

**Main tab shell** (`lib/pages/pages.dart`): vertical icon sidebar (user avatar, search, history, dynamic, to-view, recommend, settings) with `LazyIndexedStack` body.

**State management**: mix of `ValueNotifier` / `ListenableBuilder` (reactive) and imperative `setState`. Global state e.g. `loginInfoNotifier` in `lib/storages/auth.dart`.

**Bilibili API 参考**：接口的请求方式、参数、响应字段与签名规则以 [pskdje/bilibili-API-collect](https://github.com/pskdje/bilibili-API-collect) 为准；新增或调整 `lib/apis/bilibili/` 下的接口前先查阅确认。

## Conventions

- **Commits**: `type: description` — types: `feat`, `fix`, `opt`, `version`, `Merge`
- **Lint**: `package:flutter_lints/flutter.yaml` with no custom rule overrides
- **TV navigation**: uses `dpad` package for focus-based key navigation. Scroll thumbs are suppressed (`NoThumbScrollBehavior`). All interactive widgets must support focus/dpad.
- **Video player**: uses `media_kit` + `media_kit_video` + `media_kit_libs_android_video`
- **Danmaku**: `canvas_danmaku` for danmaku wall rendering; managed by `BilibiliDanmakuWall` widget

## UI 缩放规范

设计基准为 **1920×1080**（1080p，逻辑像素），全局缩放因子由 `lib/utils/ui_scale.dart` 统一提供：

- 因子 `ui = min(宽/1920, 高/1080)`，在 `GetMaterialApp.builder` 中通过 `UiScaleScope` 挂载一次，widget 内用 `context.ui` 获取。
- 系统字体缩放固定为 `TextScaler.noScaling`（见 `UiScaleScope`），字号只由 `ui` 控制，避免系统放大撑破 dpad 布局。
- 组件内统一写 `final ui = context.ui;`，不要再手写 `MediaQuery.sizeOf(context).height / 1080`。

**TV 排版总则**（改 UI 前先过一遍）：

- 第一优先级是"焦点一眼可见、选中状态明确、遥控器好按"：任何时刻画面里只应有一个焦点，聚焦态必须通过描边 + 光晕 + 放大/底色变化与未聚焦、选中态拉开差距。
- 同类元素复用同一套组件与规格（详情页相关推荐与主页共用 `VideoCard` / `VideoGridView`，视频详情页所有可聚焦项共用 `pink_style.dart` 的焦点特效，主侧边栏与动态页 UP 列共用 `side_panel.dart` 的 `SidePanel` / `SidePanelTile`），只通过尺寸与缩放系数适配，不要为小尺寸另做一套。
- 卡片上的悬浮信息（UP主/播放量/时长）必须随卡片尺寸缩放：窄卡片不缩就会喧宾夺主（见下方角标系数）。
- 主要操作按钮等宽成行排列，焦点移动路径可预期（横向一行、纵向分层），不要把可聚焦元素散落在空白里。
- 列表、面板、弹窗的留白要同时给"内容 + 焦点光晕"留位置，不能只按静止状态排。

**必须乘 `ui`**：字号、图标、padding/margin、圆角、描边（用 `context.border(x)` 保底 1 逻辑像素）、光晕半径、进度条高度、头像半径、最小焦点目标。

**不得乘 `ui`**：宽高比、Flex 权重、行列数（由可用宽度 ÷ 目标卡片尺寸推导）、文本行数、对齐、动画时长、颜色、opacity/scale 等系数。

**布局与组件约定**：

- 布局先由 Flex/约束分配空间，缩放只作用于固定视觉尺寸；不要用"容器高度 × 比例"反推一个与内容结构脱节的卡片尺寸。
- 卡片封面固定 16:9（`coverSizeRatio`，**详情页左上角播放卡与卡片封面共用同一比例**，保证"看起来就是视频画面"），卡片宽高比 `videoCardAspectRatio`（= 16:9 封面 + 两行标题，目前 1.3）是卡片规格的一部分，与卡片内部结构绑定，页面不得传入手调比例；`VideoGridView` 内部按滚动方向自动换算 delegate 比例，横向/纵向栅格观感一致。
- 封面角标（UP主/播放量/时长）尺寸与卡片宽度挂钩：`videoCardOverlayBaseWidth` 是 1080p 四列基准宽，系数为 `(卡片宽 / 基准 × ui).clamp(0.70, 1.0)`，新增角标元素时必须乘同一个系数（详情页相关推荐卡片只有主页卡片约 0.7 宽，角标不缩会喧宾夺主）。
- 卡片标题字号由 `FixedLineAdaptiveText.maxFontSize` 与卡片宽度挂钩，避免窄卡片把标题撑得过大。
- 详情页视频信息卡：标题 2 行（`maxFontSize` 40ui）→ 6 个操作按钮一行等宽胶囊（58ui 高、圆角 16ui、间距 12ui）→ 简介可聚焦小卡（浅粉底 + 右侧展开图标，点击打开全文弹窗）→ UP 信息行（头像 + 名称 + UP主标签 + 粉丝数与发布时间同行 + 右侧关注胶囊）。
- 设置项等新控件优先复用/扩展 `widgets/pink_style.dart` 与 `widgets/custom_setting_tiles.dart`，不要引入 dp 写死尺寸的第三方 UI 包。

**焦点与选中规范**（统一由 `widgets/pink_style.dart` 提供）：

- 可聚焦组件一律用 `pinkFocusEffect(...)` / `buildPinkFocusEffect(...)`，不要自己写 `BoxShadow` 焦点光晕：光晕用"描边 + 模糊"只向外绘制，`BoxShadow` 会把元素内部整片染成粉色（透明底控件尤其明显）。
- 焦点表现 = 粉色描边（默认 `3 * ui`，用 `UiScale.border` 保底 1px）+ 外发光 + 可选放大：`scale` 建议卡片 1.03、按钮/胶囊 1.04~1.05、大块区域 1.02，再大就会挤到相邻元素。
- 光晕半径与元素尺寸挂钩（`(shortestSide * 0.025).clamp(10ui, 16ui)`）；**滚动列表内的可聚焦元素，列表 `padding` 至少 14ui**，否则光晕会被视口裁出一条直边（`ListView` / 栅格用 padding，不要用 `Clip.none`，否则滚动时内容会画到面板外）。分集列表、相关推荐已按此处理。
- 选中态与焦点态必须可区分：选中（已点赞/已投币/当前分P）用粉色底或渐变，焦点用白底 + 粉边 + 光晕，底色切换用 `focusedBackgroundColor`。
- 可聚焦小控件底色统一 `focusableSurfaceColor`（浅粉），聚焦时切白；等宽胶囊用 `Expanded`，数字/文案外套 `FittedBox(fit: BoxFit.scaleDown)` 防溢出。

**弹窗规范**：用自绘 `Dialog`（`backgroundColor: transparent` + 白面板，圆角 24ui、投影、遮罩 `Colors.black.withValues(alpha: 0.5)`、`barrierDismissible: false`），结构为"渐变图标 + 标题 + 操作提示 / 内容 / 右对齐 `PinkButton`"；关闭用 `Navigator.of(dialogContext).pop()`，不要用 `Get.back()`（`showDialog` 是 Navigator 路由，纯 `MaterialApp` 测试环境会抛 contextless navigation 异常）。

- 参考实现：详情页"视频简介"弹窗（`video_detail.dart` 的 `_buildCompleteDesc`）——头部渐变图标 + "视频简介" + "↑↓ 滚动"提示，正文 `ScrollText`（24ui / 行高 1.65，上下到边界时让出焦点），底部右对齐可聚焦"关闭"，Back 键同样可关闭。

## CI / releases

- PRs to `master`: `flutter analyze` via `code_analyze.yml`
- Pushing a `v*` tag triggers `release_drafter.yml`: builds APK and creates a draft GitHub release with APK artifacts

## Testing

- UI 缩放/布局测试：`test/ui_scale_test.dart`、`test/video_grid_view_test.dart`、`test/video_card_layout_test.dart`、`test/text_test.dart`、`test/custom_setting_tiles_test.dart`、`test/pages/video_detail_layout_test.dart`，用 `flutter test` 运行。
- 新增/修改 UI 组件时必须补对应测试，并保证在 720p/1080p/4K 下无 overflow（建议顺带覆盖 4:3、21:9，详情页这类多面板页面容易在非 16:9 下溢出）。
- 纯观感类修改可以临时写 widget test 把页面渲染成 PNG 自检（`flutter test --update-goldens` 输出到 /tmp，图片兜底需 mock `path_provider` 的 `getApplicationSupportDirectory`），临时文件不要提交。

## Platform notes

- `android/` directory configures minSdk 24 for `flutter_launcher_icons`
- Cookie/auth persistence only works on actual Android (uses `dart:io` HttpOnly cookies via `Cookie.fromSetCookieValue`)
