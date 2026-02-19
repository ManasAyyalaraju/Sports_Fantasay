//
//  SupabaseNBAService.swift
//  Sport_Tracker-Fantasy
//
//  Loads NBA reference data (teams, players, season averages) from Supabase
//  so the app doesn't need to call API-Sports for this data on every run.
//

import Foundation
import Supabase

@MainActor
final class SupabaseNBAService {
    static let shared = SupabaseNBAService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    // MARK: - Helpers

    private func currentSeason() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let month = calendar.component(.month, from: Date())
        // NBA season starts in October; before that, use previous year
        let seasonYear = month >= 10 ? year : year - 1
        return String(seasonYear)
    }

    // MARK: - DTOs

    private struct PlayerRow: Decodable {
        let id: Int
        let first_name: String
        let last_name: String
        let position: String?
        let height: String?
        let weight: String?
        let jersey: String?
        let college: String?
        let country: String?
        let draft_year: Int?
        let team_id: Int?
        let season: String
    }

    private struct TeamRow: Decodable {
        let id: Int
        let name: String
        let code: String?
        let city: String?
        let conference: String?
        let division: String?
    }

    private struct SeasonAverageRow: Decodable {
        let player_id: Int
        let season: String
        let pts: Double
        let reb: Double
        let ast: Double
        let stl: Double
        let blk: Double
        let games_played: Int
        let min: String
        let fg_pct: Double
        let fg3_pct: Double
        let ft_pct: Double
    }

    // MARK: - Public API

    /// Fetches all players for the current season from Supabase and maps them to `NBAPlayer`.
    func fetchAllPlayers() async throws -> [NBAPlayer] {
        let season = currentSeason()

        let playerRows: [PlayerRow] = try await client
            .from("players")
            .select()
            .eq("season", value: season)
            .execute()
            .value

        let teamRows: [TeamRow] = try await client
            .from("teams")
            .select()
            .execute()
            .value

        // Build NBATeam dictionary
        let teamsById: [Int: NBATeam] = teamRows.reduce(into: [:]) { dict, row in
            let fullName: String
            if let city = row.city, !city.isEmpty {
                fullName = "\(city) \(row.name)"
            } else {
                fullName = row.name
            }

            let team = NBATeam(
                id: row.id,
                conference: row.conference ?? "",
                division: row.division ?? "",
                city: row.city ?? "",
                name: row.name,
                fullName: fullName,
                abbreviation: row.code ?? ""
            )
            dict[row.id] = team
        }

        // Map rows to NBAPlayer
        let players: [NBAPlayer] = playerRows.map { row in
            let team = row.team_id.flatMap { teamsById[$0] }

            return NBAPlayer(
                id: row.id,
                firstName: row.first_name,
                lastName: row.last_name,
                position: row.position ?? "",
                height: row.height,
                weight: row.weight,
                jerseyNumber: row.jersey,
                college: row.college,
                country: row.country,
                draftYear: row.draft_year,
                draftRound: nil,
                draftNumber: nil,
                team: team
            )
        }

        return players
    }

    /// Fetches players plus their season averages (when available) and returns `PlayerWithStats`
    /// sorted by fantasy score, matching the behavior of `LiveScoresAPI.fetchPlayersWithStats()`.
    func fetchPlayersWithStats() async throws -> [PlayerWithStats] {
        let season = currentSeason()

        let players = try await fetchAllPlayers()

        let averagesRows: [SeasonAverageRow] = try await client
            .from("season_averages")
            .select()
            .eq("season", value: season)
            .execute()
            .value

        let averagesByPlayerId: [Int: SeasonAverages] = averagesRows.reduce(into: [:]) { dict, row in
            let avg = SeasonAverages(
                playerId: row.player_id,
                pts: row.pts,
                reb: row.reb,
                ast: row.ast,
                stl: row.stl,
                blk: row.blk,
                gamesPlayed: row.games_played,
                min: row.min,
                fgPct: row.fg_pct,
                fg3Pct: row.fg3_pct,
                ftPct: row.ft_pct
            )
            dict[row.player_id] = avg
        }

        var result: [PlayerWithStats] = []
        result.reserveCapacity(players.count)

        for player in players {
            let averages = averagesByPlayerId[player.id]
            result.append(PlayerWithStats(player: player, averages: averages))
        }

        // Sort by fantasy score, then by name for stability
        return result.sorted { p1, p2 in
            if p1.fantasyScore != p2.fantasyScore {
                return p1.fantasyScore > p2.fantasyScore
            }
            return p1.player.fullName < p2.player.fullName
        }
    }

    /// Fetches a single player's season averages from Supabase, if available.
    func fetchSeasonAverage(for playerId: Int) async throws -> SeasonAverages? {
        let season = currentSeason()

        let rows: [SeasonAverageRow] = try await client
            .from("season_averages")
            .select()
            .eq("season", value: season)
            .eq("player_id", value: playerId)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }

        return SeasonAverages(
            playerId: row.player_id,
            pts: row.pts,
            reb: row.reb,
            ast: row.ast,
            stl: row.stl,
            blk: row.blk,
            gamesPlayed: row.games_played,
            min: row.min,
            fgPct: row.fg_pct,
            fg3Pct: row.fg3_pct,
            ftPct: row.ft_pct
        )
    }

    /// Fetches recent per-game stats for a player from Supabase (used for "Last 5 Games").
    /// Orders by game_date descending so the returned list is the true last N games by date.
    func fetchRecentGameStats(playerId: Int, lastNGames: Int = 5) async throws -> [PlayerGameStats] {
        let season = currentSeason()

        // Order by game_date desc so we get the true last N games by date (nulls sort last in PostgreSQL).
        let rows: [PlayerGameStats.SupabaseRow] = try await client
            .from("player_game_stats")
            .select()
            .eq("player_id", value: playerId)
            .eq("season", value: season)
            .order("game_date", ascending: false)
            .limit(20)
            .execute()
            .value

        let allStats = rows.map { PlayerGameStats(fromSupabase: $0) }

        // Exclude DNPs / 0 minutes so "last 5" means last 5 games played.
        let playedGames = allStats.filter { stat in
            let mins = stat.minutes.trimmingCharacters(in: .whitespacesAndNewlines)
            return !mins.isEmpty && mins != "0" && mins != "0:00" && mins != "00:00"
        }

        return Array(playedGames.prefix(lastNGames))
    }

    /// Batch fetch game stats for multiple players, optionally filtered by date.
    /// Used for computing league standings totals.
    func fetchGameStatsForPlayers(playerIds: Set<Int>, onOrAfterDate: Date?, season: String) async throws -> [PlayerGameStats] {
        guard !playerIds.isEmpty else { return [] }

        var query = client
            .from("player_game_stats")
            .select()
            .in("player_id", values: Array(playerIds))
            .eq("season", value: season)

        if let cutOff = onOrAfterDate {
            let calendar = Calendar.current
            let cutOffStart = calendar.startOfDay(for: cutOff)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let cutOffStr = formatter.string(from: cutOffStart)
            query = query.gte("game_date", value: cutOffStr)
        }

        let rows: [PlayerGameStats.SupabaseRow] = try await query
            .order("game_date", ascending: false)
            .execute()
            .value

        return rows.map { PlayerGameStats(fromSupabase: $0) }
    }
}

