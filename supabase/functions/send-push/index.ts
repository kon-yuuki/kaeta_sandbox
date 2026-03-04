import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SendPushRequest = {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

type DeviceTokenRow = {
  id: string;
  user_id: string;
  fcm_token: string;
  platform: "ios" | "android" | "web";
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function createGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const serviceAccount = JSON.parse(serviceAccountJson) as {
    client_email: string;
    private_key: string;
    token_uri: string;
  };

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: serviceAccount.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const headerPart = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const payloadPart = base64UrlEncode(encoder.encode(JSON.stringify(payload)));
  const unsignedJwt = `${headerPart}.${payloadPart}`;

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(unsignedJwt),
  );

  const signedJwt = `${unsignedJwt}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenRes = await fetch(serviceAccount.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`Failed to create Google access token: ${tokenRes.status} ${text}`);
  }

  const tokenJson = await tokenRes.json() as { access_token: string };
  return tokenJson.access_token;
}

function shouldDeleteToken(errorText: string): boolean {
  return (
    errorText.includes("UNREGISTERED") ||
    errorText.includes("registration-token-not-registered") ||
    errorText.includes("invalid-registration-token")
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }
    if (!firebaseServiceAccountJson || !firebaseProjectId) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID");
    }

    const body = await req.json() as SendPushRequest;
    if (!body.user_id || !body.title || !body.body) {
      return new Response(
        JSON.stringify({ error: "user_id, title, body are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data: rows, error } = await supabase
      .from("device_tokens")
      .select("id,user_id,fcm_token,platform")
      .eq("user_id", body.user_id);

    if (error) {
      throw error;
    }

    const tokens = (rows ?? []) as DeviceTokenRow[];
    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, deleted: 0, failed: 0, message: "No device token found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const accessToken = await createGoogleAccessToken(firebaseServiceAccountJson);
    let sent = 0;
    let deleted = 0;
    let failed = 0;

    for (const row of tokens) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: row.fcm_token,
              notification: {
                title: body.title,
                body: body.body,
              },
              data: body.data ?? {},
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                  },
                },
              },
            },
          }),
        },
      );

      if (res.ok) {
        sent += 1;
        continue;
      }

      failed += 1;
      const text = await res.text();
      console.error(`FCM send failed for token id=${row.id}: ${res.status} ${text}`);

      if (shouldDeleteToken(text)) {
        const { error: deleteError } = await supabase
          .from("device_tokens")
          .delete()
          .eq("id", row.id);
        if (deleteError) {
          console.error(`Failed to delete invalid token id=${row.id}: ${deleteError.message}`);
        } else {
          deleted += 1;
        }
      }
    }

    return new Response(
      JSON.stringify({ sent, deleted, failed }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
