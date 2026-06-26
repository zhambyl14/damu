// lib/screens/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  static const _months = [
    'қаң', 'ақп', 'нау', 'сәу', 'мам', 'мау',
    'шіл', 'там', 'қыр', 'қаз', 'қар', 'жел'
  ];

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'жаңа ғана';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин бұрын';
    if (diff.inHours < 24) return '${diff.inHours} сағ бұрын';
    if (diff.inDays < 7) return '${diff.inDays} күн бұрын';
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Хабарландырулар'),
        backgroundColor: AppColors.navyBlue,
        actions: [
          IconButton(
            tooltip: 'Бәрін оқылды деп белгілеу',
            icon: const Icon(Icons.done_all_rounded, color: AppColors.gold),
            onPressed: () => service.markAllRead(userId),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: service.watch(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('Хабарландырулар жоқ',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _tile(context, service, items[i]),
          );
        },
      ),
    );
  }

  Widget _tile(
      BuildContext context, NotificationService service, AppNotification n) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => service.delete(n.id),
      child: Material(
        color: n.read ? AppColors.white : n.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: n.read ? null : () => service.markRead(n.id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: n.read ? AppColors.divider : n.color.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: n.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(n.icon, color: n.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(n.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: n.read
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                    )),
                          ),
                          if (!n.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: n.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(n.body,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Text(_ago(n.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
