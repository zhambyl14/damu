// lib/screens/admin/bulk_import_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme.dart';
import '../../data/subjects_catalog.dart';
import '../../models/mock_test_model.dart';
import '../../models/question_model.dart';
import '../../models/flashcard_model.dart';
import '../../services/mock_test_service.dart';
import '../../services/question_bank_service.dart';
import '../../services/content_service.dart';
import '../../services/bulk_import_parser.dart';
import '../../services/excel_import_parser.dart';

/// Импорт нысаны: сұрақтар банкі / мок тест сұрағы / тақырыптық сұрақ / флешкарта.
enum BulkImportKind { bank, mock, topicQuestions, topicFlashcards }

/// PDF/мәтіннен сұрақ пен флешкартаны ЖАППАЙ импорттау экраны.
///
/// Әр сұрақты қолмен теру орнына — мәтінді арнайы форматта (Q:/A:/C:/E: немесе
/// F:/B:/H:) қойып, бір рет жазады. ИИ-ге PDF-ті осы форматқа айналдыртуға болады.
class BulkImportScreen extends StatefulWidget {
  final BulkImportKind kind;
  final String? mockId;
  final String? subjectId;
  final String? topicId;
  final String? topicTitle;

  const BulkImportScreen.bank({super.key})
      : kind = BulkImportKind.bank,
        mockId = null,
        subjectId = null,
        topicId = null,
        topicTitle = null;

  const BulkImportScreen.mock({super.key, required this.mockId})
      : kind = BulkImportKind.mock,
        subjectId = null,
        topicId = null,
        topicTitle = null;

  const BulkImportScreen.topicQuestions({
    super.key,
    required this.subjectId,
    required this.topicId,
    this.topicTitle,
  })  : kind = BulkImportKind.topicQuestions,
        mockId = null;

  const BulkImportScreen.topicFlashcards({
    super.key,
    required this.subjectId,
    required this.topicId,
    this.topicTitle,
  })  : kind = BulkImportKind.topicFlashcards,
        mockId = null;

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final _ctrl = TextEditingController();
  final _mockService = MockTestService();
  final _bankService = QuestionBankService();
  final _content = ContentService();

  // Мок үшін бөлім таңдау
  String _section = MockSection.kazakhHistory;
  String? _electiveSubjectId;

  // Талдау нәтижесі
  List<ParsedQuestion>? _questions;
  List<ParsedFlashcard>? _flashcards;
  List<String> _errors = const [];

  bool _busy = false;

  bool get _isFlashcards => widget.kind == BulkImportKind.topicFlashcards;
  // Бөлім таңдау керек пе (мок та, банк та бөлім бойынша жазады).
  bool get _isMock =>
      widget.kind == BulkImportKind.mock || widget.kind == BulkImportKind.bank;

  int get _parsedCount =>
      _isFlashcards ? (_flashcards?.length ?? 0) : (_questions?.length ?? 0);

  bool get _hasParsed => _questions != null || _flashcards != null;

  @override
  void initState() {
    super.initState();
    _electiveSubjectId = SubjectCatalog.electives.first.id;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.kind) {
      case BulkImportKind.bank:
        return 'Сұрақтар банкіне импорт';
      case BulkImportKind.mock:
        return 'Мок тестке импорт';
      case BulkImportKind.topicQuestions:
        return 'Сұрақтарды импорт';
      case BulkImportKind.topicFlashcards:
        return 'Флешкарталарды импорт';
    }
  }

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ));

  void _parse() {
    FocusScope.of(context).unfocus();
    final raw = _ctrl.text;
    if (raw.trim().isEmpty) {
      _snack('Алдымен мәтінді қойыңыз');
      return;
    }
    if (_isFlashcards) {
      final res = BulkImportParser.parseFlashcards(raw);
      setState(() {
        _flashcards = res.items;
        _questions = null;
        _errors = res.errors;
      });
    } else {
      final res = BulkImportParser.parseQuestions(raw);
      setState(() {
        _questions = res.items;
        _flashcards = null;
        _errors = res.errors;
      });
    }
  }

  Future<void> _pickExcel() async {
    FocusScope.of(context).unfocus();
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _snack('Файлды оқу мүмкін болмады', color: AppColors.error);
        return;
      }
      // .csv болса — мәтін ретінде, әйтпесе .xlsx ретінде оқимыз.
      final isCsv = (file.extension ?? '').toLowerCase() == 'csv';
      final parsed = isCsv
          ? ExcelImportParser.parseCsv(utf8.decode(bytes, allowMalformed: true))
          : ExcelImportParser.parse(bytes);
      setState(() {
        _questions = parsed.items;
        _flashcards = null;
        _errors = parsed.errors;
      });
      if (parsed.items.isEmpty && parsed.errors.isNotEmpty) {
        _snack(parsed.errors.first, color: AppColors.error);
      }
    } catch (e) {
      if (mounted) _snack('Excel қатесі: $e', color: AppColors.error);
    }
  }

  Future<void> _import() async {
    if (_parsedCount == 0) return;
    setState(() => _busy = true);
    try {
      int n = 0;
      switch (widget.kind) {
        case BulkImportKind.bank:
          final isElective = _section == MockSection.elective;
          final models = _questions!
              .map((q) => MockQuestion(
                    id: '',
                    mockId: '',
                    section: _section,
                    subjectId: isElective ? _electiveSubjectId : null,
                    question: q.question,
                    options: q.options,
                    correctIndices: q.correctIndices,
                    points: q.points,
                    imageUrl: q.imageUrl,
                    explanation: q.explanation,
                  ))
              .toList();
          n = await _bankService.bulkAddQuestions(models);
          break;
        case BulkImportKind.mock:
          final isElective = _section == MockSection.elective;
          final models = _questions!
              .map((q) => MockQuestion(
                    id: '',
                    mockId: widget.mockId!,
                    section: _section,
                    subjectId: isElective ? _electiveSubjectId : null,
                    question: q.question,
                    options: q.options,
                    correctIndices: q.correctIndices,
                    points: q.points,
                    imageUrl: q.imageUrl,
                    explanation: q.explanation,
                  ))
              .toList();
          n = await _mockService.bulkAddQuestions(models, mockId: widget.mockId!);
          break;
        case BulkImportKind.topicQuestions:
          final models = _questions!
              .map((q) => QuestionModel(
                    id: '',
                    subjectId: widget.subjectId!,
                    topicId: widget.topicId!,
                    question: q.question,
                    options: q.options,
                    correctIndex: q.correctIndex,
                    explanation: q.explanation,
                  ))
              .toList();
          n = await _content.bulkAddQuestions(models, topicId: widget.topicId!);
          break;
        case BulkImportKind.topicFlashcards:
          final models = _flashcards!
              .map((f) => FlashcardModel(
                    id: '',
                    subjectId: widget.subjectId!,
                    topicId: widget.topicId!,
                    front: f.front,
                    back: f.back,
                    hint: f.hint,
                  ))
              .toList();
          n = await _content.bulkAddFlashcards(models, topicId: widget.topicId!);
          break;
      }
      if (!mounted) return;
      _snack('$n элемент сәтті импортталды', color: AppColors.success);
      Navigator.pop(context, n);
    } catch (e) {
      if (mounted) _snack('Қате: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.navyBlue,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _formatCard(),
          if (_isMock) ...[
            const SizedBox(height: 16),
            _sectionPicker(),
          ],
          if (!_isFlashcards) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickExcel,
              icon: const Icon(Icons.table_view_rounded),
              label: const Text('Excel/CSV файлдан импорт (.xlsx, .csv)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Бағандар: Сұрақ · A · B · C · D · Дұрыс жауап · Балл · Сурет (URL) · Түсіндірме. '
              'Бірнеше дұрыс жауап: "B,D". Дұрыс жауап саны 2 болса — әдетте 2 балл. '
              '.xlsx оқылмаса, файлды CSV пішімінде сақтап импорттаңыз.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Row(children: [
              Expanded(child: Divider(color: AppColors.divider)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('немесе мәтін',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ),
              Expanded(child: Divider(color: AppColors.divider)),
            ]),
          ],
          const SizedBox(height: 16),
          _pasteField(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _parse,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Мәтінді талдау (тексеру)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navyBlue,
              side: const BorderSide(color: AppColors.navyBlue),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_hasParsed) ...[
            const SizedBox(height: 16),
            _resultSummary(),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              _errorsCard(),
            ],
            if (_parsedCount > 0) ...[
              const SizedBox(height: 12),
              _preview(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2.4))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text('$_parsedCount элементті импорттау'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Формат көмегі ────────────────────────────────────────
  Widget _formatCard() {
    final example = _isFlashcards
        ? 'F: Қазақ хандығы қашан құрылды?\n'
            'B: 1465 жылы, Керей мен Жәнібек.\n'
            'H: XV ғасыр\n'
            '---\n'
            'F: "Жеті жарғы" кім тұсында?\n'
            'B: Тәуке хан тұсында.'
        : 'Q: Қазақ хандығы қай жылы құрылды?\n'
            'A: 1456 | 1465 | 1480 | 1500\n'
            'C: 2\n'
            'E: Керей мен Жәнібек 1465 жылы құрды.\n'
            '---\n'
            'Q: Дұрыс сәйкестікті таңда (бірнеше жауап)\n'
            'A: Абай | Мұхтар | Шоқан | Ыбырай\n'
            'C: 1,3\n'
            'P: 2\n'
            'IMG: https://example.com/surak.png';

    final legend = _isFlashcards
        ? 'F: беті · B: арты · H: көмек (міндетті емес). Блоктар "---" арқылы бөлінеді.'
        : 'Q: сұрақ · A: нұсқалар ("|") · C: дұрыс жауап нөмірі ("2" не бірнешеу "1,3") · '
            'P: балл (міндетті емес) · IMG: сурет URL (міндетті емес) · '
            'E: түсіндірме. Блоктар "---" арқылы бөлінеді.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF002147), Color(0xFF003167)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PDF-ті ИИ-ге (Claude/Gemini) осы форматқа айналдыртып, мәтінді төменге қойыңыз.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.white, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(legend,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              example,
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 12,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: example));
                _snack('Үлгі көшірілді');
              },
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.gold),
              label: const Text('Үлгіні көшіру',
                  style: TextStyle(color: AppColors.gold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Бөлім таңдау (мок) ───────────────────────────────────
  Widget _sectionPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Бөлім',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.navyBlue, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Барлық қойылған сұрақтар осы бөлімге жазылады',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...MockSection.mandatory.map(_sectionChip),
            _sectionChip(MockSection.elective),
          ],
        ),
        if (_section == MockSection.elective) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _electiveSubjectId,
                items: SubjectCatalog.electives
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child:
                              Text(s.title, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _electiveSubjectId = v),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionChip(String s) {
    final selected = _section == s;
    return ChoiceChip(
      label: Text(MockSection.label(s)),
      selected: selected,
      onSelected: (_) => setState(() => _section = s),
      selectedColor: AppColors.navyBlue,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
    );
  }

  // ── Мәтін енгізу ─────────────────────────────────────────
  Widget _pasteField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _ctrl,
        maxLines: 12,
        minLines: 8,
        style: const TextStyle(fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          hintText: _isFlashcards
              ? 'Мұнда F:/B:/H: форматындағы мәтінді қойыңыз…'
              : 'Мұнда Q:/A:/C:/E: форматындағы мәтінді қойыңыз…',
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ── Талдау қорытындысы ───────────────────────────────────
  Widget _resultSummary() {
    final ok = _parsedCount;
    final bad = _errors.length;
    final color = ok > 0 ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ok > 0 ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bad > 0
                  ? '$ok дайын · $bad өткізілді'
                  : '$ok элемент талданды',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text('Өткізілген блоктар',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ..._errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              )),
        ],
      ),
    );
  }

  // ── Алдын ала көрініс ────────────────────────────────────
  Widget _preview() {
    final children = <Widget>[];
    if (_isFlashcards) {
      for (var i = 0; i < _flashcards!.length; i++) {
        final f = _flashcards![i];
        children.add(_previewCard(
          i + 1,
          f.front,
          [f.back, if (f.hint != null) '💡 ${f.hint}'],
          null,
        ));
      }
    } else {
      for (var i = 0; i < _questions!.length; i++) {
        children.add(_questionPreviewCard(i + 1, _questions![i]));
      }
    }
    return Column(children: children);
  }

  Widget _questionPreviewCard(int n, ParsedQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('№$n',
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(q.question.isEmpty ? '(сурет сұрағы)' : q.question,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              _badge('${q.points} балл', AppColors.gold),
              if (q.isMultiple) ...[
                const SizedBox(width: 4),
                _badge('көп жауап', AppColors.navyBlue),
              ],
            ],
          ),
          if (q.imageUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                q.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 48,
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    const Icon(Icons.broken_image_outlined,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(q.imageUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ),
                  ]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          ...List.generate(q.options.length, (i) {
            final isCorrect = q.correctIndices.contains(i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4),
              child: Text(
                '${String.fromCharCode(65 + i)}. ${q.options[i]}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isCorrect ? AppColors.success : AppColors.textSecondary,
                  fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 10)),
      );

  Widget _previewCard(int n, String title, List<String> lines, int? correct) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('№$n',
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(lines.length, (i) {
            final isCorrect = correct != null && i == correct;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4),
              child: Text(
                correct != null
                    ? '${String.fromCharCode(65 + i)}. ${lines[i]}'
                    : lines[i],
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isCorrect ? AppColors.success : AppColors.textSecondary,
                  fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
