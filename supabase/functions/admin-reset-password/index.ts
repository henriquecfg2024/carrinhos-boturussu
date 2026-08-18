import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

const normalizePhone = (value: unknown) =>
  String(value ?? "").replace(/[^0-9]/g, "").trim();

const authEmailForPhone = (phone: string) =>
  `${phone}@auth.app-carrinho.local`;

const base64Utf8 = (value: string) => {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Supabase service configuration is missing");
}

const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function getCaller(request: Request) {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;

  const { data, error } = await adminClient.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}

async function isCallerAdmin(callerId: string) {
  const { data, error } = await adminClient
    .from("profiles")
    .select("id, telefone, perfil, status")
    .eq("id", callerId)
    .maybeSingle();

  if (error || !data) return false;

  const phone = normalizePhone(data.telefone);
  if (phone === "11920066472") return true;

  const perfil = String(data.perfil || "").toLowerCase();
  return data.status === "ativo" && ["administrador", "master"].includes(perfil);
}

async function findProfileByPhone(phone: string) {
  const { data, error } = await adminClient
    .from("profiles")
    .select("*");

  if (error || !Array.isArray(data)) return null;
  return data.find((profile: Record<string, unknown>) =>
    normalizePhone(profile.telefone) === phone
  ) || null;
}

async function findAuthUserByPhone(phone: string, profileId?: string | null) {
  if (profileId) {
    const byId = await adminClient.auth.admin.getUserById(profileId);
    if (!byId.error && byId.data.user) return byId.data.user;
  }

  const email = authEmailForPhone(phone);
  const perPage = 1000;

  for (let page = 1; page <= 10; page++) {
    const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage });
    if (error || !data?.users?.length) return null;

    const found = data.users.find((user) => {
      const metadata = user.user_metadata || {};
      return user.email === email || normalizePhone(metadata.telefone) === phone;
    });
    if (found) return found;
    if (data.users.length < perPage) return null;
  }

  return null;
}

async function updateLegacyPassword(phone: string, newPassword: string) {
  const { data: legacyRow, error: legacyError } = await adminClient
    .from("app_store")
    .select("data")
    .eq("key", "users")
    .maybeSingle();

  if (legacyError || !legacyRow?.data || !Array.isArray(legacyRow.data)) {
    return false;
  }

  let found = false;
  const encodedPassword = base64Utf8(newPassword);
  const updatedUsers = legacyRow.data.map((user: Record<string, unknown>) => {
    if (normalizePhone(user.telefone) !== phone) return user;
    found = true;
    return { ...user, senha: encodedPassword };
  });

  if (!found) return false;

  const { error: updateError } = await adminClient
    .from("app_store")
    .upsert({ key: "users", data: updatedUsers }, { onConflict: "key" });

  if (updateError) throw updateError;
  return true;
}

async function concludePendingRequests(phone: string, adminId: string) {
  await adminClient
    .from("password_reset_requests")
    .update({
      status: "concluido",
      concluido_at: new Date().toISOString(),
      concluido_por: adminId,
    })
    .eq("telefone_normalizado", phone)
    .eq("status", "pendente");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const caller = await getCaller(request);
    if (!caller) return json({ error: "unauthorized" }, 401);

    const callerIsAdmin = await isCallerAdmin(caller.id);
    if (!callerIsAdmin) return json({ error: "forbidden" }, 403);

    const body = await request.json();
    const telefone = normalizePhone(body.telefone);
    const novaSenha = typeof body.novaSenha === "string" ? body.novaSenha : "";

    if (!/^\d{10,11}$/.test(telefone)) {
      return json({ error: "invalid_phone", message: "Telefone invalido." }, 400);
    }
    if (novaSenha.length < 6) {
      return json({ error: "invalid_password", message: "A senha deve ter pelo menos 6 caracteres." }, 400);
    }

    const profile = await findProfileByPhone(telefone);
    const authUser = await findAuthUserByPhone(
      telefone,
      profile?.id ? String(profile.id) : null,
    );

    if (authUser?.id) {
      const { error: authUpdateError } = await adminClient.auth.admin.updateUserById(
        authUser.id,
        { password: novaSenha },
      );
      if (authUpdateError) {
        console.error("Auth password reset failed:", authUpdateError.message);
        return json({ error: "auth_update_failed" }, 500);
      }
    }

    let legacyUpdated = false;
    try {
      legacyUpdated = await updateLegacyPassword(telefone, novaSenha);
    } catch (error) {
      console.error("Legacy password reset failed:", error instanceof Error ? error.message : "unknown");
      return json({ error: "legacy_update_failed" }, 500);
    }

    if (!authUser?.id && !legacyUpdated) {
      return json({ error: "not_found", message: "Usuario nao encontrado." }, 404);
    }

    await concludePendingRequests(telefone, caller.id);

    return json({ ok: true });
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
});
