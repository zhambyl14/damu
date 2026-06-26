# Supabase баптау нұсқаулығы — Damu High School

Жоба Firebase-тен Supabase-ке көшірілді. Бұл папкада дерекқор схемасы мен
edge function орналасқан.

## 1. Дерекқор схемасын құру

Supabase Dashboard → **SQL Editor** → **New query** → мына файлдың ішіндегісін
қойып, **Run** басыңыз:

```
supabase/migrations/0001_init.sql
```

Бұл мынаны жасайды:
- 11 кесте: `users`, `scores`, `topics`, `questions`, `flashcards`, `mocktests`,
  `mock_questions`, `quizattempts`, `notifications`, `streaks`, `video_progress`
  (пәндер каталогы — кодта: `lib/data/subjects_catalog.dart`, БД-да емес)
- Рөлге негізделген RLS саясаттары (admin / director / curator / student)
- Жаңа қолданушы тіркелгенде `public.users`-ке автоматты жол қосатын триггер
- Flutter `.stream()` жұмыс істеуі үшін realtime жариялымы

## 2. Бірінші админ аккаунтын құру

1. Dashboard → **Authentication → Users → Add user** — email + құпиясөз енгізіңіз.
2. SQL Editor-да рөлді admin-ге ауыстырыңыз (UID-ті жаңа қолданушыдан көшіріңіз):

```sql
update public.users set role = 'admin', name = 'Әкімші'
where id = '<АДМИН-UID>';
```

Дәл осылай `director` / `curator` рөлдерін бере аласыз.

## 3. (Қажет болса) Edge Function деплой

`admin_create_user` — админ/куратор жаңа оқушы аккаунтын құру үшін
(service_role қажет болғандықтан клиентте емес, серверде орындалады).

```bash
supabase functions deploy admin_create_user
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
```

> Қазіргі қосымшада бұл функцияны шақыратын экран жоқ — болашақта оқушы
> аккаунттарын құру қажет болғанда дайын тұр.

## Кілттер туралы

- **Publishable key** (`sb_publishable_...`) — публичный, Flutter-да қолданылады
  (`lib/supabase_config.dart`). RLS деректерді қорғайды.
- **Secret key** (`sb_secret_...`) — тек серверде. Ешқашан қосымша кодына
  немесе git-ке салмаңыз.
