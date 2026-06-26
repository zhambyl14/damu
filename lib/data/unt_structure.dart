// lib/data/unt_structure.dart
//
// Жаңа ҰБТ форматының толық құрылымы. Тест генерациясы мен балл есебі осы жерден
// бір ғана ақиқат көзі ретінде оқиды.
//
//   Міндетті блок (40 сұрақ / 40 балл):
//     • Қазақстан тарихы        — 20 сұрақ × 1 балл = 20
//     • Математикалық сауаттылық — 10 сұрақ × 1 балл = 10
//     • Оқу сауаттылығы          — 10 сұрақ × 1 балл = 10
//
//   Бейіндік блок (2 пән, әрқайсысы 40 сұрақ / 50 балл):
//     • 1–25 сұрақ — дәстүрлі, 1 балл  = 25
//     • 26–40 сұрақ — күрделі, 2 балл  = 30  (барлығы 50)
//
//   Жалпы: 120 сұрақ, 140 балл.

import '../models/mock_test_model.dart';

/// Бір бөлім ішіндегі белгілі бір балл-деңгейіне қажет сұрақ саны.
class UntTier {
  final int points; // әр сұрақтың баллы (1 не 2)
  final int count; // қанша сұрақ керек

  const UntTier({required this.points, required this.count});

  int get totalPoints => points * count;
}

/// Бір бөлімнің (немесе бейіндік пәннің) генерация талабы.
class UntSectionSpec {
  final String section; // MockSection.*
  final List<UntTier> tiers;

  const UntSectionSpec(this.section, this.tiers);

  int get questionCount => tiers.fold(0, (s, t) => s + t.count);
  int get maxPoints => tiers.fold(0, (s, t) => s + t.totalPoints);
}

class UntStructure {
  const UntStructure._();

  /// Міндетті бөлімдер (барлық оқушыға ортақ).
  static const mandatory = <UntSectionSpec>[
    UntSectionSpec(MockSection.kazakhHistory, [UntTier(points: 1, count: 20)]),
    UntSectionSpec(MockSection.mathLiteracy, [UntTier(points: 1, count: 10)]),
    UntSectionSpec(MockSection.readingLiteracy, [UntTier(points: 1, count: 10)]),
  ];

  /// Бір бейіндік пәннің құрылымы: 25×1 балл + 15×2 балл = 50 балл.
  static const profileTiers = <UntTier>[
    UntTier(points: 1, count: 25),
    UntTier(points: 2, count: 15),
  ];

  static const int profileQuestionCount = 40; // 25 + 15
  static const int profileMaxPoints = 50; // 25 + 30

  static const int totalQuestions = 120; // 40 + 40 + 40
  static const int totalPoints = 140; // 40 + 50 + 50
}
