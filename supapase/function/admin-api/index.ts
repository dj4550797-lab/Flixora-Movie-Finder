// Supabase Edge Function: admin-api
// Handles privileged Super Admin server-side actions, validating JWT and UID against SUPER_ADMIN_UUID.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const EXPECTED_SUPER_ADMIN_UID = Deno.env.get("SUPER_ADMIN_UUID") || "540e9d75-3e05-48c9-bb5c-5dac0db4c3f0";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://comxecntwlntgvjbvkjs.supabase.co";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "sb_publishable__5xCvJeJren5zsyR33SkJQ_fYwAZIbX";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Extract auth token
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Unauthorized. Missing Bearer token." }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const token = authHeader.replace("Bearer ", "").trim();
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Verify token with Supabase Auth
  const { data: { user }, error: userError } = await supabase.auth.getUser(token);
  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired session token." }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Verify user is the authorized Super Admin UID
  if (user.id !== EXPECTED_SUPER_ADMIN_UID) {
    return new Response(
      JSON.stringify({ error: "Access denied. Caller is not the authorized Super Admin." }),
      { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const url = new URL(req.url);
  const action = url.searchParams.get("action") || "status";

  // Dispatch actions
  if (action === "status" || action === "health") {
    return new Response(
      JSON.stringify({
        status: "ok",
        authenticated_admin: user.email,
        admin_uid: user.id,
        tmdb_configured: Boolean(Deno.env.get("TMDB_API_KEY")),
        service_role_configured: Boolean(SUPABASE_SERVICE_ROLE_KEY),
        timestamp: new Date().toISOString()
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (action === "audit-log" && req.method === "POST") {
    try {
      const payload = await req.json();
      if (SUPABASE_SERVICE_ROLE_KEY) {
        const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
        await adminClient.from("admin_activity_logs").insert({
          admin_uid: user.id,
          admin_email: user.email,
          action: payload.action || "SYSTEM_EVENT",
          target_entity: payload.entity || "system",
          details: payload.details || {},
          ip_address: req.headers.get("x-forwarded-for") || "unknown"
        });
      }
      return new Response(
        JSON.stringify({ success: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } catch (err: any) {
      return new Response(
        JSON.stringify({ error: err.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  }

  return new Response(
    JSON.stringify({ error: `Unknown action: ${action}` }),
    { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});

