//
//  SupabaseConfig.swift
//  Sport_Tracker-Fantasy
//
//  Configuration for the fantasyball Supabase project.
//  Get your Project URL and anon key from: Supabase Dashboard → Project Settings → API
//

import Foundation

enum SupabaseConfig {
    /// Your fantasyball Supabase project URL (e.g. https://xxxxx.supabase.co)
    static let url = "https://mkrolytvubiqklxmggdt.supabase.co"
    
    /// Your project's anon (public) key – safe for client-side use
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcm9seXR2dWJpcWtseG1nZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzNDY5NjUsImV4cCI6MjA4NTkyMjk2NX0.2e-GEyuBUV1Dgv5R8dBXYm53u14gTUUFWY4w2gFrk5A"
    
    /// Returns true when both URL and key are configured (not placeholders)
    static var isConfigured: Bool {
        !url.isEmpty &&
        !anonKey.isEmpty &&
        url != "YOUR_SUPABASE_URL" &&
        anonKey != "YOUR_SUPABASE_ANON_KEY"
    }
}
