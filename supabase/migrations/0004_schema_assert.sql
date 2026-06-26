-- 0004_schema_assert.sql
-- ИДЕМПОТЕНТТІ схема кепілдігі. 0002/0003 тірі базада толық қолданылмаған жағдайды
-- жабады. Supabase Dashboard → SQL Editor → New query → осыны қойып → Run.
-- Бірнеше рет іске қосуға болады (қауіпсіз).

-- ── mocktests: куратор айлық мок ашуы үшін қажет өрістер (0003 қайталауы) ──────
alter table public.mocktests
  add column if not exists available_from timestamptz;        -- осы күннен бастап тапсыруға болады
alter table public.mocktests
  add column if not exists class_name text;                   -- қай сыныпқа арналған (куратор)
alter table public.mocktests
  add column if not exists generated boolean not null default true; -- банктен генерация

-- ── scores: айлық мокты БІР РЕТ қана тапсыру үшін мок id-і ─────────────────────
alter table public.scores
  add column if not exists mock_id uuid; -- қай айлық мок тапсырылды (practice/monthly-де null)
create index if not exists scores_mock_id_idx on public.scores (mock_id);

-- ── mocktests жазу саясаты: admin/director ЖӘНЕ curator (0003 қайталауы) ───────
drop policy if exists mocktests_write on public.mocktests;
create policy mocktests_write on public.mocktests
  for all
  using (public.user_role() in ('admin','director','curator'))
  with check (public.user_role() in ('admin','director','curator'));

-- ── question_bank + student_seen_questions бар-жоғын қамтамасыз ету (0003) ─────
create table if not exists public.question_bank (
  id              uuid primary key default gen_random_uuid(),
  section         text not null,
  subject_id      text,
  question        text,
  options         jsonb not null default '[]'::jsonb,
  correct_indices jsonb not null default '[]'::jsonb,
  points          int  not null default 1,
  image_url       text,
  explanation     text,
  active          boolean not null default true,
  created_by      uuid,
  created_at      timestamptz not null default now()
);
create index if not exists question_bank_pick_idx
  on public.question_bank (section, subject_id, points);

create table if not exists public.student_seen_questions (
  student_id  uuid not null references public.users (id) on delete cascade,
  question_id uuid not null references public.question_bank (id) on delete cascade,
  seen_at     timestamptz not null default now(),
  primary key (student_id, question_id)
);
create index if not exists seen_student_idx
  on public.student_seen_questions (student_id);

alter table public.question_bank          enable row level security;
alter table public.student_seen_questions enable row level security;

drop policy if exists question_bank_read  on public.question_bank;
drop policy if exists question_bank_write on public.question_bank;
create policy question_bank_read on public.question_bank
  for select using (auth.uid() is not null);
create policy question_bank_write on public.question_bank
  for all
  using (public.user_role() in ('admin','director'))
  with check (public.user_role() in ('admin','director'));

drop policy if exists seen_read          on public.student_seen_questions;
drop policy if exists seen_student_write on public.student_seen_questions;
create policy seen_read on public.student_seen_questions
  for select using (student_id = auth.uid()
                    or public.user_role() in ('admin','director','curator'));
create policy seen_student_write on public.student_seen_questions
  for insert with check (student_id = auth.uid());

-- ── realtime жарияланымы (Flutter .stream() үшін) — қайталау қауіпсіз ──────────
do $$
declare t text;
begin
  foreach t in array array['question_bank','student_seen_questions'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
