// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/score_model.dart';
import '../../widgets/gold_divider.dart';
import '../../widgets/change_password_dialog.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.navyBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(user: user),
            ),
            title: Text(
              'Менің профилім',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.white),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GoldDivider(label: 'Көрсеткіштер'),
                  const SizedBox(height: 16),
                  if (user != null) _StatsGrid(userId: user.uid),

                  const SizedBox(height: 24),
                  const GoldDivider(label: 'Аккаунт'),
                  const SizedBox(height: 16),

                  _InfoTile(
                    icon: Icons.person_rounded,
                    label: 'Аты-жөні',
                    value: user?.name ?? '—',
                  ),
                  _InfoTile(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: user?.email ?? '—',
                  ),
                  _InfoTile(
                    icon: Icons.badge_rounded,
                    label: 'Рөл',
                    value: user?.roleLabel ?? '—',
                  ),
                  if (user?.className != null)
                    _InfoTile(
                      icon: Icons.class_rounded,
                      label: 'Сынып',
                      value: user!.className!,
                    ),
                  if (user != null &&
                      user.electiveProfile != ElectiveProfile.unknown)
                    _InfoTile(
                      icon: Icons.school_rounded,
                      label: 'Таңдау пәндері',
                      value: user.electiveProfileLabel,
                    ),

                  const SizedBox(height: 24),
                  const GoldDivider(label: 'Параметрлер'),
                  const SizedBox(height: 16),

                  _SettingsTile(
                    icon: Icons.notifications_rounded,
                    label: 'Хабарландырулар',
                    onTap: () {
                      if (user == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NotificationsScreen(userId: user.uid),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    label: 'Тіл',
                    trailing: 'Қазақ',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Қазірше тек қазақ тілі қолжетімді'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.lock_rounded,
                    label: 'Құпия сөзді өзгерту',
                    onTap: () => showChangePasswordSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Көмек',
                    onTap: () => _showHelp(context),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmSignOut(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Шығу'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.navyBlue),
            SizedBox(width: 10),
            Text('Көмек'),
          ],
        ),
        content: const Text(
          'Damu High School — ҰБТ-ға дайындық қосымшасы.\n\n'
          '• Курстар бөлімінен пәндер бойынша тест тапсырып, карточкаларды оқыңыз.\n'
          '• Тесттер бөлімінде куратор енгізген сынақ нәтижелерін көресіз.\n'
          '• Сұрақтар бойынша кураторыңызға хабарласыңыз.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Түсінікті'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Шығуды растау'),
        content: const Text('Сіз шынымен жүйеден шыққыңыз келе ме?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болдырмау'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  const _ProfileHeader({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.navyLight,
                  child: Text(
                    user?.initials ?? '?',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                user?.name ?? 'Пайдаланушы',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── НАҚТЫ статистика — Firestore-дан ──────────────────────
class _StatsGrid extends StatelessWidget {
  final String userId;
  const _StatsGrid({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: Supabase.instance.client.from('scores').stream(primaryKey: ['id']).eq('student_id', userId),
      builder: (context, snap) {
        // Streak деректері
        return StreamBuilder<List<dynamic>>(
          stream: Supabase.instance.client.from('streaks').stream(primaryKey: ['user_id']).eq('user_id', userId),
          builder: (context, streakSnap) {
            int streak = 0;
            if ((streakSnap.data ?? []).isNotEmpty) {
              final d = (streakSnap.data as List).first as Map<String, dynamic>;
              streak = (d['current_streak'] as num?)?.toInt() ?? 0;
            }

            final docs = snap.data ?? [];
            final scores = docs
                .map((d) => ScoreModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
                .toList();

            // Нақты есептеу
            final attempts = scores.length;
            final best = scores.isEmpty
                ? 0
                : scores.map((s) => s.totalScore).reduce((a, b) =>
                    a > b ? a : b);
            final avg = scores.isEmpty
                ? 0.0
                : scores.fold<int>(0, (s, e) => s + e.totalScore) /
                    scores.length;
            final avgPct = (avg / 140 * 100).round();

            final stats = [
              {
                'icon': Icons.quiz_rounded,
                'value': '$attempts',
                'label': 'Тапсырылған тест',
                'color': const Color(0xFF2980B9)
              },
              {
                'icon': Icons.star_rounded,
                'value': '$avgPct%',
                'label': 'Орташа балл',
                'color': const Color(0xFFC5A059)
              },
              {
                'icon': Icons.emoji_events_rounded,
                'value': '$best',
                'label': 'Ең үздік балл',
                'color': const Color(0xFF27AE60)
              },
              {
                'icon': Icons.local_fire_department_rounded,
                'value': '$streak',
                'label': 'Күн қатарынан',
                'color': const Color(0xFFE74C3C)
              },
            ];

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: stats.map((s) {
                final color = s['color'] as Color;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(s['icon'] as IconData, color: color, size: 22),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['value'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            s['label'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navyBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.navyBlue, size: 22),
        title: Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(trailing!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}