//
//  SupabaseConfig.swift
//  Sport_Tracker-Fantasy
//
//  Replace the values below with your project URL and anon key
//  from Supabase Dashboard → Project Settings → API.
//

import Foundation

enum SupabaseConfig {
    /// Your Supabase project URL (e.g. https://xxxxxxxxxxxx.supabase.co)
    static let supabaseURL = "https://acslmphtpplkltisjlpp.supabase.co"

    /// Your Supabase anon (public) key — safe for use in the app. Never use service_role here.
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjc2xtcGh0cHBsa2x0aXNqbHBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4Njk3OTEsImV4cCI6MjA4NjQ0NTc5MX0.GAz-0a3tjSqGRE4R1M48tlLuEP001bIy5ZlCb6wDoz0"

    /// True once you have set a real URL and key (used to avoid calling Supabase before config is set).
    static var isConfigured: Bool {
        !supabaseURL.contains("placeholder") && !supabaseAnonKey.contains("placeholder")
    }
}
