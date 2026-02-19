//
//  Sport_Tracker_FantasyApp.swift
//  Sport_Tracker-Fantasy
//
//  Created by Manas Ayyalaraju on 2/3/26.
//

import SwiftUI
import Supabase

@main
struct Sport_Tracker_FantasyApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        // Initialize Supabase when the app launches (uses SupabaseConfig URL and anon key).
        _ = SupabaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    Task { @MainActor in
                        SupabaseManager.shared.client.auth.handle(url)
                    }
                }
        }
    }
}
