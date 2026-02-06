//
//  HomeView.swift
//  Sport_Tracker-Fantasy
//
//  Home tab – displays favorite players and their recent performance.
//

import SwiftUI

struct HomeView: View {
    @Binding var favoritePlayerIds: Set<Int>
    
    @StateObject private var liveManager = LiveGameManager.shared
    @State private var favoritePlayers: [NBAPlayer] = []
    @State private var playerStats: [Int: [PlayerGameStats]] = [:] // playerId -> stats
    @State private var playerAverages: [Int: SeasonAverages] = [:] // playerId -> averages
    @State private var isLoading = true
    @State private var selectedPlayer: NBAPlayer?
    
    /// Sorted players with live players at the top
    private var sortedFavoritePlayers: [NBAPlayer] {
        favoritePlayers.sorted { player1, player2 in
            let isLive1 = liveManager.isPlayerLive(player1.id)
            let isLive2 = liveManager.isPlayerLive(player2.id)
            
            // Live players come first
            if isLive1 != isLive2 {
                return isLive1
            }
            
            // Among live players, sort by points (higher first)
            if isLive1 && isLive2 {
                let pts1 = liveManager.getLiveStats(for: player1.id)?.points ?? 0
                let pts2 = liveManager.getLiveStats(for: player2.id)?.points ?? 0
                return pts1 > pts2
            }
            
            // Non-live players maintain original order
            return false
        }
    }
    
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
            .onChange(of: favoritePlayerIds) { newIds in
                Task {
                    await loadFavoritePlayers()
                }
                // Update live tracking when favorites change
                liveManager.updateTrackedPlayers(newIds)
            }
            .onAppear {
                // Start or resume live tracking when home screen appears
                if !favoritePlayerIds.isEmpty {
                    liveManager.startTracking(playerIds: favoritePlayerIds)
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
                
                // Live status and stats badge
                HStack(spacing: 12) {
                    // Live indicator
                    if !liveManager.liveGames.isEmpty {
                        Button {
                            Task {
                                await liveManager.refresh()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if liveManager.isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(Color.white)
                                } else {
                                    Circle()
                                        .fill(Color(hex: "FF3B30"))
                                        .frame(width: 8, height: 8)
                                        .modifier(PulsingAnimation())
                                }
                                
                                Text("\(liveManager.liveGames.count) LIVE")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(Color(hex: "FF3B30"))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "FF3B30").opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
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
                
                // Show live player count if any
                let liveCount = favoritePlayers.filter { liveManager.isPlayerLive($0.id) }.count
                if liveCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "FF3B30"))
                            .frame(width: 6, height: 6)
                        Text("\(liveCount) playing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF3B30"))
                    }
                } else {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(hex: "FFD700"))
                }
            }
            
            ForEach(sortedFavoritePlayers) { player in
                FavoritePlayerCard(
                    player: player,
                    averages: playerAverages[player.id],
                    recentStats: playerStats[player.id] ?? [],
                    liveStats: liveManager.getLiveStats(for: player.id),
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
                }
            }
        } catch {
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
    let liveStats: LivePlayerStat?
    let onRemove: () -> Void
    
    private var isLive: Bool {
        liveStats != nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Live Game Banner (if playing)
            if let live = liveStats {
                liveGameBanner(live)
            }
            
            // Player Info Row
            HStack(spacing: 16) {
                // Player Photo with live indicator
                ZStack(alignment: .topTrailing) {
                    PlayerPhotoView(player: player, size: 70)
                    
                    if isLive {
                        Circle()
                            .fill(Color(hex: "FF3B30"))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "1C1C1E"), lineWidth: 2)
                            )
                            .modifier(PulsingAnimation())
                            .offset(x: 2, y: -2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(player.displayFullName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                        
                        if isLive {
                            Text("LIVE")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: "FF3B30"))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    
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
                    
                    // Show live stats or season averages
                    if let live = liveStats {
                        // Live stats
                        HStack(spacing: 12) {
                            liveStatBadge(value: "\(live.points)", label: "PTS", highlight: true)
                            liveStatBadge(value: "\(live.rebounds)", label: "REB")
                            liveStatBadge(value: "\(live.assists)", label: "AST")
                        }
                        .padding(.top, 4)
                    } else if let avg = averages, avg.gamesPlayed > 0 {
                        // Season averages
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
            
            // Recent Stats (only show if not live)
            if !isLive {
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
            }
            
            // View Details hint
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(isLive ? "Watch live" : "View details")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isLive ? Color(hex: "FF3B30") : Color(hex: "FF6B35"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isLive ?
                            AnyShapeStyle(Color(hex: "FF3B30").opacity(0.5)) :
                            AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: player.teamPrimaryColor).opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )),
                            lineWidth: isLive ? 2 : 1
                        )
                )
        )
    }
    
    // MARK: - Live Game Banner
    
    private func liveGameBanner(_ live: LivePlayerStat) -> some View {
        HStack(spacing: 12) {
            // Game clock
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "FF3B30"))
                    .frame(width: 8, height: 8)
                    .modifier(PulsingAnimation())
                
                Text(live.gameClockDisplay)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
            }
            
            Spacer()
            
            // Score
            HStack(spacing: 8) {
                Text(live.awayTeamCode)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(!live.isHomeTeam ? Color(hex: "FF6B35") : Color(hex: "8E8E93"))
                
                Text("\(live.awayScore)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                
                Text("-")
                    .foregroundStyle(Color(hex: "6E6E73"))
                
                Text("\(live.homeScore)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                
                Text(live.homeTeamCode)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(live.isHomeTeam ? Color(hex: "FF6B35") : Color(hex: "8E8E93"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "FF3B30").opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Live Stat Badge
    
    private func liveStatBadge(value: String, label: String, highlight: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(highlight ? Color(hex: "FF3B30") : Color.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
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
