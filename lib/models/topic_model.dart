// lib/models/topic_model.dart

/// Пән ішіндегі тақырып: subjects/{subjectId}/topics/{topicId}
class TopicModel {
  final String id;
  final String subjectId;
  final String title;
  final int order;
  final int questionCount;
  final int flashcardCount;
  final String? videoUrl;
  final String? createdBy;
  final DateTime? createdAt;

  const TopicModel({
    required this.id,
    required this.subjectId,
    required this.title,
    this.order = 0,
    this.questionCount = 0,
    this.flashcardCount = 0,
    this.videoUrl,
    this.createdBy,
    this.createdAt,
  });

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  factory TopicModel.fromMap(
    Map<String, dynamic> map,
    String id,
    String subjectId,
  ) {
    final rawDate = map['created_at'] ?? map['createdAt'];
    DateTime? created;
    if (rawDate is String) {
      created = DateTime.tryParse(rawDate);
    } else if (rawDate is int) {
      created = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is DateTime) {
      created = rawDate;
    }

    return TopicModel(
      id: id,
      subjectId: subjectId,
      title: map['title'] as String? ?? 'Тақырып',
      order: (map['order'] as num?)?.toInt() ?? 0,
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
      flashcardCount: (map['flashcard_count'] as num?)?.toInt() ?? 0,
      videoUrl: map['video_url'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'order': order,
        'question_count': questionCount,
        'flashcard_count': flashcardCount,
        'video_url': videoUrl,
        'subject_id': subjectId,
        if (createdBy != null) 'created_by': createdBy,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
