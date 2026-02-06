//
//  SupabaseModels.swift
//  Sport_Tracker-Fantasy
//
//  Codable models for Supabase tables.
//

import Foundation

struct FollowedTeam: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let teamName: String
    let league: String
    let sport: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case teamName = "team_name"
        case league
        case sport
        case createdAt = "created_at"
    }
}

struct FollowedPlayer: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let playerName: String
    let teamName: String?
    let sport: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case playerName = "player_name"
        case teamName = "team_name"
        case sport
        case createdAt = "created_at"
    }
}

struct FantasySquad: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let sport: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case sport
        case createdAt = "created_at"
    }
}

struct FantasySquadPlayer: Codable, Identifiable, Sendable {
    let id: UUID
    let squadId: UUID
    let playerName: String
    let teamName: String?
    let position: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case squadId = "squad_id"
        case playerName = "player_name"
        case teamName = "team_name"
        case position
        case createdAt = "created_at"
    }
}

struct UserProfile: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let email: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case email
        case createdAt = "created_at"
    }
}
