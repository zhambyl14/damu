// lib/utils/refresh_guard_web.dart
//
// Web нұсқасы: 'beforeunload' оқиғасына listener қосып, браузердің native
// «беттен кетесіз бе?» растауын шығарады. Бұл F5, Ctrl+R және қойынды/терезені
// жабуды қамтиды.
//
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

html.EventListener? _listener;

void enableRefreshGuard() {
  _listener ??= (event) {
    // returnValue орнату — браузердің растау диалогын қосады.
    (event as html.BeforeUnloadEvent).returnValue = '';
  };
  html.window.addEventListener('beforeunload', _listener);
}

void disableRefreshGuard() {
  if (_listener != null) {
    html.window.removeEventListener('beforeunload', _listener);
    _listener = null;
  }
}
