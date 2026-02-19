//
//  SupabaseManager.swift
//  Sport_Tracker-Fantasy
//
//  Central Supabase client. Use SupabaseManager.shared for auth, database, and realtime.
//

import Foundation
import Supabase

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let url = URL(string: SupabaseConfig.supabaseURL) ?? URL(string: "https://placeholder.supabase.co")!
        
        // Opt into new initial-session behavior: emit stored session immediately, then refresh if needed.
        // We already check session?.isExpired in AuthViewModel.observeAuthState() for validity.
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
        )
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.supabaseAnonKey,
            options: options
        )
    }

    /// Current auth session. Use for checking if user is signed in and getting user id.
    var auth: AuthClient {
        client.auth
    }
}
