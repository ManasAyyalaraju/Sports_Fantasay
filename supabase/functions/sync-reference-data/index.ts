// supabase/functions/sync-reference-data/index.ts

import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Supabase & API-Sports configuration
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const apiSportsKey = Deno.env.get("API_SPORTS_KEY")!;

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

const API_BASE = "https://v2.nba.api-sports.io";

// Match your Swift logic: NBA season year
function getSeason(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1; // 1–12
  const seasonYear = month >= 10 ? year : year - 1;
  return String(seasonYear);
}

// Small helper to call API-Sports
async function apiGet(
  path: string,
  params: Record<string, string> = {},
): Promise<any[]> {
  const url = new URL(`${API_BASE}/${path}`);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }

  const res = await fetch(url.toString(), {
    headers: { "x-apisports-key": apiSportsKey },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API ${path} failed: ${res.status} ${text}`);
  }

  const json = await res.json();
  return json.response as any[];
}

// -----------------------------------------------------
// TEAMS + PLAYERS
// -----------------------------------------------------

async function syncTeamsAndPlayers() {
  const season = getSeason();
  console.log("Starting teams/players sync for season", season);

  // 1) Fetch all teams from API-Sports
  const teamsResponse = await apiGet("teams", {});
  const nbaTeams = teamsResponse.filter((t: any) =>
    t.nbaFranchise === true && t.allStar !== true
  );

  // 2) Upsert into public.teams
  const teamRows = nbaTeams.map((t: any) => ({
    id: t.id,
    name: t.name,
    nickname: t.nickname ?? null,
    code: t.code ?? null,
    city: t.city ?? null,
    logo: t.logo ?? null,
    conference: t.leagues?.standard?.conference ?? null,
    division: t.leagues?.standard?.division ?? null,
    nba_franchise: t.nbaFranchise ?? true,
    all_star: t.allStar ?? false,
  }));

  {
    const { error } = await supabase
      .from("teams")
      .upsert(teamRows, { onConflict: "id" });

    if (error) {
      console.error("Upsert teams error:", error);
      throw error;
    }
    console.log(`Upserted ${teamRows.length} teams`);
  }

  // 3) For each team, fetch players for this season and upsert
  const seasonStr = season;
  for (const team of nbaTeams) {
    const teamId = team.id as number;
    console.log(`Fetching players for team ${teamId} (${team.name})`);

    const playersResponse = await apiGet("players", {
      team: String(teamId),
      season: seasonStr,
    });

    if (!playersResponse.length) {
      console.log(`No players for team ${teamId}`);
      continue;
    }

    const playerRows = playersResponse.map((p: any) => {
      const league = p.leagues?.standard ?? {};

      let height: string | null = null;
      if (p.height?.feets && p.height?.inches) {
        height = `${p.height.feets}-${p.height.inches}`;
      }

      let weight: string | null = null;
      if (p.weight?.pounds) {
        weight = p.weight.pounds;
      }

      const jersey = league.jersey != null ? String(league.jersey) : null;

      return {
        id: p.id,
        first_name: p.firstname,
        last_name: p.lastname,
        position: league.pos ?? null,
        height,
        weight,
        jersey,
        college: p.college ?? null,
        country: p.birth?.country ?? null,
        draft_year: p.nba?.start ?? null,
        team_id: teamId,
        season: seasonStr,
      };
    });

    const { error } = await supabase
      .from("players")
      .upsert(playerRows, { onConflict: "id" });

    if (error) {
      console.error(`Upsert players error for team ${teamId}:`, error);
      throw error;
    }

    console.log(
      `Upserted ${playerRows.length} players for team ${teamId} (${team.name})`,
    );

    // small delay to be kind to API-Sports
    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  console.log("Teams/players sync finished for season", seasonStr);
}

// -----------------------------------------------------
// GAMES + GAME_DETAILS
// -----------------------------------------------------

async function syncGames() {
  const season = getSeason();
  console.log("Starting games sync for season", season);

  const gamesResponse = await apiGet("games", { season });

  if (!gamesResponse.length) {
    console.log("No games returned from API");
    return;
  }

  const gameRows: any[] = [];
  const detailRows: any[] = [];

  for (const g of gamesResponse) {
    const id = g.id as number;

    const dateStr: string | null = g.date?.start ?? null;
    const status: string | null = g.status?.long ?? null;
    const stage: number | null = g.stage ?? null;

    const homeTeam = g.teams?.home;
    const awayTeam = g.teams?.visitors;
    const scores = g.scores ?? {};

    gameRows.push({
      id,
      season,
      stage,
      date: dateStr, // Postgres will cast ISO string to timestamptz
      status,
      home_team_id: homeTeam?.id ?? null,
      visitor_team_id: awayTeam?.id ?? null,
      home_score: scores.home?.points ?? null,
      visitor_score: scores.visitors?.points ?? null,
    });

    detailRows.push({
      game_id: id,
      home_team_name: homeTeam?.name ?? null,
      home_team_code: homeTeam?.code ?? null,
      visitor_team_name: awayTeam?.name ?? null,
      visitor_team_code: awayTeam?.code ?? null,
      home_score: scores.home?.points ?? null,
      visitor_score: scores.visitors?.points ?? null,
    });
  }

  const { error: gamesErr } = await supabase
    .from("games")
    .upsert(gameRows, { onConflict: "id" });
  if (gamesErr) {
    console.error("Upsert games error:", gamesErr);
    throw gamesErr;
  }

  const { error: detailsErr } = await supabase
    .from("game_details")
    .upsert(detailRows, { onConflict: "game_id" });
  if (detailsErr) {
    console.error("Upsert game_details error:", detailsErr);
    throw detailsErr;
  }

  console.log(`Upserted ${gameRows.length} games and details`);
}

// -----------------------------------------------------
// SEASON AVERAGES + PER-GAME STATS (subset of players)
// -----------------------------------------------------

async function syncSeasonAverages() {
  const season = getSeason();
  console.log("Starting season_averages sync for season", season);

  // Build game metadata from Supabase games + game_details (already synced by syncGames).
  // This ensures player_game_stats gets non-null game_date, teams, scores, etc.
  const { data: gamesRows, error: gamesErr } = await supabase
    .from("games")
    .select("id, date, status, home_team_id, visitor_team_id, home_score, visitor_score, stage")
    .eq("season", season);

  if (gamesErr) {
    console.error("Fetch games for metadata error:", gamesErr);
    throw gamesErr;
  }

  const { data: detailsRows, error: detailsErr } = await supabase
    .from("game_details")
    .select("game_id, home_team_name, home_team_code, visitor_team_name, visitor_team_code, home_score, visitor_score");

  if (detailsErr) {
    console.error("Fetch game_details for metadata error:", detailsErr);
    throw detailsErr;
  }

  const detailsByGameId = new Map<number, any>();
  for (const d of detailsRows ?? []) {
    detailsByGameId.set(d.game_id as number, d);
  }

  const regularSeasonGameIds = new Set<number>();
  const gameMeta = new Map<number, any>();

  for (const row of gamesRows ?? []) {
    const id = row.id as number;
    const stage: number | null = row.stage ?? null;
    // Stage 1 = preseason, skip those
    if (stage === 1) continue;

    regularSeasonGameIds.add(id);
    const details = detailsByGameId.get(id);

    let gameDate: string | null = null;
    if (row.date != null) {
      if (typeof row.date === "string") {
        gameDate = row.date;
      } else if (typeof row.date === "object" && (row.date as any).toISOString) {
        gameDate = (row.date as any).toISOString();
      } else {
        gameDate = String(row.date);
      }
    }

    gameMeta.set(id, {
      game_date: gameDate,
      home_team_id: row.home_team_id ?? null,
      visitor_team_id: row.visitor_team_id ?? null,
      home_team_score: row.home_score ?? details?.home_score ?? null,
      visitor_team_score: row.visitor_score ?? details?.visitor_score ?? null,
      game_status: row.status ?? null,
      home_team_name: details?.home_team_name ?? null,
      home_team_abbreviation: details?.home_team_code ?? null,
      visitor_team_name: details?.visitor_team_name ?? null,
      visitor_team_abbreviation: details?.visitor_team_code ?? null,
    });
  }

  console.log(
    `Loaded metadata for ${regularSeasonGameIds.size} regular-season games from Supabase (games + game_details)`,
  );

  // Players to process: all with team_id, but prioritize those missing season_averages this season
  const { data: existingAverages } = await supabase
    .from("season_averages")
    .select("player_id")
    .eq("season", season);

  const existingPlayerIds = new Set(
    (existingAverages ?? []).map((r: any) => r.player_id as number),
  );

  const { data: players, error } = await supabase
    .from("players")
    .select("id, position")
    .not("team_id", "is", null);

  if (error) {
    console.error("Fetch players for averages error:", error);
    throw error;
  }
  if (!players || players.length === 0) {
    console.log("No players found for season_averages sync");
    return;
  }

  // Process players missing season_averages first, then the rest (so re-runs fill the gap)
  const missing = (players as any[]).filter((p) => !existingPlayerIds.has(p.id as number));
  const toProcess = missing.length > 0 ? missing : (players as any[]);
  console.log(
    `Season averages: ${existingPlayerIds.size} already synced, ${toProcess.length} to process`,
  );

  const playerPositionById = new Map<number, string | null>();
  for (const p of players as any[]) {
    playerPositionById.set(p.id as number, p.position ?? null);
  }

  const BATCH_SIZE = 8;
  const DELAY_MS = 80;

  async function processOnePlayer(p: { id: number; position?: string | null }) {
    const playerId = p.id as number;
    const stats = await apiGet("players/statistics", {
      id: String(playerId),
      season,
    });

    if (!stats.length) return;

    const perGameRows: any[] = [];
    let games = 0;
    let totalPts = 0,
      totalReb = 0,
      totalAst = 0,
      totalStl = 0,
      totalBlk = 0;
    let totalFgm = 0,
      totalFga = 0,
      totalFg3m = 0,
      totalFg3a = 0,
      totalFtm = 0,
      totalFta = 0;
    let totalMin = 0;

    for (const s of stats) {
      const rawGameId: number | undefined = s.game?.id;
      const meta =
        typeof rawGameId === "number"
          ? gameMeta.get(rawGameId)
          : undefined;

      if (!rawGameId || !meta) continue;

      const gameId = rawGameId as number;
      games += 1;
      totalPts += s.points ?? 0;
      totalReb += s.totReb ?? 0;
      totalAst += s.assists ?? 0;
      totalStl += s.steals ?? 0;
      totalBlk += s.blocks ?? 0;
      totalFgm += s.fgm ?? 0;
      totalFga += s.fga ?? 0;
      totalFg3m += s.tpm ?? 0;
      totalFg3a += s.tpa ?? 0;
      totalFtm += s.ftm ?? 0;
      totalFta += s.fta ?? 0;

      if (s.min && typeof s.min === "string") {
        const [mins] = s.min.split(":");
        const m = parseInt(mins, 10);
        if (!Number.isNaN(m)) totalMin += m;
      }

      perGameRows.push({
        game_id: gameId,
        player_id: playerId,
        season,
        game_date: meta.game_date ?? null,
        home_team_id: meta.home_team_id ?? null,
        visitor_team_id: meta.visitor_team_id ?? null,
        home_team_score: meta.home_team_score ?? null,
        visitor_team_score: meta.visitor_team_score ?? null,
        game_status: meta.game_status ?? null,
        home_team_name: meta.home_team_name ?? null,
        home_team_abbreviation: meta.home_team_abbreviation ?? null,
        visitor_team_name: meta.visitor_team_name ?? null,
        visitor_team_abbreviation: meta.visitor_team_abbreviation ?? null,
        player_first_name: s.player?.firstname ?? null,
        player_last_name: s.player?.lastname ?? null,
        player_position: s.pos ?? playerPositionById.get(playerId) ?? null,
        player_team_id: s.team?.id ?? null,
        team_id: s.team?.id ?? null,
        team_abbreviation: s.team?.code ?? null,
        team_full_name: s.team?.name ?? null,
        min: s.min ?? null,
        pts: s.points ?? null,
        reb: s.totReb ?? null,
        ast: s.assists ?? null,
        stl: s.steals ?? null,
        blk: s.blocks ?? null,
        turnovers: s.turnovers ?? null,
        fgm: s.fgm ?? null,
        fga: s.fga ?? null,
        fg3m: s.tpm ?? null,
        fg3a: s.tpa ?? null,
        ftm: s.ftm ?? null,
        fta: s.fta ?? null,
        pf: s.pFouls ?? null,
      });
    }

    const g = games || 1;
    const avgMin = games ? Math.round(totalMin / games) : 0;

    const row = {
      player_id: playerId,
      season,
      pts: totalPts / g,
      reb: totalReb / g,
      ast: totalAst / g,
      stl: totalStl / g,
      blk: totalBlk / g,
      games_played: games,
      min: String(avgMin),
      fg_pct: totalFga ? (totalFgm / totalFga) * 100 : 0,
      fg3_pct: totalFg3a ? (totalFg3m / totalFg3a) * 100 : 0,
      ft_pct: totalFta ? (totalFtm / totalFta) * 100 : 0,
    };

    if (perGameRows.length > 0) {
      const { error: gameStatsErr } = await supabase
        .from("player_game_stats")
        .upsert(perGameRows, { onConflict: "game_id,player_id" });

      if (gameStatsErr) {
        console.error(`Upsert player_game_stats for player ${playerId}:`, gameStatsErr);
        throw gameStatsErr;
      }
    }

    const { error: upsertErr } = await supabase
      .from("season_averages")
      .upsert(row, { onConflict: "player_id,season" });

    if (upsertErr) {
      console.error(`Upsert season_averages for player ${playerId}:`, upsertErr);
      throw upsertErr;
    }
  }

  for (let i = 0; i < toProcess.length; i += BATCH_SIZE) {
    const batch = toProcess.slice(i, i + BATCH_SIZE);
    const results = await Promise.allSettled(
      batch.map((p) => processOnePlayer(p)),
    );
    const failed = results.filter((r) => r.status === "rejected");
    if (failed.length > 0) {
      for (const r of failed) {
        console.error("Player batch item failed:", (r as PromiseRejectedResult).reason);
      }
    }
    if (i + BATCH_SIZE < toProcess.length) {
      await new Promise((resolve) => setTimeout(resolve, DELAY_MS));
    }
  }

  console.log("season_averages sync finished");
}

// -----------------------------------------------------
// HTTP entrypoint
// -----------------------------------------------------

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Only POST allowed", { status: 405 });
  }

  try {
    await syncTeamsAndPlayers();
    await syncGames();
    await syncSeasonAverages();

    return new Response(
      JSON.stringify({ ok: true }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Sync failed:", error);
    return new Response(
      JSON.stringify({ ok: false, error: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});