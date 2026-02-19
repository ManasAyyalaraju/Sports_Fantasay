//
//  FavoritesService.swift
//  Sport_Tracker-Fantasy
//
//  Stores favorite player IDs per account in Supabase. Only used when signed in.
//

import Foundation
import Combine
import Supabase
import SwiftUI

@MainActor
final class FavoritesService: ObservableObject {
    @Published private(set) var favoritePlayerIds: Set<Int> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client = SupabaseManager.shared.client

    /// Loads favorites for the current user from Supabase. Call when ContentView appears or user changes.
    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let rows: [FavoriteRow] = try await client
                .from("user_favorite_players")
                .select("player_id")
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value

            favoritePlayerIds = Set(rows.map(\.player_id))
        } catch {
            errorMessage = error.localizedDescription
            favoritePlayerIds = []
        }
    }

    /// Adds a player to favorites (Supabase + local state).
    func addFavorite(playerId: Int, userId: UUID) async {
        do {
            try await client
                .from("user_favorite_players")
                .insert(FavoriteRowInsert(user_id: userId, player_id: playerId))
                .execute()

            favoritePlayerIds.insert(playerId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes a player from favorites (Supabase + local state).
    func removeFavorite(playerId: Int, userId: UUID) async {
        do {
            try await client
                .from("user_favorite_players")
                .delete()
                .eq("user_id", value: userId.uuidString.lowercased())
                .eq("player_id", value: playerId)
                .execute()

            favoritePlayerIds.remove(playerId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggle: add if not in set, remove if in set. Call with current user id.
    func toggleFavorite(playerId: Int, userId: UUID) async {
        if favoritePlayerIds.contains(playerId) {
            await removeFavorite(playerId: playerId, userId: userId)
        } else {
            await addFavorite(playerId: playerId, userId: userId)
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Supabase row types

private struct FavoriteRow: Decodable {
    let player_id: Int
}

private struct FavoriteRowInsert: Encodable {
    let user_id: UUID
    let player_id: Int

    enum CodingKeys: String, CodingKey {
        case user_id
        case player_id
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id.uuidString.lowercased(), forKey: .user_id)
        try c.encode(player_id, forKey: .player_id)
    }
}
