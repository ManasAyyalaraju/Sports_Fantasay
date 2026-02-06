//
//  Sport_Tracker_FantasyApp.swift
//  Sport_Tracker-Fantasy
//
//  Created by Manas Ayyalaraju on 2/3/26.
//

import SwiftUI

@main
struct Sport_Tracker_FantasyApp: App {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    
    init() {
        // Debug fonts on app launch
        #if DEBUG
        FontHelper.debugFonts()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if OnboardingViewModel.hasCompletedOnboarding {
                    ContentView()
                        .task {
                            await SupabaseService.shared.signInAnonymouslyIfNeeded()
                        }
                } else {
                    OnboardingView()
                        .environmentObject(onboardingViewModel)
                }
            }
        }
    }
}
