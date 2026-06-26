import 'package:flutter/foundation.dart';

class NavProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_index != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  int get _index => _currentIndex;

  void goHome() => setIndex(0);
  void goCourses() => setIndex(1);
  void goTests() => setIndex(2);
  void goFlashcards() => setIndex(3);
  void goProfile() => setIndex(4);
}