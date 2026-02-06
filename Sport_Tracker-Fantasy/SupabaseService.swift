//
//  SupabaseService.swift
//  Sport_Tracker-Fantasy
//
//  Service layer for Supabase database operations.
//

import Foundation
import Supabase

typealias Session = Supabase.Session
typealias User = Supabase.User

@MainActor
final class SupabaseService: Sendable {
    static let shared = SupabaseService()
    
    private var client: Supabase.SupabaseClient? {
        SupabaseClient.shared
    }
    
    private init() {}
    
    // MARK: - Auth
    
    /// Signs up a new user with email and password
    func signUp(email: String, password: String, name: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        
        // Sign up the user
        let session = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        // Create user profile (name stored in our user_profiles table)
        let userId = session.user.id
        try await createUserProfile(userId: userId, name: name, email: email)
    }
    
    /// Signs in an existing user with email and password
    func signIn(email: String, password: String) async throws {
        guard let client else { throw SupabaseError.notConfigured }
        _ = try await client.auth.signIn(email: email, password: password)
    }
    
    /// Signs out the current user
    func signOut() async throws {
        guard let client else { throw SupabaseError.notConfigured }
        try await client.auth.signOut()
    }
    
    /// Gets the current user session
    func getCurrentSession() async throws -> Session? {
        guard let client else { return nil }
        do {
            return try await client.auth.session
        } catch {
            return nil
        }
    }
    
    /// Gets the current user
    func getCurrentUser() async throws -> User? {
        guard let client else { return nil }
        do {
            let session = try await client.auth.session
            return session.user
        } catch {
            return nil
        }
    }
    
    /// Checks if user is authenticated
    var isAuthenticated: Bool {
        get async {
            guard let client else { return false }
            do {
                _ = try await client.auth.session
                return true
            } catch {
                return false
            }
        }
    }
    
    /// Signs in anonymously as fallback (for guests)
    func signInAnonymouslyIfNeeded() async {
        guard let client else { return }
        do {
            _ = try await client.auth.session
            return // Already have a session
        } catch {
            // No session – sign in anonymously
        }
        do {
            _ = try await client.auth.signInAnonymously()
        } catch {
            #if DEBUG
            print("Supabase anonymous sign-in failed:", error)
            #endif
        }
    }
    
    // MARK: - User Profile
    
    private func createUserProfile(userId: UUID, name: String, email: String) async throws {
        guard let client else { return }
        struct Profile: Encodable {
            let userId: UUID
            let name: String
            let email: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case name
                case email
            }
        }
        try await client
            .from("user_profiles")
            .insert(Profile(userId: userId, name: name, email: email))
            .execute()
    }
    
    func getUserProfile() async throws -> UserProfile? {
        guard let client else { return nil }
        let userId = try await requireUserId()
        let profiles: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return profiles.first
    }
    
    // MARK: - Followed Teams
    
    func fetchFollowedTeams() async throws -> [FollowedTeam] {
        guard let client else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await client
            .from("followed_teams")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func addFollowedTeam(teamName: String, league: String, sport: String = "basketball") async throws {
        guard let client else { return }
        let userId = try await requireUserId()
        struct Insert: Encodable {
            let userId: UUID
            let teamName: String
            let league: String
            let sport: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case teamName = "team_name"
                case league
                case sport
            }
        }
        try await client
            .from("followed_teams")
            .insert(Insert(userId: userId, teamName: teamName, league: league, sport: sport))
            .execute()
    }
    
    func removeFollowedTeam(id: UUID) async throws {
        guard let client else { return }
        try await client
            .from("followed_teams")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Followed Players
    
    func fetchFollowedPlayers() async throws -> [FollowedPlayer] {
        guard let client else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await client
            .from("followed_players")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func addFollowedPlayer(playerName: String, teamName: String?, sport: String = "basketball") async throws {
        guard let client else { return }
        let userId = try await requireUserId()
        struct Insert: Encodable {
            let userId: UUID
            let playerName: String
            let teamName: String?
            let sport: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case playerName = "player_name"
                case teamName = "team_name"
                case sport
            }
        }
        try await client
            .from("followed_players")
            .insert(Insert(userId: userId, playerName: playerName, teamName: teamName, sport: sport))
            .execute()
    }
    
    func removeFollowedPlayer(id: UUID) async throws {
        guard let client else { return }
        try await client
            .from("followed_players")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Fantasy Squads
    
    func fetchFantasySquads() async throws -> [FantasySquad] {
        guard let client else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await client
            .from("fantasy_squads")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func createFantasySquad(name: String, sport: String = "basketball") async throws -> FantasySquad {
        guard let client else { throw SupabaseError.notConfigured }
        let userId = try await requireUserId()
        struct Insert: Encodable {
            let userId: UUID
            let name: String
            let sport: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case name
                case sport
            }
        }
        let inserted: [FantasySquad] = try await client
            .from("fantasy_squads")
            .insert(Insert(userId: userId, name: name, sport: sport))
            .select()
            .execute()
            .value
        guard let squad = inserted.first else { throw SupabaseError.insertFailed }
        return squad
    }
    
    func deleteFantasySquad(id: UUID) async throws {
        guard let client else { return }
        try await client
            .from("fantasy_squads")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Helpers
    
    private func requireUserId() async throws -> UUID {
        guard let client else { throw SupabaseError.notConfigured }
        let session = try await client.auth.session
        return session.user.id
    }
}

enum SupabaseError: Error {
    case notConfigured
    case notAuthenticated
    case insertFailed
}
