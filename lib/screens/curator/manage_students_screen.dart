// lib/screens/curator/manage_students_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'add_edit_student_screen.dart';
import 'student_scores_screen.dart';

/// Куратордың оқушыларын басқару: тіркеу, түзету, балл тарихы.
class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curator = context.watch<AuthProvider>().userModel;
    if (curator == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Оқушылар'),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Оқушы қосу'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditStudentScreen(curator: curator),
          ),
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('curator_id', curator.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }

          final students = (snap.data ?? [])
              .where((d) => (d as Map)['role'] == 'student')
              .map((d) => UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          final filtered = students
              .where((s) =>
                  _query.isEmpty ||
                  s.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Оқушыны іздеу...',
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
              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline_rounded,
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _studentTile(context, curator, filtered[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _studentTile(
      BuildContext context, UserModel curator, UserModel student) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActions(context, curator, student),
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
                child: Text(student.initials,
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      student.electiveProfile == ElectiveProfile.unknown
                          ? 'Профиль белгіленбеген'
                          : student.electiveProfileLabel,
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

  void _showActions(
      BuildContext context, UserModel curator, UserModel student) {
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
              leading: const Icon(Icons.assignment_rounded,
                  color: AppColors.navyBlue),
              title: const Text('Тест нәтижелері'),
              subtitle: const Text('Балл қосу, түзету, өшіру'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentScoresScreen(
                        curator: curator, student: student),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_rounded, color: AppColors.navyBlue),
              title: const Text('Профильді түзету'),
              subtitle: const Text('Аты, сынып, таңдау профилі'),
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
            ),
          ],
        ),
      ),
    );
  }
}
