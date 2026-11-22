import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const ALLOWED_ORIGINS = new Set(["https://alazm-global-real-estate.vercel.app"]);
const headers = {
  "Access-Control-Allow-Origin": "https://alazm-global-real-estate.vercel.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...headers, "Content-Type": "application/json" } });

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  const origin = req.headers.get("origin") || "";
  if (!ALLOWED_ORIGINS.has(origin)) return reply({ error: "origin_not_allowed" }, 403);

  let body: { text?: string; target?: string; source?: string };
  try { body = await req.json(); } catch { return reply({ error: "invalid_json" }, 400); }
  const source = typeof body.text === "string" ? body.text.trim() : "";
  const target = typeof body.target === "string" ? body.target.toLowerCase() : "";
  const sourceLang = body.source === undefined ? "en" : (body.source === "ar" || body.source === "en" ? body.source : "");
  if (!source || source.length > 430 || !sourceLang || !/^[a-z]{2,3}(-[a-z0-9]{2,8})?$/i.test(target) || target === sourceLang) {
    return reply({ error: "invalid_input" }, 400);
  }

  const sourceHash = await sha256(source);
  const { data: cached, error: cacheError } = await supabase
    .from("site_translation_cache")
    .select("translated_text")
    .eq("source_hash", sourceHash)
    .eq("source_lang", sourceLang)
    .eq("target_lang", target)
    .maybeSingle();
  if (cacheError) return reply({ error: "cache_unavailable" }, 503);
  if (cached?.translated_text) return reply({ translated: cached.translated_text, cached: true });

  const url = new URL("https://api.mymemory.translated.net/get");
  url.searchParams.set("q", source);
  url.searchParams.set("langpair", sourceLang + "|" + target);
  url.searchParams.set("mt", "1");
  let upstream: Response;
  try {
    upstream = await fetch(url, { headers: { Accept: "application/json" }, signal: AbortSignal.timeout(10000) });
  } catch {
    return reply({ error: "provider_unavailable", retryable: true }, 503);
  }
  if (upstream.status === 429) return reply({ error: "provider_throttled", retryable: true }, 429);
  if (!upstream.ok) return reply({ error: "provider_error", retryable: true }, 503);

  let data: any;
  try { data = await upstream.json(); } catch { return reply({ error: "provider_invalid_response" }, 502); }
  const translated = data?.responseData?.translatedText;
  if (data?.responseStatus !== 200 || typeof translated !== "string" || !translated.trim() ||
      translated.trim().toLowerCase() === source.toLowerCase()) {
    return reply({ error: "language_or_translation_unavailable", retryable: false }, 422);
  }

  const { error: insertError } = await supabase.from("site_translation_cache").upsert({
    source_hash: sourceHash,
    source_lang: sourceLang,
    target_lang: target,
    source_text: source,
    translated_text: translated,
    provider: "mymemory",
    updated_at: new Date().toISOString(),
  }, { onConflict: "source_hash,source_lang,target_lang" });
  if (insertError) return reply({ error: "cache_write_failed" }, 503);
  return reply({ translated, cached: false });
});
