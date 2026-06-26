// lib/utils/refresh_guard.dart
//
// Web-те байқаусыз бет жаңарту (F5 / Ctrl+R / қойындыны жабу) кезінде браузердің
// «Бұл беттен кетесіз бе?» растауын шығарады — оқушы тестті байқамай жаңартып
// жауаптарынан айырылмауы үшін.
//
// Native (Android/iOS/Desktop) платформаларда бұл әрекет жоқ — артқа шығу
// PopScope арқылы қорғалады, сондықтан мұнда no-op.

import 'refresh_guard_stub.dart'
    if (dart.library.html) 'refresh_guard_web.dart' as impl;

class RefreshGuard {
  /// Тест белсенді кезде қосу.
  static void enable() => impl.enableRefreshGuard();

  /// Тест аяқталғанда/экраннан шыққанда өшіру.
  static void disable() => impl.disableRefreshGuard();
}
