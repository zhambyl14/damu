// lib/screens/student/student_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../notifications/notifications_screen.dart';
import 'student_analytics_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Қайырлы таң'
        : hour < 17
            ? 'Қайырлы күн'
            : 'Қайырлы кеш';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('scores')
            .stream(primaryKey: ['id'])
            .eq('student_id', user.uid),
        builder: (context, snap) {
          final docs = snap.data ?? [];
          final allScores = docs
              .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          final latest = allScores.isNotEmpty ? allScores.first : null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.navyBlue,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _StudentHero(user: user, greeting: greeting),
                ),
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.school_rounded,
                          color: AppColors.navyBlue,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Damu High School',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
                actions: [
                  _NotificationBell(userId: user.uid),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Жылдам кіру (streak орнына — қазірден бастап)
                      const _SectionTitle('Жылдам кіру'),
                      const SizedBox(height: 12),
                      const _QuickAccessRow(),
                      const SizedBox(height: 28),

                      if (latest != null) ...[
                        _SectionRow(
                          title: 'Соңғы тест нәтижесі',
                          subtitle: latest.testName ?? 'Сынақтама',
                        ),
                        const SizedBox(height: 14),
                        _TotalScoreCard(score: latest),
                        const SizedBox(height: 28),
                      ],

                      _SectionRow(
                        title: 'Менің пәндерім',
                        subtitle: user.electiveProfileLabel,
                      ),
                      const SizedBox(height: 14),

                      // 3 МІНДЕТТІ ПӘН
                      _SubjectTile(
                        title: 'Қазақстан тарихы',
                        badge: 'Міндетті',
                        badgeColor: AppColors.navyBlue,
                        icon: Icons.history_edu_rounded,
                        color: const Color(0xFFC0392B),
                        score: latest?.kazakhHistory ?? 0,
                        maxScore: 20,
                      ),
                      _SubjectTile(
                        title: 'Оқу сауаттылығы',
                        badge: 'Міндетті',
                        badgeColor: AppColors.navyBlue,
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFF8E44AD),
                        score: latest?.readingLiteracy ?? 0,
                        maxScore: 10,
                      ),
                      _SubjectTile(
                        title: 'Математикалық сауаттылық',
                        badge: 'Міндетті',
                        badgeColor: AppColors.navyBlue,
                        icon: Icons.calculate_rounded,
                        color: const Color(0xFF27AE60),
                        score: latest?.mathLiteracy ?? 0,
                        maxScore: 10,
                      ),

                      // 2 ТАҢДАУ ПӘНІ
                      if (user.electiveProfile != ElectiveProfile.unknown) ...[
                        _SubjectTile(
                          title: latest?.elective1Name ??
                              (user.electiveSubjects.isNotEmpty
                                  ? user.electiveSubjects[0].label
                                  : 'Таңдау пәні 1'),
                          badge: 'Таңдау',
                          badgeColor: AppColors.gold,
                          icon: Icons.science_rounded,
                          color: const Color(0xFF2980B9),
                          score: latest?.elective1 ?? 0,
                          maxScore: 50,
                        ),
                        _SubjectTile(
                          title: latest?.elective2Name ??
                              (user.electiveSubjects.length > 1
                                  ? user.electiveSubjects[1].label
                                  : 'Таңдау пәні 2'),
                          badge: 'Таңдау',
                          badgeColor: AppColors.gold,
                          icon: Icons.biotech_rounded,
                          color: const Color(0xFF16A085),
                          score: latest?.elective2 ?? 0,
                          maxScore: 50,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppColors.warning, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Таңдау пәндері белгіленбеген. Кураторға хабарласыңыз.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                      const _SectionTitle('Сынып рейтингі'),
                      const SizedBox(height: 12),
                      _ClassLeaderboard(user: user),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentHero extends StatelessWidget {
  final UserModel user;
  final String greeting;
  const _StudentHero({required this.user, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue, Color(0xFF003D7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(greeting,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppColors.gold, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        user.className != null
                            ? '${user.className} сыныбы'
                            : user.roleLabel,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppColors.goldLight,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalScoreCard extends StatelessWidget {
  final ScoreModel score;
  const _TotalScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final fraction = (score.totalScore / 140).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Жалпы балл',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${score.totalScore}',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          )),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('/ 140',
                            style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: score.scoreColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: score.scoreColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(score.scoreGrade,
                    style: TextStyle(
                      color: score.scoreColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ChipMini(label: 'Міндетті', value: '${score.mandatoryScore}/40'),
              const SizedBox(width: 8),
              _ChipMini(label: 'Таңдау', value: '${score.electiveScore}/100'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipMini extends StatelessWidget {
  final String label, value;
  const _ChipMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.6), fontSize: 11)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavProvider>();
    final user = context.read<AuthProvider>().userModel;

    return Row(
      children: [
        Expanded(
          child: _QuickBtn(
            icon: Icons.quiz_rounded,
            label: 'Тест',
            color: AppColors.navyBlue,
            onTap: () => nav.setIndex(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickBtn(
            icon: Icons.style_rounded,
            label: 'Карточка',
            color: AppColors.gold,
            onTap: () => nav.setIndex(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickBtn(
            icon: Icons.bar_chart_rounded,
            label: 'Рейтинг',
            color: const Color(0xFF8E44AD),
            onTap: () {
              if (user == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentAnalyticsScreen(studentId: user.uid),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String title;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color color;
  final int score;
  final int maxScore;

  const _SubjectTile({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.color,
    required this.score,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
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
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: badgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$score / $maxScore',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassLeaderboard extends StatelessWidget {
  final UserModel user;
  const _ClassLeaderboard({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.curatorId == null) {
      return _emptyBox(context, 'Куратор тіркелмеген');
    }

    return StreamBuilder<List<dynamic>>(
      stream: Supabase.instance.client
          .from('scores')
          .stream(primaryKey: ['id'])
          .eq('curator_id', user.curatorId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.navyBlue),
            ),
          );
        }

        final docs = snap.data ?? [];
        if (docs.isEmpty) return _emptyBox(context, 'Деректер жоқ');

        final Map<String, int> best = {};
        final Map<String, String> nameMap = {};
        for (final doc in docs) {
          final m = ScoreModel.fromMap(doc as Map<String, dynamic>, doc['id'].toString());
          final cur = best[m.studentId] ?? 0;
          if (m.totalScore > cur) {
            best[m.studentId] = m.totalScore;
            nameMap[m.studentId] = m.studentName;
          }
        }

        final entries = best.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = entries.take(10).toList();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: top.asMap().entries.map((e) {
              final rank = e.key + 1;
              final studentId = e.value.key;
              final score = e.value.value;
              final name = nameMap[studentId] ?? 'Оқушы';
              final isMe = studentId == user.uid;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.navyBlue.withValues(alpha: 0.05)
                      : Colors.transparent,
                  border: rank < top.length
                      ? const Border(
                          bottom: BorderSide(
                              color: AppColors.divider, width: 1))
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: rank <= 3
                          ? Text(
                              rank == 1
                                  ? '🥇'
                                  : rank == 2
                                      ? '🥈'
                                      : '🥉',
                              style: const TextStyle(fontSize: 20),
                            )
                          : Text('#$rank',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMe ? '$name (Сіз)' : name,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight:
                                  isMe ? FontWeight.w700 : FontWeight.w400,
                              color: isMe
                                  ? AppColors.navyBlue
                                  : AppColors.textPrimary,
                            ),
                      ),
                    ),
                    Text(
                      '$score',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: rank == 1
                                ? AppColors.gold
                                : AppColors.navyBlue,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _emptyBox(BuildContext context, String text) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted)),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.navyBlue,
              fontWeight: FontWeight.w700,
            ),
      );
}

class _NotificationBell extends StatelessWidget {
  final String userId;
  const _NotificationBell({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().watch(userId),
      builder: (context, snap) {
        final unread = (snap.data ?? []).where((n) => !n.read).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(userId: userId),
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                      )),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.gold)),
            ],
          ),
        ],
      );
}