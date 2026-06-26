// lib/data/subjects_catalog.dart
//
// Барлық ҰБТ пәндерінің ортақ каталогы. Бұрын courses_screen.dart пен
// flashcards_screen.dart ішінде қайталанып жазылған еді — енді бір жерде.
import 'package:flutter/material.dart';

class CatalogSubject {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool isMandatory;
  final int topicsCount;

  const CatalogSubject({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.isMandatory,
    this.topicsCount = 0,
  });

  /// ҰБТ-да міндетті пәндер 20 баллдан, таңдау пәндері 40 баллдан.
  int get maxScore => isMandatory ? 20 : 40;
}

class SubjectCatalog {
  const SubjectCatalog._();

  static const List<String> mandatoryIds = [
    'history_kz',
    'reading_literacy',
    'math_literacy',
  ];

  static const List<CatalogSubject> all = <CatalogSubject>[
    // ── 3 МІНДЕТТІ ──
    CatalogSubject(
      id: 'history_kz',
      title: 'Қазақстан тарихы',
      icon: Icons.history_edu_rounded,
      color: Color(0xFFC0392B),
      isMandatory: true,
      topicsCount: 12,
    ),
    CatalogSubject(
      id: 'reading_literacy',
      title: 'Оқу сауаттылығы',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF8E44AD),
      isMandatory: true,
      topicsCount: 8,
    ),
    CatalogSubject(
      id: 'math_literacy',
      title: 'Математикалық сауаттылық',
      icon: Icons.calculate_rounded,
      color: Color(0xFF27AE60),
      isMandatory: true,
      topicsCount: 10,
    ),
    // ── ТАҢДАУ ──
    CatalogSubject(
      id: 'mathematics',
      title: 'Математика',
      icon: Icons.functions_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 15,
    ),
    CatalogSubject(
      id: 'physics',
      title: 'Физика',
      icon: Icons.bolt_rounded,
      color: Color(0xFF1ABC9C),
      isMandatory: false,
      topicsCount: 12,
    ),
    CatalogSubject(
      id: 'informatics',
      title: 'Информатика',
      icon: Icons.code_rounded,
      color: Color(0xFF2C3E50),
      isMandatory: false,
      topicsCount: 10,
    ),
    CatalogSubject(
      id: 'biology',
      title: 'Биология',
      icon: Icons.biotech_rounded,
      color: Color(0xFF16A085),
      isMandatory: false,
      topicsCount: 14,
    ),
    CatalogSubject(
      id: 'chemistry',
      title: 'Химия',
      icon: Icons.science_rounded,
      color: Color(0xFFD35400),
      isMandatory: false,
      topicsCount: 13,
    ),
    CatalogSubject(
      id: 'geography',
      title: 'География',
      icon: Icons.public_rounded,
      color: Color(0xFF27AE60),
      isMandatory: false,
      topicsCount: 11,
    ),
    CatalogSubject(
      id: 'world_history',
      title: 'Дүниежүзі тарихы',
      icon: Icons.travel_explore_rounded,
      color: Color(0xFF8E44AD),
      isMandatory: false,
      topicsCount: 12,
    ),
    CatalogSubject(
      id: 'english',
      title: 'Ағылшын тілі',
      icon: Icons.language_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 16,
    ),
    CatalogSubject(
      id: 'foreign',
      title: 'Шет тілі',
      icon: Icons.language_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 14,
    ),
    CatalogSubject(
      id: 'kazakh_language',
      title: 'Қазақ тілі',
      icon: Icons.text_fields_rounded,
      color: Color(0xFFC0392B),
      isMandatory: false,
      topicsCount: 12,
    ),
    CatalogSubject(
      id: 'kazakh_literature',
      title: 'Қазақ әдебиеті',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFFE67E22),
      isMandatory: false,
      topicsCount: 10,
    ),
    CatalogSubject(
      id: 'russian_language',
      title: 'Орыс тілі',
      icon: Icons.text_fields_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 12,
    ),
    CatalogSubject(
      id: 'russian_literature',
      title: 'Орыс әдебиеті',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF8E44AD),
      isMandatory: false,
      topicsCount: 10,
    ),
  ];

  static CatalogSubject? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static String titleOf(String id) => byId(id)?.title ?? id;

  static List<CatalogSubject> get mandatory =>
      all.where((s) => s.isMandatory).toList();

  static List<CatalogSubject> get electives =>
      all.where((s) => !s.isMandatory).toList();
}
