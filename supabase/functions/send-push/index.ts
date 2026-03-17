import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SendPushRequest = {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

type ProcessPendingRequest = {
  mode?: "process_pending";
  batch_size?: number;
};

type DeviceTokenRow = {
  id: string;
  user_id: string;
  fcm_token: string;
  platform: "ios" | "android" | "web";
};

type TokenDeliveryResult = {
  token_id: string;
  platform: DeviceTokenRow["platform"];
  status: "sent" | "failed" | "deleted";
  error?: string;
};

type NotificationJobRow = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  data: Record<string, string> | null;
  status: "pending" | "processing" | "sent" | "failed";
  attempts: number;
};

const MAX_JOB_ATTEMPTS = 3;
const RETRYABLE_JOB_STATUSES = ["pending", "failed"] as const;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function isDeferredShoppingAddedJob(job: NotificationJobRow): boolean {
  return job.data?.aggregate_kind === "shopping_added" &&
    typeof job.data?.aggregate_until === "string";
}

function isReadyToProcess(job: NotificationJobRow): boolean {
  if (!isDeferredShoppingAddedJob(job)) {
    return true;
  }

  const aggregateUntil = Date.parse(job.data!.aggregate_until);
  if (Number.isNaN(aggregateUntil)) {
    console.warn(`Invalid aggregate_until for job id=${job.id}: ${job.data?.aggregate_until}`);
    return true;
  }

  return Date.now() >= aggregateUntil;
}

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

async function sendPushToUser(
  supabase: ReturnType<typeof createClient>,
  accessToken: string,
  firebaseProjectId: string,
  request: SendPushRequest,
): Promise<{
  sent: number;
  deleted: number;
  failed: number;
  total_tokens: number;
  results: TokenDeliveryResult[];
  message?: string;
}> {
  const { data: rows, error } = await supabase
    .from("device_tokens")
    .select("id,user_id,fcm_token,platform")
    .eq("user_id", request.user_id);

  if (error) {
    throw error;
  }

  const tokens = (rows ?? []) as DeviceTokenRow[];
  if (tokens.length === 0) {
    return {
      sent: 0,
      deleted: 0,
      failed: 0,
      total_tokens: 0,
      results: [],
      message: "No device token found",
    };
  }

  let sent = 0;
  let deleted = 0;
  let failed = 0;
  const results: TokenDeliveryResult[] = [];

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
              title: request.title,
              body: request.body,
            },
            data: request.data ?? {},
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
      results.push({
        token_id: row.id,
        platform: row.platform,
        status: "sent",
      });
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
        results.push({
          token_id: row.id,
          platform: row.platform,
          status: "deleted",
          error: text,
        });
        continue;
      }
    }

    results.push({
      token_id: row.id,
      platform: row.platform,
      status: "failed",
      error: text,
    });
  }

  return { sent, deleted, failed, total_tokens: tokens.length, results };
}

async function insertDeliveryLog(
  supabase: ReturnType<typeof createClient>,
  payload: {
    job_id: string;
    user_id: string;
    attempt: number;
    outcome: "sent" | "partial_failure" | "failed";
    total_tokens: number;
    sent_count: number;
    failed_count: number;
    deleted_count: number;
    detail: Record<string, unknown>;
    last_error: string | null;
  },
): Promise<void> {
  const { error } = await supabase
    .from("notification_job_delivery_logs")
    .insert(payload);

  if (error) {
    throw error;
  }
}

async function markJobResult(
  supabase: ReturnType<typeof createClient>,
  jobId: string,
  fields: Partial<Pick<NotificationJobRow, "status" | "attempts">> & {
    last_error: string | null;
    processed_at: string;
    delivery_summary?: Record<string, unknown>;
  },
): Promise<void> {
  const { error } = await supabase
    .from("notification_jobs")
    .update(fields)
    .eq("id", jobId);

  if (error) {
    throw error;
  }
}

async function processPendingJobs(
  supabase: ReturnType<typeof createClient>,
  accessToken: string,
  firebaseProjectId: string,
  batchSize: number,
): Promise<{
  requested: number;
  claimed: number;
  sent_jobs: number;
  failed_jobs: number;
}> {
  const { data, error } = await supabase
    .from("notification_jobs")
    .select("id,user_id,title,body,data,status,attempts")
    .in("status", [...RETRYABLE_JOB_STATUSES])
    .lt("attempts", MAX_JOB_ATTEMPTS)
    .order("created_at", { ascending: true })
    .limit(Math.max(batchSize * 5, batchSize));

  if (error) {
    throw error;
  }

  const jobs = (data ?? []) as NotificationJobRow[];
  let claimed = 0;
  let sentJobs = 0;
  let failedJobs = 0;

  for (const job of jobs) {
    if (claimed >= batchSize) {
      break;
    }

    if (!isReadyToProcess(job)) {
      continue;
    }

    const { data: claimedRows, error: claimError } = await supabase
      .from("notification_jobs")
      .update({
        status: "processing",
        attempts: job.attempts + 1,
        last_error: null,
      })
      .eq("id", job.id)
      .eq("attempts", job.attempts)
      .in("status", [...RETRYABLE_JOB_STATUSES])
      .select("id");

    if (claimError) {
      throw claimError;
    }

    if (!claimedRows || claimedRows.length === 0) {
      continue;
    }

    claimed += 1;

    try {
      const result = await sendPushToUser(supabase, accessToken, firebaseProjectId, {
        user_id: job.user_id,
        title: job.title,
        body: job.body,
        data: job.data ?? {},
      });

      const processedAt = new Date().toISOString();
      const outcome = result.total_tokens === 0
        ? "failed"
        : result.failed === 0
        ? "sent"
        : result.sent > 0 || result.deleted > 0
        ? "partial_failure"
        : "failed";

      const summary = {
        outcome,
        total_tokens: result.total_tokens,
        sent_count: result.sent,
        failed_count: result.failed,
        deleted_count: result.deleted,
      };

      await insertDeliveryLog(supabase, {
        job_id: job.id,
        user_id: job.user_id,
        attempt: job.attempts + 1,
        outcome,
        total_tokens: result.total_tokens,
        sent_count: result.sent,
        failed_count: result.failed,
        deleted_count: result.deleted,
        detail: {
          title: job.title,
          body: job.body,
          token_results: result.results,
        },
        last_error: result.message ??
          (outcome === "partial_failure"
            ? `partial_failure: sent=${result.sent}, failed=${result.failed}, deleted=${result.deleted}`
            : outcome === "failed"
            ? `delivery_failed: sent=${result.sent}, failed=${result.failed}, deleted=${result.deleted}`
            : null),
      });

      if (outcome === "sent") {
        sentJobs += 1;
        await markJobResult(supabase, job.id, {
          status: "sent",
          attempts: job.attempts + 1,
          last_error: null,
          processed_at: processedAt,
          delivery_summary: summary,
        });
      } else {
        failedJobs += 1;
        await markJobResult(supabase, job.id, {
          status: "failed",
          attempts: job.attempts + 1,
          last_error: result.message ??
            (outcome === "partial_failure"
              ? `partial_failure: sent=${result.sent}, failed=${result.failed}, deleted=${result.deleted}`
              : "No device token found"),
          processed_at: processedAt,
          delivery_summary: summary,
        });
      }
    } catch (error) {
      failedJobs += 1;
      const message = error instanceof Error ? error.message : String(error);
      const processedAt = new Date().toISOString();
      await insertDeliveryLog(supabase, {
        job_id: job.id,
        user_id: job.user_id,
        attempt: job.attempts + 1,
        outcome: "failed",
        total_tokens: 0,
        sent_count: 0,
        failed_count: 0,
        deleted_count: 0,
        detail: {
          error: message,
        },
        last_error: message,
      });
      await markJobResult(supabase, job.id, {
        status: "failed",
        attempts: job.attempts + 1,
        last_error: message,
        processed_at: processedAt,
        delivery_summary: {
          outcome: "failed",
          total_tokens: 0,
          sent_count: 0,
          failed_count: 0,
          deleted_count: 0,
        },
      });
    }
  }

  return {
    requested: jobs.length,
    claimed,
    sent_jobs: sentJobs,
    failed_jobs: failedJobs,
  };
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

    const rawBody = req.headers.get("content-length") === "0"
      ? {}
      : await req.json().catch(() => ({}));

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const accessToken = await createGoogleAccessToken(firebaseServiceAccountJson);

    const processPendingBody = rawBody as ProcessPendingRequest;
    if (processPendingBody.mode === "process_pending" || Object.keys(rawBody).length === 0) {
      const batchSize = Math.min(Math.max(processPendingBody.batch_size ?? 20, 1), 100);
      const result = await processPendingJobs(supabase, accessToken, firebaseProjectId, batchSize);
      return new Response(
        JSON.stringify(result),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = rawBody as SendPushRequest;
    if (!body.user_id || !body.title || !body.body) {
      return new Response(
        JSON.stringify({ error: "user_id, title, body are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const result = await sendPushToUser(supabase, accessToken, firebaseProjectId, body);

    return new Response(
      JSON.stringify(result),
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
