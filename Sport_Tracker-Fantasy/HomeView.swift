//
//  HomeView.swift
//  Sport_Tracker-Fantasy
//
//  Home tab – league selector + roster (or empty state). Live-at-top sort by fantasy points (Phase 3).
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var rosterService: RosterService
    let selectedLeagueId: UUID?
    let myLeagues: [League]
    let onSelectLeague: (UUID?) -> Void
    /// When nil, roster cards don't show remove button. When set, tapping remove calls this.
    let onRemoveFromRoster: ((Int) async -> Void)?
    let favoritePlayerIds: Set<Int>
    let onToggleFavorite: (Int) async -> Void

    private var rosterPlayerIds: Set<Int> {
        rosterService.rosterPlayerIds
    }

    @StateObject private var liveManager = LiveGameManager.shared
    @State private var rosterPlayers: [NBAPlayer] = []
    @State private var playerStats: [Int: [PlayerGameStats]] = [:]
    @State private var playerAverages: [Int: SeasonAverages] = [:]
    @State private var nextGameByTeamId: [Int: UpcomingGameInfo] = [:]
    @State private var isLoading = true
    @State private var selectedPlayer: NBAPlayer?
    @State private var searchText = ""

    private var displayPlayerIds: Set<Int> {
        selectedLeagueId != nil ? rosterPlayerIds : []
    }

    private var sortedRosterPlayers: [NBAPlayer] {
        rosterPlayers.sorted { player1, player2 in
            let isLive1 = liveManager.isPlayerLive(player1.id)
            let isLive2 = liveManager.isPlayerLive(player2.id)
            if isLive1 != isLive2 { return isLive1 }
            if isLive1 && isLive2 {
                let fp1 = liveManager.getLiveStats(for: player1.id)?.fantasyPoints ?? 0
                let fp2 = liveManager.getLiveStats(for: player2.id)?.fantasyPoints ?? 0
                return fp1 > fp2
            }
            let avg1 = playerAverages[player1.id]?.fantasyScore ?? 0
            let avg2 = playerAverages[player2.id]?.fantasyScore ?? 0
            return avg1 > avg2
        }
    }

    /// Roster filtered by search (name); empty search = all.
    private var filteredRosterPlayers: [NBAPlayer] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return sortedRosterPlayers }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return sortedRosterPlayers.filter { $0.displayFullName.lowercased().contains(q) }
    }

    /// Selected league (for draft date filtering).
    private var selectedLeague: League? {
        guard let id = selectedLeagueId else { return nil }
        return myLeagues.first { $0.id == id }
    }

    /// Total fantasy points for the roster: only games on or after league draft date (or live). If no league/draft date, falls back to last-game sum.
    private var totalRosterFantasyPoints: Double {
        let draftDate = selectedLeague?.draftDate
        var total: Double = 0
        for player in rosterPlayers {
            if let live = liveManager.getLiveStats(for: player.id) {
                total += live.fantasyPoints
            } else if let stats = playerStats[player.id] {
                if let cutOff = draftDate {
                    let calendar = Calendar.current
                    let cutOffStart = calendar.startOfDay(for: cutOff)
                    for stat in stats {
                        guard let gameDate = stat.gameDateAsDate else { continue }
                        if gameDate >= cutOffStart {
                            total += stat.fantasyPoints
                        }
                    }
                } else {
                    if let last = stats.first { total += last.fantasyPoints }
                }
            }
        }
        return total
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header: gradient, league name + chevron, total fantasy pts (Figma style)
                        headerSectionFigma
                        if !myLeagues.isEmpty {
                            leagueRowFigma
                        }

                        if let err = rosterService.errorMessage {
                            errorBanner(err)
                        }

                        if myLeagues.isEmpty {
                            noLeagueEmptyState
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        } else if selectedLeagueId == nil {
                            selectLeaguePrompt
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        } else if isLoading && !rosterPlayerIds.isEmpty {
                            loadingView
                                .padding(.top, 24)
                        } else if rosterPlayers.isEmpty {
                            noRosterEmptyState
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        } else {
                            // "Your Roster" section title (Figma Main Page)
                            rosterSectionHeader
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .padding(.bottom, 16)

                            // Compact roster list (Figma: avatar, name, game info, #jersey position, status/FP)
                            LazyVStack(spacing: 8) {
                                ForEach(filteredRosterPlayers) { player in
                                    RosterPlayerRow(
                                        player: player,
                                        recentStats: playerStats[player.id] ?? [],
                                        liveStats: liveManager.getLiveStats(for: player.id),
                                        leagueDraftDate: selectedLeague?.draftDate,
                                        nextGameInfo: player.team.flatMap { nextGameByTeamId[$0.id] },
                                        onRemove: onRemoveFromRoster != nil ? { removePlayerFromRoster(player.id) } : nil
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
                    await refreshHomeData()
                }
                .background(
                    ZStack {
                        Color.black
                        // Top-left corner: cyan/teal radial glow
                        RadialGradient(
                            colors: [Color(hex: "00EFEB").opacity(0.58), Color.clear],
                            center: UnitPoint(x: 0, y: 0.12),
                            startRadius: 0,
                            endRadius: 400
                        )
                        // Top-right corner: blue radial glow
                        RadialGradient(
                            colors: [Color(hex: "0073EF").opacity(0.58), Color.clear],
                            center: UnitPoint(x: 1, y: 0.12),
                            startRadius: 0,
                            endRadius: 400
                        )
                    }
                    .ignoresSafeArea()
                )
            }
            .sheet(item: $selectedPlayer) { player in
                PlayerDetailView(
                    player: player,
                    isFavorite: favoritePlayerIds.contains(player.id),
                    onFavoriteToggle: { toggleFavorite(player) }
                )
            }
            .task(id: Array(displayPlayerIds).sorted()) {
                await loadRosterPlayers()
            }
            .onChange(of: rosterPlayerIds) { newIds in
                liveManager.updateTrackedPlayers(newIds)
            }
            .onAppear {
                if !rosterPlayerIds.isEmpty {
                    liveManager.startTracking(playerIds: rosterPlayerIds)
                }
                if myLeagues.count == 1, selectedLeagueId == nil, let only = myLeagues.first {
                    onSelectLeague(only.id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    accountMenu
                }
            }
        }
    }

    // MARK: - Figma-style header (gradient, league + total pts)

    private var headerSectionFigma: some View {
        VStack(alignment: .leading, spacing: 12) {
            // League name with chevron (dropdown)
            Menu {
                Button("No league") { onSelectLeague(nil) }
                ForEach(myLeagues) { league in
                    Button(league.name) { onSelectLeague(league.id) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLeagueName ?? "Select league")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.top, 8)

            // Total fantasy points + optional LIVE pill (Figma Main Page)
            if selectedLeagueId != nil {
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(String(format: "%.0f pts", totalRosterFantasyPoints))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !liveManager.liveGames.isEmpty {
                        Button {
                            Task { await liveManager.refresh() }
                        } label: {
                            HStack(spacing: 6) {
                                if liveManager.isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(Color(hex: "FF3B30"))
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
                            .background(Color(hex: "FF3B30").opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var leagueRowFigma: some View {
        EmptyView() // League is in header; keep for any extra spacing if needed
    }

    /// "Your Roster" section title + optional live count (Figma Main Page)
    private var rosterSectionHeader: some View {
        HStack(alignment: .center) {
            Text("Your Roster")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            let liveCount = rosterPlayers.filter { liveManager.isPlayerLive($0.id) }.count
            if liveCount > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "FF3B30"))
                        .frame(width: 6, height: 6)
                    Text("\(liveCount) playing")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "FF3B30"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "FF3B30").opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(hex: "FF3B30"))
            Spacer()
            Button("Dismiss") { rosterService.clearError() }
                .font(.subheadline)
                .foregroundStyle(Color.white)
        }
        .padding(12)
        .background(Color(hex: "FF3B30").opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
            TextField("Search", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var leaguePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("League")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
            Menu {
                Button("No league") {
                    onSelectLeague(nil)
                }
                ForEach(myLeagues) { league in
                    Button(league.name) {
                        onSelectLeague(league.id)
                    }
                }
            } label: {
                HStack {
                    Text(selectedLeagueName ?? "Select league")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .padding(14)
                .background(Color(hex: "1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var selectedLeagueName: String? {
        guard let id = selectedLeagueId else { return nil }
        return myLeagues.first { $0.id == id }?.name
    }

    private var noLeagueEmptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "sportscourt")
                .font(.system(size: 56))
                .foregroundStyle(Color.white.opacity(0.7))
            Text("No Leagues Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Go to the Leagues tab to create or join a league.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    /// Shown when user has leagues but hasn't selected one yet — tap the picker above.
    private var selectLeaguePrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.tap")
                .font(.system(size: 56))
                .foregroundStyle(Color.white.opacity(0.7))
            Text("Choose Your League")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Tap \"Select league\" above and pick the league to see your roster.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var noRosterEmptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "8E8E93").opacity(0.7))
            Text("No Roster Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Your league roster will appear here after the draft, or add players from the league detail for testing.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var accountMenu: some View {
        Menu {
            if let displayName = auth.currentUserDisplayName {
                Text(displayName)
                    .font(.headline)
            } else if let email = auth.currentUserEmail {
                Text(email)
                    .font(.caption)
            }
            if let email = auth.currentUserEmail {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Button(role: .destructive) {
                Task { await auth.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(Color.white)
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
                                colors: [Color(hex: "0073EF"), Color.white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(selectedLeagueId != nil ? "Your roster · Live at top" : "Select a league to see your roster")
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
                    
                    // Roster count badge
                    if selectedLeagueId != nil && !rosterPlayers.isEmpty {
                        VStack(spacing: 2) {
                            Text("\(rosterPlayers.count)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("roster")
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
                .tint(Color.white)
            Text("Loading roster...")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Roster Players Section

    private var rosterPlayersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Roster")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                let liveCount = rosterPlayers.filter { liveManager.isPlayerLive($0.id) }.count
                if liveCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "FF3B30"))
                            .frame(width: 6, height: 6)
                        Text("\(liveCount) playing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF3B30"))
                    }
                }
            }
            ForEach(sortedRosterPlayers) { player in
                FavoritePlayerCard(
                    player: player,
                    averages: playerAverages[player.id],
                    recentStats: playerStats[player.id] ?? [],
                    liveStats: liveManager.getLiveStats(for: player.id),
                    onRemove: onRemoveFromRoster != nil ? { removePlayerFromRoster(player.id) } : nil
                )
                .onTapGesture {
                    selectedPlayer = player
                }
            }
            .animation(.easeOut(duration: 0.25), value: rosterPlayers.map(\.id))
        }
    }

    // MARK: - Data Loading

    private func loadRosterPlayers() async {
        guard selectedLeagueId != nil, !rosterPlayerIds.isEmpty else {
            rosterPlayers = []
            playerStats = [:]
            playerAverages = [:]
            nextGameByTeamId = [:]
            isLoading = false
            return
        }
        isLoading = true
        do {
            let allPlayers: [NBAPlayer] = try await SupabaseNBAService.shared.fetchAllPlayers()
            rosterPlayers = allPlayers.filter { rosterPlayerIds.contains($0.id) }
            let teamIds = Set(rosterPlayers.compactMap { $0.team?.id })
            let upcomingTask = !teamIds.isEmpty ? Task { try await LiveScoresAPI.shared.fetchUpcomingGamesForTeams(teamIds) } : nil
            for player in rosterPlayers {
                do {
                    async let statsTask = LiveScoresAPI.shared.fetchPlayerStats(playerId: player.id, lastNGames: 3)
                    async let supabaseAvgTask = SupabaseNBAService.shared.fetchSeasonAverage(for: player.id)
                    let stats = try await statsTask
                    let supabaseAvg = try await supabaseAvgTask
                    playerStats[player.id] = stats
                    if let avg = supabaseAvg { playerAverages[player.id] = avg }
                } catch {}
            }
            if let task = upcomingTask {
                nextGameByTeamId = (try? await task.value) ?? [:]
            } else {
                nextGameByTeamId = [:]
            }
        } catch {}
        isLoading = false
    }
    
    /// Refresh all home data (roster players, live stats, etc.)
    private func refreshHomeData() async {
        // Refresh live game data
        await liveManager.refresh()
        // Reload roster players (which will reload stats and averages)
        await loadRosterPlayers()
    }

    private func toggleFavorite(_ player: NBAPlayer) {
        Task { await onToggleFavorite(player.id) }
    }

    private func removePlayerFromRoster(_ playerId: Int) {
        Task {
            await onRemoveFromRoster?(playerId)
        }
    }
}

// MARK: - Favorite Player Card

// MARK: - Roster Player Row (Figma: compact list row)

struct RosterPlayerRow: View {
    let player: NBAPlayer
    let recentStats: [PlayerGameStats]
    let liveStats: LivePlayerStat?
    /// When set, only games on or after this date count; no games since draft → "Upcoming" and no score.
    let leagueDraftDate: Date?
    /// Next game for this player's team (from season schedule). Shown when no games since draft.
    let nextGameInfo: UpcomingGameInfo?
    let onRemove: (() -> Void)?

    private var isLive: Bool { liveStats != nil }

    /// Stats that count for this league (games on or after league draft date). Order preserved (most recent first).
    private var statsSinceDraft: [PlayerGameStats] {
        guard let draftDate = leagueDraftDate else { return recentStats }
        let calendar = Calendar.current
        let cutOff = calendar.startOfDay(for: draftDate)
        return recentStats.filter { stat in
            guard let gameDate = stat.gameDateAsDate else { return false }
            return gameDate >= cutOff
        }
    }

    /// Flow: Upcoming until game starts → Live while playing → Final for up to 12 hrs after game end → then back to Upcoming (next game).
    /// "Recent final" = last game ended less than 12 hours ago (game end ≈ start + 3 hr, then 12 hr final window).
    private var isRecentFinal: Bool {
        guard let last = statsSinceDraft.first, let gameStart = last.gameDateAsDate else { return false }
        let endOfFinalWindow = Calendar.current.date(byAdding: .hour, value: 15, to: gameStart) ?? gameStart // ~3hr game + 12hr display
        return Date() < endOfFinalWindow
    }

    private var gameStatusLabel: String {
        if liveStats != nil { return "In Progress" }
        if isRecentFinal { return "Final" }
        return "Upcoming"
    }

    /// Next game info line (Figma: matchup + time under name). "VIS @ HOM, 7:00pm" or next game from schedule when upcoming.
    private var gameMatchupLine: String {
        if let live = liveStats {
            return "\(live.awayTeamCode) @ \(live.homeTeamCode)"
        }
        if isRecentFinal, let last = statsSinceDraft.first {
            let matchup = last.game.homeTeamAbbreviation.isEmpty ? "\(last.team.abbreviation) game" : "\(last.game.visitorTeamAbbreviation) @ \(last.game.homeTeamAbbreviation)"
            let time = formatGameTime(last.game.date)
            return time.isEmpty ? matchup : "\(matchup), \(time)"
        }
        if let next = nextGameInfo {
            return next.displayLine
        }
        return "Next: —"
    }

    /// Formats game date string to "7:00pm" for display under player name.
    private func formatGameTime(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: dateStr) {
            let out = DateFormatter()
            out.dateFormat = "h:mma"
            out.locale = Locale(identifier: "en_US_POSIX")
            return out.string(from: date)
        }
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: String(dateStr.prefix(10))) {
            let out = DateFormatter()
            out.dateFormat = "h:mma"
            out.locale = Locale(identifier: "en_US_POSIX")
            return out.string(from: date)
        }
        return ""
    }

    private var fantasyPointsDisplay: Double? {
        if let live = liveStats { return live.fantasyPoints }
        if isRecentFinal, let last = statsSinceDraft.first { return last.fantasyPoints }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar (Figma 16:85, 19:124, 19:141, 19:157)
            ZStack(alignment: .topTrailing) {
                PlayerPhotoView(player: player, size: 48)
                if isLive {
                    Circle()
                        .fill(Color(hex: "FF3B30"))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(hex: "1C1C1E"), lineWidth: 1))
                        .offset(x: 2, y: -2)
                }
            }

            // Name, next game info, jersey+position tag (Figma: matchup + time under name, then #jersey position tag)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayFullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(gameMatchupLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .lineLimit(1)
                // Jersey + position in rounded tag (Figma: small pill)
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

            // Status tag + FP (Figma: status pill on top-right, large number bottom-right)
            VStack(alignment: .trailing, spacing: 6) {
                statusBadge
                if let fp = fantasyPointsDisplay {
                    Text(String(format: "%.0f", fp))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "6E6E73"))
                }
            }
            if onRemove != nil {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "1C1C1E").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 4)
    }

    /// Status pill (Figma: In Progress = red dot + red text; Upcoming/Final = grey)
    private var statusBadge: some View {
        let (dotColor, textColor): (Color, Color) = isLive
            ? (Color(hex: "FF3B30"), Color(hex: "FF3B30"))
            : (statsSinceDraft.isEmpty ? Color(hex: "8E8E93") : Color(hex: "8E8E93"), Color(hex: "8E8E93"))
        return HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(gameStatusLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isLive ? Color(hex: "FF3B30").opacity(0.15) : Color(hex: "2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Favorite Player Card (legacy / detail-style card)

struct FavoritePlayerCard: View {
    let player: NBAPlayer
    let averages: SeasonAverages?
    let recentStats: [PlayerGameStats]
    let liveStats: LivePlayerStat?
    /// When nil, the remove button is hidden (e.g. favorites mode). When set, shows remove-from-roster.
    let onRemove: (() -> Void)?
    
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
                    
                    // Show fantasy points: live (this game) or last game
                    if let live = liveStats {
                        fantasyPointsBadge(value: String(format: "%.1f", live.fantasyPoints), label: "FP (this game)", highlight: true)
                            .padding(.top, 4)
                    } else if let lastGame = recentStats.first {
                        fantasyPointsBadge(value: String(format: "%.1f", lastGame.fantasyPoints), label: "FP (last game)", highlight: false)
                            .padding(.top, 4)
                    } else {
                        HStack(spacing: 4) {
                            Text("—")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "8E8E93"))
                            Text("FP (no games yet)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                if let onRemove = onRemove {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onRemove()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
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
                .foregroundStyle(isLive ? Color(hex: "FF3B30") : Color.white)
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
                    .foregroundStyle(!live.isHomeTeam ? Color.white : Color(hex: "8E8E93"))
                
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
                    .foregroundStyle(live.isHomeTeam ? Color.white : Color(hex: "8E8E93"))
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
                .foregroundStyle(Color.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
    }

    private func fantasyPointsBadge(value: String, label: String, highlight: Bool) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(highlight ? Color(hex: "FF3B30") : Color.white)
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
            
            Text(String(format: "%.1f", stat.fantasyPoints))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            
            Text("FP")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
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
    HomeView(
        rosterService: RosterService.shared,
        selectedLeagueId: nil,
        myLeagues: [],
        onSelectLeague: { _ in },
        onRemoveFromRoster: nil,
        favoritePlayerIds: [],
        onToggleFavorite: { _ in }
    )
    .environmentObject(AuthViewModel())
}