-- 0002_mock_questions_new_format.sql
-- Жаңа ҰБТ форматы: mock_questions кестесіне қосымша өрістер.
--   correct_indices — бірнеше дұрыс жауап (сәйкестендіру/26–40 сұрақтар)
--   points          — сұрақ баллы (дәстүрлі 1, күрделі 2)
--   image_url       — суреті бар сұрақтар үшін сурет URL мекенжайы
-- Идемпотентті: бірнеше рет іске қосуға болады.

alter table public.mock_questions
  add column if not exists correct_indices jsonb default '[]'::jsonb;

alter table public.mock_questions
  add column if not exists points int default 1;

alter table public.mock_questions
  add column if not exists image_url text;

-- Бар сұрақтарды (бір дұрыс жауап) жаңа өріске көшіру.
update public.mock_questions
set correct_indices = jsonb_build_array(correct_index)
where (correct_indices is null or correct_indices = '[]'::jsonb)
  and correct_index is not null;
