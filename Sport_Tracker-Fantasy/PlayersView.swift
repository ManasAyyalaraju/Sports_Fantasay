//
//  PlayersView.swift
//  Sport_Tracker-Fantasy
//
//  Browse NBA players, search, and add favorites.
//

import SwiftUI

struct PlayersView: View {
    @Binding var favoritePlayerIds: Set<Int>
    
    @StateObject private var liveManager = LiveGameManager.shared
    
    @State private var playersWithStats: [PlayerWithStats] = []
    @State private var filteredPlayers: [PlayerWithStats] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedPlayer: NBAPlayer?
    @State private var sortOption: SortOption = .topPerformers
    
    enum SortOption: String, CaseIterable {
        case topPerformers = "Top Performers"
        case name = "A-Z"
        case team = "Team"
        case fppg = "Fantasy Points"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Players")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                        
                        // Live indicator & refresh button
                        if !favoritePlayerIds.isEmpty {
                            liveStatusButton
                        }
                    }
                    
                    HStack {
                        Text("Browse NBA players and track your favorites")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "8E8E93"))
                        
                        Spacer()
                        
                        // Show live count if any favorites are live
                        if !liveManager.livePlayerStats.isEmpty {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: "FF3B30"))
                                    .frame(width: 6, height: 6)
                                
                                Text("\(liveManager.livePlayerStats.count) LIVE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "FF3B30"))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "FF3B30").opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Search Bar
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search players...", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white)
                            .autocorrectionDisabled()
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color(hex: "8E8E93"))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Sort Menu
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                                applyFiltersAndSort()
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF6B35"))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Content
                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color(hex: "FF6B35"))
                            Text("Loading top players...")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(hex: "FF6B35"))
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "8E8E93"))
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await loadPlayers() }
                            }
                            .font(.headline)
                            .foregroundStyle(Color(hex: "FF6B35"))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredPlayers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(hex: "3A3A3C"))
                            Text("No players found")
                                .font(.headline)
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(filteredPlayers.enumerated()), id: \.element.id) { index, playerWithStats in
                                    let playerId = playerWithStats.player.id
                                    let isFavorite = favoritePlayerIds.contains(playerId)
                                    let liveStats = isFavorite ? liveManager.getLiveStats(for: playerId) : nil
                                    
                                    PlayerRowView(
                                        player: playerWithStats.player,
                                        averages: playerWithStats.averages,
                                        liveStats: liveStats,
                                        rank: sortOption == .topPerformers && index < 100 ? index + 1 : nil,
                                        isFavorite: isFavorite,
                                        onFavoriteToggle: {
                                            toggleFavorite(playerWithStats.player)
                                        }
                                    )
                                    .onTapGesture {
                                        selectedPlayer = playerWithStats.player
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                        .refreshable {
                            await refreshData()
                        }
                    }
                }
            }
            .background(Color(hex: "0A0A0A"))
            .sheet(item: $selectedPlayer) { player in
                PlayerDetailView(
                    player: player,
                    isFavorite: favoritePlayerIds.contains(player.id),
                    onFavoriteToggle: { toggleFavorite(player) }
                )
            }
            .task {
                await loadPlayers()
            }
            .onChange(of: searchText) { _ in
                applyFiltersAndSort()
            }
            .onChange(of: favoritePlayerIds) { newIds in
                // Update live tracking when favorites change
                liveManager.updateTrackedPlayers(newIds)
            }
            .onAppear {
                // Start or resume live tracking
                if !favoritePlayerIds.isEmpty {
                    liveManager.startTracking(playerIds: favoritePlayerIds)
                }
            }
        }
    }
    
    // MARK: - Live Status Button
    
    private var liveStatusButton: some View {
        Button {
            Task {
                await liveManager.refresh()
            }
        } label: {
            HStack(spacing: 6) {
                if liveManager.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color.white)
                } else if !liveManager.liveGames.isEmpty {
                    // Pulsing live dot
                    Circle()
                        .fill(Color(hex: "FF3B30"))
                        .frame(width: 8, height: 8)
                        .modifier(PulsingAnimation())
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                
                if liveManager.isRefreshing {
                    Text("Updating...")
                        .font(.system(size: 12, weight: .semibold))
                } else if !liveManager.liveGames.isEmpty {
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Text("Refresh")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(!liveManager.liveGames.isEmpty ? Color(hex: "FF3B30") : Color(hex: "8E8E93"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                (!liveManager.liveGames.isEmpty ? Color(hex: "FF3B30") : Color(hex: "3A3A3C")).opacity(0.15)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(liveManager.isRefreshing)
    }
    
    private func loadPlayers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            playersWithStats = try await LiveScoresAPI.shared.fetchPlayersWithStats()
            applyFiltersAndSort()
        } catch {
            errorMessage = "Failed to load players.\nPlease check your connection."
        }
        
        isLoading = false
    }
    
    /// Pull-to-refresh: clears all caches and reloads fresh data
    private func refreshData() async {
        // Clear all caches
        LiveScoresAPI.shared.clearCache()
        await PlayerPhotoService.shared.clearCache()
        
        // Reload data
        do {
            playersWithStats = try await LiveScoresAPI.shared.fetchPlayersWithStats()
            applyFiltersAndSort()
        } catch { }
    }
    
    private func applyFiltersAndSort() {
        var result = playersWithStats
        
        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { playerWithStats in
                playerWithStats.player.fullName.lowercased().contains(query) ||
                playerWithStats.player.teamFullName.lowercased().contains(query) ||
                playerWithStats.player.teamAbbreviation.lowercased().contains(query)
            }
        }
        
        // Sort (with secondary sort by name for stability)
        switch sortOption {
        case .topPerformers:
            result.sort { p1, p2 in
                if p1.fantasyScore != p2.fantasyScore {
                    return p1.fantasyScore > p2.fantasyScore
                }
                return p1.player.fullName < p2.player.fullName
            }
        case .name:
            result.sort { $0.player.lastName < $1.player.lastName }
        case .team:
            result.sort { p1, p2 in
                if p1.player.teamFullName != p2.player.teamFullName {
                    return p1.player.teamFullName < p2.player.teamFullName
                }
                return p1.player.fullName < p2.player.fullName
            }
        case .fppg:
            result.sort { p1, p2 in
                if p1.fantasyScore != p2.fantasyScore {
                    return p1.fantasyScore > p2.fantasyScore
                }
                return p1.player.fullName < p2.player.fullName
            }
        }
        
        filteredPlayers = result
    }
    
    private func toggleFavorite(_ player: NBAPlayer) {
        if favoritePlayerIds.contains(player.id) {
            favoritePlayerIds.remove(player.id)
        } else {
            favoritePlayerIds.insert(player.id)
        }
    }
}

// MARK: - Player Row View

struct PlayerRowView: View {
    let player: NBAPlayer
    let averages: SeasonAverages?
    let liveStats: LivePlayerStat?
    let rank: Int?
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    
    var isLive: Bool {
        liveStats != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Rank badge (for top performers)
                if let rank = rank {
                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(rank <= 3 ? Color(hex: "FFD700") : Color(hex: "8E8E93"))
                        .frame(width: 24)
                }
                
                // Player Photo with live indicator
                ZStack(alignment: .topTrailing) {
                    PlayerPhotoView(player: player, size: 56)
                    
                    // Live badge overlay
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
                
                // Player Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(player.fullName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                        
                        // LIVE badge
                        if isLive {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "FF3B30"))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(player.teamAbbreviation)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: player.teamPrimaryColor))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: player.teamPrimaryColor).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        if !player.position.isEmpty {
                            Text(player.position)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                        
                        // Show live stats or FPPG (Fantasy Points Per Game)
                        if let live = liveStats {
                            Text("•")
                                .foregroundStyle(Color(hex: "3A3A3C"))
                            Text("\(live.points) PTS")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "FF3B30"))
                        } else if let avg = averages, avg.gamesPlayed > 0 {
                            Text("•")
                                .foregroundStyle(Color(hex: "3A3A3C"))
                            Text(String(format: "%.1f FPPG", avg.fantasyScore))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "FF6B35"))
                        }
                    }
                }
                
                Spacer()
                
                // Favorite Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onFavoriteToggle()
                    }
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle(isFavorite ? Color(hex: "FFD700") : Color(hex: "3A3A3C"))
                }
                .buttonStyle(.plain)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "3A3A3C"))
            }
            .padding(16)
            
            // Live Stats Bar (only for live players)
            if let live = liveStats {
                liveStatsBar(live)
            }
        }
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isLive ? Color(hex: "FF3B30").opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Live Stats Bar
    
    private func liveStatsBar(_ live: LivePlayerStat) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(hex: "2C2C2E"))
            
            HStack(spacing: 0) {
                // Game info
                VStack(alignment: .leading, spacing: 2) {
                    Text(live.scoreDisplay)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white)
                    
                    Text(live.gameClockDisplay)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "FF3B30"))
                }
                .frame(width: 90, alignment: .leading)
                
                Spacer()
                
                // Live stats
                HStack(spacing: 16) {
                    liveStatItem(value: live.points, label: "PTS", highlight: true)
                    liveStatItem(value: live.rebounds, label: "REB")
                    liveStatItem(value: live.assists, label: "AST")
                    liveStatItem(value: live.steals, label: "STL")
                    liveStatItem(value: live.blocks, label: "BLK")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "FF3B30").opacity(0.08))
        }
    }
    
    private func liveStatItem(value: Int, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Color(hex: "FF3B30") : Color.white)
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "6E6E73"))
        }
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Player Photo View

struct PlayerPhotoView: View {
    let player: NBAPlayer
    let size: CGFloat
    
    @State private var avatarURL: URL?
    
    var body: some View {
        Group {
            if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_):
                        initialsAvatar
                    case .empty:
                        // Show initials while loading
                        initialsAvatar
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .tint(.white.opacity(0.5))
                            )
                    @unknown default:
                        initialsAvatar
                    }
                }
            } else {
                initialsAvatar
            }
        }
        .task {
            await loadAvatarURL()
        }
    }
    
    private func loadAvatarURL() async {
        // Try API-Sports media CDN first, falls back to UI Avatars
        avatarURL = await PlayerPhotoService.shared.getHeadshotURLWithLookup(
            firstName: player.firstName,
            lastName: player.lastName,
            teamAbbr: player.teamAbbreviation
        )
    }
    
    private var initialsAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: player.teamPrimaryColor),
                            Color(hex: player.teamSecondaryColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Text(player.firstName.prefix(1) + player.lastName.prefix(1))
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PlayersView(favoritePlayerIds: .constant([]))
}
