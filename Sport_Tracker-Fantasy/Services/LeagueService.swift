//
//  LeagueService.swift
//  Sport_Tracker-Fantasy
//
//  Create league, join by invite code, load my leagues.
//

import Combine
import Foundation
import Supabase
import SwiftUI

// MARK: - App models

struct League: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let capacity: Int
    let draftDate: Date
    let inviteCode: String
    let creatorId: UUID
    let status: String
    let season: String
    let createdAt: Date
    let updatedAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var statusDisplay: String {
        switch status {
        case "open": return "Open"
        case "draft_scheduled": return "Draft scheduled"
        case "draft_in_progress": return "Draft in progress"
        case "draft_completed": return "Draft completed"
        case "active": return "Active"
        default: return status
        }
    }
}

struct LeagueMember: Identifiable {
    let id: UUID
    let leagueId: UUID
    let userId: UUID
    let joinedAt: Date
    let draftOrder: Int?
}

@MainActor
final class LeagueService: ObservableObject {
    @Published private(set) var myLeagues: [League] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client = SupabaseManager.shared.client

    private func currentSeason() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let month = calendar.component(.month, from: Date())
        let seasonYear = month >= 10 ? year : year - 1
        return String(seasonYear)
    }

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    /// Create a league and add the creator as first member.
    func createLeague(name: String, capacity: Int, draftDate: Date, creatorId: UUID) async throws -> League {
        var code = generateInviteCode()
        var attempts = 0
        while attempts < 10 {
            let existing: [LeagueRow] = try await client
                .from("leagues")
                .select("id")
                .eq("invite_code", value: code)
                .execute()
                .value
            if existing.isEmpty { break }
            code = generateInviteCode()
            attempts += 1
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let draftDateStr = formatter.string(from: draftDate)

        let leagueInsert = LeagueInsert(
            name: name,
            capacity: capacity,
            draft_date: draftDateStr,
            invite_code: code,
            creator_id: creatorId,
            status: "open",
            season: currentSeason()
        )

        let inserted: [LeagueRow] = try await client
            .from("leagues")
            .insert(leagueInsert)
            .select()
            .execute()
            .value

        guard let row = inserted.first else { throw LeagueServiceError.insertFailed }

        try await client
            .from("league_members")
            .insert(LeagueMemberInsert(league_id: row.id, user_id: creatorId))
            .execute()

        return League(from: row)
    }

    /// Resolve invite code to league and join current user. Throws if full, already member, or invalid code.
    func joinLeague(inviteCode: String, userId: UUID) async throws {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw LeagueServiceError.invalidCode }

        let leagues: [LeagueRow] = try await client
            .from("leagues")
            .select()
            .eq("invite_code", value: code)
            .eq("status", value: "open")
            .execute()
            .value

        guard let league = leagues.first else { throw LeagueServiceError.leagueNotFound }

        let members: [LeagueMemberRow] = try await client
            .from("league_members")
            .select("id")
            .eq("league_id", value: league.id)
            .execute()
            .value

        if members.count >= league.capacity {
            throw LeagueServiceError.leagueFull
        }

        let alreadyMember: [LeagueMemberRow] = try await client
            .from("league_members")
            .select("id")
            .eq("league_id", value: league.id)
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
            .value

        if !alreadyMember.isEmpty {
            throw LeagueServiceError.alreadyMember
        }

        try await client
            .from("league_members")
            .insert(LeagueMemberInsert(league_id: league.id, user_id: userId))
            .execute()
    }

    /// Load leagues the user is a member of.
    func loadMyLeagues(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let refs: [LeagueMemberRefRow] = try await client
                .from("league_members")
                .select("league_id")
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value

            let leagueIds = refs.map(\.league_id)
            if leagueIds.isEmpty {
                myLeagues = []
                return
            }

            let rows: [LeagueRow] = try await client
                .from("leagues")
                .select()
                .in("id", values: leagueIds.map { $0.uuidString.lowercased() })
                .execute()
                .value

            myLeagues = rows.map { League(from: $0) }.sorted { $0.createdAt > $1.createdAt }
        } catch {
            // Don't show cancellation errors to the user (expected when tasks are cancelled)
            if (error as NSError).code == NSURLErrorCancelled {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
                myLeagues = []
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    /// Allow callers (e.g. views) to report an error when they catch one from a throwing method.
    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    /// Load all members of a league.
    func loadLeagueMembers(leagueId: UUID) async throws -> [LeagueMember] {
        let rows: [LeagueMemberFullRow] = try await client
            .from("league_members")
            .select("id, league_id, user_id, joined_at, draft_order")
            .eq("league_id", value: leagueId.uuidString.lowercased())
            .execute()
            .value

        return rows.map { LeagueMember(from: $0) }
    }

    /// Start the draft for a league (creator only). Calls Edge Function; assigns draft order, creates draft row, sets league status.
    func startDraft(leagueId: UUID) async throws {
        let session = try await client.auth.session
        let url = URL(string: SupabaseConfig.supabaseURL)!
            .appendingPathComponent("functions/v1/start-draft")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "Apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["league_id": leagueId.uuidString.lowercased()])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LeagueServiceError.startDraftFailed("Invalid response") }

        if http.statusCode == 200 {
            return
        }
        struct ErrorBody: Decodable { let error: String? }
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? String(data: data, encoding: .utf8) ?? "Unknown error"
        throw LeagueServiceError.startDraftFailed(message)
    }

    /// Fetch profiles for a list of user IDs. Returns a map of userId -> displayName (or fallback).
    /// RLS allows reading profiles of users in the same league.
    func fetchProfiles(userIds: [UUID]) async throws -> [UUID: String] {
        guard !userIds.isEmpty else { return [:] }

        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select("id, display_name")
            .in("id", values: userIds.map { $0.uuidString.lowercased() })
            .execute()
            .value

        var result: [UUID: String] = [:]
        for row in rows {
            if let displayName = row.display_name, !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                result[row.id] = displayName
            }
        }
        return result
    }
}

enum LeagueServiceError: LocalizedError {
    case invalidCode
    case leagueNotFound
    case leagueFull
    case alreadyMember
    case insertFailed
    case startDraftFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "Please enter a valid invite code."
        case .leagueNotFound: return "No open league found with this code."
        case .leagueFull: return "This league is full."
        case .alreadyMember: return "You are already in this league."
        case .insertFailed: return "Failed to create league."
        case .startDraftFailed(let msg): return msg
        }
    }
}

// MARK: - Supabase row types

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

private let leagueDateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func parseLeagueDate(_ s: String) -> Date {
    leagueDateFormatter.date(from: s)
        ?? ISO8601DateFormatter().date(from: s)
        ?? Date()
}

private struct LeagueInsert: Encodable {
    let name: String
    let capacity: Int
    let draft_date: String
    let invite_code: String
    let creator_id: UUID
    let status: String
    let season: String

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(capacity, forKey: .capacity)
        try c.encode(draft_date, forKey: .draft_date)
        try c.encode(invite_code, forKey: .invite_code)
        try c.encode(creator_id.uuidString.lowercased(), forKey: .creator_id)
        try c.encode(status, forKey: .status)
        try c.encode(season, forKey: .season)
    }

    enum CodingKeys: String, CodingKey {
        case name, capacity, draft_date, invite_code, creator_id, status, season
    }
}

private struct LeagueMemberRefRow: Decodable {
    let league_id: UUID
}

private struct LeagueMemberRow: Decodable {
    let id: UUID
}

private struct LeagueMemberFullRow: Decodable {
    let id: UUID
    let league_id: UUID
    let user_id: UUID
    let joined_at: String
    let draft_order: Int?
}

private struct LeagueMemberInsert: Encodable {
    let league_id: UUID
    let user_id: UUID

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(league_id.uuidString.lowercased(), forKey: .league_id)
        try c.encode(user_id.uuidString.lowercased(), forKey: .user_id)
    }

    enum CodingKeys: String, CodingKey {
        case league_id, user_id
    }
}

extension League {
    fileprivate init(from row: LeagueRow) {
        id = row.id
        name = row.name
        capacity = row.capacity
        draftDate = parseLeagueDate(row.draft_date)
        inviteCode = row.invite_code
        creatorId = row.creator_id
        status = row.status
        season = row.season
        createdAt = parseLeagueDate(row.created_at)
        updatedAt = parseLeagueDate(row.updated_at)
    }
}

extension LeagueMember {
    fileprivate init(from row: LeagueMemberFullRow) {
        id = row.id
        leagueId = row.league_id
        userId = row.user_id
        joinedAt = parseLeagueDate(row.joined_at)
        draftOrder = row.draft_order
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let display_name: String?
}
