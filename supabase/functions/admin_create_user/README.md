# admin_create_user — Edge Function

Жаңа Auth пайдаланушысын (`auth.users`) және профильді (`public.users`) бір
транзакцияға жақын логикамен жасайды. `service_role` key қолданады, сондықтан
**тек сервер жағында** жұмыс істейді — клиентке ешқашан service_role key бермейді.

## Кім шақыра алады

Тек `public.users` кестесінде `role = 'admin'` немесе `role = 'curator'`
жазбасы бар, авторизацияланған пайдаланушы. Curator тек `role: 'student'`
жасай алады; admin/curator жасай алмайды.

## Күтілетін request body (Flutter `user_admin_service.dart`-пен сәйкес)

```json
{
  "email": "string (міндетті)",
  "password": "string (міндетті)",
  "name": "string",
  "role": "student | curator",
  "curatorId": "string (student үшін)",
  "className": "string",
  "classId": "string",
  "grade": "number",
  "electivePairKey": "string",
  "studentType": "online | offline"
}
```

## Жауап

Сәтті: `201 { "id": "<new-user-uuid>" }`
Қате: `4xx/5xx { "error": "...", "details": "..." }`

## Деплой

```bash
# 1. Supabase CLI орнатылған болуы керек
supabase login
supabase link --project-ref <PROJECT_REF>

# 2. Функцияны деплой ету
supabase functions deploy admin_create_user

# 3. Service role key секрет ретінде автоматты түрде қолжетімді болады,
#    бірақ жоба баптауларында тексеріп ал:
supabase secrets list
```

`SUPABASE_URL` және `SUPABASE_SERVICE_ROLE_KEY` Supabase Edge Functions
ортасында әдетте автоматты түрде бар болады (Dashboard → Project Settings →
Edge Functions). Егер жоқ болса:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
```

## Локалды тестілеу

```bash
supabase functions serve admin_create_user --env-file ./supabase/.env.local
```

`curl` арқылы тексеру:

```bash
curl -i --location --request POST \
  'http://127.0.0.1:54321/functions/v1/admin_create_user' \
  --header 'Authorization: Bearer <ADMIN_USER_JWT>' \
  --header 'Content-Type: application/json' \
  --data '{"email":"curator1@damu.kz","password":"strongpass123","name":"Куратор Аян","role":"curator"}'
```

## ⚠️ RLS ескертуі

Бұл функция `service_role` арқылы жұмыс істейтіндіктен RLS-ті айналып
өтеді — сондықтан рөл тексеруі (admin/curator) функцияның ӨЗІНІҢ ішінде
қатаң сақталуы керек (жоғарыдағы кодта бар). Бұл тексеруді алып тастамаңыз.