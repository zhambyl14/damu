// lib/screens/curator/subject_content_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../data/subjects_catalog.dart';
import '../../models/topic_model.dart';
import '../../services/content_service.dart';
import 'topic_content_screen.dart';

/// Бір пәннің тақырыптарын басқару (қосу/түзету/өшіру).
class SubjectContentScreen extends StatelessWidget {
  final CatalogSubject subject;
  final String curatorUid;

  const SubjectContentScreen({
    super.key,
    required this.subject,
    required this.curatorUid,
  });

  ContentService get _content => ContentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(subject.title),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Тақырып қосу'),
        onPressed: () => _topicDialog(context),
      ),
      body: StreamBuilder<List<TopicModel>>(
        stream: _content.watchTopics(subject.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final topics = snap.data ?? [];
          if (topics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(subject.icon, size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('Тақырыптар әлі жоқ',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text('"Тақырып қосу" батырмасын басыңыз',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _topicCard(context, topics[i]),
          );
        },
      ),
    );
  }

  Widget _topicCard(BuildContext context, TopicModel t) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicContentScreen(
              subjectId: subject.id,
              topicId: t.id,
              topicTitle: t.title,
              curatorUid: curatorUid,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: subject.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(subject.icon, color: subject.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge('${t.questionCount} сұрақ',
                            AppColors.navyBlue),
                        _badge('${t.flashcardCount} карточка',
                            AppColors.gold),
                        if (t.hasVideo)
                          _badge('📹 видео', AppColors.error),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                onSelected: (v) {
                  if (v == 'edit') {
                    _topicDialog(context, topic: t);
                  } else {
                    _confirmDeleteTopic(context, t);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded,
                          size: 18, color: AppColors.navyBlue),
                      SizedBox(width: 10),
                      Text('Атауын түзету'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Өшіру'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Future<void> _topicDialog(BuildContext context, {TopicModel? topic}) async {
    final titleCtrl = TextEditingController(text: topic?.title ?? '');
    final videoCtrl = TextEditingController(text: topic?.videoUrl ?? '');
    final isEdit = topic != null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Тақырыпты түзету' : 'Жаңа тақырып'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Тақырып атауы',
                hintText: 'Мысалы: Қазақ хандығы',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: videoCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Видеосабақ сілтемесі (міндетті емес)',
                hintText: 'https://youtu.be/...',
                prefixIcon: Icon(Icons.ondemand_video_rounded,
                    color: AppColors.navyBlue, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болдырмау')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сақтау'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final video = videoCtrl.text.trim().isEmpty ? null : videoCtrl.text.trim();
    if (isEdit) {
      await _content.updateTopic(
          subjectId: subject.id,
          topicId: topic.id,
          title: title,
          videoUrl: video);
    } else {
      await _content.addTopic(
          subjectId: subject.id,
          title: title,
          videoUrl: video,
          createdBy: curatorUid);
    }
  }

  Future<void> _confirmDeleteTopic(BuildContext context, TopicModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Тақырыпты өшіру'),
        content: Text(
            '"${t.title}" тақырыбы және оның барлық сұрақтары мен флешкарталары өшеді. Жалғастырамыз ба?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Болдырмау')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өшіру'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _content.deleteTopic(subject.id, t.id);
    }
  }
}
