import 'dart:async';

import 'package:blt/apis/bilibili/client.dart' show bilibiliHttpClient;
import 'package:blt/apis/bilibili/history.dart';
import 'package:blt/apis/bilibili/media.dart'
    show getVideoPlayURL, GetVideoPlayURLResponse, Quality, DashData;
import 'package:blt/consts/settings.dart';
import 'package:blt/icons/iconfont.dart';
import 'package:blt/models/video.dart' as model;
import 'package:blt/pages/setting.dart';
import 'package:blt/storages/auth.dart';
import 'package:blt/storages/settings.dart';
import 'package:blt/utils/stream.dart';
import 'package:blt/widgets/bilibili_danmaku_wall.dart';
import 'package:blt/widgets/focus_progress_bar.dart';
import 'package:blt/widgets/loading.dart';
import 'package:blt/widgets/player_controls.dart';
import 'package:blt/widgets/tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const _step = Duration(seconds: 5);
const _danmakuWaitDuration = Duration(seconds: 5);

// 视频播放页
class VideoPlayerPage extends StatefulWidget {
  final model.Video video;
  final int cid;

  final bool danmu;
  final bool ha;
  final VideoOutputDrivers vo;
  final HardwareVideoDecoder hwdec;

  const VideoPlayerPage({
    super.key,
    required this.video,
    required this.cid,
    required this.danmu,
    required this.ha,
    required this.vo,
    required this.hwdec,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final ValueNotifier<int> _currentCid;
  late GetVideoPlayURLResponse _videoPlayURLInfo;
  late final ValueNotifier<Quality?> _currentQuality;
  late int _playingCid; // 当前实际播放的分P，用于进度上报，避免与_currentCid错配

  late final VideoController _controller;
  late final BilibiliDanmakuWallController _danmakuCtl;

  late final FocusNode _screenFocusNode;
  late final ValueNotifier<bool> _displayControl;
  late final ValueNotifier<bool> _panelVisible; // 右侧设置面板是否展开
  late final ValueNotifier<double> _playbackRate;
  late final ValueNotifier<PlayerAspectMode> _aspectMode;
  late final ValueNotifier<PlayerLoopMode> _loopMode;

  Timer? _heartbeatTimer; // 播放心跳timer
  Timer? _autoNextTimer; // 播完自动切下一分P的计时器
  late final StreamController<bool> loading;

  // memoize合并流，避免rebuild时StreamBuilder对单订阅loading流重新订阅
  late final Stream<bool> _bufferingOrLoading = combineBoolStream(
    _controller.player.stream.buffering,
    loading.stream,
  );
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  final _videoReady = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _currentCid = ValueNotifier(widget.cid);
    _currentCid.addListener(_onEpisodeChanged);
    _playingCid = widget.cid;
    _controller = VideoController(
      Player(),
      configuration: VideoControllerConfiguration(
        vo: widget.vo.value,
        hwdec: widget.hwdec.value,
        enableHardwareAcceleration: widget.ha,
      ),
    );
    _completedSub = _controller.player.stream.completed.listen((v) {
      if (v) _onPlayCompleted();
    });
    _errorSub = _controller.player.stream.error.listen(_onPlayError);
    _danmakuCtl = BilibiliDanmakuWallController(widget.danmu);
    _screenFocusNode = FocusNode();
    _displayControl = ValueNotifier(false);
    _displayControl.addListener(_onDisplayControlChanged);
    _panelVisible = ValueNotifier(false);
    _currentQuality = ValueNotifier(null);
    _playbackRate = ValueNotifier(1);
    _aspectMode = ValueNotifier(PlayerAspectMode.fit);
    _loopMode = ValueNotifier(PlayerLoopMode.none);
    loading = StreamController<bool>();
    _loadPlayerSettings().ignore();
    _onEpisodeChanged();
  }

  @override
  void dispose() {
    if (_heartbeatTimer != null) _heartbeatTimer!.cancel();
    _cancelAutoNext();
    _completedSub?.cancel();
    _errorSub?.cancel();
    if (!loading.isClosed) loading.close();
    _displayControl.removeListener(_onDisplayControlChanged);
    _displayControl.dispose();
    _panelVisible.dispose();
    _currentQuality.dispose();
    _playbackRate.dispose();
    _aspectMode.dispose();
    _loopMode.dispose();
    _videoReady.dispose();
    _screenFocusNode.dispose();
    _danmakuCtl.dispose();
    _controller.player.dispose();
    _currentCid.dispose();
    super.dispose();
  }

  // 读取播放参数（倍速/画面比例/循环播放）并应用到播放器
  Future<void> _loadPlayerSettings() async {
    try {
      final rate = double.tryParse(
        await Settings.getString(Settings.pathPlaybackRateSwitch) ?? '',
      );
      if (rate != null && playerPlaybackRates.contains(rate)) {
        _playbackRate.value = rate;
      }
      final aspect = PlayerAspectMode.parse(
        await Settings.getString(Settings.pathAspectModeSwitch),
      );
      if (aspect != null) _aspectMode.value = aspect;
      final loop = PlayerLoopMode.parse(
        await Settings.getString(Settings.pathLoopModeSwitch),
      );
      if (loop != null) _loopMode.value = loop;
    } catch (_) {
      // 读取失败时使用默认值
    }
    await _controller.player.setRate(_playbackRate.value);
    await _controller.player.setPlaylistMode(_toPlaylistMode(_loopMode.value));
  }

  PlaylistMode _toPlaylistMode(PlayerLoopMode mode) {
    return mode == PlayerLoopMode.single
        ? PlaylistMode.single
        : PlaylistMode.none;
  }

  void _onDisplayControlChanged() {
    if (_displayControl.value) {
      return;
    }
    // 控制层隐藏时设置面板一并收起
    _panelVisible.value = false;
    _screenFocusNode.requestFocus();
  }

  void _onPlayError(String err) {
    if (!mounted) return;
    // 视频源失败：仅在"无法打开"类错误时轮换到下一个备份地址，其他错误直接提示
    if (_videoUrls.isNotEmpty && err.contains(_videoUrls.first)) {
      if (!err.contains('Can not open external file')) {
        pushTooltipError(context, '视频加载失败');
        return;
      }
      _videoUrls.removeAt(0);
      if (_videoUrls.isEmpty) {
        pushTooltipError(context, '视频加载失败');
        return;
      }
      _restartPlayback().ignore();
      return;
    }
    // 音频源失败：轮换到下一个备份地址
    if (_audioUrls.isNotEmpty && err.contains(_audioUrls.first)) {
      if (!err.contains('Can not open external file')) {
        pushTooltipError(context, "音频加载失败");
        return;
      }
      _audioUrls.removeAt(0);
      if (_audioUrls.isEmpty) {
        pushTooltipError(context, "音频加载失败");
        return;
      }
      _controller.player
          .setAudioTrack(AudioTrack.uri(_audioUrls.first))
          .ignore();
      return;
    }
    pushTooltipError(context, err);
  }

  // 切换视频备份地址后重新打开媒体，保留播放进度、弹幕时间轴与音轨
  Future<void> _restartPlayback() async {
    if (_videoUrls.isEmpty) return;
    final start = _controller.player.state.position;
    // 重置弹幕时间轴，避免重开后按旧时间轴推送导致长时间无弹幕
    _danmakuCtl.clear();
    try {
      await _controller.player.open(
        Media(
          _videoUrls.first,
          httpHeaders: bilibiliHttpClient.options.headers
              .cast<String, String>(),
          start: start,
        ),
      );
      if (_audioUrls.isNotEmpty) {
        await _controller.player.setAudioTrack(
          AudioTrack.uri(_audioUrls.first),
        );
      }
      await _controller.player.setRate(_playbackRate.value);
      await _controller.player.setPlaylistMode(
        _toPlaylistMode(_loopMode.value),
      );
    } catch (_) {
      // 打开失败会通过错误流再次触发轮换
    }
  }

  DateTime? _lastBackTime;

  void _onBack(didPop) {
    if (didPop || !mounted) return;

    // 返回键优先收起设置面板
    if (_panelVisible.value) {
      _panelVisible.value = false;
      return;
    }
    if (_displayControl.value) return;

    final now = DateTime.now();
    if (_lastBackTime != null && now.difference(_lastBackTime!).inSeconds < 2) {
      // 上报播放进度
      if (loginInfoNotifier.value.isLogin) {
        reportPlayProgress(
          widget.video.avid,
          _playingCid,
          _controller.player.state.position,
        ).ignore();
      }
      return Get.back();
    }
    _lastBackTime = now;

    pushTooltipInfo(
      context,
      '再按一次返回退出播放',
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _onEpisodeChanged() async {
    // 快照本次请求的分P，若处理过程中用户又切了分P则丢弃本次结果
    final cid = _currentCid.value;
    // 新分P就绪前禁止画质等操作，避免用到旧分P的播放信息
    _videoReady.value = false;
    // 结束心跳
    _heartbeatTimer?.cancel();
    // 取消待执行的自动下一分P
    _cancelAutoNext();
    // 上报上一分P的播放进度（使用实际播放中的cid，避免切P后cid与位置错配）
    if (loginInfoNotifier.value.isLogin &&
        _controller.player.state.position.inSeconds > 0) {
      reportPlayProgress(
        widget.video.avid,
        _playingCid,
        _controller.player.state.position,
      ).ignore();
    }
    reportPlayStart(widget.video.avid, cid).ignore();
    // 暂停弹幕
    final danmakuEnabled = _danmakuCtl.enabled;
    _danmakuCtl.enabled = false;

    var success = false;
    if (!loading.isClosed) loading.sink.add(true);
    try {
      MediaPlayInfo? playInfo;
      // 若已登陆，获取播放进度
      if (loginInfoNotifier.value.isLogin) {
        try {
          final lastPlayInfo = await getMediaPlayInfo(
            avid: widget.video.avid,
            cid: cid,
          );
          if (cid == lastPlayInfo.lastPlayCid) {
            playInfo = lastPlayInfo;
          }
        } catch (_) {}
        if (!mounted || cid != _currentCid.value) return;
      }

      final info = await getVideoPlayURL(avid: widget.video.avid, cid: cid);
      if (!mounted || cid != _currentCid.value) return;
      if (info.supportFormats.isEmpty) {
        throw Exception('该视频暂无可播放清晰度');
      }

      final qualityID =
          await Settings.getInt(Settings.pathQualitySwitch) ??
          info.defaultQualityID;
      // 用户设置的画质不可用时依次回退到默认画质、第一个可用画质
      final quality = info.supportFormats.firstWhere(
        (e) => e.id == qualityID,
        orElse: () => info.supportFormats.firstWhere(
          (e) => e.id == info.defaultQualityID,
          orElse: () => info.supportFormats.first,
        ),
      );
      // 打开媒体前再校验一次分P未变，避免并发切P时旧请求最后执行覆盖新请求
      if (!mounted || cid != _currentCid.value) return;

      await _playDashMedia(
        info.dashData,
        quality,
        start: playInfo?.lastPlayTime,
      );
      if (!mounted || cid != _currentCid.value) return;

      // 应用用户设置的倍速与循环模式
      await _controller.player.setRate(_playbackRate.value);
      await _controller.player.setPlaylistMode(
        _toPlaylistMode(_loopMode.value),
      );
      if (!mounted || cid != _currentCid.value) return;

      // 播放成功后才提交状态，失败时保持旧画质/旧播放信息不变
      _videoPlayURLInfo = info;
      _currentQuality.value = quality;
      _videoReady.value = true;
      success = true;
      // 开始周期心跳（每15秒上报一次，切P/退出时取消）
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _onHeartbeat(),
      );
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (!loading.isClosed) loading.sink.add(false);
      // 仅当前分P的请求仍有效时恢复弹幕，避免旧请求覆盖新请求的状态
      if (mounted && cid == _currentCid.value) {
        _danmakuCtl.enabled = danmakuEnabled;
        if (success) _playingCid = cid;
      }
    }
  }

  void _onHeartbeat() {
    if (!loginInfoNotifier.value.isLogin) return;
    reportPlayHeartbeat(
      avid: widget.video.avid,
      cid: _playingCid,
      progress: _controller.player.state.position,
    ).ignore();
  }

  Future<void> _onQualityChange(Quality sf) async {
    if (!mounted || _currentQuality.value?.id == sf.id) return;
    // 快照当前分P，切画质期间若用户切换了分P则不恢复弹幕，避免覆盖新分P的状态
    final cid = _currentCid.value;

    // 暂停弹幕
    final danmakuEnabled = _danmakuCtl.enabled;
    _danmakuCtl.enabled = false;

    if (!loading.isClosed) loading.sink.add(true);
    try {
      await _playDashMedia(
        _videoPlayURLInfo.dashData,
        sf,
        start: _controller.player.state.position,
      );
      // 切画质期间用户切换了分P时丢弃结果，避免画质与分P错配
      if (!mounted || cid != _currentCid.value) return;
      // 播放成功后才提交画质
      _currentQuality.value = sf;
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (!loading.isClosed) loading.sink.add(false);
      if (mounted && cid == _currentCid.value) {
        // 恢复弹幕
        _danmakuCtl.enabled = danmakuEnabled;
      }
    }
  }

  List<String> _videoUrls = [];
  List<String> _audioUrls = [];

  Future<void> _playDashMedia(
    DashData media,
    Quality quality, {
    Duration? start,
  }) async {
    var video = media.video.firstWhere(
      (e) => e.quality == quality.id,
      orElse: () => throw Exception('该画质无可用视频流'),
    );
    var videoUrls = [
      video.baseUrl,
      ...video.backupUrls,
    ].where((u) => u.isNotEmpty).toList();
    if (videoUrls.isEmpty) {
      throw Exception('该画质无可用视频流');
    }
    var audioUrls = media.audio
        .expand((e) => [e.baseUrl, ...e.backupUrls])
        .where((u) => u.isNotEmpty)
        .toList();

    // 先记录全部候选地址，供_onPlayError在首个地址失败时轮换备份地址
    _videoUrls = videoUrls;
    _audioUrls = audioUrls;

    // 先打开视频流，成功后再设置DASH音轨，两者完成前不提交播放成功状态
    await _controller.player.open(
      Media(
        videoUrls.first,
        httpHeaders: bilibiliHttpClient.options.headers.cast<String, String>(),
        start: start,
      ),
    );
    if (audioUrls.isNotEmpty) {
      await _controller.player.setAudioTrack(AudioTrack.uri(audioUrls.first));
    }
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
  }

  void _onPlayCompleted() {
    // 上报播放进度
    if (loginInfoNotifier.value.isLogin) {
      reportPlayProgress(
        widget.video.avid,
        _playingCid,
        _controller.player.state.position,
      ).ignore();
    }

    // 单个循环由播放器内部循环，不触发自动下一分P
    if (_loopMode.value == PlayerLoopMode.single) return;

    final index = widget.video.episodes.indexWhere((e) => e.cid == _playingCid);
    if (index < 0 || index == widget.video.episodes.length - 1) return;
    if (!mounted) return;

    // 3秒后自动切到下一分P，用户seek或手动切P会取消该计时器
    _autoNextTimer = Timer(const Duration(seconds: 3), () {
      _autoNextTimer = null;
      if (!mounted ||
          _currentCid.value != widget.video.episodes[index].cid ||
          _playingCid != widget.video.episodes[index].cid) {
        return;
      }
      _currentCid.value = widget.video.episodes[index + 1].cid;
    });
    pushTooltipInfo(context, '即将播放下一分P', duration: const Duration(seconds: 3));
  }

  // 当前分P下标，-1 表示不在列表中
  int get _currentEpisodeIndex {
    return widget.video.episodes.indexWhere((e) => e.cid == _currentCid.value);
  }

  void _onPrevEpisode() {
    final index = _currentEpisodeIndex;
    if (index <= 0) return;
    _currentCid.value = widget.video.episodes[index - 1].cid;
  }

  void _onNextEpisode() {
    final index = _currentEpisodeIndex;
    final episodes = widget.video.episodes;
    if (index < 0 || index >= episodes.length - 1) return;
    _currentCid.value = episodes[index + 1].cid;
  }

  void _onPlayOrPause() {
    _controller.player.playOrPause();
  }

  void _onSeekPosition(Duration position) {
    _controller.player.seek(position);
    _cancelAutoNext();
    _danmakuCtl.wait(_danmakuWaitDuration);
    _danmakuCtl.clear();
  }

  void _onDanmakuSwitchTapped() {
    _danmakuCtl.enabled = !_danmakuCtl.enabled;
    Settings.setBool(Settings.pathDanmuSwitch, _danmakuCtl.enabled).ignore();
  }

  void _onUnsupportedTapped() {
    pushTooltipInfo(context, '暂不支持该功能！');
  }

  Future<void> _onMoreSettingsTapped() async {
    await Get.to(() => const SettingPage());
  }

  String _qualityLabel(Quality? quality) {
    if (quality == null) return '--';
    if (quality.description.isEmpty) return '${quality.id}P';
    return quality.description;
  }

  Future<void> _onQualityTapped() async {
    if (!_videoReady.value) return;
    final formats = _videoPlayURLInfo.supportFormats;
    final current = _currentQuality.value;
    if (formats.isEmpty || current == null) return;

    final selected = await showPlayerPicker<Quality>(
      context: context,
      title: '画质·清晰度',
      options: formats,
      current: current,
      labelOf: _qualityLabel,
    );
    if (!mounted || selected == null) return;
    await Settings.setInt(Settings.pathQualitySwitch, selected.id);
    await _onQualityChange(selected);
  }

  Future<void> _onRateTapped() async {
    final selected = await showPlayerPicker<double>(
      context: context,
      title: '播放倍速',
      options: playerPlaybackRates,
      current: _playbackRate.value,
      labelOf: playbackRateString,
    );
    if (!mounted || selected == null) return;
    _playbackRate.value = selected;
    await Settings.setString(Settings.pathPlaybackRateSwitch, '$selected');
    await _controller.player.setRate(selected);
  }

  Future<void> _onAspectTapped() async {
    final selected = await showPlayerPicker<PlayerAspectMode>(
      context: context,
      title: '画面比例',
      options: PlayerAspectMode.values,
      current: _aspectMode.value,
      labelOf: (mode) => mode.description,
    );
    if (!mounted || selected == null) return;
    _aspectMode.value = selected;
    await Settings.setString(Settings.pathAspectModeSwitch, selected.value);
  }

  Future<void> _onLoopTapped() async {
    final selected = await showPlayerPicker<PlayerLoopMode>(
      context: context,
      title: '循环播放',
      options: PlayerLoopMode.values,
      current: _loopMode.value,
      labelOf: (mode) => mode.description,
    );
    if (!mounted || selected == null) return;
    _loopMode.value = selected;
    await Settings.setString(Settings.pathLoopModeSwitch, selected.value);
    if (selected == PlayerLoopMode.single) _cancelAutoNext();
    await _controller.player.setPlaylistMode(_toPlaylistMode(selected));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onBack(didPop),
      child: Scaffold(
        body: KeyboardListener(
          autofocus: true,
          focusNode: _screenFocusNode,
          onKeyEvent: _onKeyEvent,
          child: Stack(
            children: [
              _buildVideo(),
              StreamBuilder<bool>(
                stream: _bufferingOrLoading,
                builder: (context, buffering) => (buffering.data ?? false)
                    ? buildLoadingStyle3()
                    : const SizedBox(),
              ),
              ValueListenableBuilder(
                valueListenable: _currentCid,
                builder: (context, cid, child) => BilibiliDanmakuWall(
                  controller: _danmakuCtl,
                  cid: cid,
                  timeline: _controller.player.stream.position,
                  playing: _controller.player.stream.playing,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _displayControl,
                builder: (context, display, _) => ExcludeFocus(
                  excluding: !display,
                  child: Offstage(
                    offstage: !display,
                    child: _buildControlLayer(display),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 视频画面：按画面比例设置切换填充方式
  Widget _buildVideo() {
    return ValueListenableBuilder<PlayerAspectMode>(
      valueListenable: _aspectMode,
      builder: (context, mode, _) => Video(
        controller: _controller,
        controls: NoVideoControls,
        fit: switch (mode) {
          PlayerAspectMode.fit => BoxFit.contain,
          PlayerAspectMode.fill => BoxFit.fill,
          PlayerAspectMode.cover => BoxFit.cover,
        },
      ),
    );
  }

  Widget _buildControlLayer(bool display) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _currentCid,
        _currentQuality,
        _playbackRate,
        _aspectMode,
        _loopMode,
        _videoReady,
        _danmakuCtl.enableNotifier,
      ]),
      builder: (context, _) => StreamBuilder<bool>(
        stream: _controller.player.stream.playing,
        builder: (context, playing) {
          final playingNow = playing.data ?? _controller.player.state.playing;
          return PlayerControlLayer(
            title: widget.video.title,
            uploader: widget.video.userName,
            avatar: widget.video.userAvatar,
            visible: display,
            panelVisible: _panelVisible,
            progressBar: _buildProgressBar(),
            playing: playingNow,
            actions: _buildBarActions(playingNow),
            panelRows: _buildPanelRows(),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _controller.player.stream.position,
      builder: (context, position) => FocusProgressBar(
        position: position.data ?? _controller.player.state.position,
        duration: _controller.player.state.duration,
        buffered: _controller.player.state.buffer,
        onPositionChanged: _onSeekPosition,
      ),
    );
  }

  List<PlayerBarAction> _buildBarActions(bool playing) {
    final index = _currentEpisodeIndex;
    final episodes = widget.video.episodes;
    final ready = _videoReady.value;
    final danmakuOn = _danmakuCtl.enabled;
    return [
      PlayerBarAction(
        kind: PlayerControlKind.prevEpisode,
        icon: Icons.skip_previous_rounded,
        label: '上一集',
        iconSize: 58,
        enabled: index > 0,
        onSelect: _onPrevEpisode,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.playPause,
        icon: Icons.play_arrow_rounded,
        label: playing ? '暂停' : '播放',
        primary: true,
        onSelect: _onPlayOrPause,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.nextEpisode,
        icon: Icons.skip_next_rounded,
        label: '下一集',
        iconSize: 58,
        enabled: index >= 0 && index < episodes.length - 1,
        onSelect: _onNextEpisode,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.quality,
        icon: Icons.high_quality_outlined,
        label: '清晰度',
        value: ready ? _qualityLabel(_currentQuality.value) : '--',
        enabled: ready,
        dividerBefore: true,
        onSelect: _onQualityTapped,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.rate,
        icon: Icons.speed_rounded,
        label: '倍速',
        value: playbackRateString(_playbackRate.value),
        onSelect: _onRateTapped,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.audio,
        icon: Icons.music_note_rounded,
        label: '音轨',
        value: '默认',
        onSelect: _onUnsupportedTapped,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.danmaku,
        icon: danmakuOn ? IconFont.danmukai : IconFont.danmuguanbi,
        label: '弹幕',
        value: danmakuOn ? '开' : '关',
        onSelect: _onDanmakuSwitchTapped,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.aspect,
        icon: Icons.aspect_ratio_rounded,
        label: '画面比例',
        value: _aspectMode.value.description,
        dividerBefore: true,
        onSelect: _onAspectTapped,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.loop,
        icon: Icons.loop_rounded,
        label: '循环播放',
        value: _loopMode.value.description,
        onSelect: _onLoopTapped,
      ),
      PlayerBarAction(
        kind: PlayerControlKind.moreSettings,
        icon: Icons.more_horiz_rounded,
        label: '更多设置',
        onSelect: () => _panelVisible.value = true,
      ),
    ];
  }

  List<PlayerPanelRow> _buildPanelRows() {
    final ready = _videoReady.value;
    final danmakuOn = _danmakuCtl.enabled;
    return [
      PlayerPanelRow.item(
        kind: PlayerControlKind.quality,
        icon: Icons.high_quality_outlined,
        label: '画质·清晰度',
        value: ready ? _qualityLabel(_currentQuality.value) : '--',
        enabled: ready,
        onSelect: _onQualityTapped,
      ),
      PlayerPanelRow.item(
        kind: PlayerControlKind.rate,
        icon: Icons.speed_rounded,
        label: '播放倍速',
        value: playbackRateString(_playbackRate.value),
        onSelect: _onRateTapped,
      ),
      PlayerPanelRow.item(
        kind: PlayerControlKind.audio,
        icon: Icons.music_note_rounded,
        label: '音轨',
        value: '默认',
        onSelect: _onUnsupportedTapped,
      ),
      PlayerPanelRow.toggle(
        kind: PlayerControlKind.danmaku,
        icon: danmakuOn ? IconFont.danmukai : IconFont.danmuguanbi,
        label: '弹幕',
        switchValue: danmakuOn,
        onSelect: _onDanmakuSwitchTapped,
      ),
      const PlayerPanelRow.divider(),
      PlayerPanelRow.item(
        kind: PlayerControlKind.danmakuSettings,
        icon: IconFont.danmushezhi,
        label: '弹幕设置',
        onSelect: _onUnsupportedTapped,
      ),
      PlayerPanelRow.item(
        kind: PlayerControlKind.aspect,
        icon: Icons.aspect_ratio_rounded,
        label: '画面比例',
        value: _aspectMode.value.description,
        onSelect: _onAspectTapped,
      ),
      PlayerPanelRow.item(
        kind: PlayerControlKind.loop,
        icon: Icons.loop_rounded,
        label: '循环播放',
        value: _loopMode.value.description,
        onSelect: _onLoopTapped,
      ),
      const PlayerPanelRow.divider(),
      PlayerPanelRow.item(
        kind: PlayerControlKind.moreSettings,
        icon: Icons.more_horiz_rounded,
        label: '更多设置',
        onSelect: _onMoreSettingsTapped,
      ),
    ];
  }

  void _onKeyEvent(KeyEvent value) {
    if (!_displayControl.value) {
      if (value is KeyDownEvent || value is KeyRepeatEvent) {
        switch (value.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
            _onStepForward(false);
            break;
          case LogicalKeyboardKey.arrowRight:
            _onStepForward(true);
            break;
        }
      }
    }

    if (value is! KeyUpEvent) {
      return;
    }

    if (_displayControl.value) {
      switch (value.logicalKey) {
        case LogicalKeyboardKey.goBack:
          // 面板展开时返回键只收面板，控制层保持显示
          final panelWasOpen = _panelVisible.value;
          // 延迟一帧后再隐藏控制层：确保PopScope的_onBack先被调用，
          // 这样_onBack里才能拿到此时的displayControl.value（true），
          // 从而仅关闭控制层而不是退出播放页
          Future.delayed(const Duration(milliseconds: 10)).then((_) {
            if (!mounted || panelWasOpen) return;
            _displayControl.value = false;
          });
          break;
        case LogicalKeyboardKey.contextMenu:
          _displayControl.value = false;
          break;
      }
      return;
    }

    switch (value.logicalKey) {
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        // 仅当没有控件持有焦点时才由页面接管播放/暂停，
        // 避免与控件自身的激活（ActivateIntent）重复触发
        if (FocusManager.instance.primaryFocus != _screenFocusNode) {
          break;
        }
        _controller.player.playOrPause();
        break;
      case LogicalKeyboardKey.contextMenu:
        _displayControl.value = true;
        break;
    }
  }

  void _onStepForward(bool forward) {
    _cancelAutoNext();
    if (forward) {
      if (_controller.player.state.duration -
              _controller.player.state.position <
          _step) {
        _controller.player.seek(_controller.player.state.duration);
      } else {
        _controller.player.seek(_controller.player.state.position + _step);
      }
    } else {
      if (_controller.player.state.position < _step) {
        _controller.player.seek(Duration(seconds: 0));
      } else {
        _controller.player.seek(_controller.player.state.position - _step);
      }
    }
    _danmakuCtl.wait(_danmakuWaitDuration);
    _danmakuCtl.clear();
  }
}
