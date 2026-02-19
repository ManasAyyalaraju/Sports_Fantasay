// supabase/functions/make-pick/index.ts
// Phase 5.2: Make a draft pick. Validates turn, inserts roster_pick, advances draft (and completes draft + league when done).
// POST, body: { "league_id": "uuid", "player_id": number }, Authorization: Bearer <user JWT>.

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

// Snake order: round 1 = draft_order 1,2,...,N; round 2 = N,...,1. So for round r (1-based), pick index i (0-based):
// orderIndex = (r % 2 === 1) ? i : (capacity - 1 - i)
function orderIndexForPick(round: number, pickIndex: number, capacity: number): number {
  return round % 2 === 1 ? pickIndex : capacity - 1 - pickIndex;
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

  let body: { league_id?: string; player_id?: number };
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: corsHeaders() },
    );
  }

  const leagueId = body.league_id;
  const playerId = body.player_id;
  if (!leagueId || typeof leagueId !== "string") {
    return new Response(
      JSON.stringify({ error: "Missing league_id in body" }),
      { status: 400, headers: corsHeaders() },
    );
  }
  if (playerId == null || typeof playerId !== "number") {
    return new Response(
      JSON.stringify({ error: "Missing or invalid player_id in body" }),
      { status: 400, headers: corsHeaders() },
    );
  }

  try {
    const { data: draft, error: draftErr } = await supabase
      .from("drafts")
      .select("id, league_id, status, current_round, current_pick_index, total_picks_made, total_rounds")
      .eq("league_id", leagueId)
      .single();

    if (draftErr || !draft || draft.status !== "in_progress") {
      return new Response(
        JSON.stringify({ error: "Draft not found or not in progress" }),
        { status: 400, headers: corsHeaders() },
      );
    }

    const { data: league, error: leagueErr } = await supabase
      .from("leagues")
      .select("id, capacity")
      .eq("id", leagueId)
      .single();

    if (leagueErr || !league) {
      return new Response(
        JSON.stringify({ error: "League not found" }),
        { status: 404, headers: corsHeaders() },
      );
    }

    const capacity = league.capacity;
    const totalRounds = draft.total_rounds ?? 15;
    const maxPicks = capacity * totalRounds;

    if (draft.total_picks_made >= maxPicks) {
      return new Response(
        JSON.stringify({ error: "Draft is already complete" }),
        { status: 400, headers: corsHeaders() },
      );
    }

    const { data: members, error: membersErr } = await supabase
      .from("league_members")
      .select("user_id, draft_order")
      .eq("league_id", leagueId)
      .not("draft_order", "is", null)
      .order("draft_order", { ascending: true });

    if (membersErr || !members?.length || members.length !== capacity) {
      return new Response(
        JSON.stringify({ error: "Could not load draft order" }),
        { status: 500, headers: corsHeaders() },
      );
    }

    const orderIdx = orderIndexForPick(draft.current_round, draft.current_pick_index, capacity);
    const currentTurnUserId = members[orderIdx].user_id;
    if (currentTurnUserId !== userId) {
      return new Response(
        JSON.stringify({ error: "It is not your turn to pick" }),
        { status: 403, headers: corsHeaders() },
      );
    }

    const { data: alreadyPicked } = await supabase
      .from("roster_picks")
      .select("id")
      .eq("league_id", leagueId)
      .eq("player_id", playerId)
      .maybeSingle();

    if (alreadyPicked) {
      return new Response(
        JSON.stringify({ error: "Player has already been drafted" }),
        { status: 400, headers: corsHeaders() },
      );
    }

    const pickNumber = draft.total_picks_made + 1;
    const round = draft.current_round;

    const { error: insertErr } = await supabase.from("roster_picks").insert({
      league_id: leagueId,
      user_id: userId,
      player_id: playerId,
      pick_number: pickNumber,
      round,
    });
    if (insertErr) {
      console.error("roster_picks insert failed", insertErr);
      return new Response(
        JSON.stringify({ error: "Failed to record pick" }),
        { status: 500, headers: corsHeaders() },
      );
    }

    const newTotalPicks = draft.total_picks_made + 1;
    const atEndOfRound = draft.current_pick_index + 1 >= capacity;
    const newRound = atEndOfRound ? draft.current_round + 1 : draft.current_round;
    const newPickIndex = atEndOfRound ? 0 : draft.current_pick_index + 1;
    const isComplete = newTotalPicks >= maxPicks;

    const draftUpdate: Record<string, unknown> = {
      total_picks_made: newTotalPicks,
      current_round: newRound,
      current_pick_index: newPickIndex,
      updated_at: new Date().toISOString(),
    };
    if (isComplete) {
      draftUpdate.status = "completed";
      draftUpdate.completed_at = new Date().toISOString();
    }

    const { error: updateDraftErr } = await supabase
      .from("drafts")
      .update(draftUpdate)
      .eq("id", draft.id);
    if (updateDraftErr) {
      console.error("drafts update failed", updateDraftErr);
      return new Response(
        JSON.stringify({ error: "Failed to advance draft" }),
        { status: 500, headers: corsHeaders() },
      );
    }

    if (isComplete) {
      const { error: leagueUpdateErr } = await supabase
        .from("leagues")
        .update({ status: "active", updated_at: new Date().toISOString() })
        .eq("id", leagueId);
      if (leagueUpdateErr) {
        console.error("league status update failed", leagueUpdateErr);
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        pick_number: pickNumber,
        round,
        draft_complete: isComplete,
      }),
      { status: 200, headers: corsHeaders() },
    );
  } catch (err) {
    console.error("Make pick error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: corsHeaders() },
    );
  }
});
