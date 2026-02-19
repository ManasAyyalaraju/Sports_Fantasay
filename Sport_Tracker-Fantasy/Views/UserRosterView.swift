//
//  UserRosterView.swift
//  Sport_Tracker-Fantasy
//
//  View to display a user's roster with player scores (similar to Home screen).
//

import SwiftUI
import Foundation

struct UserRosterView: View {
    let userId: UUID
    let displayName: String
    let leagueId: UUID
    let leagueDraftDate: Date?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rosterService = RosterService.shared
    @StateObject private var liveManager = LiveGameManager.shared
    
    @State private var rosterPlayers: [NBAPlayer] = []
    @State private var playerStats: [Int: [PlayerGameStats]] = [:]
    @State private var playerAverages: [Int: SeasonAverages] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPlayer: NBAPlayer?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "0A0A0A"), Color(hex: "1A1A1A")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header: User name and total points
                        headerSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Search bar (optional, can add later)
                        
                        // Roster list
                        if isLoading {
                            loadingView
                                .padding(.top, 40)
                        } else if let error = errorMessage {
                            errorView(error)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        } else if rosterPlayers.isEmpty {
                            emptyRosterView
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(sortedRosterByPoints) { player in
                                    UserRosterPlayerRow(
                                        player: player,
                                        pointsContributed: pointsContributed(for: player)
                                    )
                                    .onTapGesture { selectedPlayer = player }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                }
                .refreshable {
                    await refreshRosterData()
                }
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPlayer) { player in
                NavigationStack {
                    PlayerDetailView(
                        player: player,
                        isFavorite: false,
                        onFavoriteToggle: {}
                    )
                }
            }
            .task {
                await loadRoster()
            }
            .onAppear {
                // Track players for live updates
                liveManager.updateTrackedPlayers(Set(rosterPlayers.map(\.id)))
            }
            .onChange(of: rosterPlayers.map(\.id)) { newIds in
                liveManager.updateTrackedPlayers(Set(newIds))
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // Total fantasy points
            Text(String(format: "%.0f pts", totalFantasyPoints))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var totalFantasyPoints: Double {
        rosterPlayers.reduce(0.0) { total, player in
            total + pointsContributed(for: player)
        }
    }

    /// Roster sorted by points contributed (descending).
    private var sortedRosterByPoints: [NBAPlayer] {
        rosterPlayers.sorted { pointsContributed(for: $0) > pointsContributed(for: $1) }
    }

    /// Points this player contributes to the total (live FP, else last game since draft, else season average).
    private func pointsContributed(for player: NBAPlayer) -> Double {
        let stats = playerStats[player.id] ?? []
        let statsSinceDraft: [PlayerGameStats]
        if let draftDate = leagueDraftDate {
            let calendar = Calendar.current
            let cutOff = calendar.startOfDay(for: draftDate)
            statsSinceDraft = stats.filter { stat in
                guard let gameDate = stat.gameDateAsDate else { return false }
                return gameDate >= cutOff
            }
        } else {
            statsSinceDraft = stats
        }
        if let live = liveManager.getLiveStats(for: player.id) {
            return live.fantasyPoints
        }
        if let lastGame = statsSinceDraft.first {
            return lastGame.fantasyPoints
        }
        if let avg = playerAverages[player.id] {
            return avg.fantasyScore
        }
        return 0
    }
    
    // MARK: - Loading and Error States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.white)
            Text("Loading roster...")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "FF3B30"))
                Spacer()
            }
            Button {
                Task { await loadRoster() }
            } label: {
                Text("Retry")
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
            }
        }
        .padding(12)
        .background(Color(hex: "FF3B30").opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var emptyRosterView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "8E8E93").opacity(0.7))
            Text("No Roster Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("This user hasn't added any players to their roster yet.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Data Loading
    
    /// Refresh roster data (live stats + reload roster)
    private func refreshRosterData() async {
        // Refresh live game data
        await liveManager.refresh()
        // Reload roster
        await loadRoster()
    }
    
    private func loadRoster() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Load roster picks for this user
            let picks = try await rosterService.loadAllRosterPicks(leagueId: leagueId)
            let userPicks = picks.filter { $0.userId == userId }
            let playerIds = Set(userPicks.map(\.playerId))
            
            guard !playerIds.isEmpty else {
                rosterPlayers = []
                return
            }
            
            // Fetch all players and filter to roster
            let allPlayers: [NBAPlayer] = try await SupabaseNBAService.shared.fetchAllPlayers()
            rosterPlayers = allPlayers.filter { playerIds.contains($0.id) }
            
            // Load stats and averages for each player
            for player in rosterPlayers {
                do {
                    async let statsTask = LiveScoresAPI.shared.fetchPlayerStats(playerId: player.id, lastNGames: 3)
                    async let supabaseAvgTask = SupabaseNBAService.shared.fetchSeasonAverage(for: player.id)
                    let stats = try await statsTask
                    let supabaseAvg = try await supabaseAvgTask
                    playerStats[player.id] = stats
                    if let avg = supabaseAvg { playerAverages[player.id] = avg }
                } catch {
                    print("⚠️ UserRosterView: Failed to load stats for player \(player.id): \(error)")
                }
            }
        } catch {
            // Don't show error for cancelled requests (e.g. pull-to-refresh or navigation cancels in-flight request)
            let isCancelled = (error as NSError).code == NSURLErrorCancelled
            if !isCancelled {
                errorMessage = error.localizedDescription
                print("❌ UserRosterView: Failed to load roster: \(error)")
            }
        }
    }
}

// MARK: - Row: player + contributed points (no next game / status pill)

struct UserRosterPlayerRow: View {
    let player: NBAPlayer
    let pointsContributed: Double

    var body: some View {
        HStack(spacing: 14) {
            PlayerPhotoView(player: player, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayFullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let jersey = player.jerseyNumber, !jersey.isEmpty || !player.position.isEmpty {
                    HStack(spacing: 4) {
                        if !jersey.isEmpty {
                            Text("#\(jersey)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        if !player.position.isEmpty {
                            Text(player.position)
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.0f pts", pointsContributed))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "1C1C1E").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 4)
    }
}

#Preview {
    UserRosterView(
        userId: UUID(),
        displayName: "Test User",
        leagueId: UUID(),
        leagueDraftDate: Date()
    )
}
