// lib/widgets/staff_profile_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../screens/notifications/notifications_screen.dart';
import 'change_password_dialog.dart';

/// Қызметкерлерге (куратор/директор/админ) ортақ профиль қойындысы:
/// деректер + хабарландырулар + құпия сөз + шығу.
class StaffProfileTab extends StatelessWidget {
  const StaffProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2.5),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.navyBlue,
                      child: Text(user.initials,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(user.roleLabel,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _infoTile(context, Icons.email_rounded, 'Email', user.email),
            if (user.className != null)
              _infoTile(context, Icons.class_rounded, 'Сынып', user.className!),
            _infoTile(context, Icons.badge_rounded, 'Рөл', user.roleLabel),
            const SizedBox(height: 20),
            _NotificationsTile(userId: user.uid),
            _actionTile(
              context,
              icon: Icons.lock_rounded,
              label: 'Құпия сөзді өзгерту',
              onTap: () => showChangePasswordSheet(context),
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
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
      BuildContext context, IconData icon, String label, String value) {
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
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
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
                color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textMuted, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              child: const Text('Болдырмау')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
            child: const Text('Шығу'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsTile extends StatelessWidget {
  final String userId;
  const _NotificationsTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().watch(userId),
      builder: (context, snap) {
        final unread = (snap.data ?? []).where((n) => !n.read).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(userId: userId),
              ),
            ),
            leading: const Icon(Icons.notifications_rounded,
                color: AppColors.navyBlue, size: 22),
            title: Text('Хабарландырулар',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$unread',
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
              ],
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      },
    );
  }
}
