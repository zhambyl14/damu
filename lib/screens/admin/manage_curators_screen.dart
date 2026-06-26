// lib/screens/admin/manage_curators_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../services/user_admin_service.dart';
import 'add_edit_curator_screen.dart';

/// Әкімші кураторларды тіркейді және профилін түзетеді.
class ManageCuratorsScreen extends StatefulWidget {
  const ManageCuratorsScreen({super.key});

  @override
  State<ManageCuratorsScreen> createState() => _ManageCuratorsScreenState();
}

class _ManageCuratorsScreenState extends State<ManageCuratorsScreen> {
  final _searchCtrl = TextEditingController();
  final _admin = UserAdminService();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Кураторлар'),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Куратор қосу'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddEditCuratorScreen(),
          ),
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: Supabase.instance.client
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('role', 'curator'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }

          final curators = (snap.data ?? [])
              .map((d) => UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          final filtered = curators
              .where((c) =>
                  _query.isEmpty ||
                  c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Куратор іздеу...',
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
                        const Icon(Icons.supervisor_account_outlined,
                            color: AppColors.textMuted, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          curators.isEmpty
                              ? 'Кураторлар тіркелмеген'
                              : 'Сәйкес куратор табылмады',
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
                    itemBuilder: (_, i) => _curatorTile(context, filtered[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _curatorTile(BuildContext context, UserModel curator) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActions(context, curator),
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
                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                child: Text(curator.initials,
                    style: const TextStyle(
                        color: AppColors.goldDark,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(curator.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      curator.className != null
                          ? '${curator.className} сынып'
                          : 'Сынып тағайындалмаған',
                      style: Theme.of(context).textTheme.bodySmall,
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

  void _showActions(BuildContext context, UserModel curator) {
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
              subtitle: const Text('Аты, сынып'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditCuratorScreen(existing: curator),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Кураторды өшіру',
                  style: TextStyle(color: AppColors.error)),
              subtitle: const Text('Оқушыларын басқа кураторға көшіреміз'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(curator);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Кураторды өшіру. Оқушылары болса — алдымен басқа кураторға көшіреміз.
  Future<void> _confirmDelete(UserModel curator) async {
    final supabase = Supabase.instance.client;
    List students;
    List curatorsRaw;
    try {
      students = await supabase
          .from('users')
          .select('id')
          .eq('curator_id', curator.uid)
          .eq('role', 'student');
      curatorsRaw = await supabase.from('users').select().eq('role', 'curator');
    } catch (e) {
      if (!mounted) return;
      _snack('Қате: $e', isError: true);
      return;
    }
    final studentCount = students.length;
    final others = curatorsRaw
        .map((d) =>
            UserModel.fromMap(d as Map<String, dynamic>, d['id'].toString()))
        .where((c) => c.uid != curator.uid)
        .toList();

    if (!mounted) return;

    UserModel? target;
    if (studentCount > 0) {
      if (others.isEmpty) {
        _snack(
            'Бұл кураторда $studentCount оқушы бар, бірақ көшіруге басқа куратор жоқ. '
            'Алдымен жаңа куратор қосыңыз.',
            isError: true);
        return;
      }
      target = others.first;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Кураторды өшіру'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${curator.name}" өшіріледі.'),
              if (studentCount > 0) ...[
                const SizedBox(height: 12),
                Text('$studentCount оқушы мына кураторға көшеді:',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserModel>(
                      isExpanded: true,
                      value: target,
                      items: others
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                    '${c.name}${c.className != null ? " (${c.className})" : ""}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setLocal(() => target = v),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
      ),
    );
    if (confirmed != true) return;

    try {
      if (studentCount > 0 && target != null) {
        await _admin.reassignStudents(curator.uid, target!.uid);
      }
      await _admin.deleteStaffProfile(curator.uid);
      if (!mounted) return;
      _snack('Куратор өшірілді');
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
