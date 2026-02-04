//
//  ContentView.swift
//  Sport_Tracker-Fantasy
//
//  Created by Manas Ayyalaraju on 2/3/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            FantasyView()
                .tabItem {
                    Image(systemName: "sportscourt.fill")
                    Text("Fantasy")
                }
            
            FollowingView()
                .tabItem {
                    Image(systemName: "star.fill")
                    Text("Following")
                }
        }
        .tint(AppColors.accent)
    }
}

#Preview {
    ContentView()
}
