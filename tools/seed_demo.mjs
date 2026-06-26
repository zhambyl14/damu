// tools/seed_demo.mjs
//
// Damu High School — базаны ТОЛЫҚ тазалап, демо деректермен қайта толтырады.
//   • 1 директор, 3 куратор, әр кураторға 10 оқушы (барлығы 30).
//   • Әр оқушыға: мемлекеттік (қаңтар/наурыз) + нағыз ҰБТ 1/2 нәтижелері,
//     әрі қыркүйектен бергі әр айдың мок балы.
//   • Әр пәнге ≥4 тақырып, әр тақырыпқа 2 тақырыптық тест сұрағы + 2 флешкарта.
//   • Сұрақтар банкі (толық ҰБТ генерациясы жұмыс істеуі үшін).
//   • Әр куратор өз сыныбына 1 белсенді айлық мок + оқушыларға хабарландыру.
//
// Іске қосу:
//   1) tools/.env.example → tools/.env (SUPABASE_SERVICE_ROLE_KEY толтыру)
//   2) cd tools && npm install && node seed_demo.mjs
//
// ⚠️ Бұл скрипт бар деректі ӨШІРЕДІ (admin аккаунттан басқа). Сақ болыңыз.

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// ── .env жүктеу (қосымша тәуелділіксіз) ───────────────────────────────────────
const __dirname = dirname(fileURLToPath(import.meta.url));
function loadEnv() {
  try {
    const raw = readFileSync(join(__dirname, '.env'), 'utf8');
    for (const line of raw.split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].trim();
    }
  } catch { /* .env жоқ — process.env қолданылады */ }
}
loadEnv();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const PASSWORD = process.env.SEED_PASSWORD || 'Damu2025!';

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ SUPABASE_URL немесе SUPABASE_SERVICE_ROLE_KEY жоқ (tools/.env).');
  process.exit(1);
}

const db = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// ── Каталог (lib/data/subjects_catalog.dart көшірмесі) ────────────────────────
const MANDATORY = [
  { id: 'history_kz', title: 'Қазақстан тарихы' },
  { id: 'reading_literacy', title: 'Оқу сауаттылығы' },
  { id: 'math_literacy', title: 'Математикалық сауаттылық' },
];
const ELECTIVES = [
  { id: 'mathematics', title: 'Математика' },
  { id: 'physics', title: 'Физика' },
  { id: 'informatics', title: 'Информатика' },
  { id: 'biology', title: 'Биология' },
  { id: 'chemistry', title: 'Химия' },
  { id: 'geography', title: 'География' },
  { id: 'world_history', title: 'Дүниежүзі тарихы' },
  { id: 'english', title: 'Ағылшын тілі' },
  { id: 'foreign', title: 'Шет тілі' },
  { id: 'kazakh_language', title: 'Қазақ тілі' },
  { id: 'kazakh_literature', title: 'Қазақ әдебиеті' },
  { id: 'russian_language', title: 'Орыс тілі' },
  { id: 'russian_literature', title: 'Орыс әдебиеті' },
];
const ALL_SUBJECTS = [...MANDATORY, ...ELECTIVES];

// Профиль кілті → 2 бейіндік пән (lib/models/user_model.dart electiveSubjects).
const PROFILE_SUBJECTS = {
  math_physics: [['mathematics', 'Математика'], ['physics', 'Физика']],
  math_informatics: [['mathematics', 'Математика'], ['informatics', 'Информатика']],
  bio_chemistry: [['biology', 'Биология'], ['chemistry', 'Химия']],
  bio_geography: [['biology', 'Биология'], ['geography', 'География']],
  math_geography: [['mathematics', 'Математика'], ['geography', 'География']],
  geography_foreign: [['geography', 'География'], ['foreign', 'Шет тілі']],
  history_english: [['world_history', 'Дүниежүзі тарихы'], ['english', 'Ағылшын тілі']],
  kazakh_lit: [['kazakh_language', 'Қазақ тілі'], ['kazakh_literature', 'Қазақ әдебиеті']],
  russian_lit: [['russian_language', 'Орыс тілі'], ['russian_literature', 'Орыс әдебиеті']],
};
const PROFILE_KEYS = Object.keys(PROFILE_SUBJECTS);

// ── ҰБТ балл максимумдары ──────────────────────────────────────────────────────
const MAX = { history: 20, reading: 10, math: 10, elective: 50 };

// ── Көмекшілер ────────────────────────────────────────────────────────────────
const rnd = (a, b) => a + Math.random() * (b - a);
const clampInt = (v, max) => Math.max(0, Math.min(max, Math.round(v)));
const iso = (y, m, d = 15) => new Date(Date.UTC(y, m - 1, d, 9, 0, 0)).toISOString();

async function deleteAll(table, keyCol = 'id') {
  // PostgREST өшіруге сүзгі талап етеді — ешқашан тең болмайтын мәнмен «бәрін» өшіреміз.
  const { error } = await db
    .from(table)
    .delete()
    .neq(keyCol, '00000000-0000-0000-0000-000000000000');
  if (error) throw new Error(`delete ${table}: ${error.message}`);
}

async function createUser(email, name, role, extra = {}) {
  const { data, error } = await db.auth.admin.createUser({
    email,
    password: PASSWORD,
    email_confirm: true,
    user_metadata: { name },
  });
  if (error) throw new Error(`createUser ${email}: ${error.message}`);
  const id = data.user.id;
  const profile = { id, email, name, role, ...extra };
  const { error: upErr } = await db.from('users').upsert(profile, { onConflict: 'id' });
  if (upErr) throw new Error(`profile ${email}: ${upErr.message}`);
  return id;
}

// ── 1) ТАЗАЛАУ ─────────────────────────────────────────────────────────────────
async function clean() {
  console.log('🧹 Тазалау...');
  await deleteAll('student_seen_questions', 'student_id');
  await deleteAll('quizattempts');
  await deleteAll('video_progress');
  await deleteAll('scores');
  await deleteAll('mock_questions');
  await deleteAll('mocktests');
  await deleteAll('notifications');
  await deleteAll('streaks', 'user_id');
  await deleteAll('flashcards');
  await deleteAll('questions');
  await deleteAll('topics');
  await deleteAll('question_bank');

  // admin емес барлық auth қолданушыны өшіру (профильдер FK-cascade-пен өшеді).
  const { data: profs, error: pErr } = await db.from('users').select('id, role');
  if (pErr) throw new Error(`profiles: ${pErr.message}`);
  const adminIds = new Set((profs ?? []).filter((p) => p.role === 'admin').map((p) => p.id));

  let page = 1;
  for (;;) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw new Error(`listUsers: ${error.message}`);
    const users = data.users ?? [];
    if (users.length === 0) break;
    for (const u of users) {
      if (!adminIds.has(u.id)) {
        await db.auth.admin.deleteUser(u.id);
      }
    }
    if (users.length < 200) break;
    page += 1;
  }
  console.log(`   admin сақталды (${adminIds.size}), қалғаны өшірілді.`);
}

// ── 2) ҚОЛДАНУШЫЛАР ─────────────────────────────────────────────────────────────
const KZ_FIRST = ['Айдос', 'Аружан', 'Бекзат', 'Дана', 'Ерлан', 'Жанель', 'Қанат',
  'Мадина', 'Нұрлан', 'Сая', 'Темірлан', 'Ұлжан', 'Әсел', 'Бауыржан', 'Гүлнар',
  'Дамир', 'Еркежан', 'Жасұлан', 'Камила', 'Мирас'];
const KZ_LAST = ['Серіков', 'Қасымова', 'Нұрланұлы', 'Әбенова', 'Жұмабек',
  'Тоқтарова', 'Сейтқали', 'Оразбаева', 'Дәулетов', 'Исақызы'];

let nameCounter = 0;
function nextName() {
  const f = KZ_FIRST[nameCounter % KZ_FIRST.length];
  const l = KZ_LAST[Math.floor(nameCounter / KZ_FIRST.length) % KZ_LAST.length];
  nameCounter += 1;
  return `${f} ${l}`;
}

async function seedUsers() {
  console.log('👤 Қолданушылар...');
  await createUser('director@damu.kz', 'Директор Демеуов', 'director');

  const classes = [
    { name: '11А', id: 'class_11a' },
    { name: '11Ә', id: 'class_11e' },
    { name: '11Б', id: 'class_11b' },
  ];

  const students = []; // {id, name, className, curatorId, profileKey}
  for (let c = 0; c < classes.length; c++) {
    const cls = classes[c];
    const curatorId = await createUser(
      `curator${c + 1}@damu.kz`,
      `Куратор ${cls.name}`,
      'curator',
      { class_name: cls.name, class_id: cls.id, grade: 11 },
    );

    for (let j = 0; j < 10; j++) {
      const idx = c * 10 + j;
      const profileKey = PROFILE_KEYS[idx % PROFILE_KEYS.length];
      const studentType = j >= 8 ? 'offline' : 'online'; // әр сыныпта 2 оффлайн (демо)
      const name = nextName();
      const num = String(idx + 1).padStart(2, '0');
      const sid = await createUser(
        `s${num}@damu.kz`,
        name,
        'student',
        {
          curator_id: curatorId,
          class_name: cls.name,
          class_id: cls.id,
          grade: 11,
          elective_pair: profileKey,
          student_type: studentType,
        },
      );
      students.push({ id: sid, name, className: cls.name, curatorId, profileKey });
    }
    console.log(`   ${cls.name}: куратор + 10 оқушы.`);
  }
  return { students, classes };
}

// ── 3) БАЛЛДАР ───────────────────────────────────────────────────────────────────
function genScore(student, abilityPct, date, testType, testName) {
  const subs = PROFILE_SUBJECTS[student.profileKey];
  const f = abilityPct; // 0..1
  const n = () => rnd(-0.08, 0.08);
  const kh = clampInt(MAX.history * (f + n()), MAX.history);
  const rl = clampInt(MAX.reading * (f + n()), MAX.reading);
  const ml = clampInt(MAX.math * (f + n()), MAX.math);
  const e1 = clampInt(MAX.elective * (f + n()), MAX.elective);
  const e2 = clampInt(MAX.elective * (f + n()), MAX.elective);
  return {
    student_id: student.id,
    student_name: student.name,
    class_name: student.className,
    curator_id: student.curatorId,
    date,
    test_type: testType,
    test_name: testName,
    kazakh_history: kh,
    reading_literacy: rl,
    math_literacy: ml,
    elective1: e1,
    elective2: e2,
    elective1_name: subs[0][1],
    elective2_name: subs[1][1],
    total_score: kh + rl + ml + e1 + e2,
    mandatory_score: kh + rl + ml,
    elective_score: e1 + e2,
  };
}

async function seedScores(students) {
  console.log('📊 Баллдар...');
  const rows = [];
  // Қыркүйек 2025 → Маусым 2026 (айлық мок).
  const monthly = [
    [2025, 9], [2025, 10], [2025, 11], [2025, 12],
    [2026, 1], [2026, 2], [2026, 3], [2026, 4], [2026, 5], [2026, 6],
  ];
  const monthNames = ['', 'Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым',
    'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'];

  for (const s of students) {
    const base = rnd(0.45, 0.72); // бастапқы деңгей
    // Айлық моктар — біртіндеп өсу.
    monthly.forEach(([y, m], i) => {
      const ability = Math.min(0.95, base + i * 0.025 + rnd(-0.03, 0.03));
      rows.push(genScore(s, ability, iso(y, m), 'mock',
        `${monthNames[m]} айлық мок`));
    });
    // Мемлекеттік + нағыз ҰБТ (state_exam).
    const top = Math.min(0.97, base + 0.18);
    rows.push(genScore(s, base + 0.05, iso(2026, 1, 20), 'state_exam', 'Мемлекеттік қаңтар'));
    rows.push(genScore(s, base + 0.10, iso(2026, 3, 18), 'state_exam', 'Наурыз сынағы'));
    rows.push(genScore(s, base + 0.14, iso(2026, 5, 25), 'state_exam', 'Нағыз ҰБТ 1'));
    rows.push(genScore(s, top, iso(2026, 6, 10), 'state_exam', 'Нағыз ҰБТ 2'));
  }

  // Топтап жазу (1000-нан асса бөлектеп).
  for (let i = 0; i < rows.length; i += 500) {
    const chunk = rows.slice(i, i + 500);
    const { error } = await db.from('scores').insert(chunk);
    if (error) throw new Error(`scores: ${error.message}`);
  }
  console.log(`   ${rows.length} балл жазбасы.`);
}

// ── 4) КОНТЕНТ (тақырып + сұрақ + флешкарта) ─────────────────────────────────────
const SAMPLE_VIDEO = 'https://youtu.be/jNQXAC9IVRw'; // ашық демо видео

async function seedContent() {
  console.log('📚 Контент (тақырыптар/тесттер/флешкарталар)...');
  let topicCount = 0, qCount = 0, fCount = 0;

  for (const subj of ALL_SUBJECTS) {
    // 4 тақырып.
    const topicRows = [];
    for (let t = 0; t < 4; t++) {
      topicRows.push({
        subject_id: subj.id,
        title: `${subj.title}: ${t + 1}-тақырып`,
        order: t,
        question_count: 2,
        flashcard_count: 2,
        video_url: t === 0 ? SAMPLE_VIDEO : null, // 1-тақырыпта видео
      });
    }
    const { data: topics, error: tErr } = await db
      .from('topics').insert(topicRows).select();
    if (tErr) throw new Error(`topics ${subj.id}: ${tErr.message}`);
    topicCount += topics.length;

    const questions = [];
    const flashcards = [];
    for (const tp of topics) {
      for (let q = 0; q < 2; q++) {
        const correct = q % 4;
        questions.push({
          subject_id: subj.id,
          topic_id: tp.id,
          question: `${subj.title} — ${tp.title} бойынша ${q + 1}-сұрақ?`,
          options: ['A нұсқа', 'B нұсқа', 'C нұсқа', 'D нұсқа'],
          correct_index: correct,
          explanation: 'Дұрыс жауаптың түсіндірмесі (демо).',
          points: 1,
          order: q,
        });
      }
      for (let k = 0; k < 2; k++) {
        flashcards.push({
          subject_id: subj.id,
          topic_id: tp.id,
          front: `${tp.title}: термин ${k + 1}`,
          back: `Термин ${k + 1} анықтамасы (демо).`,
          hint: 'Кеңес: негізгі ұғымды есте сақта.',
          order: k,
        });
      }
    }
    const { error: qErr } = await db.from('questions').insert(questions);
    if (qErr) throw new Error(`questions ${subj.id}: ${qErr.message}`);
    const { error: fErr } = await db.from('flashcards').insert(flashcards);
    if (fErr) throw new Error(`flashcards ${subj.id}: ${fErr.message}`);
    qCount += questions.length;
    fCount += flashcards.length;
  }
  console.log(`   ${topicCount} тақырып, ${qCount} сұрақ, ${fCount} флешкарта.`);
}

// ── 5) СҰРАҚТАР БАНКІ (ҰБТ генерациясы үшін) ─────────────────────────────────────
function bankRow(section, subjectId, points, i) {
  return {
    section,
    subject_id: subjectId,
    question: `[Банк] ${section}${subjectId ? '/' + subjectId : ''} ${points}б №${i + 1}`,
    options: ['A нұсқа', 'B нұсқа', 'C нұсқа', 'D нұсқа',
      ...(points === 2 ? ['E нұсқа', 'F нұсқа'] : [])],
    correct_indices: points === 2 ? [i % 3, (i % 3) + 1] : [i % 4],
    points,
    active: true,
  };
}

async function seedBank() {
  console.log('🏦 Сұрақтар банкі...');
  const rows = [];
  // Міндетті (қор үшін талаптан көбірек).
  for (let i = 0; i < 30; i++) rows.push(bankRow('kazakhHistory', null, 1, i));
  for (let i = 0; i < 20; i++) rows.push(bankRow('mathLiteracy', null, 1, i));
  for (let i = 0; i < 20; i++) rows.push(bankRow('readingLiteracy', null, 1, i));
  // Бейіндік: әр пәнге 30×1 балл + 20×2 балл (талап: 25×1 + 15×2).
  for (const e of ELECTIVES) {
    for (let i = 0; i < 30; i++) rows.push(bankRow('elective', e.id, 1, i));
    for (let i = 0; i < 20; i++) rows.push(bankRow('elective', e.id, 2, i));
  }
  for (let i = 0; i < rows.length; i += 500) {
    const { error } = await db.from('question_bank').insert(rows.slice(i, i + 500));
    if (error) throw new Error(`question_bank: ${error.message}`);
  }
  console.log(`   ${rows.length} банк сұрағы.`);
}

// ── 6) МОК ТЕСТТЕР + ХАБАРЛАНДЫРУ ────────────────────────────────────────────────
async function seedMocks(students, classes) {
  console.log('📝 Мок тесттер + хабарландыру...');
  const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString();

  // Әр сыныптың кураторын тап (бірінші студенттен).
  const byClass = {};
  for (const s of students) {
    byClass[s.className] ??= { curatorId: s.curatorId, students: [] };
    byClass[s.className].students.push(s);
  }

  const notifications = [];
  for (const cls of classes) {
    const info = byClass[cls.name];
    if (!info) continue;
    const { error } = await db.from('mocktests').insert({
      title: `${cls.name} — Маусым айлық мок`,
      active: true,
      created_by: info.curatorId,
      class_name: cls.name,
      available_from: yesterday,
      generated: true,
    });
    if (error) throw new Error(`mocktests ${cls.name}: ${error.message}`);

    for (const s of info.students) {
      notifications.push({
        user_id: s.id,
        title: 'Жаңа айлық мок тест',
        body: `«${cls.name} — Маусым айлық мок» қолжетімді — тапсырыңыз!`,
        type: 'mock',
        read: false,
      });
    }
  }
  if (notifications.length) {
    const { error } = await db.from('notifications').insert(notifications);
    if (error) throw new Error(`notifications: ${error.message}`);
  }
  console.log(`   ${classes.length} мок, ${notifications.length} хабарландыру.`);
}

// ── Іске қосу ─────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n🚀 Damu reseed → ${SUPABASE_URL}\n`);
  await clean();
  const { students, classes } = await seedUsers();
  await seedScores(students);
  await seedContent();
  await seedBank();
  await seedMocks(students, classes);

  console.log('\n✅ Дайын! Тіркелгілер (құпия сөз бәріне ортақ):');
  console.log(`   Құпия сөз: ${PASSWORD}`);
  console.log('   ── Директор:  director@damu.kz');
  console.log('   ── Кураторлар: curator1@damu.kz, curator2@damu.kz, curator3@damu.kz');
  console.log('   ── Оқушылар:   s01@damu.kz … s30@damu.kz');
  console.log('\n(Әкімшіні скрипт өзгертпейді — бұрынғы admin аккаунтыңыз сол күйінде.)\n');
}

main().catch((e) => {
  console.error('\n❌ Қате:', e.message);
  process.exit(1);
});
