-- 0005_test_drafts.sql
-- Аяқталмаған тестті АВТО-САҚТАУ. Интернет үзілсе/қосымша жабылса да оқушының
-- жауаптары жоғалмайды — қайта кіргенде сол жерден жалғастыра алады.
-- Supabase Dashboard → SQL Editor → New query → осыны қойып → Run.
-- Идемпотентті — бірнеше рет іске қосуға болады (қауіпсіз).

create table if not exists public.test_drafts (
  student_id        uuid not null references public.users (id) on delete cascade,
  mock_id           text not null,                       -- айлық мок id-і немесе 'practice'
  question_ids      jsonb not null default '[]'::jsonb,  -- генерацияланған сұрақтардың реті (қалпына келтіру)
  answers           jsonb not null default '{}'::jsonb,  -- {"индекс": [таңдалған нұсқа индекстері]}
  flagged           jsonb not null default '[]'::jsonb,  -- 🚩 белгіленген сұрақ индекстері
  current_index     int  not null default 0,             -- соңғы ашық сұрақ
  remaining_seconds int  not null default 0,             -- таймерде қалған уақыт
  updated_at        timestamptz not null default now(),
  primary key (student_id, mock_id)
);
create index if not exists test_drafts_student_idx
  on public.test_drafts (student_id);

alter table public.test_drafts enable row level security;

-- Оқушы тек ӨЗІНІҢ draft-ын оқиды/жазады/өшіреді.
drop policy if exists test_drafts_rw on public.test_drafts;
create policy test_drafts_rw on public.test_drafts
  for all
  using (student_id = auth.uid())
  with check (student_id = auth.uid());
