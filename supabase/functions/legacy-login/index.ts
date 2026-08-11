import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

const base64Utf8 = (value: string) => {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
};

const normalizePhone = (value: unknown) =>
  String(value ?? "").replace(/[^0-9]/g, "").trim();

const authEmailForPhone = (phone: string) =>
  `${phone}@auth.app-carrinho.local`;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Supabase service configuration is missing");
}

const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const body = await request.json();
    const phone = normalizePhone(body.phone);
    const password = typeof body.password === "string" ? body.password : "";

    if (!/^\d{10,11}$/.test(phone) || password.length < 6) {
      return json({ error: "invalid_credentials" }, 401);
    }

    // A chave legada só é acessada com service role no servidor. Nunca é
    // devolvida ao cliente e o password nunca é registrado em logs.
    const { data: legacyRow, error: legacyError } = await adminClient
      .from("app_store")
      .select("data")
      .eq("key", "users")
      .maybeSingle();

    if (legacyError || !legacyRow?.data || !Array.isArray(legacyRow.data)) {
      return json({ error: "invalid_credentials" }, 401);
    }

    const legacyUser = legacyRow.data.find((candidate: Record<string, unknown>) => {
      const candidatePhone = normalizePhone(candidate.telefone);
      if (candidatePhone !== phone) return false;
      const storedPass = String(candidate.senha || candidate.senhaHash || candidate.senha_hash || "");
      const targetPass = base64Utf8(password);
      return storedPass === targetPass || storedPass === password;
    });

    if (!legacyUser) return json({ error: "invalid_credentials" }, 401);

    const email = authEmailForPhone(phone);
    let authUser: { id: string } | null = null;
    const existing = await adminClient.auth.admin.getUserByEmail(email);

    if (existing.data.user) {
      const updated = await adminClient.auth.admin.updateUserById(existing.data.user.id, {
        password,
        user_metadata: {
          nome: legacyUser.nome,
          telefone: phone,
          congregacao_id: legacyUser.congregacaoId || "boturussu",
        },
      });
      if (updated.error || !updated.data.user) return json({ error: "migration_failed" }, 500);
      authUser = updated.data.user;
    } else {
      const created = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          nome: legacyUser.nome,
          telefone: phone,
          congregacao_id: legacyUser.congregacaoId || "boturussu",
        },
      });
      if (created.error || !created.data.user) return json({ error: "migration_failed" }, 500);
      authUser = created.data.user;
    }

    const perfil = String(legacyUser.perfil || legacyUser.role || "publicador");
    const status = String(legacyUser.status || "pendente");
    const { error: profileError } = await adminClient.from("profiles").upsert({
      id: authUser.id,
      legacy_id: legacyUser.id ? String(legacyUser.id) : null,
      nome: String(legacyUser.nome || "Usuário"),
      telefone: phone,
      perfil: ["publicador", "administrador", "master"].includes(perfil)
        ? perfil
        : "publicador",
      status: ["pendente", "ativo", "inativo"].includes(status)
        ? status
        : "pendente",
      congregacao_id: String(legacyUser.congregacaoId || "boturussu"),
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });

    if (profileError) {
      console.error("Profile upsert warning:", profileError.message);
    }

    return json({ migrated: true });
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
});
