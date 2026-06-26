// lib/models/mock_test_model.dart

/// Мектеп бойынша ҰБТ мок тесті: mockTests/{mockId}
/// Сұрақтары: mockTests/{mockId}/questions/{qid}
class MockTest {
  final String id;
  final String title;
  final String? description;
  final bool active;
  final DateTime? createdAt;
  final String? createdBy;

  /// Осы күн/уақыттан бастап оқушыларға тапсыруға қолжетімді (куратор белгілейді).
  final DateTime? availableFrom;

  /// Қай сыныпқа арналған (null — барлығына).
  final String? className;

  const MockTest({
    required this.id,
    required this.title,
    this.description,
    this.active = true,
    this.createdAt,
    this.createdBy,
    this.availableFrom,
    this.className,
  });

  static DateTime? _parseDate(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is DateTime) return raw;
    return null;
  }

  factory MockTest.fromMap(Map<String, dynamic> map, String id) {
    return MockTest(
      id: id,
      title: map['title'] as String? ?? 'Мок тест',
      description: map['description'] as String?,
      active: map['active'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      createdBy: map['createdBy'] as String? ?? (map['created_by'] as String?),
      availableFrom: _parseDate(map['available_from']),
      className: map['class_name'] as String?,
    );
  }

  /// Оқушыға қазір қолжетімді ме (белсенді + available_from өтті).
  bool get isAvailableNow =>
      active &&
      (availableFrom == null || !availableFrom!.isAfter(DateTime.now()));

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'active': active,
        if (createdBy != null) 'created_by': createdBy,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (availableFrom != null)
          'available_from': availableFrom!.toIso8601String(),
        if (className != null) 'class_name': className,
      };
}

/// ҰБТ бөлімдері. Міндетті 3 бөлім + таңдау пәндері.
class MockSection {
  static const kazakhHistory = 'kazakhHistory';
  static const readingLiteracy = 'readingLiteracy';
  static const mathLiteracy = 'mathLiteracy';
  static const elective = 'elective';

  static const mandatory = [kazakhHistory, readingLiteracy, mathLiteracy];

  static String label(String section) {
    switch (section) {
      case kazakhHistory:   return 'Қазақстан тарихы';
      case readingLiteracy: return 'Оқу сауаттылығы';
      case mathLiteracy:    return 'Математикалық сауаттылық';
      case elective:        return 'Таңдау пәні';
      default:              return section;
    }
  }

  /// Бөлімнің ең жоғары баллы (жаңа ҰБТ форматы):
  /// тарих 20, оқу 10, матем 10, бейіндік (elective) 50.
  static int maxScore(String section) {
    switch (section) {
      case kazakhHistory:   return 20;
      case readingLiteracy: return 10;
      case mathLiteracy:    return 10;
      case elective:        return 50;
      default:              return 20;
    }
  }
}

class MockQuestion {
  final String id;
  final String mockId;
  final String section; // MockSection.*
  final String? subjectId; // elective болғанда — қай таңдау пәні
  final String question;
  final List<String> options;

  /// Дұрыс жауап(тар)дың индекстері. Бір дұрыс жауап — бір элемент,
  /// бірнеше дұрыс жауап (сәйкестендіру/26–40 сұрақтар) — бірнеше элемент.
  final List<int> correctIndices;
  final String? explanation;

  /// Сұрақтың баллы: дәстүрлі (1–25) — 1 балл, күрделі (26–40) — 2 балл.
  final int points;

  /// Сурет URL мекенжайы (Excel «сурет» бағанынан). Болмаса — null.
  final String? imageUrl;

  final int order;

  const MockQuestion({
    required this.id,
    required this.mockId,
    required this.section,
    this.subjectId,
    required this.question,
    required this.options,
    required this.correctIndices,
    this.explanation,
    this.points = 1,
    this.imageUrl,
    this.order = 0,
  });

  /// Артқа үйлесімділік: бірінші дұрыс жауаптың индексі.
  int get correctIndex => correctIndices.isEmpty ? 0 : correctIndices.first;

  /// Бірнеше дұрыс жауабы бар (күрделі) сұрақ па?
  bool get isMultiple => correctIndices.length > 1;

  factory MockQuestion.fromMap(Map<String, dynamic> map, String id, String mockId) {
    // correct_indices (jsonb тізім) басым; болмаса ескі correct_index өрісі.
    final rawIndices = map['correct_indices'];
    List<int> indices;
    if (rawIndices is List) {
      indices = rawIndices.map((e) => (e as num).toInt()).toList();
    } else {
      indices = [(map['correct_index'] as num?)?.toInt() ?? 0];
    }
    return MockQuestion(
      id: id,
      mockId: mockId,
      section: map['section'] as String? ?? MockSection.kazakhHistory,
      subjectId: map['subject_id'] as String?,
      question: map['question'] as String? ?? '',
      options:
          (map['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      correctIndices: indices,
      explanation: map['explanation'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 1,
      imageUrl: map['image_url'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'mock_id': mockId,
        'section': section,
        'subject_id': subjectId,
        'question': question,
        'options': options,
        'correct_index': correctIndex, // ескі өріс — үйлесімділік үшін
        'correct_indices': correctIndices,
        'points': points,
        'image_url': imageUrl,
        'explanation': explanation,
        'order': order,
      };

  /// Сұрақтар банкіне жазу үшін (question_bank кестесі — mock_id/order жоқ).
  Map<String, dynamic> toBankMap() => {
        'section': section,
        'subject_id': subjectId,
        'question': question,
        'options': options,
        'correct_indices': correctIndices,
        'points': points,
        'image_url': imageUrl,
        'explanation': explanation,
      };

  MockQuestion copyWith({
    String? section,
    String? subjectId,
    String? question,
    List<String>? options,
    List<int>? correctIndices,
    String? explanation,
    int? points,
    String? imageUrl,
  }) =>
      MockQuestion(
        id: id,
        mockId: mockId,
        section: section ?? this.section,
        subjectId: subjectId ?? this.subjectId,
        question: question ?? this.question,
        options: options ?? this.options,
        correctIndices: correctIndices ?? this.correctIndices,
        explanation: explanation ?? this.explanation,
        points: points ?? this.points,
        imageUrl: imageUrl ?? this.imageUrl,
        order: order,
      );
}
