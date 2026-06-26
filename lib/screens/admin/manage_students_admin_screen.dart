// lib/screens/admin/manage_students_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../services/user_admin_service.dart';
import '../curator/add_edit_student_screen.dart';

/// Әкімші мектептегі БАРЛЫҚ оқушыларды көреді әрі басқарады (түзету/өшіру).
class ManageStudentsAdminScreen extends StatefulWidget {
  const ManageStudentsAdminScreen({super.key});

  @override
  State<ManageStudentsAdminScreen> createState() =>
      _ManageStudentsAdminScreenState();
}

class _ManageStudentsAdminScreenState extends State<ManageStudentsAdminScreen> {
  final _admin = UserAdminService();
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// curatorId → куратор (атын көрсету + түзету экранына беру үшін).
  Map<String, UserModel> _curators = {};

  @override
  void initState() {
    super.initState();
    _loadCurators();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurators() async {
    final res = await Supabase.instance.client
        .from('users')
        .select()
        .eq('role', 'curator');
    if (!mounted) return;
    setState(() {
      _curators = {
        for (final d in (res as List))
          (d['id']).toString():
              UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString())
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Оқушылар'),
        backgroundColor: AppColors.navyBlue,
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('users')
            .stream(primaryKey: ['id']).eq('role', 'student'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final students = (snap.data ?? [])
              .map((d) =>
                  UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          final filtered = students.where((s) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                (s.className ?? '').toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Оқушы іздеу (аты/сынып)...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.navyBlue, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Барлығы: ${students.length} оқушы',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups_outlined,
                            color: AppColors.textMuted, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          students.isEmpty
                              ? 'Оқушылар тіркелмеген'
                              : 'Сәйкес оқушы табылмады',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _studentTile(filtered[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _studentTile(UserModel s) {
    final curator = s.curatorId != null ? _curators[s.curatorId] : null;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActions(s, curator),
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
                backgroundColor: AppColors.navyBlue.withValues(alpha: 0.08),
                child: Text(s.initials,
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${s.className ?? "—"} · ${curator?.name ?? "куратор жоқ"}'
                      ' · ${s.studentTypeLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

  void _showActions(UserModel student, UserModel? curator) {
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
            if (curator != null)
              ListTile(
                leading:
                    const Icon(Icons.edit_rounded, color: AppColors.navyBlue),
                title: const Text('Профильді түзету'),
                subtitle: const Text('Аты, сынып, тип, профиль'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditStudentScreen(
                          curator: curator, existing: student),
                    ),
                  );
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.info_outline_rounded,
                    color: AppColors.warning),
                title: Text('Кураторы жоқ'),
                subtitle: Text('Түзету үшін алдымен куратор тағайындаңыз'),
              ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Оқушыны өшіру',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(student);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserModel student) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Оқушыны өшіру'),
        content: Text(
            '"${student.name}" профилі өшеді. Жалғастырамыз ба?'),
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
      await _admin.removeStudentProfile(student.uid);
      if (!mounted) return;
      _snack('Оқушы өшірілді');
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
