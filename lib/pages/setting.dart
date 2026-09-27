import 'package:blt/consts/settings.dart';
import 'package:blt/icons/iconfont.dart';
import 'package:blt/storages/settings.dart';
import 'package:blt/utils/ui_scale.dart';
import 'package:blt/widgets/cache_future_builder.dart';
import 'package:blt/widgets/custom_setting_tiles.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late bool _danmu;
  late int _danmuBlockWeight;
  late int _danmuFontSize;
  late bool _ha;
  late VideoOutputDrivers _vo;
  late HardwareVideoDecoder _hwdec;
  late String _version;

  Future<void> _loadSettings() async {
    try {
      _danmu = await Settings.getBool(Settings.pathDanmuSwitch) ?? true;
      _danmuBlockWeight =
          await Settings.getInt(Settings.pathDanmuBlockWeightSwitch) ?? 6;
      _danmuFontSize = await Settings.getInt(Settings.pathDanmuFontSize) ?? 20;
      _ha = await Settings.getBool(Settings.pathHASwitch) ?? true;
      _vo =
          VideoOutputDrivers.parse(
            await Settings.getString(Settings.pathVOSwitch) ??
                VideoOutputDrivers.gpu.value,
          ) ??
          VideoOutputDrivers.gpu;
      _hwdec =
          HardwareVideoDecoder.parse(
            await Settings.getString(Settings.pathHwdecSwitch) ??
                HardwareVideoDecoder.autoSafe.value,
          ) ??
          HardwareVideoDecoder.autoSafe;
      final pi = await PackageInfo.fromPlatform();
      _version = pi.version;
    } catch (_) {
      // 读取失败时使用默认值，避免页面因late字段未初始化而崩溃
      _danmu = true;
      _danmuBlockWeight = 6;
      _danmuFontSize = 20;
      _ha = true;
      _vo = VideoOutputDrivers.gpu;
      _hwdec = HardwareVideoDecoder.autoSafe;
      _version = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CacheFutureBuilder(
        future: _loadSettings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox();
          }
          if (snapshot.hasError) {
            return const Center(child: Text('加载失败，请稍后重试'));
          }
          final ui = context.ui;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(24 * ui),
                  children: [
                    CustomSettingsPanel(
                      children: [
                        CustomSettingsSwitchTile(
                          leading: const Icon(IconFont.danmushezhi),
                          title: '弹幕设置-是否开启弹幕',
                          value: _danmu,
                          autofocus: true,
                          onChanged: (value) => setState(() {
                            Settings.setBool(Settings.pathDanmuSwitch, value);
                            _danmu = value;
                          }),
                        ),
                        CustomSettingsDropdownTile<int>(
                          leading: const Icon(IconFont.danmushezhi),
                          title: '弹幕屏蔽权重：值越大弹幕越少',
                          value: _danmuBlockWeight,
                          items: List<int>.generate(
                            11,
                            (int index) => index,
                            growable: false,
                          ),
                          onChanged: (value) => setState(() {
                            Settings.setInt(
                              Settings.pathDanmuBlockWeightSwitch,
                              value,
                            );
                            _danmuBlockWeight = value;
                          }),
                        ),
                        CustomSettingsDropdownTile<int>(
                          leading: const Icon(IconFont.danmushezhi),
                          title: '弹幕字体大小',
                          value: _danmuFontSize,
                          items: const [16, 18, 20, 22, 25, 28, 30, 36],
                          onChanged: (value) => setState(() {
                            Settings.setInt(Settings.pathDanmuFontSize, value);
                            _danmuFontSize = value;
                          }),
                        ),
                        CustomSettingsSwitchTile(
                          leading: const Icon(IconFont.ha),
                          title: '播放设置-是否开启硬解',
                          value: _ha,
                          onChanged: (value) => setState(() {
                            Settings.setBool(Settings.pathHASwitch, value);
                            _ha = value;
                          }),
                        ),
                        CustomSettingsDropdownTile<VideoOutputDrivers>(
                          leading: const Icon(Icons.video_settings_rounded),
                          title: '播放设置-输出驱动',
                          value: _vo,
                          items: VideoOutputDrivers.values,
                          onChanged: (value) => setState(() {
                            Settings.setString(
                              Settings.pathVOSwitch,
                              value.value,
                            );
                            _vo = value;
                          }),
                        ),
                        CustomSettingsDropdownTile<HardwareVideoDecoder>(
                          leading: const Icon(Icons.video_stable_rounded),
                          title: '播放设置-硬解方式',
                          value: _hwdec,
                          items: HardwareVideoDecoder.values,
                          onChanged: (value) => setState(() {
                            Settings.setString(
                              Settings.pathHwdecSwitch,
                              value.value,
                            );
                            _hwdec = value;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 20 * ui),
                child: Text(
                  'v$_version',
                  style: TextStyle(
                    fontSize: 12 * ui,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
