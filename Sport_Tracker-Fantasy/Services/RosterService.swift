//
//  RosterService.swift
//  Sport_Tracker-Fantasy
//
//  Load roster (player ids) for a league + user; add player for testing (Phase 3).
//

import Combine
import Foundation
import Supabase
import SwiftUI

struct RosterPick: Identifiable {
    let id: UUID
    let leagueId: UUID
    let userId: UUID
    let playerId: Int
    let pickNumber: Int
    let round: Int
    let createdAt: Date
}

@MainActor
final class RosterService: ObservableObject {
    static let shared = RosterService()

    @Published private(set) var rosterPlayerIds: Set<Int> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client = SupabaseManager.shared.client

    /// Load roster (player ids) for the given league and user.
    func loadRoster(leagueId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let rows: [RosterPickRow] = try await client
                .from("roster_picks")
                .select("id, league_id, user_id, player_id, pick_number, round, created_at")
                .eq("league_id", value: leagueId.uuidString.lowercased())
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value

            rosterPlayerIds = Set(rows.map(\.player_id))
        } catch {
            errorMessage = error.localizedDescription
            rosterPlayerIds = []
        }
    }

    /// Add a player to the current user's roster for the league (for testing before draft).
    /// Does not enforce roster size; use for Phase 3 manual testing.
    func addPlayerToRoster(leagueId: UUID, userId: UUID, playerId: Int, pickNumber: Int, round: Int) async throws {
        struct Insert: Encodable {
            let league_id: String
            let user_id: String
            let player_id: Int
            let pick_number: Int
            let round: Int
        }
        let insert = Insert(
            league_id: leagueId.uuidString.lowercased(),
            user_id: userId.uuidString.lowercased(),
            player_id: playerId,
            pick_number: pickNumber,
            round: round
        )
        try await client
            .from("roster_picks")
            .insert(insert)
            .execute()

        rosterPlayerIds.insert(playerId)
    }

    /// Remove a player from the current user's roster (e.g. undo test add).
    /// Uses current session user id. SELECT before delete to confirm row exists; DELETE by league_id, user_id, player_id; verify with .select("id"); updates local state only after delete succeeds.
    func removePlayerFromRoster(leagueId: UUID, playerId: Int) async throws {
        errorMessage = nil

        let session = try await client.auth.session
        let userId = session.user.id

        let leagueIdStr = leagueId.uuidString.lowercased()
        let userIdStr = userId.uuidString.lowercased()
        // Schema: player_id is int; use Int. If your column is text, use String(playerId) instead.
        let playerIdValue: Int = playerId

        // 1) SELECT with same filters and log to confirm row exists
        do {
            let existing: [RosterPickRow] = try await client
                .from("roster_picks")
                .select("id, league_id, user_id, player_id, pick_number, round, created_at")
                .eq("league_id", value: leagueIdStr)
                .eq("user_id", value: userIdStr)
                .eq("player_id", value: playerIdValue)
                .execute()
                .value
            if existing.isEmpty {
                print("[RosterService] SELECT before delete: 0 rows (league: \(leagueId), user: \(userId), playerId: \(playerId)). Cannot delete.")
                throw NSError(domain: "RosterService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No roster pick found for this league and player."])
            }
            print("[RosterService] SELECT before delete: \(existing.count) row(s) – id: \(existing.map(\.id))")
        } catch {
            errorMessage = error.localizedDescription
            print("[RosterService] SELECT before delete failed: \(error)")
            throw error
        }

        // 2) DELETE with same filters; return deleted id for verification
        do {
            struct DeletedId: Decodable { let id: UUID }
            let deleted: [DeletedId] = try await client
                .from("roster_picks")
                .delete()
                .eq("league_id", value: leagueIdStr)
                .eq("user_id", value: userIdStr)
                .eq("player_id", value: playerIdValue)
                .select("id")
                .execute()
                .value

            if deleted.isEmpty {
                print("[RosterService] DELETE succeeded but returned 0 rows (RLS may have hidden the row on delete).")
                throw NSError(domain: "RosterService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Delete did not match any row. Check RLS policy for roster_picks delete."])
            }
            print("[RosterService] Deleted roster_picks id(s): \(deleted.map(\.id))")
            rosterPlayerIds.remove(playerId)
        } catch {
            let message = "Failed to remove player from roster: \(error.localizedDescription). Check RLS/permissions for roster_picks delete."
            errorMessage = message
            print("[RosterService] \(message)")
            throw error
        }
    }

    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    /// Clear in-memory roster (e.g. when no league selected).
    func clearRoster() {
        rosterPlayerIds = []
    }

    func clearError() {
        errorMessage = nil
    }

    /// Load all roster picks for a league (all users). RLS allows league members to read all picks.
    func loadAllRosterPicks(leagueId: UUID) async throws -> [RosterPick] {
        let rows: [RosterPickRow] = try await client
            .from("roster_picks")
            .select("id, league_id, user_id, player_id, pick_number, round, created_at")
            .eq("league_id", value: leagueId.uuidString.lowercased())
            .execute()
            .value

        return rows.map { RosterPick(from: $0) }
    }
}

private struct RosterPickRow: Decodable {
    let id: UUID
    let league_id: UUID
    let user_id: UUID
    let player_id: Int
    let pick_number: Int
    let round: Int
    let created_at: String
}

extension RosterPick {
    fileprivate init(from row: RosterPickRow) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        id = row.id
        leagueId = row.league_id
        userId = row.user_id
        playerId = row.player_id
        pickNumber = row.pick_number
        round = row.round
        createdAt = dateFormatter.date(from: row.created_at)
            ?? ISO8601DateFormatter().date(from: row.created_at)
            ?? Date()
    }
}
