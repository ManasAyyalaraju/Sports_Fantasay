//
//  SupabaseClient.swift
//  Sport_Tracker-Fantasy
//
//  Shared Supabase client for the fantasyball backend.
//

import Foundation
import Supabase

enum SupabaseClient {
    private static var _shared: Supabase.SupabaseClient?
    
    /// The shared Supabase client. Returns nil if not configured.
    static var shared: Supabase.SupabaseClient? {
        if _shared == nil && SupabaseConfig.isConfigured {
            guard let url = URL(string: SupabaseConfig.url) else { return nil }
            _shared = Supabase.SupabaseClient(
                supabaseURL: url,
                supabaseKey: SupabaseConfig.anonKey
            )
        }
        return _shared
    }
    
    /// Resets the client (e.g. after config change)
    static func reset() {
        _shared = nil
    }
}
