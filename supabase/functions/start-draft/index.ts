// supabase/functions/start-draft/index.ts
// Phase 5.1: Start a league draft — assign draft order, create draft row, set league status.
// Call with: POST, body: { "league_id": "uuid" }, header: Authorization: Bearer <user JWT>.
// Only the league creator can start the draft (or change to allow any member if desired).

import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: corsHeaders() },
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid Authorization header" }),
      { status: 401, headers: corsHeaders() },
    );
  }
  const token = authHeader.replace("Bearer ", "");

  let userId: string;
  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: corsHeaders() },
      );
    }
    userId = user.id;
  } catch {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: corsHeaders() },
    );
  }

  let body: { league_id?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: corsHeaders() },
    );
  }

  const leagueId = body.league_id;
  if (!leagueId || typeof leagueId !== "string") {
    return new Response(
      JSON.stringify({ error: "Missing league_id in body" }),
      { status: 400, headers: corsHeaders() },
    );
  }

  try {
    // 1) Load league and ensure creator is starting
    const { data: league, error: leagueErr } = await supabase
      .from("leagues")
      .select("id, capacity, status, creator_id")
      .eq("id", leagueId)
      .single();

    if (leagueErr || !league) {
      return new Response(
        JSON.stringify({ error: "League not found" }),
        { status: 404, headers: corsHeaders() },
      );
    }

    if (league.creator_id !== userId) {
      return new Response(
        JSON.stringify({ error: "Only the league creator can start the draft" }),
        { status: 403, headers: corsHeaders() },
      );
    }

    if (league.status !== "open" && league.status !== "draft_scheduled") {
      return new Response(
        JSON.stringify({ error: "Draft can only be started when league is open or draft_scheduled" }),
        { status: 400, headers: corsHeaders() },
      );
    }

    // 2) Load members and ensure league is full
    const { data: members, error: membersErr } = await supabase
      .from("league_members")
      .select("id, user_id")
      .eq("league_id", leagueId);

    if (membersErr || !members?.length) {
      return new Response(
        JSON.stringify({ error: "Could not load league members" }),
        { status: 500, headers: corsHeaders() },
      );
    }

    if (members.length !== league.capacity) {
      return new Response(
        JSON.stringify({ error: `League must be full (${members.length}/${league.capacity} members) to start draft` }),
        { status: 400, headers: corsHeaders() },
      );
    }

    // 3) Assign random draft order 1..N
    const order = Array.from({ length: league.capacity }, (_, i) => i + 1);
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }

    const memberIds = members.map((m) => m.id);
    for (let i = 0; i < memberIds.length; i++) {
      const { error: updateErr } = await supabase
        .from("league_members")
        .update({ draft_order: order[i] })
        .eq("id", memberIds[i]);
      if (updateErr) {
        console.error("Failed to set draft_order for member", memberIds[i], updateErr);
        return new Response(
          JSON.stringify({ error: "Failed to assign draft order" }),
          { status: 500, headers: corsHeaders() },
        );
      }
    }

    // 4) Create draft row (avoid duplicate if retry)
    const { data: existingDraft } = await supabase
      .from("drafts")
      .select("id")
      .eq("league_id", leagueId)
      .maybeSingle();

    if (!existingDraft) {
      const { error: draftErr } = await supabase.from("drafts").insert({
        league_id: leagueId,
        status: "in_progress",
        current_round: 1,
        current_pick_index: 0,
        total_picks_made: 0,
        total_rounds: 15,
        started_at: new Date().toISOString(),
      });
      if (draftErr) {
        console.error("Failed to create draft", draftErr);
        return new Response(
          JSON.stringify({ error: "Failed to create draft" }),
          { status: 500, headers: corsHeaders() },
        );
      }
    }

    // 5) Update league status
    const { error: leagueUpdateErr } = await supabase
      .from("leagues")
      .update({ status: "draft_in_progress", updated_at: new Date().toISOString() })
      .eq("id", leagueId);

    if (leagueUpdateErr) {
      console.error("Failed to update league status", leagueUpdateErr);
      return new Response(
        JSON.stringify({ error: "Failed to update league status" }),
        { status: 500, headers: corsHeaders() },
      );
    }

    return new Response(
      JSON.stringify({ ok: true, league_id: leagueId }),
      { status: 200, headers: corsHeaders() },
    );
  } catch (err) {
    console.error("Start draft error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: corsHeaders() },
    );
  }
});
