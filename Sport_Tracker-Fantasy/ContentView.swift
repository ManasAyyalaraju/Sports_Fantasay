//
//  ContentView.swift
//  Sport_Tracker-Fantasy
//
//  NBA Fantasy App - Main Content View
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("favoritePlayerIds") private var favoritePlayerIdsData: Data = Data()
    @State private var favoritePlayerIds: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Content views
            Group {
                switch selectedTab {
                case 0:
                    HomeView(favoritePlayerIds: $favoritePlayerIds)
                case 1:
                    PlayersView(favoritePlayerIds: $favoritePlayerIds)
                case 2:
                    ProfileView()
                default:
                    HomeView(favoritePlayerIds: $favoritePlayerIds)
                }
            }
            
            // Liquid glass tabbar overlay
            VStack {
                Spacer()
                LiquidGlassTabBar(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            // Load saved favorites
            loadFavorites()
        }
        .onChange(of: favoritePlayerIds) { newValue in
            saveFavorites(newValue)
        }
    }
    
    private func loadFavorites() {
        guard !favoritePlayerIdsData.isEmpty else { return }
        do {
            let decoded = try JSONDecoder().decode(Set<Int>.self, from: favoritePlayerIdsData)
            favoritePlayerIds = decoded
        } catch {
        }
    }
    
    private func saveFavorites(_ favorites: Set<Int>) {
        do {
            let encoded = try JSONEncoder().encode(favorites)
            favoritePlayerIdsData = encoded
        } catch {
        }
    }
}

#Preview {
    ContentView()
}
