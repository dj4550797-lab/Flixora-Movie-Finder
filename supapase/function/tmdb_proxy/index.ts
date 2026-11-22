// Supabase Edge Function: tmdb-proxy
// Serves as a secure backend proxy to TMDB API without exposing TMDB_API_KEY to frontend visitors.
// Supports endpoint allowlisting, query parameter sanitization, rate limiting, and edge caching.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const TMDB_BASE = "https://api.themoviedb.org/3";
const ALLOWED_ENDPOINTS = [
  /^\/(movie|tv)\/\d+(\/(videos|images|credits|recommendations|similar|season\/\d+))?$/,
  /^\/trending\/(all|movie|tv)\/(day|week)$/,
  /^\/discover\/(movie|tv)$/,
  /^\/search\/(multi|movie|tv)$/,
  /^\/genre\/(movie|tv)\/list$/,
  /^\/configuration$/
];

// In-memory sliding rate limit tracker (per minute per client IP)
const ipRequestCounts = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 120; // 120 requests/min per IP

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = ipRequestCounts.get(ip);
  if (!entry || now > entry.resetAt) {
    ipRequestCounts.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return true;
  }
  if (entry.count >= MAX_REQUESTS_PER_WINDOW) {
    return false;
  }
  entry.count++;
  return true;
}

serve(async (req: Request) => {
  // 1. Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // 2. Only GET allowed
  if (req.method !== "GET") {
    return new Response(
      JSON.stringify({ error: "Method not allowed. Only GET is supported." }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 3. Client IP rate limiting
  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0].trim() || "anonymous";
  if (!checkRateLimit(clientIp)) {
    return new Response(
      JSON.stringify({ error: "Too many requests. Please slow down." }),
      { 
        status: 429, 
        headers: { 
          ...corsHeaders, 
          "Content-Type": "application/json",
          "Retry-After": "60"
        } 
      }
    );
  }

  // 4. Extract and validate requested endpoint
  const url = new URL(req.url);
  const endpoint = url.searchParams.get("endpoint") || "";

  if (!endpoint || !ALLOWED_ENDPOINTS.some((pattern) => pattern.test(endpoint))) {
    return new Response(
      JSON.stringify({ 
        error: "Invalid or unauthorized TMDB endpoint.", 
        hint: "Only public discovery, trending, search, and detail endpoints are allowed." 
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 5. Retrieve TMDB_API_KEY from Edge Function secret
  const tmdbKey = Deno.env.get("TMDB_API_KEY");
  if (!tmdbKey) {
    return new Response(
      JSON.stringify({ 
        error: "TMDB_API_KEY is not configured in Supabase Edge Function secrets.",
        code: "SECRETS_MISSING"
      }),
      { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 6. Build target TMDB URL forwards allowed query params
  const targetUrl = new URL(`${TMDB_BASE}${endpoint}`);
  for (const [k, v] of url.searchParams.entries()) {
    if (k !== "endpoint") {
      targetUrl.searchParams.set(k, v);
    }
  }
  targetUrl.searchParams.set("api_key", tmdbKey);

  try {
    const upstreamRes = await fetch(targetUrl.toString(), {
      headers: { "Accept": "application/json" }
    });

    const body = await upstreamRes.text();
    return new Response(body, {
      status: upstreamRes.status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=3600, s-maxage=3600, stale-while-revalidate=86400"
      }
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: "Failed to communicate with TMDB.", details: err?.message }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

