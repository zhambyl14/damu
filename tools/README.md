# Demo reseed (tools/)

Базаны **толық тазалап**, демо деректермен толтыратын скрипт (1 директор, 3 куратор,
30 оқушы, баллдар, контент, сұрақтар банкі, мок тесттер).

> ⚠️ Бұл бар деректі өшіреді (бұрынғы **admin** аккаунттан басқа). Алдымен
> `supabase/migrations/0004_schema_assert.sql`-ді Supabase SQL editor-де іске қосыңыз.

## Қадамдар

1. `tools/.env.example` → `tools/.env` көшіріп, `SUPABASE_SERVICE_ROLE_KEY`-ді толтырыңыз
   (Dashboard → Project Settings → API → **service_role**). Бұл файл git-ке кірмейді.
2. Терминалда:
   ```bash
   cd tools
   npm install
   node seed_demo.mjs
   ```
3. Скрипт соңында тіркелгілер басылады. Барлығына ортақ құпия сөз — `Damu2025!`
   (`.env`-те `SEED_PASSWORD` арқылы өзгертуге болады).

## Тіркелгілер

| Рөл       | Email                                    | Құпия сөз  |
|-----------|------------------------------------------|------------|
| Директор  | director@damu.kz                         | Damu2025!  |
| Кураторлар| curator1@damu.kz … curator3@damu.kz      | Damu2025!  |
| Оқушылар  | s01@damu.kz … s30@damu.kz                | Damu2025!  |
