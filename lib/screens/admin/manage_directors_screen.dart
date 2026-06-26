// lib/screens/admin/manage_directors_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../services/user_admin_service.dart';
import 'add_edit_director_screen.dart';

/// Әкімші директорларды тіркейді, түзетеді, өшіреді.
class ManageDirectorsScreen extends StatefulWidget {
  const ManageDirectorsScreen({super.key});

  @override
  State<ManageDirectorsScreen> createState() => _ManageDirectorsScreenState();
}

class _ManageDirectorsScreenState extends State<ManageDirectorsScreen> {
  final _admin = UserAdminService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Директорлар'),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Директор қосу'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditDirectorScreen()),
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('users')
            .stream(primaryKey: ['id']).eq('role', 'director'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final directors = (snap.data ?? [])
              .map((d) =>
                  UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          if (directors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium_outlined,
                      color: AppColors.textMuted, size: 56),
                  const SizedBox(height: 12),
                  Text('Директор тіркелмеген',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text('"Директор қосу" батырмасымен тіркеңіз',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: directors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _tile(directors[i]),
          );
        },
      ),
    );
  }

  Widget _tile(UserModel director) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActions(director),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                child: Text(director.initials,
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(director.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(director.email,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(UserModel director) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_rounded, color: AppColors.navyBlue),
              title: const Text('Профильді түзету'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditDirectorScreen(existing: director),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Директорды өшіру',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(director);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserModel director) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Директорды өшіру'),
        content:
            Text('"${director.name}" профилі өшеді. Жалғастырамыз ба?'),
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
    if (ok != true) return;
    try {
      await _admin.deleteStaffProfile(director.uid);
      if (!mounted) return;
      _snack('Директор өшірілді');
    } catch (e) {
      if (!mounted) return;
      _snack('Қате: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
