import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type RequestBody =
  | { action: "store"; authorizationCode: string }
  | { action: "revoke" };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function base64UrlEncode(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem.replaceAll("\\n", "\n");
  const base64 = normalized
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function createAppleClientSecret(): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!teamId || !clientId || !keyId || !privateKey) {
    throw new Error("Missing Apple revoke environment variables");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = {
    iss: teamId,
    iat: now,
    exp: now + 60 * 60 * 24 * 30,
    aud: "https://appleid.apple.com",
    sub: clientId,
  };
  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

async function getAuthedUserId(req: Request, supabaseUrl: string, serviceRoleKey: string): Promise<string> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) throw new Error("not authenticated");
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) throw new Error("not authenticated");
  return data.user.id;
}

async function exchangeAuthorizationCode(authorizationCode: string, clientSecret: string) {
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!clientId) throw new Error("Missing APPLE_CLIENT_ID");
  const params = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });
  const response = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`apple token exchange failed: ${JSON.stringify(json)}`);
  }
  const refreshToken = typeof json.refresh_token === "string" ? json.refresh_token : "";
  if (!refreshToken) throw new Error("apple token exchange did not return refresh_token");
  return refreshToken;
}

async function revokeRefreshToken(refreshToken: string, clientSecret: string): Promise<void> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!clientId) throw new Error("Missing APPLE_CLIENT_ID");
  const params = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: "refresh_token",
  });
  const response = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`apple revoke failed: ${response.status} ${body}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }
    const userId = await getAuthedUserId(req, supabaseUrl, serviceRoleKey);
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const body = await req.json() as RequestBody;
    const clientSecret = await createAppleClientSecret();

    if (body.action === "store") {
      if (!body.authorizationCode?.trim()) throw new Error("authorizationCode is required");
      const refreshToken = await exchangeAuthorizationCode(body.authorizationCode, clientSecret);
      const { error } = await supabase
        .from("apple_auth_revoke_tokens")
        .upsert({ user_id: userId, refresh_token: refreshToken }, { onConflict: "user_id" });
      if (error) throw error;
      return new Response(JSON.stringify({ ok: true, stored: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (body.action === "revoke") {
      const { data, error } = await supabase
        .from("apple_auth_revoke_tokens")
        .select("refresh_token")
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw error;
      if (!data?.refresh_token) {
        return new Response(JSON.stringify({ ok: true, revoked: false, reason: "missing_token" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      await revokeRefreshToken(data.refresh_token, clientSecret);
      const { error: deleteError } = await supabase
        .from("apple_auth_revoke_tokens")
        .delete()
        .eq("user_id", userId);
      if (deleteError) throw deleteError;
      return new Response(JSON.stringify({ ok: true, revoked: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    throw new Error("invalid action");
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error(`apple-auth-revoke failed: ${message}`);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
