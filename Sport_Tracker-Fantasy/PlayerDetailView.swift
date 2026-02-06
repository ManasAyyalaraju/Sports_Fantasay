//
//  PlayerDetailView.swift
//  Sport_Tracker-Fantasy
//
//  Shows player details and past 5 games stat lines.
//

import SwiftUI

struct PlayerDetailView: View {
    let player: NBAPlayer
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveManager = LiveGameManager.shared
    @State private var recentStats: [PlayerGameStats] = []
    @State private var seasonAverages: SeasonAverages?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    /// Check if this player is currently live
    private var liveStats: LivePlayerStat? {
        liveManager.getLiveStats(for: player.id)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live Game Card (if player is currently playing)
                    if let live = liveStats {
                        liveGameCard(live)
                    }
                    
                    // Player Header Card
                    playerHeaderCard
                    
                    // Season Averages
                    if let averages = seasonAverages {
                        seasonAveragesCard(averages)
                    }
                    
                    // Last 5 Games
                    recentGamesSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color(hex: "0A0A0A"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "3A3A3C"))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            onFavoriteToggle()
                        }
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundStyle(isFavorite ? Color(hex: "FFD700") : Color(hex: "8E8E93"))
                    }
                }
            }
            .task {
                await loadPlayerData()
            }
        }
    }
    
    // MARK: - Player Header Card
    
    private var playerHeaderCard: some View {
        VStack(spacing: 20) {
            // Player Photo
            PlayerPhotoView(player: player, size: 120)
                .shadow(color: Color(hex: player.teamPrimaryColor).opacity(0.4), radius: 20, y: 10)
            
            // Name and Position
            VStack(spacing: 8) {
                Text(player.displayFullName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                HStack(spacing: 12) {
                    if !player.position.isEmpty {
                        positionBadge(player.position)
                    }
                    
                    if let jersey = player.jerseyNumber, !jersey.isEmpty {
                        Text("#\(jersey)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "8E8E93"))
                    }
                }
            }
            
            // Team Info
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: player.teamPrimaryColor))
                    .frame(width: 12, height: 12)
                
                Text(player.teamFullName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Player Details Grid
            if player.height != nil || player.college != nil || player.country != nil {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let height = player.height, !height.isEmpty {
                        detailCell(title: "Height", value: height)
                    }
                    if let weight = player.weight, !weight.isEmpty {
                        detailCell(title: "Weight", value: "\(weight) lbs")
                    }
                    if let college = player.college, !college.isEmpty {
                        detailCell(title: "College", value: college)
                    }
                    if let country = player.country, !country.isEmpty {
                        detailCell(title: "Country", value: country)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: player.teamPrimaryColor).opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func positionBadge(_ position: String) -> some View {
        let fullPosition: String = {
            switch position {
            case "G": return "Guard"
            case "F": return "Forward"
            case "C": return "Center"
            case "G-F", "F-G": return "Guard-Forward"
            case "F-C", "C-F": return "Forward-Center"
            default: return position
            }
        }()
        
        return Text(fullPosition)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: player.teamPrimaryColor))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: player.teamPrimaryColor).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func detailCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "8E8E93"))
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Live Game Card
    
    private func liveGameCard(_ live: LivePlayerStat) -> some View {
        VStack(spacing: 16) {
            // Header with pulsing live indicator
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "FF3B30"))
                        .frame(width: 10, height: 10)
                        .modifier(PulsingAnimation())
                    
                    Text("LIVE NOW")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color(hex: "FF3B30"))
                }
                
                Spacer()
                
                // Game clock
                Text(live.gameClockDisplay)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "FF3B30").opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Score
            HStack(spacing: 16) {
                // Away team
                VStack(spacing: 4) {
                    Text(live.awayTeamCode)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(!live.isHomeTeam ? Color(hex: "FF6B35") : Color(hex: "8E8E93"))
                    
                    Text("\(live.awayScore)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity)
                
                Text("@")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(hex: "6E6E73"))
                
                // Home team
                VStack(spacing: 4) {
                    Text(live.homeTeamCode)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(live.isHomeTeam ? Color(hex: "FF6B35") : Color(hex: "8E8E93"))
                    
                    Text("\(live.homeScore)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
                .background(Color(hex: "3A3A3C"))
            
            // Player's current stats
            HStack(spacing: 0) {
                liveStatColumn(value: "\(live.points)", label: "PTS", highlight: true)
                liveStatColumn(value: "\(live.rebounds)", label: "REB")
                liveStatColumn(value: "\(live.assists)", label: "AST")
                liveStatColumn(value: "\(live.steals)", label: "STL")
                liveStatColumn(value: "\(live.blocks)", label: "BLK")
            }
            
            // Shooting line
            HStack(spacing: 16) {
                shootingLiveStat(label: "FG", made: live.fgm, attempted: live.fga)
                shootingLiveStat(label: "3PT", made: live.fg3m, attempted: live.fg3a)
                shootingLiveStat(label: "FT", made: live.ftm, attempted: live.fta)
                
                Spacer()
                
                // Minutes
                VStack(alignment: .trailing, spacing: 2) {
                    Text(live.minutes)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("MIN")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "6E6E73"))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "FF3B30").opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private func liveStatColumn(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Color(hex: "FF3B30") : Color.white)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func shootingLiveStat(label: String, made: Int, attempted: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "6E6E73"))
            
            Text("\(made)/\(attempted)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Season Averages Card
    
    private func seasonAveragesCard(_ averages: SeasonAverages) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Season Averages")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                Text("\(averages.gamesPlayed) GP")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            
            // Main Stats
            HStack(spacing: 0) {
                statColumn(value: String(format: "%.1f", averages.pts), label: "PTS", highlight: true)
                statColumn(value: String(format: "%.1f", averages.reb), label: "REB")
                statColumn(value: String(format: "%.1f", averages.ast), label: "AST")
                statColumn(value: String(format: "%.1f", averages.stl), label: "STL")
                statColumn(value: String(format: "%.1f", averages.blk), label: "BLK")
            }
            
            Divider()
                .background(Color(hex: "3A3A3C"))
            
            // Shooting Percentages
            HStack(spacing: 16) {
                shootingStatPill(label: "FG%", value: String(format: "%.1f", averages.fgPct))
                shootingStatPill(label: "3P%", value: String(format: "%.1f", averages.fg3Pct))
                shootingStatPill(label: "FT%", value: String(format: "%.1f", averages.ftPct))
                Spacer()
            }
        }
        .padding(20)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func statColumn(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Color(hex: "FF6B35") : Color.white)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func shootingStatPill(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Recent Games Section
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Last 5 Games")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                if !recentStats.isEmpty {
                    // Quick stats summary
                    let avgPts = Double(recentStats.compactMap { $0.pts }.reduce(0, +)) / Double(recentStats.count)
                    Text(String(format: "%.1f PPG", avgPts))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "FF6B35"))
                }
            }
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color(hex: "FF6B35"))
                    Text("Loading game logs...")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "FF9500"))
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                    
                    Button {
                        Task {
                            await loadPlayerData()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "FF6B35"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if recentStats.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "3A3A3C"))
                    Text("No recent games found")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                // Game Cards
                VStack(spacing: 12) {
                    ForEach(recentStats) { stat in
                        GameStatCard(stat: stat, playerTeamId: player.team?.id ?? 0)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Data Loading
    
    private func loadPlayerData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch stats and averages concurrently
            async let statsTask = LiveScoresAPI.shared.fetchPlayerStats(playerId: player.id, lastNGames: 5)
            async let averagesTask = LiveScoresAPI.shared.fetchSeasonAverages(playerId: player.id)
            
            let (stats, averages) = try await (statsTask, averagesTask)
            recentStats = stats
            seasonAverages = averages
            
        } catch let urlError as URLError {
            // Network-specific errors
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "No internet connection.\nPlease check your network."
            case .timedOut:
                errorMessage = "Request timed out.\nTry again later."
            default:
                errorMessage = "Network error.\nPlease try again."
            }
        } catch let nsError as NSError {
            // API-specific errors
            if nsError.code == 429 {
                errorMessage = "Too many requests.\nPlease wait a moment."
            } else {
                errorMessage = "Unable to load stats.\nPlayer may not have played recently."
            }
        } catch {
            errorMessage = "Unable to load stats.\nPlease try again."
        }
        
        isLoading = false
    }
}

// MARK: - Game Stat Card

struct GameStatCard: View {
    let stat: PlayerGameStats
    let playerTeamId: Int
    
    @State private var isExpanded = false
    
    /// Determine if player's team won
    private var isWin: Bool {
        let playerTeamIsHome = stat.team.id == stat.game.homeTeamId
        if playerTeamIsHome {
            return stat.game.homeTeamScore > stat.game.visitorTeamScore
        } else {
            return stat.game.visitorTeamScore > stat.game.homeTeamScore
        }
    }
    
    /// Get opponent team abbreviation
    private var opponentAbbr: String {
        let playerTeamIsHome = stat.team.id == stat.game.homeTeamId
        if playerTeamIsHome {
            return stat.game.visitorTeamAbbreviation
        } else {
            return stat.game.homeTeamAbbreviation
        }
    }
    
    /// Get opponent team full name
    private var opponentName: String {
        let playerTeamIsHome = stat.team.id == stat.game.homeTeamId
        if playerTeamIsHome {
            return stat.game.visitorTeamName
        } else {
            return stat.game.homeTeamName
        }
    }
    
    /// Home or away indicator
    private var homeAwayIndicator: String {
        let playerTeamIsHome = stat.team.id == stat.game.homeTeamId
        return playerTeamIsHome ? "vs" : "@"
    }
    
    /// Get game score display
    private var scoreDisplay: String {
        let playerTeamIsHome = stat.team.id == stat.game.homeTeamId
        if playerTeamIsHome {
            return "\(stat.game.homeTeamScore)-\(stat.game.visitorTeamScore)"
        } else {
            return "\(stat.game.visitorTeamScore)-\(stat.game.homeTeamScore)"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row (Always Visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                mainRow
            }
            .buttonStyle(.plain)
            
            // Expanded Details
            if isExpanded {
                expandedDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isExpanded ? Color(hex: "FF6B35").opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Main Row
    
    private var mainRow: some View {
        HStack(spacing: 16) {
            // Result & Opponent (compact left section)
            VStack(alignment: .leading, spacing: 6) {
                // Opponent team with home/away
                HStack(spacing: 3) {
                    Text(homeAwayIndicator)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "6E6E73"))
                    
                    Text(opponentAbbr)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "AEAEB2"))
                }
                
                // W/L Badge with score
                HStack(spacing: 6) {
                    Text(isWin ? "W" : "L")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(isWin ? Color(hex: "34C759") : Color(hex: "FF3B30"))
                    
                    Text(scoreDisplay)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 72, alignment: .leading)
            
            // Key Stats (larger, more prominent)
            HStack(spacing: 4) {
                statPill(value: "\(stat.pts ?? 0)", label: "PTS", highlight: true)
                statPill(value: "\(stat.reb ?? 0)", label: "REB")
                statPill(value: "\(stat.ast ?? 0)", label: "AST")
                statPill(value: stat.minutes, label: "MIN")
            }
            
            Spacer()
            
            // Expand Indicator
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "6E6E73"))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    private func statPill(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Color(hex: "FF6B35") : Color.white)
            
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "6E6E73"))
        }
        .frame(width: 48)
    }
    
    // MARK: - Expanded Details
    
    private var expandedDetails: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color(hex: "3A3A3C"))
            
            // Shooting Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("SHOOTING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .tracking(1)
                
                HStack(spacing: 16) {
                    shootingStat(
                        label: "FG",
                        made: stat.fgm ?? 0,
                        attempted: stat.fga ?? 0
                    )
                    
                    shootingStat(
                        label: "3PT",
                        made: stat.fg3m ?? 0,
                        attempted: stat.fg3a ?? 0
                    )
                    
                    shootingStat(
                        label: "FT",
                        made: stat.ftm ?? 0,
                        attempted: stat.fta ?? 0
                    )
                    
                    Spacer()
                }
            }
            
            // Other Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("OTHER STATS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .tracking(1)
                
                HStack(spacing: 20) {
                    miniStat(label: "STL", value: stat.stl ?? 0)
                    miniStat(label: "BLK", value: stat.blk ?? 0)
                    miniStat(label: "TO", value: stat.turnover ?? 0, negative: true)
                    miniStat(label: "PF", value: stat.pf ?? 0, negative: true)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func shootingStat(label: String, made: Int, attempted: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "6E6E73"))
            
            HStack(spacing: 8) {
                Text("\(made)/\(attempted)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                // Percentage
                if attempted > 0 {
                    let pct = Double(made) / Double(attempted) * 100
                    Text(String(format: "%.0f%%", pct))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(pct >= 50 ? Color(hex: "34C759") : (pct >= 40 ? Color(hex: "FF9500") : Color(hex: "8E8E93")))
                }
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "3A3A3C"))
                        .frame(height: 4)
                    
                    if attempted > 0 {
                        let pct = CGFloat(made) / CGFloat(attempted)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                pct >= 0.5 ? Color(hex: "34C759") :
                                    (pct >= 0.4 ? Color(hex: "FF9500") : Color(hex: "FF6B35"))
                            )
                            .frame(width: geo.size.width * pct, height: 4)
                    }
                }
            }
            .frame(width: 70, height: 4)
        }
    }
    
    private func miniStat(label: String, value: Int, negative: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(negative && value > 3 ? Color(hex: "FF3B30") : Color.white)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "6E6E73"))
        }
    }
}

#Preview {
    PlayerDetailView(
        player: NBAPlayer(
            id: 115,
            firstName: "Stephen",
            lastName: "Curry",
            position: "G",
            height: "6-2",
            weight: "185",
            jerseyNumber: "30",
            college: "Davidson",
            country: "USA",
            draftYear: 2009,
            draftRound: 1,
            draftNumber: 7,
            team: NBATeam(
                id: 10,
                conference: "West",
                division: "Pacific",
                city: "Golden State",
                name: "Warriors",
                fullName: "Golden State Warriors",
                abbreviation: "GSW"
            )
        ),
        isFavorite: true,
        onFavoriteToggle: {}
    )
}
