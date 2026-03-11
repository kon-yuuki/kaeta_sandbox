import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type DeleteItemImagesRequest =
  | { scope: "family"; familyId: string }
  | { scope: "account" };

type ItemRow = {
  image_url: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ITEM_IMAGES_BUCKET = "item_images";
const REMOVE_CHUNK_SIZE = 100;

function extractObjectPathFromImageUrl(imageUrl: string): string | null {
  if (!imageUrl) return null;
  const marker = `/${ITEM_IMAGES_BUCKET}/`;
  const markerIndex = imageUrl.indexOf(marker);
  if (markerIndex < 0) return null;
  const pathWithMaybeQuery = imageUrl.slice(markerIndex + marker.length);
  const [pathOnly] = pathWithMaybeQuery.split("?");
  const decoded = decodeURIComponent(pathOnly);
  return decoded.trim().length > 0 ? decoded : null;
}

async function getAuthedUserId(
  req: Request,
  supabase: ReturnType<typeof createClient>,
): Promise<string> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    console.error("delete-item-images auth failed: missing bearer token header");
    throw new Error("missing bearer token");
  }
  const token = authHeader.replace("Bearer ", "").trim();
  const tokenPrefix = token.length >= 12 ? token.slice(0, 12) : token;
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    console.error(
      `delete-item-images auth failed: tokenPrefix=${tokenPrefix}, error=${error?.message ?? "unknown"}`,
    );
    throw new Error("not authenticated");
  }
  console.log(`delete-item-images auth ok: userId=${data.user.id}, tokenPrefix=${tokenPrefix}`);
  return data.user.id;
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

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const userId = await getAuthedUserId(req, supabase);
    const body = await req.json() as DeleteItemImagesRequest;

    let rows: ItemRow[] = [];

    if (body.scope === "family") {
      if (!body.familyId) throw new Error("familyId is required");
      const { data: family, error: familyError } = await supabase
        .from("families")
        .select("id")
        .eq("id", body.familyId)
        .eq("owner_id", userId)
        .maybeSingle();
      if (familyError) throw familyError;
      if (!family) throw new Error("forbidden: only owner can delete family images");

      const { data, error } = await supabase
        .from("items")
        .select("image_url")
        .eq("family_id", body.familyId)
        .not("image_url", "is", null);
      if (error) throw error;
      rows = (data ?? []) as ItemRow[];
    } else if (body.scope === "account") {
      const { data, error } = await supabase
        .from("items")
        .select("image_url")
        .eq("user_id", userId)
        .not("image_url", "is", null);
      if (error) throw error;
      rows = (data ?? []) as ItemRow[];
    } else {
      throw new Error("invalid scope");
    }

    const paths = Array.from(
      new Set(
        rows
          .map((row) => row.image_url)
          .filter((url): url is string => !!url && url.trim().length > 0)
          .map(extractObjectPathFromImageUrl)
          .filter((path): path is string => path != null),
      ),
    );

    let removed = 0;
    const failed: string[] = [];
    for (let i = 0; i < paths.length; i += REMOVE_CHUNK_SIZE) {
      const chunk = paths.slice(i, i + REMOVE_CHUNK_SIZE);
      const { data, error } = await supabase.storage
        .from(ITEM_IMAGES_BUCKET)
        .remove(chunk);
      if (error) {
        failed.push(error.message);
        continue;
      }
      removed += data?.length ?? 0;
    }

    return new Response(
      JSON.stringify({
        scope: body.scope,
        requested: paths.length,
        removed,
        failedCount: failed.length,
        failed,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error(`delete-item-images failed: ${message}`);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
