// lib/screens/courses/courses_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/content_service.dart';
import 'subject_topics_screen.dart';

class _CourseSubject {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool isMandatory;
  final int topicsCount;

  const _CourseSubject({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.isMandatory,
    this.topicsCount = 0,
  });
}

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  // Барлық пәндер каталогы
  static const _allSubjects = <_CourseSubject>{
    // 3 МІНДЕТТІ
    _CourseSubject(
      id: 'history_kz',
      title: 'Қазақстан тарихы',
      icon: Icons.history_edu_rounded,
      color: Color(0xFFC0392B),
      isMandatory: true,
      topicsCount: 12,
    ),
    _CourseSubject(
      id: 'reading_literacy',
      title: 'Оқу сауаттылығы',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF8E44AD),
      isMandatory: true,
      topicsCount: 8,
    ),
    _CourseSubject(
      id: 'math_literacy',
      title: 'Математикалық сауаттылық',
      icon: Icons.calculate_rounded,
      color: Color(0xFF27AE60),
      isMandatory: true,
      topicsCount: 10,
    ),
    // ТАҢДАУ
    _CourseSubject(
      id: 'mathematics',
      title: 'Математика',
      icon: Icons.functions_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 15,
    ),
    _CourseSubject(
      id: 'physics',
      title: 'Физика',
      icon: Icons.bolt_rounded,
      color: Color(0xFF1ABC9C),
      isMandatory: false,
      topicsCount: 12,
    ),
    _CourseSubject(
      id: 'informatics',
      title: 'Информатика',
      icon: Icons.code_rounded,
      color: Color(0xFF2C3E50),
      isMandatory: false,
      topicsCount: 10,
    ),
    _CourseSubject(
      id: 'biology',
      title: 'Биология',
      icon: Icons.biotech_rounded,
      color: Color(0xFF16A085),
      isMandatory: false,
      topicsCount: 14,
    ),
    _CourseSubject(
      id: 'chemistry',
      title: 'Химия',
      icon: Icons.science_rounded,
      color: Color(0xFFD35400),
      isMandatory: false,
      topicsCount: 13,
    ),
    _CourseSubject(
      id: 'geography',
      title: 'География',
      icon: Icons.public_rounded,
      color: Color(0xFF27AE60),
      isMandatory: false,
      topicsCount: 11,
    ),
    _CourseSubject(
      id: 'world_history',
      title: 'Дүниежүзі тарихы',
      icon: Icons.travel_explore_rounded,
      color: Color(0xFF8E44AD),
      isMandatory: false,
      topicsCount: 12,
    ),
    _CourseSubject(
      id: 'english',
      title: 'Ағылшын тілі',
      icon: Icons.language_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 16,
    ),
    _CourseSubject(
      id: 'foreign',
      title: 'Шет тілі',
      icon: Icons.language_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 14,
    ),
    _CourseSubject(
      id: 'kazakh_language',
      title: 'Қазақ тілі',
      icon: Icons.text_fields_rounded,
      color: Color(0xFFC0392B),
      isMandatory: false,
      topicsCount: 12,
    ),
    _CourseSubject(
      id: 'kazakh_literature',
      title: 'Қазақ әдебиеті',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFFE67E22),
      isMandatory: false,
      topicsCount: 10,
    ),
    _CourseSubject(
      id: 'russian_language',
      title: 'Орыс тілі',
      icon: Icons.text_fields_rounded,
      color: Color(0xFF2980B9),
      isMandatory: false,
      topicsCount: 12,
    ),
    _CourseSubject(
      id: 'russian_literature',
      title: 'Орыс әдебиеті',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF8E44AD),
      isMandatory: false,
      topicsCount: 10,
    ),
  };

  /// Оқушыға қол жетімді 5 пән
  List<_CourseSubject> _accessibleSubjects(UserModel user) {
    const mandatoryIds = ['history_kz', 'reading_literacy', 'math_literacy'];
    final electiveIds = user.electiveSubjectIds;

    final result = _allSubjects.where((s) {
      return mandatoryIds.contains(s.id) || electiveIds.contains(s.id);
    }).toList();

    // Міндетті алдымен
    result.sort((a, b) {
      if (a.isMandatory && !b.isMandatory) return -1;
      if (!a.isMandatory && b.isMandatory) return 1;
      return 0;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    final subjects = _accessibleSubjects(user);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Менің курстарым'),
        backgroundColor: AppColors.navyBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Хедер
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF002147), Color(0xFF003167)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: AppColors.gold, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Сіздің пәндеріңіз',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.electiveProfileLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (user.electiveProfile == ElectiveProfile.unknown) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Таңдау пәндері белгіленбеген. Тек 3 міндетті пән қол жетімді. Кураторға хабарласыңыз.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3 МІНДЕТТІ
            Text('Міндетті пәндер',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 12),
            ...subjects.where((s) => s.isMandatory).map(
                  (s) => _CourseTile(subject: s, user: user),
                ),

            const SizedBox(height: 20),

            // ТАҢДАУ
            if (subjects.any((s) => !s.isMandatory)) ...[
              Text('Таңдау пәндері',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 12),
              ...subjects.where((s) => !s.isMandatory).map(
                    (s) => _CourseTile(subject: s, user: user),
                  ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final _CourseSubject subject;
  final UserModel user;
  const _CourseTile({required this.subject, required this.user});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectTopicsScreen(
              subjectId: subject.id,
              subjectTitle: subject.title,
              icon: subject.icon,
              color: subject.color,
              student: user,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subject.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(subject.icon, color: subject.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (subject.isMandatory
                                    ? AppColors.navyBlue
                                    : AppColors.gold)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            subject.isMandatory ? 'Міндетті' : 'Таңдау',
                            style: TextStyle(
                              color: subject.isMandatory
                                  ? AppColors.navyBlue
                                  : AppColors.gold,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Нақты тақырып саны базадан (админ әлі қоспаса — 0).
                    FutureBuilder<int>(
                      future: ContentService()
                          .getTopics(subject.id)
                          .then((t) => t.length),
                      builder: (context, snap) {
                        final count = snap.data;
                        final text = count == null
                            ? '…'
                            : (count == 0
                                ? 'Тақырыптар әзірленуде'
                                : '$count тақырып');
                        return Text(text,
                            style: Theme.of(context).textTheme.bodySmall);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

}