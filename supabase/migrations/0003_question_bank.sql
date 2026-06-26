-- 0003_question_bank.sql
-- Сұрақтар БАНКІ + оқушының КӨРГЕН сұрақтары.
--
-- Идея: админ тек банкті толтырады (пән/бөлім/балл бойынша). Мок не дайындық
-- тесті ашылғанда жүйе банктен сұрақтарды толық ҰБТ структурасы бойынша
-- генерациялайды. Әр оқушыға — өзіне бұрын түспеген сұрақтардан кездейсоқ нұсқа.

-- ── 1) QUESTION_BANK — сұрақтар банкі (mock-қа байланбаған) ───────────────────
create table if not exists public.question_bank (
  id              uuid primary key default gen_random_uuid(),
  section         text not null,            -- kazakhHistory|readingLiteracy|mathLiteracy|elective
  subject_id      text,                     -- elective болғанда: қай бейіндік пән
  question        text,
  options         jsonb not null default '[]'::jsonb,
  correct_indices jsonb not null default '[]'::jsonb,
  points          int  not null default 1,  -- 1 (дәстүрлі) немесе 2 (күрделі)
  image_url       text,
  explanation     text,
  active          boolean not null default true,
  created_by      uuid,
  created_at      timestamptz not null default now()
);
-- Генерация осы үш баған бойынша сүзеді → құрама индекс.
create index if not exists question_bank_pick_idx
  on public.question_bank (section, subject_id, points);

-- ── 2) STUDENT_SEEN_QUESTIONS — оқушы көрген банк сұрақтары ───────────────────
create table if not exists public.student_seen_questions (
  student_id  uuid not null references public.users (id) on delete cascade,
  question_id uuid not null references public.question_bank (id) on delete cascade,
  seen_at     timestamptz not null default now(),
  primary key (student_id, question_id)
);
create index if not exists seen_student_idx
  on public.student_seen_questions (student_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table public.question_bank          enable row level security;
alter table public.student_seen_questions enable row level security;

-- QUESTION_BANK: оқу = кірген кез келген, жазу = admin/director.
drop policy if exists question_bank_read  on public.question_bank;
drop policy if exists question_bank_write on public.question_bank;
create policy question_bank_read on public.question_bank
  for select using (auth.uid() is not null);
create policy question_bank_write on public.question_bank
  for all
  using (public.user_role() in ('admin','director'))
  with check (public.user_role() in ('admin','director'));

-- STUDENT_SEEN_QUESTIONS: оқушы өзінікін оқиды/қосады; staff оқиды.
drop policy if exists seen_read          on public.student_seen_questions;
drop policy if exists seen_student_write on public.student_seen_questions;
create policy seen_read on public.student_seen_questions
  for select using (student_id = auth.uid()
                    or public.user_role() in ('admin','director','curator'));
create policy seen_student_write on public.student_seen_questions
  for insert with check (student_id = auth.uid());

-- ── 3) MOCKTESTS: айлық мок тестті КУРАТОР ашады әрі қашан қолжетімді болатынын
--      белгілейді. generated = банктен генерацияланатын ҰБТ (per-student).
alter table public.mocktests
  add column if not exists available_from timestamptz; -- осы күннен бастап тапсыруға болады
alter table public.mocktests
  add column if not exists class_name text;             -- қай сыныпқа арналған (куратор)
alter table public.mocktests
  add column if not exists generated boolean not null default true; -- банктен генерация

-- Кураторлар да мок тест аша алуы үшін жазу саясатын кеңейтеміз.
drop policy if exists mocktests_write on public.mocktests;
create policy mocktests_write on public.mocktests
  for all
  using (public.user_role() in ('admin','director','curator'))
  with check (public.user_role() in ('admin','director','curator'));
