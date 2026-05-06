import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type RequestBody = {
  familyId: string;
};

type RevenueCatEntitlement = {
  expires_date?: string | null;
  product_identifier?: string | null;
};

type RevenueCatSubscription = {
  expires_date?: string | null;
  period_type?: string | null;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
};

type BillingSnapshot = {
  ownerId: string;
  plan: "free" | "basic" | "premium";
  lifecycle: "neverSubscribed" | "trialing" | "active" | "canceling" | "expired";
  isInTrial: boolean;
  trialEndsAt: string | null;
  accessEndsAt: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function getBearerAuthHeader(req: Request): string {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) throw new Error("not authenticated");
  return authHeader;
}

async function getAuthedUserId(req: Request, supabaseUrl: string, serviceRoleKey: string): Promise<string> {
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: getBearerAuthHeader(req) } },
  });
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) throw new Error("not authenticated");
  return data.user.id;
}

function isActiveExpiresDate(expiresDate?: string | null): boolean {
  if (!expiresDate) return true;
  const expiresAt = Date.parse(expiresDate);
  return Number.isFinite(expiresAt) && expiresAt > Date.now();
}

function lifecycleForSubscription(
  subscription?: RevenueCatSubscription,
): BillingSnapshot["lifecycle"] {
  if (!subscription) return "active";
  if (subscription.period_type === "trial") return "trialing";
  if (subscription.unsubscribe_detected_at || subscription.billing_issues_detected_at) {
    return "canceling";
  }
  return "active";
}

function snapshotFromRevenueCat(ownerId: string, payload: Record<string, unknown>): BillingSnapshot {
  const subscriber = payload.subscriber as Record<string, unknown> | undefined;
  const entitlements =
    (subscriber?.entitlements as Record<string, RevenueCatEntitlement> | undefined) ?? {};
  const subscriptions =
    (subscriber?.subscriptions as Record<string, RevenueCatSubscription> | undefined) ?? {};

  for (const plan of ["premium", "basic"] as const) {
    const entitlement = entitlements[plan];
    if (!entitlement || !isActiveExpiresDate(entitlement.expires_date)) continue;
    const productId = entitlement.product_identifier ?? "";
    const subscription = productId ? subscriptions[productId] : undefined;
    const lifecycle = lifecycleForSubscription(subscription);
    const isInTrial = lifecycle === "trialing";
    return {
      ownerId,
      plan,
      lifecycle,
      isInTrial,
      trialEndsAt: isInTrial ? entitlement.expires_date ?? null : null,
      accessEndsAt: entitlement.expires_date ?? null,
    };
  }

  const hasBillingHistory =
    Boolean(entitlements.premium) ||
    Boolean(entitlements.basic) ||
    Object.keys(subscriptions).some((productId) =>
      productId.includes("premium") || productId.includes("basic")
    );

  return {
    ownerId,
    plan: "free",
    lifecycle: hasBillingHistory ? "expired" : "neverSubscribed",
    isInTrial: false,
    trialEndsAt: null,
    accessEndsAt: null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const revenueCatSecretKey = Deno.env.get("REVENUECAT_SECRET_API_KEY");
    if (!supabaseUrl || !serviceRoleKey || !revenueCatSecretKey) {
      throw new Error("Missing family-owner-billing environment variables");
    }

    const userId = await getAuthedUserId(req, supabaseUrl, serviceRoleKey);
    const body = await req.json() as RequestBody;
    const familyId = body.familyId?.trim();
    if (!familyId) throw new Error("familyId is required");

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data: member, error: memberError } = await supabase
      .from("family_members")
      .select("id")
      .eq("family_id", familyId)
      .eq("user_id", userId)
      .maybeSingle();
    if (memberError) throw memberError;
    if (!member) throw new Error("not a family member");

    const { data: family, error: familyError } = await supabase
      .from("families")
      .select("owner_id")
      .eq("id", familyId)
      .maybeSingle();
    if (familyError) throw familyError;
    const ownerId = family?.owner_id as string | undefined;
    if (!ownerId) throw new Error("family owner not found");

    const revenueCatResponse = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(ownerId)}`,
      { headers: { Authorization: `Bearer ${revenueCatSecretKey}` } },
    );
    const revenueCatJson = await revenueCatResponse.json().catch(() => ({}));
    if (!revenueCatResponse.ok) {
      throw new Error(`RevenueCat fetch failed: ${revenueCatResponse.status}`);
    }

    const snapshot = snapshotFromRevenueCat(ownerId, revenueCatJson);
    return new Response(JSON.stringify(snapshot), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error(`family-owner-billing failed: ${message}`);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
