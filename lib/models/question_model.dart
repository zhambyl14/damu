// lib/models/question_model.dart

/// Тест сұрағы:
/// subjects/{subjectId}/topics/{topicId}/questions/{questionId}
class QuestionModel {
  final String id;
  final String subjectId;
  final String topicId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final int points;
  final int order;
  final String? createdBy;
  final DateTime? createdAt;

  const QuestionModel({
    required this.id,
    required this.subjectId,
    required this.topicId,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.points = 1,
    this.order = 0,
    this.createdBy,
    this.createdAt,
  });

  factory QuestionModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? subjectId,
    String? topicId,
  }) {
    final rawDate = map['created_at'] ?? map['createdAt'];
    DateTime? created;
    if (rawDate is String) {
      created = DateTime.tryParse(rawDate);
    } else if (rawDate is int) {
      created = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is DateTime) {
      created = rawDate;
    }

    return QuestionModel(
      id: id,
      subjectId: (map['subject_id'] as String?) ?? subjectId ?? '',
      topicId: (map['topic_id'] as String?) ?? topicId ?? '',
      question: map['question'] as String? ?? '',
      options: (map['options'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      correctIndex: (map['correct_index'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 1,
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdBy: map['created_by'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() => {
        'subject_id': subjectId,
        'topic_id': topicId,
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
        'points': points,
        'order': order,
        if (createdBy != null) 'created_by': createdBy,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  QuestionModel copyWith({
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    int? points,
    int? order,
  }) =>
      QuestionModel(
        id: id,
        subjectId: subjectId,
        topicId: topicId,
        question: question ?? this.question,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        explanation: explanation ?? this.explanation,
        points: points ?? this.points,
        order: order ?? this.order,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
