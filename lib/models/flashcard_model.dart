// lib/models/flashcard_model.dart

/// Firestore-дағы флешкарта:
/// subjects/{subjectId}/topics/{topicId}/flashcards/{flashcardId}
///
/// (flashcards_screen.dart ішіндегі hardcoded `Flashcard` класынан бөлек —
/// бұл базадан оқылады/жазылады.)
class FlashcardModel {
  final String id;
  final String subjectId;
  final String topicId;
  final String front;
  final String back;
  final String? hint;
  final int order;
  final String? createdBy;
  final DateTime? createdAt;

  const FlashcardModel({
    required this.id,
    required this.subjectId,
    required this.topicId,
    required this.front,
    required this.back,
    this.hint,
    this.order = 0,
    this.createdBy,
    this.createdAt,
  });

  factory FlashcardModel.fromMap(
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

    return FlashcardModel(
      id: id,
      subjectId: (map['subject_id'] as String?) ?? subjectId ?? '',
      topicId: (map['topic_id'] as String?) ?? topicId ?? '',
      front: map['front'] as String? ?? '',
      back: map['back'] as String? ?? '',
      hint: map['hint'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdBy: map['created_by'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() => {
        'subject_id': subjectId,
        'topic_id': topicId,
        'front': front,
        'back': back,
        'hint': hint,
        'order': order,
        if (createdBy != null) 'created_by': createdBy,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  FlashcardModel copyWith({
    String? front,
    String? back,
    String? hint,
    int? order,
  }) =>
      FlashcardModel(
        id: id,
        subjectId: subjectId,
        topicId: topicId,
        front: front ?? this.front,
        back: back ?? this.back,
        hint: hint ?? this.hint,
        order: order ?? this.order,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
