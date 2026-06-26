// lib/screens/admin/question_bank_screen.dart
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../data/subjects_catalog.dart';
import '../../data/unt_structure.dart';
import '../../models/mock_test_model.dart';
import '../../services/question_bank_service.dart';
import 'add_edit_mock_question_screen.dart';
import 'bulk_import_screen.dart';

/// Әкімші СҰРАҚТАР БАНКІН толтырады. Мок/дайындық тесті осы банктен толық ҰБТ
/// структурасы бойынша генерацияланады — әр бөлім/пәнге жеткілікті сұрақ керек.
///
/// Пән бойынша сүзу + іздеу: оқушы белгілі бір сұрақты қайта қарауды сұраса,
/// әкімші пәнін таңдап, мәтін бойынша тез тауып, түзете алады.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final _bank = QuestionBankService();
  final _searchCtrl = TextEditingController();

  String _query = '';
  String? _subjectFilter; // null — барлық пән

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Сұрақтың пәні/бөлімі (сүзу кілті).
  String _bucketOf(MockQuestion q) => q.section == MockSection.elective
      ? (q.subjectId ?? 'elective')
      : q.section;

  String _bucketLabel(String key) => MockSection.mandatory.contains(key)
      ? MockSection.label(key)
      : SubjectCatalog.titleOf(key);

  String _sectionTitle(MockQuestion q) => q.section == MockSection.elective
      ? SubjectCatalog.titleOf(q.subjectId ?? '')
      : MockSection.label(q.section);

  bool _matchesQuery(MockQuestion q) {
    if (_query.isEmpty) return true;
    final ql = _query.toLowerCase();
    if (q.question.toLowerCase().contains(ql)) return true;
    for (final o in q.options) {
      if (o.toLowerCase().contains(ql)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Сұрақтар банкі'),
        backgroundColor: AppColors.navyBlue,
        actions: [
          IconButton(
            tooltip: 'Excel/мәтін импорт',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BulkImportScreen.bank()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Сұрақ қосу'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddEditMockQuestionScreen(bank: true),
          ),
        ),
      ),
      body: StreamBuilder<List<MockQuestion>>(
        stream: _bank.watchBank(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navyBlue));
          }
          final items = snap.data ?? [];

          // Банкте бар пәндер (сүзгі чиптері үшін).
          final buckets = <String>{for (final q in items) _bucketOf(q)};
          final ordered = <String>[
            for (final sec in MockSection.mandatory)
              if (buckets.contains(sec)) sec,
          ];
          final electives = buckets
              .where((b) => !MockSection.mandatory.contains(b))
              .toList()
            ..sort((a, b) => _bucketLabel(a).compareTo(_bucketLabel(b)));
          ordered.addAll(electives);

          // Таңдалған пән енді банкте жоқ болса — сүзгіні тазалаймыз.
          if (_subjectFilter != null && !buckets.contains(_subjectFilter)) {
            _subjectFilter = null;
          }

          // Сүзу + іздеу.
          final filtered = items.where((q) {
            if (_subjectFilter != null && _bucketOf(q) != _subjectFilter) {
              return false;
            }
            return _matchesQuery(q);
          }).toList();

          return Column(
            children: [
              _searchBar(),
              if (ordered.isNotEmpty) _filterChips(ordered, items),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _readinessCard(context, items),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      _empty(context)
                    else if (filtered.isEmpty)
                      _noMatch(context)
                    else ...[
                      _resultCount(filtered.length, items.length),
                      const SizedBox(height: 8),
                      ...filtered.map((q) => _card(context, q)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Іздеу жолағы ──────────────────────────────────────────────────────────
  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Сұрақты немесе жауапты іздеу…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Тазалау',
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
          ),
        ),
      );

  // ── Пән сүзгісі чиптері ────────────────────────────────────────────────────
  Widget _filterChips(List<String> buckets, List<MockQuestion> items) {
    Widget chip(String? key) {
      final selected = _subjectFilter == key;
      final label = key == null ? 'Барлығы' : _bucketLabel(key);
      final count = key == null
          ? items.length
          : items.where((q) => _bucketOf(q) == key).length;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _subjectFilter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.navyBlue : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.navyBlue : AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        color:
                            selected ? AppColors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.gold.withValues(alpha: 0.25)
                        : AppColors.navyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          color: selected ? AppColors.white : AppColors.navyBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [chip(null), ...buckets.map(chip)],
      ),
    );
  }

  Widget _resultCount(int shown, int total) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          shown == total ? 'Барлығы: $shown сұрақ' : 'Табылды: $shown / $total',
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      );

  Widget _noMatch(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded,
                size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Сәйкес сұрақ табылмады',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text('Іздеу мәтінін немесе пән сүзгісін өзгертіп көріңіз',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Банк бос',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text('Excel/мәтін импорт немесе "Сұрақ қосу" арқылы толтырыңыз',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  // ── Толықтық картасы: ҰБТ генерациясына жеткілікті ме ───────────────────
  Widget _readinessCard(BuildContext context, List<MockQuestion> items) {
    // Шелек → сан. Бейіндік: subject + балл (1/2) бойынша бөлек.
    final c1 = <String, int>{}; // 1 баллдық
    final c2 = <String, int>{}; // 2 баллдық
    for (final q in items) {
      final key = q.section == MockSection.elective
          ? 'e:${q.subjectId}'
          : q.section;
      (q.points >= 2 ? c2 : c1)[key] = ((q.points >= 2 ? c2 : c1)[key] ?? 0) + 1;
    }

    final rows = <Widget>[];
    void line(String label, int have, int need) {
      final ok = have >= need;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 15, color: ok ? AppColors.success : AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12.5))),
          Text('$have / $need',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ok ? AppColors.success : AppColors.warning)),
        ]),
      ));
    }

    // Міндетті бөлімдер.
    for (final spec in UntStructure.mandatory) {
      line(MockSection.label(spec.section), c1[spec.section] ?? 0,
          spec.questionCount);
    }
    // Банкте бар бейіндік пәндер.
    final subjects = items
        .where((q) => q.section == MockSection.elective && q.subjectId != null)
        .map((q) => q.subjectId!)
        .toSet();
    for (final s in subjects) {
      line('${SubjectCatalog.titleOf(s)} · 1 балл', c1['e:$s'] ?? 0, 25);
      line('${SubjectCatalog.titleOf(s)} · 2 балл', c2['e:$s'] ?? 0, 15);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF002147), Color(0xFF003167)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.inventory_2_rounded,
                color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('Банк: ${items.length} сұрақ',
                style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          const Text('Генерацияға бір ҰБТ-ға қажетті ең аз сұрақ саны:',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: rows.isEmpty
                  ? [
                      const Text('Бейіндік пәндерге сұрақ қосыңыз',
                          style: TextStyle(color: Colors.white70, fontSize: 12))
                    ]
                  : rows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, MockQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_sectionTitle(q),
                  style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 10)),
            ),
            const SizedBox(width: 6),
            _miniBadge('${q.points} балл', AppColors.gold),
            if (q.isMultiple) ...[
              const SizedBox(width: 4),
              _miniBadge('көп жауап', AppColors.navyBlue),
            ],
            if (q.imageUrl != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.image_rounded,
                  size: 14, color: AppColors.textMuted),
            ],
            const Spacer(),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted),
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddEditMockQuestionScreen(bank: true, existing: q),
                    ),
                  );
                } else {
                  _confirmDelete(context, q);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: AppColors.navyBlue),
                    SizedBox(width: 10),
                    Text('Түзету'),
                  ]),
                ),
                PopupMenuItem(
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
          ]),
          if (q.question.isNotEmpty)
            Text(q.question, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...List.generate(q.options.length, (i) {
            final correct = q.correctIndices.contains(i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 15,
                    color: correct ? AppColors.success : AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(q.options[i],
                      style: TextStyle(
                          fontSize: 13,
                          color: correct
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight:
                              correct ? FontWeight.w700 : FontWeight.w400)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 10)),
      );

  Future<void> _confirmDelete(BuildContext context, MockQuestion q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Сұрақты өшіру'),
        content: Text(
            q.question.isEmpty ? 'Осы сұрақты өшіру?' : '"${q.question}" — өшіру?',
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
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
    if (ok == true) await _bank.deleteQuestion(q.id);
  }
}
