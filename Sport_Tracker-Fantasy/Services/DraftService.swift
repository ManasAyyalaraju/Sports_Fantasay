//
//  DraftService.swift
//  Sport_Tracker-Fantasy
//
//  Phase 5.2: Load draft state, compute whose turn, call make-pick Edge Function.
//

import Combine
import Foundation
import Supabase
import SwiftUI

struct Draft: Identifiable {
    let id: UUID
    let leagueId: UUID
    let status: String
    let currentRound: Int
    let currentPickIndex: Int
    let totalPicksMade: Int
    let totalRounds: Int
    let startedAt: Date?
    let completedAt: Date?
}

struct DraftState {
    let draft: Draft
    let capacity: Int
    /// User id whose turn it is (nil if draft complete).
    let whoseTurnUserId: UUID?
    /// Display name for whose turn (optional).
    let whoseTurnDisplayName: String?
    /// Members in draft order (1..N) for current round.
    let membersInOrder: [LeagueMember]
}

enum DraftServiceError: LocalizedError {
    case notFound
    case makePickFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Draft not found."
        case .makePickFailed(let msg): return msg
        }
    }
}

@MainActor
final class DraftService: ObservableObject {
    @Published private(set) var draftState: DraftState?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isMakingPick = false

    private let client = SupabaseManager.shared.client

    /// Snake order: round 1 = draft_order 1,2,...,N; round 2 = N,...,1.
    /// For round r (1-based), pick index i (0-based): orderIndex = (r % 2 == 1) ? i : (capacity - 1 - i)
    private func orderIndexForPick(round: Int, pickIndex: Int, capacity: Int) -> Int {
        round % 2 == 1 ? pickIndex : (capacity - 1 - pickIndex)
    }

    /// Load draft and compute whose turn. Returns nil if no draft or not in progress.
    func loadDraft(leagueId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let draftRows: [DraftRow] = try await client
                .from("drafts")
                .select("id, league_id, status, current_round, current_pick_index, total_picks_made, total_rounds, started_at, completed_at")
                .eq("league_id", value: leagueId.uuidString.lowercased())
                .execute()
                .value
            let draftRow = draftRows.first

            guard let row = draftRow, row.status == "in_progress" || row.status == "completed" else {
                draftState = nil
                return
            }

            let leagueRows: [LeagueCapacityRow] = try await client
                .from("leagues")
                .select("capacity")
                .eq("id", value: leagueId.uuidString.lowercased())
                .execute()
                .value
            let capacity = leagueRows.first?.capacity ?? 0

            let memberRows: [DraftMemberRow] = try await client
                .from("league_members")
                .select("id, league_id, user_id, joined_at, draft_order")
                .eq("league_id", value: leagueId.uuidString.lowercased())
                .execute()
                .value

            let members = memberRows
                .compactMap { LeagueMember(fromDraftRow: $0) }
                .sorted { ($0.draftOrder ?? 0) < ($1.draftOrder ?? 0) }
            guard members.count == capacity else {
                draftState = DraftState(from: row, capacity: capacity, members: members)
                return
            }

            let draft = Draft(from: row)
            let totalPicks = capacity * draft.totalRounds
            let whoseTurnUserId: UUID?
            if draft.totalPicksMade >= totalPicks {
                whoseTurnUserId = nil
            } else {
                let idx = orderIndexForPick(round: draft.currentRound, pickIndex: draft.currentPickIndex, capacity: capacity)
                whoseTurnUserId = members[idx].userId
            }

            var displayName: String?
            if let uid = whoseTurnUserId {
                let profiles: [ProfileRow] = try await client
                    .from("profiles")
                    .select("id, display_name")
                    .eq("id", value: uid.uuidString.lowercased())
                    .execute()
                    .value
                displayName = profiles.first?.display_name
            }

            draftState = DraftState(
                draft: draft,
                capacity: capacity,
                whoseTurnUserId: whoseTurnUserId,
                whoseTurnDisplayName: displayName,
                membersInOrder: members
            )
        } catch {
            errorMessage = error.localizedDescription
            draftState = nil
        }
    }

    /// Make a pick (current user). Calls make-pick Edge Function.
    func makePick(leagueId: UUID, playerId: Int) async throws {
        isMakingPick = true
        defer { isMakingPick = false }
        let session = try await client.auth.session
        let url = URL(string: SupabaseConfig.supabaseURL)!
            .appendingPathComponent("functions/v1/make-pick")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "Apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct MakePickBody: Encodable {
            let league_id: String
            let player_id: Int
        }
        request.httpBody = try JSONEncoder().encode(MakePickBody(
            league_id: leagueId.uuidString.lowercased(),
            player_id: playerId
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DraftServiceError.makePickFailed("Invalid response") }

        if http.statusCode == 200 {
            await loadDraft(leagueId: leagueId)
            return
        }
        struct ErrorBody: Decodable { let error: String? }
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? String(data: data, encoding: .utf8) ?? "Unknown error"
        throw DraftServiceError.makePickFailed(message)
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Supabase row types

private struct DraftRow: Decodable {
    let id: String
    let league_id: String
    let status: String
    let current_round: Int
    let current_pick_index: Int
    let total_picks_made: Int
    let total_rounds: Int
    let started_at: String?
    let completed_at: String?
}

private struct LeagueCapacityRow: Decodable {
    let capacity: Int
}

private struct ProfileRow: Decodable {
    let id: UUID
    let display_name: String?
}

private let draftDateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func parseDraftDate(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    return draftDateFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
}

extension Draft {
    fileprivate init(from row: DraftRow) {
        id = UUID(uuidString: row.id) ?? UUID()
        leagueId = UUID(uuidString: row.league_id) ?? UUID()
        status = row.status
        currentRound = row.current_round
        currentPickIndex = row.current_pick_index
        totalPicksMade = row.total_picks_made
        totalRounds = row.total_rounds
        startedAt = parseDraftDate(row.started_at)
        completedAt = parseDraftDate(row.completed_at)
    }
}

private struct DraftMemberRow: Decodable {
    let id: UUID
    let league_id: UUID
    let user_id: UUID
    let joined_at: String
    let draft_order: Int?
}

extension LeagueMember {
    fileprivate init?(fromDraftRow row: DraftMemberRow) {
        guard row.draft_order != nil else { return nil }
        id = row.id
        leagueId = row.league_id
        userId = row.user_id
        joinedAt = draftDateParser(row.joined_at)
        draftOrder = row.draft_order
    }
}

private func draftDateParser(_ s: String) -> Date {
    draftDateFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Date()
}

extension DraftState {
    fileprivate init(from row: DraftRow, capacity: Int, members: [LeagueMember]) {
        let draft = Draft(from: row)
        self.init(
            draft: draft,
            capacity: capacity,
            whoseTurnUserId: nil,
            whoseTurnDisplayName: nil,
            membersInOrder: members
        )
    }
}
