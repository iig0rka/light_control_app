import 'package:hive/hive.dart';

class HeadlightStorage {
  static const String boxName = 'headlightsBox';

  // 🔹 ЗРУЧНИЙ ГЕТТЕР, ЯКОГО ЗАРАЗ НЕ ВИСТАЧАЄ
  static Box get box => Hive.box(boxName);

  // дефолтні значення
  static const int defaultLeftColor = 0xFFFF66FF;
  static const int defaultRightColor = 0xFFFF6666;
  static const double defaultLeftBrightness = 0.8;
  static const double defaultRightBrightness = 0.5;
  static const bool _defaultMasterEnabled = true;

  // --------- READ ---------
  static int getLeftColor() =>
      (box.get('leftColor', defaultValue: defaultLeftColor) as int);

  static int getRightColor() =>
      (box.get('rightColor', defaultValue: defaultRightColor) as int);

  static double getLeftBrightness() =>
      (box.get('leftBrightness', defaultValue: defaultLeftBrightness) as num)
          .toDouble();

  static double getRightBrightness() =>
      (box.get('rightBrightness', defaultValue: defaultRightBrightness) as num)
          .toDouble();

  static bool getMasterEnabled() =>
      (box.get('masterEnabled', defaultValue: _defaultMasterEnabled) as bool);

  // --------- WRITE ---------
  static Future<void> setLeftColor(int value) async =>
      box.put('leftColor', value);

  static Future<void> setRightColor(int value) async =>
      box.put('rightColor', value);

  static Future<void> setBothColors(int value) async {
    await box.put('leftColor', value);
    await box.put('rightColor', value);
  }

  static Future<void> setLeftBrightness(double value) async =>
      box.put('leftBrightness', value);

  static Future<void> setRightBrightness(double value) async =>
      box.put('rightBrightness', value);

  static Future<void> setBothBrightness(double value) async {
    await box.put('leftBrightness', value);
    await box.put('rightBrightness', value);
  }

  static Future<void> setMasterEnabled(bool value) async =>
      box.put('masterEnabled', value);
}
