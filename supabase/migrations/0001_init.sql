-- ============================================================================
-- Damu High School — Supabase толық схемасы (толық қосымша)
-- Кестелер: users, scores, topics, questions, flashcards, mocktests,
--           mock_questions, quizattempts, notifications, streaks, video_progress
-- (subjects — статикалық каталог, кодта: lib/data/subjects_catalog.dart)
--
-- Қолдану: Supabase Dashboard → SQL Editor → New query → осыны қойып → Run
-- ============================================================================

create extension if not exists "pgcrypto";

-- ── 1) USERS — профиль (auth.users-пен 1:1) ──────────────────────────────────
create table if not exists public.users (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text,
  name          text,
  avatar_url    text,
  role          text not null default 'student'
                check (role in ('admin','director','curator','student')),
  curator_id    uuid references public.users (id) on delete set null,
  class_id      text,
  class_name    text,
  grade         int,
  elective_pair text,
  student_type  text default 'online' check (student_type in ('online','offline')),
  created_at    timestamptz not null default now()
);
create index if not exists users_curator_id_idx on public.users (curator_id);
create index if not exists users_role_idx       on public.users (role);

-- ── 2) SCORES — ҰБТ нәтижелері ───────────────────────────────────────────────
create table if not exists public.scores (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid references public.users (id) on delete cascade,
  student_name     text,
  class_name       text,
  curator_id       uuid,
  date             timestamptz not null default now(),
  test_type        text not null default 'monthly',
  test_name        text,
  kazakh_history   int not null default 0,
  reading_literacy int not null default 0,
  math_literacy    int not null default 0,
  elective1        int not null default 0,
  elective2        int not null default 0,
  elective1_name   text,
  elective2_name   text,
  total_score      int not null default 0,
  mandatory_score  int not null default 0,
  elective_score   int not null default 0,
  created_at       timestamptz not null default now()
);
create index if not exists scores_student_id_idx on public.scores (student_id);
create index if not exists scores_curator_id_idx on public.scores (curator_id);

-- ── 3) TOPICS — пән ішіндегі тақырыптар (subject_id — каталог id) ─────────────
create table if not exists public.topics (
  id              uuid primary key default gen_random_uuid(),
  subject_id      text not null,
  title           text,
  "order"         int default 0,
  question_count  int default 0,
  flashcard_count int default 0,
  video_url       text,
  created_by      uuid,
  created_at      timestamptz not null default now()
);
create index if not exists topics_subject_id_idx on public.topics (subject_id);

-- ── 4) QUESTIONS — тақырыптық сұрақтар ───────────────────────────────────────
create table if not exists public.questions (
  id            uuid primary key default gen_random_uuid(),
  subject_id    text,
  topic_id      uuid references public.topics (id) on delete cascade,
  question      text,
  options       jsonb,
  correct_index int default 0,
  explanation   text,
  points        int default 1,
  "order"       int default 0,
  created_by    uuid,
  created_at    timestamptz not null default now()
);
create index if not exists questions_topic_id_idx on public.questions (topic_id);

-- ── 5) FLASHCARDS — флешкарталар ─────────────────────────────────────────────
create table if not exists public.flashcards (
  id          uuid primary key default gen_random_uuid(),
  subject_id  text,
  topic_id    uuid references public.topics (id) on delete cascade,
  front       text,
  back        text,
  hint        text,
  "order"     int default 0,
  created_by  uuid,
  created_at  timestamptz not null default now()
);
create index if not exists flashcards_topic_id_idx on public.flashcards (topic_id);

-- ── 6) MOCKTESTS — мектеп мок тесттері ───────────────────────────────────────
create table if not exists public.mocktests (
  id             uuid primary key default gen_random_uuid(),
  title          text,
  description    text,
  active         boolean not null default true,
  question_count int default 0,
  created_by     uuid,
  created_at     timestamptz not null default now()
);

-- ── 7) MOCK_QUESTIONS — мок тест сұрақтары ───────────────────────────────────
create table if not exists public.mock_questions (
  id              uuid primary key default gen_random_uuid(),
  mock_id         uuid references public.mocktests (id) on delete cascade,
  section         text not null default 'kazakhHistory',
  subject_id      text,
  question        text,
  options         jsonb,
  correct_index   int default 0,            -- ескі: бір дұрыс жауап (үйлесімділік)
  correct_indices jsonb default '[]'::jsonb, -- жаңа: дұрыс жауап(тар) индекстері
  points          int default 1,            -- сұрақ баллы (1 немесе 2)
  image_url       text,                     -- сурет URL (болса)
  explanation     text,
  "order"         int default 0
);
create index if not exists mock_questions_mock_id_idx on public.mock_questions (mock_id);

-- ── 8) QUIZATTEMPTS — тақырыптық тест нәтижелері ─────────────────────────────
create table if not exists public.quizattempts (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid references public.users (id) on delete cascade,
  student_name text,
  subject_id   text,
  topic_id     text,
  topic_title  text,
  correct      int default 0,
  total        int default 0,
  percent      int default 0,
  created_at   timestamptz not null default now()
);
create index if not exists quizattempts_student_id_idx on public.quizattempts (student_id);

-- ── 9) NOTIFICATIONS — хабарландырулар ───────────────────────────────────────
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.users (id) on delete cascade,
  title      text,
  body       text,
  type       text default 'system',
  read       boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_id_idx on public.notifications (user_id);

-- ── 10) STREAKS — белсенділік сериясы ────────────────────────────────────────
create table if not exists public.streaks (
  user_id        uuid primary key references public.users (id) on delete cascade,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  last_active    timestamptz
);

-- ── 11) VIDEO_PROGRESS — қаралған видеосабақтар ──────────────────────────────
create table if not exists public.video_progress (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.users (id) on delete cascade,
  subject_id text not null,
  topic_id   text not null,
  watched_at timestamptz not null default now(),
  unique (user_id, subject_id, topic_id)
);
create index if not exists video_progress_user_id_idx on public.video_progress (user_id);

-- ============================================================================
-- РОЛЬ КӨМЕКШІ ФУНКЦИЯСЫ (SECURITY DEFINER — users саясатында рекурсияны болдырмайды)
-- ============================================================================
create or replace function public.user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid();
$$;

-- ============================================================================
-- ЖАҢА ҚОЛДАНУШЫ → public.users-ке автоматты жол (рөлі әдепкі 'student')
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    'student'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
alter table public.users          enable row level security;
alter table public.scores         enable row level security;
alter table public.topics         enable row level security;
alter table public.questions      enable row level security;
alter table public.flashcards     enable row level security;
alter table public.mocktests      enable row level security;
alter table public.mock_questions enable row level security;
alter table public.quizattempts   enable row level security;
alter table public.notifications  enable row level security;
alter table public.streaks        enable row level security;
alter table public.video_progress enable row level security;

-- ── USERS ────────────────────────────────────────────────────────────────────
drop policy if exists users_select_self     on public.users;
drop policy if exists users_update_self      on public.users;
drop policy if exists users_insert_self      on public.users;
drop policy if exists users_staff_select     on public.users;
drop policy if exists users_admin_all        on public.users;
drop policy if exists users_curator_students on public.users;

create policy users_select_self on public.users
  for select using (id = auth.uid());
create policy users_update_self on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy users_insert_self on public.users
  for insert with check (id = auth.uid());
create policy users_staff_select on public.users
  for select using (public.user_role() in ('admin','director','curator'));
create policy users_admin_all on public.users
  for all
  using (public.user_role() in ('admin','director'))
  with check (public.user_role() in ('admin','director'));
create policy users_curator_students on public.users
  for update
  using (public.user_role() = 'curator' and curator_id = auth.uid())
  with check (public.user_role() = 'curator' and curator_id = auth.uid());

-- ── SCORES ───────────────────────────────────────────────────────────────────
drop policy if exists scores_select_all     on public.scores;
drop policy if exists scores_admin_all       on public.scores;
drop policy if exists scores_curator_insert  on public.scores;
drop policy if exists scores_curator_update  on public.scores;
drop policy if exists scores_curator_delete  on public.scores;
drop policy if exists scores_student_insert  on public.scores;

create policy scores_select_all on public.scores
  for select using (auth.uid() is not null);
create policy scores_admin_all on public.scores
  for all
  using (public.user_role() in ('admin','director'))
  with check (public.user_role() in ('admin','director'));
create policy scores_curator_insert on public.scores
  for insert with check (public.user_role() = 'curator' and curator_id = auth.uid());
create policy scores_curator_update on public.scores
  for update using (public.user_role() = 'curator' and curator_id = auth.uid())
              with check (public.user_role() = 'curator' and curator_id = auth.uid());
create policy scores_curator_delete on public.scores
  for delete using (public.user_role() = 'curator' and curator_id = auth.uid());
create policy scores_student_insert on public.scores
  for insert with check (student_id = auth.uid());

-- ── CONTENT (topics/questions/flashcards): оқу=кірген, жазу=staff ─────────────
do $$
declare t text;
begin
  foreach t in array array['topics','questions','flashcards'] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format($f$create policy %1$I_read on public.%1$I
        for select using (auth.uid() is not null)$f$, t);
    execute format($f$create policy %1$I_write on public.%1$I
        for all
        using (public.user_role() in ('admin','director','curator'))
        with check (public.user_role() in ('admin','director','curator'))$f$, t);
  end loop;
end $$;

-- ── MOCKTESTS / MOCK_QUESTIONS: оқу=кірген, жазу=admin/director ───────────────
do $$
declare t text;
begin
  foreach t in array array['mocktests','mock_questions'] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format($f$create policy %1$I_read on public.%1$I
        for select using (auth.uid() is not null)$f$, t);
    execute format($f$create policy %1$I_write on public.%1$I
        for all
        using (public.user_role() in ('admin','director'))
        with check (public.user_role() in ('admin','director'))$f$, t);
  end loop;
end $$;

-- ── QUIZATTEMPTS: оқушы өзінікін қосады, staff оқиды ─────────────────────────
drop policy if exists quizattempts_read           on public.quizattempts;
drop policy if exists quizattempts_student_insert  on public.quizattempts;
create policy quizattempts_read on public.quizattempts
  for select using (student_id = auth.uid() or public.user_role() in ('admin','director','curator'));
create policy quizattempts_student_insert on public.quizattempts
  for insert with check (student_id = auth.uid());

-- ── NOTIFICATIONS: иесі немесе staff ─────────────────────────────────────────
drop policy if exists notifications_read   on public.notifications;
drop policy if exists notifications_insert on public.notifications;
drop policy if exists notifications_modify on public.notifications;
create policy notifications_read on public.notifications
  for select using (user_id = auth.uid() or public.user_role() in ('admin','director','curator'));
create policy notifications_insert on public.notifications
  for insert with check (user_id = auth.uid() or public.user_role() in ('admin','director','curator'));
create policy notifications_modify on public.notifications
  for update using (user_id = auth.uid() or public.user_role() in ('admin','director','curator'))
             with check (user_id = auth.uid() or public.user_role() in ('admin','director','curator'));

-- ── STREAKS: иесі толық, staff оқу ───────────────────────────────────────────
drop policy if exists streaks_owner        on public.streaks;
drop policy if exists streaks_staff_select  on public.streaks;
create policy streaks_owner on public.streaks
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy streaks_staff_select on public.streaks
  for select using (public.user_role() in ('admin','director','curator'));

-- ── VIDEO_PROGRESS: иесі толық, staff оқу ────────────────────────────────────
drop policy if exists video_progress_owner       on public.video_progress;
drop policy if exists video_progress_staff_select on public.video_progress;
create policy video_progress_owner on public.video_progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy video_progress_staff_select on public.video_progress
  for select using (public.user_role() in ('admin','director','curator'));

-- ============================================================================
-- REALTIME — Flutter .stream() жұмыс істеуі үшін
-- ============================================================================
do $$
declare t text;
begin
  foreach t in array array['users','scores','topics','questions','flashcards',
      'mocktests','mock_questions','quizattempts','notifications','streaks','video_progress'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ============================================================================
-- Дайын. Бірінші админ:
--   1) Authentication → Users → Add user (email + password)
--   2) update public.users set role='admin', name='Әкімші' where id='<АДМИН-UID>';
-- ============================================================================
