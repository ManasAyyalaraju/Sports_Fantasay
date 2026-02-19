//
//  LeaderboardService.swift
//  Sport_Tracker-Fantasy
//
//  Compute league standings / leaderboard (Phase 2: backend with live stats).
//

import Foundation
import Supabase
import SwiftUI

struct LeagueStandingsEntry: Identifiable, Hashable {
    let id: UUID // userId
    let rank: Int
    let userId: UUID
    let displayName: String
    let totalFantasyPoints: Double
}

@MainActor
final class LeaderboardService {
    static let shared = LeaderboardService()

    private let leagueService = LeagueService()
    private let rosterService = RosterService.shared
    private let nbaService = SupabaseNBAService.shared
    private let liveManager = LiveGameManager.shared

    /// Compute standings for a league. Supports live stats (real-time) and season averages (testing).
    func loadStandings(leagueId: UUID, useSeasonAverages: Bool = false) async throws -> [LeagueStandingsEntry] {
        // 1. Load league (to get draftDate and season)
        guard let league = try await loadLeague(leagueId: leagueId) else {
            throw LeaderboardError.leagueNotFound
        }

        // 2. Load all league members
        let members = try await leagueService.loadLeagueMembers(leagueId: leagueId)
        print("📊 LeaderboardService: Loaded \(members.count) members for league \(leagueId)")

        guard !members.isEmpty else {
            print("⚠️ LeaderboardService: No members found for league")
            return []
        }

        // 3. Load all roster picks for the league (group by user_id → [player_id])
        let allPicks = try await rosterService.loadAllRosterPicks(leagueId: leagueId)
        print("📊 LeaderboardService: Loaded \(allPicks.count) total roster picks")
        let rostersByUser: [UUID: [Int]] = Dictionary(grouping: allPicks, by: { $0.userId })
            .mapValues { $0.map(\.playerId) }
        print("📊 LeaderboardService: Rosters by user: \(rostersByUser.keys.count) users have rosters")

        // 4. Compute totals for each member
        var entries: [(userId: UUID, total: Double)] = []

        for member in members {
            guard let playerIds = rostersByUser[member.userId], !playerIds.isEmpty else {
                // No roster → 0 points
                entries.append((member.userId, 0))
                continue
            }

            let total: Double
            if useSeasonAverages {
                // Testing mode: use season averages
                total = try await computeTotalFromSeasonAverages(playerIds: Set(playerIds))
            } else {
                // Production mode: live stats + completed games after draft date
                total = try await computeTotalWithLiveStats(
                    playerIds: Set(playerIds),
                    draftDate: league.draftDate,
                    season: league.season
                )
            }

            entries.append((member.userId, total))
        }

        // 5. Sort by total descending
        entries.sort { $0.total > $1.total }

        // 6. Fetch profiles for display names (gracefully handle errors)
        let userIds = entries.map { $0.userId }
        var profiles: [UUID: String] = [:]
        do {
            profiles = try await leagueService.fetchProfiles(userIds: userIds)
            print("📊 LeaderboardService: Fetched \(profiles.count) profiles with display names")
        } catch {
            print("⚠️ LeaderboardService: Failed to fetch profiles: \(error). Using 'Member' as fallback.")
            // Continue with empty profiles map - we'll use "Member" fallback
        }

        // 7. Assign ranks and create standings entries with display names
        var standings: [LeagueStandingsEntry] = []
        var currentRank = 1
        var previousTotal: Double?

        for (index, entry) in entries.enumerated() {
            if let prev = previousTotal, entry.total < prev {
                // New rank (skip for ties)
                currentRank = index + 1
            }
            
            // Get display name from profile, fallback to "Member"
            let displayName = profiles[entry.userId] ?? "Member"
            
            standings.append(LeagueStandingsEntry(
                id: entry.userId,
                rank: currentRank,
                userId: entry.userId,
                displayName: displayName,
                totalFantasyPoints: entry.total
            ))
            previousTotal = entry.total
        }

        print("📊 LeaderboardService: Computed standings for \(standings.count) members (league has \(members.count) total members)")
        return standings
    }

    // MARK: - Private Helpers

    private func loadLeague(leagueId: UUID) async throws -> League? {
        // Load from myLeagues if available
        if let league = leagueService.myLeagues.first(where: { $0.id == leagueId }) {
            return league
        }
        // If not in myLeagues, query leagues table directly
        let client = SupabaseManager.shared.client
        let rows: [LeagueRow] = try await client
            .from("leagues")
            .select()
            .eq("id", value: leagueId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        
        guard let row = rows.first else { return nil }
        
        // Parse league from row (reuse LeagueService's parsing logic)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        func parseDate(_ s: String) -> Date {
            dateFormatter.date(from: s)
                ?? ISO8601DateFormatter().date(from: s)
                ?? Date()
        }
        
        return League(
            id: row.id,
            name: row.name,
            capacity: row.capacity,
            draftDate: parseDate(row.draft_date),
            inviteCode: row.invite_code,
            creatorId: row.creator_id,
            status: row.status,
            season: row.season,
            createdAt: parseDate(row.created_at),
            updatedAt: parseDate(row.updated_at)
        )
    }
    
    private struct LeagueRow: Decodable {
        let id: UUID
        let name: String
        let capacity: Int
        let draft_date: String
        let invite_code: String
        let creator_id: UUID
        let status: String
        let season: String
        let created_at: String
        let updated_at: String
    }

    private func computeTotalFromSeasonAverages(playerIds: Set<Int>) async throws -> Double {
        var total: Double = 0
        for playerId in playerIds {
            if let avg = try await nbaService.fetchSeasonAverage(for: playerId) {
                total += avg.fantasyScore
            }
        }
        return total
    }

    private func computeTotalWithLiveStats(playerIds: Set<Int>, draftDate: Date, season: String) async throws -> Double {
        var total: Double = 0

        // Fetch completed game stats (on or after draft date)
        let completedStats = try await nbaService.fetchGameStatsForPlayers(
            playerIds: playerIds,
            onOrAfterDate: draftDate,
            season: season
        )

        // Group stats by player_id
        let statsByPlayer: [Int: [PlayerGameStats]] = Dictionary(grouping: completedStats, by: { $0.player.id })
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // For each player, compute their total
        for playerId in playerIds {
            let playerStats = statsByPlayer[playerId] ?? []
            
            if let liveStat = liveManager.getLiveStats(for: playerId) {
                // Player is live: use live FP for today's game, add completed games from other days
                total += liveStat.fantasyPoints
                
                // Add completed stats from days other than today (to avoid double-counting)
                let otherDayStats = playerStats.filter { stat in
                    guard let gameDate = stat.gameDateAsDate else { return false }
                    return !calendar.isDate(gameDate, inSameDayAs: today)
                }
                total += otherDayStats.reduce(0.0) { $0 + $1.fantasyPoints }
            } else {
                // Not live: sum all completed games
                total += playerStats.reduce(0.0) { $0 + $1.fantasyPoints }
            }
        }

        return total
    }
}

enum LeaderboardError: LocalizedError {
    case leagueNotFound

    var errorDescription: String? {
        switch self {
        case .leagueNotFound: return "League not found."
        }
    }
}
