// supabase/functions/admin_create_user/index.ts
//
// Админ/куратор жаңа оқушы аккаунтын құру үшін (service_role қажет, сондықтан
// клиентте емес, осында жасалады). Шақырушының JWT-і тексеріледі, рөлі расталады.
//
// Deploy: supabase functions deploy admin_create_user
// Secret:  supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
//          (SUPABASE_URL автоматты беріледі)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method Not Allowed' }, 405);
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json({ error: 'Server misconfigured: missing SUPABASE_URL or SERVICE_ROLE_KEY' }, 500);
  }

  // service_role клиенті — RLS-ті айналып өтеді, тек артықшылықты әрекеттерге.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    // 1. Шақырушыны JWT арқылы тану
    const authHeader = req.headers.get('authorization') ?? '';
    const token = authHeader.replace('Bearer ', '').trim();
    if (!token) return json({ error: 'Missing authorization token' }, 401);

    const { data: callerData, error: callerErr } = await admin.auth.getUser(token);
    if (callerErr || !callerData?.user) return json({ error: 'Invalid token' }, 401);
    const callerId = callerData.user.id;

    // 2. Шақырушының рөлін тексеру
    const { data: callerProfile, error: profileErr } = await admin
      .from('users').select('role').eq('id', callerId).maybeSingle();
    if (profileErr) return json({ error: 'DB error', details: profileErr.message }, 500);

    const callerRole = callerProfile?.role;
    if (!['admin', 'curator'].includes(callerRole ?? '')) {
      return json({ error: 'Forbidden: only admin or curator can create users' }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const {
      email, password, name, role,
      curatorId, className, classId, grade,
      electivePairKey, studentType,
    } = body ?? {};

    if (!email || !password) return json({ error: 'email and password required' }, 400);

    const targetRole = role || 'student';
    if (callerRole === 'curator' && targetRole !== 'student') {
      return json({ error: 'Forbidden: curators may only create students' }, 403);
    }

    // 3. Auth user құру
    const { data: createdUser, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name },
    });
    if (createErr || !createdUser?.user) {
      return json({ error: 'Auth create error', details: createErr?.message ?? 'unknown' }, 500);
    }
    const newUserId = createdUser.user.id;

    // 4. public.users профилін upsert (триггер 'student' жолын құрып қойуы мүмкін)
    const profile: Record<string, unknown> = {
      id: newUserId,
      email,
      name: name ?? null,
      role: targetRole,
    };
    if (curatorId !== undefined)       profile.curator_id = curatorId;
    if (className !== undefined)       profile.class_name = className;
    if (classId !== undefined)         profile.class_id = classId;
    if (grade !== undefined)           profile.grade = grade;
    if (electivePairKey !== undefined) profile.elective_pair = electivePairKey;
    if (studentType !== undefined)     profile.student_type = studentType;

    const { error: upsertErr } = await admin.from('users').upsert(profile, { onConflict: 'id' });
    if (upsertErr) {
      await admin.auth.admin.deleteUser(newUserId); // orphan қалдырмау
      return json({ error: 'DB upsert error', details: upsertErr.message }, 500);
    }

    return json({ id: newUserId }, 201);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
