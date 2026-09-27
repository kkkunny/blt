import 'package:blt/storages/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bool/int/String 读写往返', () async {
    await Settings.setBool(Settings.pathHASwitch, true);
    expect(await Settings.getBool(Settings.pathHASwitch), true);

    await Settings.setInt(Settings.pathDanmuFontSize, 30);
    expect(await Settings.getInt(Settings.pathDanmuFontSize), 30);

    await Settings.setString(Settings.pathQualitySwitch, '80');
    expect(await Settings.getString(Settings.pathQualitySwitch), '80');
  });

  test('未设置时返回 null', () async {
    expect(await Settings.getBool(Settings.pathHASwitch), isNull);
    expect(await Settings.getInt(Settings.pathDanmuFontSize), isNull);
    expect(await Settings.getString(Settings.pathQualitySwitch), isNull);
  });

  test('不同 path 互不影响', () async {
    await Settings.setBool(Settings.pathHASwitch, true);
    await Settings.setBool(Settings.pathVOSwitch, false);

    expect(await Settings.getBool(Settings.pathHASwitch), true);
    expect(await Settings.getBool(Settings.pathVOSwitch), false);
  });
}
