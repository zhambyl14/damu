// lib/models/score_model.dart
import 'package:flutter/material.dart';

class ScoreModel {
  // ── ҰБТ жаңа форматының ең жоғары баллдары (барлығы 140) ──
  // Тарих 20 + Оқу 10 + Матем 10 + Бейіндік 50 + Бейіндік 50 = 140
  static const int maxKazakhHistory = 20;
  static const int maxReadingLiteracy = 10;
  static const int maxMathLiteracy = 10;
  static const int maxElective = 50;
  static const int maxTotal = 140;

  final String id;
  final String studentId;
  final String studentName;
  final String? className;
  final String curatorId;
  final DateTime date;
  final String testType; // 'monthly' | 'internal_mock' | 'state_exam' | 'mock' | 'practice'
  final String? testName;

  /// Айлық мок тестті тапсырғанда — сол моктың id-і (бір рет қана тапсыру үшін).
  final String? mockId;

  // 5 пән баллы (жаңа ҰБТ форматы)
  final int kazakhHistory;     // 0-20
  final int readingLiteracy;   // 0-10
  final int mathLiteracy;      // 0-10
  final int elective1;         // 0-50  (бейіндік пән 1)
  final int elective2;         // 0-50  (бейіндік пән 2)

  // Таңдау пәндерінің атаулары (Firestore-дан)
  final String? elective1Name;
  final String? elective2Name;

  const ScoreModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.className,
    required this.curatorId,
    required this.date,
    required this.testType,
    this.testName,
    this.mockId,
    required this.kazakhHistory,
    required this.readingLiteracy,
    required this.mathLiteracy,
    required this.elective1,
    required this.elective2,
    this.elective1Name,
    this.elective2Name,
  });

  int get totalScore =>
      kazakhHistory + readingLiteracy + mathLiteracy + elective1 + elective2;

  int get mandatoryScore => kazakhHistory + readingLiteracy + mathLiteracy;
  int get electiveScore => elective1 + elective2;

  factory ScoreModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate;
    final rawDate = map['date'] ?? map['createdAt'] ?? map['created_at'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
    }

    return ScoreModel(
      id: id,
      studentId: map['student_id'] as String? ?? '',
      studentName: map['student_name'] as String? ?? 'Оқушы',
      className: map['class_name'] as String?,
      curatorId: map['curator_id'] as String? ?? '',
      date: parsedDate,
      testType: map['test_type'] as String? ?? 'monthly',
      testName: map['test_name'] as String?,
      mockId: map['mock_id'] as String?,
      kazakhHistory: (map['kazakh_history'] as num?)?.toInt() ?? 0,
      readingLiteracy: (map['reading_literacy'] as num?)?.toInt() ?? 0,
      mathLiteracy: (map['math_literacy'] as num?)?.toInt() ?? 0,
      elective1: (map['elective1'] as num?)?.toInt() ?? 0,
      elective2: (map['elective2'] as num?)?.toInt() ?? 0,
      elective1Name: map['elective1_name'] as String?,
      elective2Name: map['elective2_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'student_name': studentName,
        if (className != null) 'class_name': className,
        'curator_id': curatorId,
        'date': date.toIso8601String(),
        'test_type': testType,
        if (testName != null) 'test_name': testName,
        if (mockId != null) 'mock_id': mockId,
        'kazakh_history': kazakhHistory,
        'reading_literacy': readingLiteracy,
        'math_literacy': mathLiteracy,
        'elective1': elective1,
        'elective2': elective2,
        if (elective1Name != null) 'elective1_name': elective1Name,
        if (elective2Name != null) 'elective2_name': elective2Name,
        'total_score': totalScore,
        'mandatory_score': mandatoryScore,
        'elective_score': electiveScore,
      };

  String get monthLabel {
    const months = ['Қаң', 'Ақп', 'Нау', 'Сәу', 'Мам', 'Мау',
                    'Шіл', 'Там', 'Қыр', 'Қаз', 'Қар', 'Жел'];
    return months[date.month - 1];
  }

  Color get scoreColor {
    final t = totalScore;
    if (t >= 110) return const Color(0xFF27AE60);
    if (t >= 90) return const Color(0xFFC5A059);
    if (t >= 70) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  String get scoreGrade {
    final t = totalScore;
    if (t >= 110) return 'Өте жақсы';
    if (t >= 90) return 'Жақсы';
    if (t >= 70) return 'Орташа';
    return 'Жақсарту керек';
  }
}