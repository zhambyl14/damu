// lib/utils/screen_secure.dart
import 'package:flutter/widgets.dart';
import 'package:screen_protector/screen_protector.dart';

/// Скриншот пен экран жазудан қорғау (Android: FLAG_SECURE, iOS: скриншот блок).
/// Видеосабақ пен тест экрандарында қолданылады — контент таратылмауы үшін.
class ScreenSecure {
  const ScreenSecure._();

  static Future<void> enable() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {}
    try {
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {}
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {}
  }
}

/// StatefulWidget-терге қосылатын миксин: экран ашылғанда қорғауды қосады,
/// жабылғанда өшіреді.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ScreenSecure.enable();
  }

  @override
  void dispose() {
    ScreenSecure.disable();
    super.dispose();
  }
}
