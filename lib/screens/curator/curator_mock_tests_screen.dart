// lib/screens/curator/curator_mock_tests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/mock_test_model.dart';
import '../../models/user_model.dart';
import '../../services/mock_test_service.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';

/// Куратор айлық мок тест ашады. Сұрақтар банктен генерацияланады (per-student),
/// сондықтан мұнда тек: атауы, сыныбы, ҚАЙ КҮНІ қолжетімді болатыны белгіленеді.
class CuratorMockTestsScreen extends StatelessWidget {
  const CuratorMockTestsScreen({super.key});

  MockTestService get _service => MockTestService();

  static const _months = [
    'Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым',
    'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final curator = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Айлық мок тесттер'),
        backgroundColor: AppColors.navyBlue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Мок тест'),
        onPressed: curator == null
            ? null
            : () => _editDialog(context, curator),
      ),
      body: StreamBuilder<List<MockTest>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          // Тек осы куратор ашқан мок тесттер.
          final mocks = (snap.data ?? [])
              .where((m) => m.createdBy == curator?.uid)
              .toList();
          if (mocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_outlined,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('Әлі мок тест жоқ',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text('"Мок тест" батырмасымен ашыңыз',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: mocks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _card(context, mocks[i], curator!),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, MockTest m, UserModel curator) {
    final now = DateTime.now();
    final pending = m.availableFrom != null && m.availableFrom!.isAfter(now);
    final statusColor = !m.active
        ? AppColors.textMuted
        : (pending ? AppColors.warning : AppColors.success);
    final statusText = !m.active
        ? 'Жасырын'
        : (pending ? '${_fmt(m.availableFrom!)} ашылады' : 'Қолжетімді');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fact_check_rounded, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusText,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                  if (m.className != null) ...[
                    const SizedBox(width: 6),
                    Text('${m.className} сынып',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textMuted),
            onSelected: (v) {
              if (v == 'edit') {
                _editDialog(context, curator, existing: m);
              } else if (v == 'toggle') {
                _service.updateMock(m.id, {'active': !m.active});
              } else {
                _confirmDelete(context, m);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 18, color: AppColors.navyBlue),
                  SizedBox(width: 10),
                  Text('Түзету'),
                ]),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                      m.active
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: AppColors.navyBlue),
                  const SizedBox(width: 10),
                  Text(m.active ? 'Жасыру' : 'Белсендіру'),
                ]),
              ),
              const PopupMenuItem(
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
    );
  }

  Future<void> _editDialog(BuildContext context, UserModel curator,
      {MockTest? existing}) async {
    final titleCtrl = TextEditingController(
        text: existing?.title ?? 'Айлық мок тест');
    final classCtrl = TextEditingController(
        text: existing?.className ?? curator.className ?? '');
    DateTime available = existing?.availableFrom ?? DateTime.now();
    bool active = existing?.active ?? true;
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Мок тестті түзету' : 'Жаңа мок тест'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Атауы'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Сынып (бос — барлық оқушыға)',
                    hintText: 'Мысалы: 11А',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: available,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setLocal(() => available = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Қай күні ашылады',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(_fmt(available)),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Белсенді'),
                  value: active,
                  activeThumbColor: AppColors.navyBlue,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Болдырмау')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сақтау')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final className =
        classCtrl.text.trim().isEmpty ? null : classCtrl.text.trim();

    try {
      if (isEdit) {
        await _service.updateMock(existing.id, {
          'title': title,
          'class_name': className,
          'available_from': available.toIso8601String(),
          'active': active,
        });
      } else {
        await _service.addMock(MockTest(
          id: '',
          title: title,
          active: active,
          createdBy: curator.uid,
          className: className,
          availableFrom: available,
        ));
        // Тест ашылған соң (немесе бұрын болашаққа белгіленсе де) сол куратордың
        // оқушыларына «тапсырыңыз» хабарландыруы жіберіледі.
        if (active) await _notifyStudents(curator, title, available);
      }
      if (!context.mounted) return;
      _snack(context, isEdit ? 'Мок тест жаңартылды' : 'Мок тест ашылды');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Қате: $e', isError: true);
    }
  }

  /// Куратордың оқушыларына жаңа мок тест туралы хабарландыру.
  Future<void> _notifyStudents(
      UserModel curator, String title, DateTime available) async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('curator_id', curator.uid)
          .eq('role', 'student');
      final ids = (res as List).map((d) => d['id'].toString()).toList();
      final notifications = NotificationService();
      final pending = available.isAfter(DateTime.now());
      final body = pending
          ? '«$title» — ${_fmt(available)} ашылады. Дайын болыңыз!'
          : '«$title» қолжетімді — тапсырыңыз!';
      for (final id in ids) {
        await notifications.send(
          userId: id,
          title: 'Жаңа айлық мок тест',
          body: body,
          type: 'mock',
        );
      }
    } catch (_) {
      // Хабарландыру сәтсіз болса да мок ашылды — үнсіз өтеміз.
    }
  }

  void _snack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _confirmDelete(BuildContext context, MockTest m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Мок тестті өшіру'),
        content: Text('"${m.title}" өшеді. Жалғастырамыз ба?'),
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
    if (ok == true) await _service.deleteMock(m.id);
  }
}
