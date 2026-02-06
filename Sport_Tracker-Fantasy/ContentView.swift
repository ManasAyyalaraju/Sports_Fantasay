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
        TabView(selection: $selectedTab) {
            HomeView(favoritePlayerIds: $favoritePlayerIds)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            PlayersView(favoritePlayerIds: $favoritePlayerIds)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.3.fill" : "person.3")
                    Text("Players")
                }
                .tag(1)
        }
        .tint(Color(hex: "FF6B35"))
        .onAppear {
            // Load saved favorites
            loadFavorites()
            
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: "1C1C1E"))
            
            // Unselected state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color(hex: "8E8E93"))
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color(hex: "8E8E93"))
            ]
            
            // Selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "FF6B35"))
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color(hex: "FF6B35"))
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
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
