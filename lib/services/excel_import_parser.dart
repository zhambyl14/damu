// lib/services/excel_import_parser.dart
//
// Мок тест сұрақтарын Excel (.xlsx) файлдан ЖАППАЙ импорттау.
// Бірінші парақтың (sheet) бірінші жолы — баған атаулары (header).
//
// Танылатын бағандар (атауы қазақша/орысша/ағылшынша болуы мүмкін, регистр маңызды емес):
//   • Сұрақ        — question / q / сұрақ
//   • Нұсқалар     — бөлек A,B,C,D бағандары НЕМЕСЕ "нұсқалар" бағаны ("|" арқылы)
//   • Дұрыс жауап  — "B" / "2" / бірнешеу: "B,D" / "2,4"   (correct / answer / жауап / кілт)
//   • Балл         — 1 не 2 (міндетті емес; бірнеше дұрыс жауап → әдетте 2)   (points / балл)
//   • Сурет        — сурет URL мекенжайы (міндетті емес)   (image / photo / url / фото)
//   • Түсіндірме   — міндетті емес   (explanation / түсінік)
//
// Нәтиже мәтін импортымен бірдей ParsedQuestion тізімі болады.

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'bulk_import_parser.dart';

class ExcelImportParser {
  const ExcelImportParser._();

  // Баған тақырыбын танитын кілт сөздер.
  static const _questionKeys = ['сұрақ', 'сурак', 'question', 'вопрос'];
  static const _correctKeys = [
    'дұрыс', 'дурыс', 'жауап', 'correct', 'answer', 'кілт', 'кiлт', 'key', 'ответ'
  ];
  static const _pointsKeys = ['балл', 'балы', 'ұпай', 'упай', 'point', 'балла'];
  static const _imageKeys = ['сурет', 'image', 'photo', 'фото', 'url', 'сілтеме', 'силтеме', 'рисунок'];
  static const _explainKeys = ['түсінд', 'тусинд', 'explanation', 'түсінік', 'комментар', 'примечан'];
  static const _optionKeys = ['нұсқа', 'нуска', 'вариант', 'option', 'жауап нұсқа'];

  /// Жалғыз латын/кирилл әрпі: бөлек жауап бағаны (A / Ә / Б / В ...).
  static final _singleLetter = RegExp(r'^[a-zа-яёәіңғүұқөһ]$');

  static String _cellText(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    if (v is BoolCellValue) return v.value.toString();
    return v.toString().trim();
  }

  static bool _matches(String header, List<String> keys) {
    final h = header.toLowerCase();
    return keys.any((k) => h.contains(k));
  }

  /// "B,D" / "2,4" / "BD" сияқты жолды 0-ден басталатын индекстерге аударады.
  static List<int>? _parseCorrect(String raw, int optionCount) {
    final cleaned = raw.replaceAll(RegExp(r'[,\s;|]+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    // Бөлгіш болмаса (мыс. "BD") — әр символды бөлек оқимыз.
    final tokens = cleaned.contains(' ')
        ? cleaned.split(' ')
        : cleaned.split('');
    final indices = <int>{};
    for (final t in tokens) {
      if (t.isEmpty) continue;
      int? idx;
      final num = int.tryParse(t);
      if (num != null) {
        idx = num - 1; // 1-ден басталатын нөмір
      } else if (t.length == 1) {
        final code = t.toLowerCase().codeUnitAt(0);
        if (code >= 97 && code <= 122) idx = code - 97; // a→0, b→1 ...
      }
      if (idx == null || idx < 0 || idx >= optionCount) return null;
      indices.add(idx);
    }
    if (indices.isEmpty) return null;
    final list = indices.toList()..sort();
    return list;
  }

  /// Excel байттарынан сұрақтарды талдайды.
  static BulkParseResult<ParsedQuestion> parse(Uint8List bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      // excel дестесі кейбір .xlsx файлдарды оқи алмай "Unexpected null value"
      // тәрізді қате береді (Google Sheets экспорты, диаграмма/стиль бар файлдар).
      // Мұндайда CSV (.csv) ретінде сақтап импорттауды ұсынамыз.
      return BulkParseResult([], [
        'Excel файлды оқу мүмкін болмады ($e). Файлды Excel/Google Sheets ішінде '
            '«CSV (.csv)» пішімінде сақтап, қайта импорттап көріңіз.'
      ]);
    }
    if (excel.tables.isEmpty) {
      return const BulkParseResult([], ['Файлда парақ (sheet) табылмады']);
    }

    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      return const BulkParseResult([], ['Парақ бос']);
    }

    // Excel жасушаларын мәтін кестесіне айналдырып, ортақ талдаушыға береміз.
    final rows = sheet.rows
        .map((row) => row.map(_cellText).toList())
        .toList();
    return _parseRows(rows);
  }

  /// CSV мәтінінен сұрақтарды талдайды (.xlsx оқылмаған кездегі сенімді жол).
  /// Бөлгіш автоматты түрде анықталады: үтір, нүктелі үтір немесе таб.
  static BulkParseResult<ParsedQuestion> parseCsv(String text) {
    final rows = _parseCsvRows(text);
    if (rows.isEmpty) {
      return const BulkParseResult([], ['Файл бос']);
    }
    return _parseRows(rows);
  }

  /// CSV мәтінін жолдар × жасушалар кестесіне айналдырады (тырнақшаны ескереді).
  static List<List<String>> _parseCsvRows(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Бөлгішті бірінші жолдан анықтаймыз (тырнақшадан тыс есептейміз).
    final firstLine = normalized.split('\n').firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '');
    final delimiter = _detectDelimiter(firstLine);

    final rows = <List<String>>[];
    var field = StringBuffer();
    var record = <String>[];
    var inQuotes = false;
    for (var i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < normalized.length && normalized[i + 1] == '"') {
            field.write('"');
            i++; // екі тырнақша → бір тырнақша
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        record.add(field.toString().trim());
        field = StringBuffer();
      } else if (ch == '\n') {
        record.add(field.toString().trim());
        rows.add(record);
        record = <String>[];
        field = StringBuffer();
      } else {
        field.write(ch);
      }
    }
    // Соңғы жасуша/жол.
    if (field.isNotEmpty || record.isNotEmpty) {
      record.add(field.toString().trim());
      rows.add(record);
    }
    // Толық бос жолдарды алып тастаймыз.
    return rows.where((r) => r.any((c) => c.isNotEmpty)).toList();
  }

  static String _detectDelimiter(String line) {
    var inQuotes = false;
    var comma = 0, semicolon = 0, tab = 0;
    for (final ch in line.split('')) {
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == ',') comma++;
        if (ch == ';') semicolon++;
        if (ch == '\t') tab++;
      }
    }
    if (semicolon >= comma && semicolon >= tab) return ';';
    if (tab > comma) return '\t';
    return ',';
  }

  /// Мәтін кестесінен (жолдар × жасушалар) сұрақтарды талдайтын ортақ логика.
  /// Бірінші жол — баған атаулары (header).
  static BulkParseResult<ParsedQuestion> _parseRows(List<List<String>> rows) {
    final items = <ParsedQuestion>[];
    final errors = <String>[];

    if (rows.isEmpty) {
      return const BulkParseResult([], ['Парақ бос']);
    }

    // ── Баған картасы (header жолы) ──
    final header = rows.first;
    int? qCol, correctCol, pointsCol, imageCol, explainCol;
    final optionCols = <int>[]; // бөлек A/B/C/D бағандары
    int? combinedOptionCol; // "нұсқалар" бағаны ("|" арқылы)

    for (var c = 0; c < header.length; c++) {
      final h = header[c].trim();
      if (h.isEmpty) continue;
      final hl = h.toLowerCase();
      if (qCol == null && _matches(h, _questionKeys)) {
        qCol = c;
      } else if (correctCol == null && _matches(h, _correctKeys)) {
        correctCol = c;
      } else if (pointsCol == null && _matches(h, _pointsKeys)) {
        pointsCol = c;
      } else if (imageCol == null && _matches(h, _imageKeys)) {
        imageCol = c;
      } else if (explainCol == null && _matches(h, _explainKeys)) {
        explainCol = c;
      } else if (_singleLetter.hasMatch(hl)) {
        optionCols.add(c); // бөлек жауап бағаны
      } else if (combinedOptionCol == null &&
          (hl.contains('нұсқалар') || hl.contains('options') ||
              _matches(h, _optionKeys))) {
        combinedOptionCol = c;
      }
    }

    if (qCol == null && imageCol == null) {
      return const BulkParseResult([], [
        'Баған атаулары танылмады. Бірінші жолда «Сұрақ», «A/B/C/D» (немесе '
            '«Нұсқалар»), «Дұрыс жауап» бағандары болуы керек.'
      ]);
    }
    if (optionCols.isEmpty && combinedOptionCol == null) {
      return const BulkParseResult([], [
        'Жауап нұсқалары бағаны табылмады («A,B,C,D» немесе «Нұсқалар»).'
      ]);
    }

    // ── Деректер жолдары ──
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final n = r + 1; // Excel жол нөмірі (адамға түсінікті)
      String cell(int? col) =>
          (col != null && col < row.length) ? row[col].trim() : '';

      final q = cell(qCol);
      final img = cell(imageCol);

      // Толық бос жолды үнсіз өткіземіз.
      final hasAny = q.isNotEmpty ||
          img.isNotEmpty ||
          optionCols.any((c) => cell(c).isNotEmpty) ||
          (combinedOptionCol != null && cell(combinedOptionCol).isNotEmpty);
      if (!hasAny) continue;

      if (q.isEmpty && img.isEmpty) {
        errors.add('№$n жол: «Сұрақ» де, «Сурет» де жоқ — өткізілді');
        continue;
      }

      final options = <String>[];
      if (optionCols.isNotEmpty) {
        for (final c in optionCols) {
          final v = cell(c);
          if (v.isNotEmpty) options.add(v);
        }
      } else {
        options.addAll(cell(combinedOptionCol)
            .split('|')
            .map((o) => o.trim())
            .where((o) => o.isNotEmpty));
      }
      if (options.length < 2) {
        errors.add('№$n жол: кемінде 2 жауап нұсқасы керек — өткізілді');
        continue;
      }

      final indices = _parseCorrect(cell(correctCol), options.length);
      if (indices == null) {
        errors.add(
            '№$n жол: «Дұрыс жауап» қате (мыс. "B" не "2", бірнешеу: "B,D") — өткізілді');
        continue;
      }

      final pRaw = cell(pointsCol);
      final points = int.tryParse(pRaw) ?? (indices.length > 1 ? 2 : 1);
      final e = cell(explainCol);

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
}
