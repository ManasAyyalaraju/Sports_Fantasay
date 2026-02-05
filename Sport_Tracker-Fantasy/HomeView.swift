//
//  HomeView.swift
//  Sport_Tracker-Fantasy
//
//  Home tab – displays favorite players and their recent performance.
//

import SwiftUI

struct HomeView: View {
    @Binding var favoritePlayerIds: Set<Int>
    
    @State private var favoritePlayers: [NBAPlayer] = []
    @State private var playerStats: [Int: [PlayerGameStats]] = [:] // playerId -> stats
    @State private var playerAverages: [Int: SeasonAverages] = [:] // playerId -> averages
    @State private var isLoading = true
    @State private var selectedPlayer: NBAPlayer?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Content
                    if isLoading && favoritePlayerIds.isEmpty == false {
                        loadingView
                    } else if favoritePlayers.isEmpty {
                        emptyStateView
                    } else {
                        favoritePlayersSection
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "0A0A0A"), Color(hex: "1A1A1A")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .sheet(item: $selectedPlayer) { player in
                PlayerDetailView(
                    player: player,
                    isFavorite: favoritePlayerIds.contains(player.id),
                    onFavoriteToggle: { toggleFavorite(player) }
                )
            }
            .task {
                await loadFavoritePlayers()
            }
            .onChange(of: favoritePlayerIds) { _ in
                Task {
                    await loadFavoritePlayers()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NBA Fantasy")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Track your favorite players")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                
                Spacer()
                
                // Stats badge
                if !favoritePlayers.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(favoritePlayers.count)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "FF6B35"))
                        Text("favorites")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.top, 12)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "FF6B35"))
            Text("Loading your favorites...")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "1C1C1E"))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Favorites Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                Text("Head to the Players tab to add your\nfavorite NBA players")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Tip Card
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "FFD700"))
                
                Text("Tap the ⭐ next to any player to add them to your favorites")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(16)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Favorite Players Section
    
    private var favoritePlayersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Favorites")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .foregroundStyle(Color(hex: "FFD700"))
            }
            
            ForEach(favoritePlayers) { player in
                FavoritePlayerCard(
                    player: player,
                    averages: playerAverages[player.id],
                    recentStats: playerStats[player.id] ?? [],
                    onRemove: { toggleFavorite(player) }
                )
                .onTapGesture {
                    selectedPlayer = player
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadFavoritePlayers() async {
        guard !favoritePlayerIds.isEmpty else {
            favoritePlayers = []
            playerStats = [:]
            playerAverages = [:]
            isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            // Fetch all players first
            let allPlayers = try await LiveScoresAPI.shared.fetchAllPlayers()
            
            // Filter to favorites
            favoritePlayers = allPlayers.filter { favoritePlayerIds.contains($0.id) }
            
            // Fetch stats and averages for each favorite player
            for player in favoritePlayers {
                do {
                    async let statsTask = LiveScoresAPI.shared.fetchPlayerStats(playerId: player.id, lastNGames: 3)
                    async let averagesTask = LiveScoresAPI.shared.fetchSeasonAverages(playerId: player.id)
                    
                    let (stats, averages) = try await (statsTask, averagesTask)
                    playerStats[player.id] = stats
                    if let avg = averages {
                        playerAverages[player.id] = avg
                    }
                } catch {
                    #if DEBUG
                    print("Failed to load stats for player \(player.id):", error)
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("Failed to load favorite players:", error)
            #endif
        }
        
        isLoading = false
    }
    
    private func toggleFavorite(_ player: NBAPlayer) {
        if favoritePlayerIds.contains(player.id) {
            favoritePlayerIds.remove(player.id)
        } else {
            favoritePlayerIds.insert(player.id)
        }
    }
}

// MARK: - Favorite Player Card

struct FavoritePlayerCard: View {
    let player: NBAPlayer
    let averages: SeasonAverages?
    let recentStats: [PlayerGameStats]
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Player Info Row
            HStack(spacing: 16) {
                // Player Photo
                PlayerPhotoView(player: player, size: 70)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.fullName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                    
                    HStack(spacing: 8) {
                        Text(player.teamAbbreviation)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: player.teamPrimaryColor))
                        
                        if !player.position.isEmpty {
                            Text("•")
                                .foregroundStyle(Color(hex: "3A3A3C"))
                            Text(player.position)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                    }
                    
                    // Season averages
                    if let avg = averages, avg.gamesPlayed > 0 {
                        HStack(spacing: 12) {
                            statBadge(value: String(format: "%.1f", avg.pts), label: "PPG")
                            statBadge(value: String(format: "%.1f", avg.reb), label: "RPG")
                            statBadge(value: String(format: "%.1f", avg.ast), label: "APG")
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // Remove button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onRemove()
                    }
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "FFD700"))
                }
                .buttonStyle(.plain)
            }
            
            // Recent Stats
            if !recentStats.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECENT GAMES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    
                    HStack(spacing: 8) {
                        ForEach(recentStats.prefix(3)) { stat in
                            miniStatCard(stat)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(Color(hex: "3A3A3C"))
                    Text("No recent stats available")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .padding(.top, 4)
            }
            
            // View Details hint
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("View details")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "FF6B35"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: player.teamPrimaryColor).opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func statBadge(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "FF6B35"))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
    }
    
    private func miniStatCard(_ stat: PlayerGameStats) -> some View {
        VStack(spacing: 6) {
            Text(stat.formattedDate)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
            
            Text("\(stat.pts ?? 0)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "FF6B35"))
            
            Text("PTS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
            
            HStack(spacing: 8) {
                miniStat(value: stat.reb ?? 0, label: "R")
                miniStat(value: stat.ast ?? 0, label: "A")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func miniStat(value: Int, label: String) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
    }
}

#Preview {
    HomeView(favoritePlayerIds: .constant([]))
}
