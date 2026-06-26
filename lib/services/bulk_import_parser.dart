// lib/services/bulk_import_parser.dart
//
// PDF/мәтіннен тест сұрақтары мен флешкарталарды ЖАППАЙ импорттауға арналған
// мәтін талдаушы. Әр сұрақты қолмен теру орнына — ИИ-ге (Claude/Gemini/ChatGPT)
// PDF-ті осы форматқа айналдыртып, нәтижесін осында қойсаң жеткілікті.
//
// Формат: блоктар жеке жолдағы "---" арқылы бөлінеді.
//
//   Сұрақ:
//     Q: Сұрақ мәтіні
//     A: 1-нұсқа | 2-нұсқа | 3-нұсқа | 4-нұсқа
//     C: 2                ← дұрыс жауап(тар) нөмірі (1-ден). Бірнешеу: "2,4"
//     P: 2                ← балл (міндетті емес; әдетте бір дұрыс=1, бірнешеу=2)
//     IMG: https://...    ← сурет URL (міндетті емес)
//     E: Түсіндірме        ← міндетті емес
//     ---
//
//   Флешкарта:
//     F: Беткі жағы (сұрақ/термин)
//     B: Артқы жағы (жауап/түсінік)
//     H: Көмек              ← міндетті емес
//     ---
//
// Тегсіз (жалғасу) жолдар алдыңғы тегке қосылады — PDF-тен көшірілген, бірнеше
// жолға бөлініп кеткен мәтін де дұрыс жиналады.

/// Талданған тест сұрағы.
class ParsedQuestion {
  final String question;
  final List<String> options;

  /// Дұрыс жауап индекстері (0-ден). Бір немесе бірнешеу.
  final List<int> correctIndices;
  final int points;
  final String? imageUrl;
  final String? explanation;

  const ParsedQuestion({
    required this.question,
    required this.options,
    required this.correctIndices,
    this.points = 1,
    this.imageUrl,
    this.explanation,
  });

  int get correctIndex => correctIndices.isEmpty ? 0 : correctIndices.first;
  bool get isMultiple => correctIndices.length > 1;
}

/// Талданған флешкарта.
class ParsedFlashcard {
  final String front;
  final String back;
  final String? hint;

  const ParsedFlashcard({
    required this.front,
    required this.back,
    this.hint,
  });
}

/// Талдау нәтижесі: сәтті элементтер + адамға түсінікті қателер тізімі.
class BulkParseResult<T> {
  final List<T> items;
  final List<String> errors;

  const BulkParseResult(this.items, this.errors);

  bool get hasItems => items.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

class BulkImportParser {
  const BulkImportParser._();

  // Белгілі тегтер ғана жол басын «тег» деп таниды — қалғаны жалғасу мәтіні.
  static const _knownTags = {'Q', 'A', 'C', 'P', 'IMG', 'E', 'F', 'B', 'H'};
  static final RegExp _tag = RegExp(r'^([A-Za-z]+)\s*:\s?(.*)$');

  /// Мәтінді блоктарға бөледі ("---" жеке жолда болғанда).
  static List<String> _blocks(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = <String>[];
    final buf = StringBuffer();
    for (final line in normalized.split('\n')) {
      if (line.trim() == '---') {
        blocks.add(buf.toString());
        buf.clear();
      } else {
        buf.writeln(line);
      }
    }
    if (buf.toString().trim().isNotEmpty) blocks.add(buf.toString());
    return blocks.where((b) => b.trim().isNotEmpty).toList();
  }

  /// Бір блоктағы тегтерді оқиды. Тегсіз жолдар соңғы тегке жалғанады.
  static Map<String, String> _fields(String block) {
    final fields = <String, String>{};
    String? current;
    for (final rawLine in block.split('\n')) {
      if (rawLine.trim().isEmpty) continue;
      final m = _tag.firstMatch(rawLine.trimLeft());
      final tag = m?.group(1)!.toUpperCase();
      if (m != null && _knownTags.contains(tag)) {
        current = tag;
        fields[current!] = m.group(2)!.trim();
      } else if (current != null) {
        fields[current] = ('${fields[current]} ${rawLine.trim()}').trim();
      }
    }
    return fields;
  }

  /// Тест сұрақтарын талдау.
  static BulkParseResult<ParsedQuestion> parseQuestions(String raw) {
    final items = <ParsedQuestion>[];
    final errors = <String>[];
    final blocks = _blocks(raw);

    for (var i = 0; i < blocks.length; i++) {
      final n = i + 1;
      final f = _fields(blocks[i]);
      final q = (f['Q'] ?? '').trim();
      final aRaw = (f['A'] ?? '').trim();
      final cRaw = (f['C'] ?? '').trim();
      final pRaw = (f['P'] ?? '').trim();
      final img = (f['IMG'] ?? '').trim();
      final e = (f['E'] ?? '').trim();

      // Суреті бар, бірақ мәтінсіз сұраққа да жол беру (тек сурет көрсетіледі).
      if (q.isEmpty && img.isEmpty) {
        errors.add('№$n блок: «Q:» (сұрақ) немесе «IMG:» (сурет) жоқ — өткізілді');
        continue;
      }
      final options =
          aRaw.split('|').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
      if (options.length < 2) {
        errors.add('№$n блок: «A:» кемінде 2 нұсқа керек ("|" арқылы) — өткізілді');
        continue;
      }
      // C: бір ("2") немесе бірнеше ("2,4") дұрыс жауап нөмірі.
      final nums = cRaw
          .split(RegExp(r'[,\s]+'))
          .map((s) => int.tryParse(s.trim()))
          .toList();
      if (nums.isEmpty || nums.any((x) => x == null || x < 1 || x > options.length)) {
        errors.add(
            '№$n блок: «C:» дұрыс жауап нөмірі қате (1–${options.length}, бірнешеу: "2,4") — өткізілді');
        continue;
      }
      final indices = nums.map((x) => x! - 1).toSet().toList()..sort();

      // Балл: P: берілсе сол; әйтпесе бірнеше дұрыс жауап = 2, біреу = 1.
      final points = int.tryParse(pRaw) ?? (indices.length > 1 ? 2 : 1);

      items.add(ParsedQuestion(
        question: q,
        options: options,
        correctIndices: indices,
        points: points,
        imageUrl: img.isEmpty ? null : img,
        explanation: e.isEmpty ? null : e,
      ));
    }

    return BulkParseResult(items, errors);
  }

  /// Флешкарталарды талдау.
  static BulkParseResult<ParsedFlashcard> parseFlashcards(String raw) {
    final items = <ParsedFlashcard>[];
    final errors = <String>[];
    final blocks = _blocks(raw);

    for (var i = 0; i < blocks.length; i++) {
      final n = i + 1;
      final f = _fields(blocks[i]);
      final front = (f['F'] ?? '').trim();
      final back = (f['B'] ?? '').trim();
      final hint = (f['H'] ?? '').trim();

      if (front.isEmpty || back.isEmpty) {
        errors.add('№$n блок: «F:» (беті) және «B:» (арты) толтырылуы керек — өткізілді');
        continue;
      }

      items.add(ParsedFlashcard(
        front: front,
        back: back,
        hint: hint.isEmpty ? null : hint,
      ));
    }

    return BulkParseResult(items, errors);
  }
}
