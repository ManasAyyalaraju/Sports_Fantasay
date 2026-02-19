//
//  StandingsView.swift
//  Sport_Tracker-Fantasy
//
//  League standings / leaderboard tab (Phase 1: UI placeholder).
//

import SwiftUI

struct StandingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var leagueService = LeagueService()
    @AppStorage("selectedStandingsLeagueId") private var selectedLeagueIdRaw: String = ""
    @State private var selectedTimeframe: TimeframeFilter = .overall
    @State private var standings: [LeagueStandingsEntry] = []
    @State private var isLoadingStandings = false
    @State private var standingsError: String?
    @State private var selectedUserRoster: LeagueStandingsEntry?
    @State private var loadTask: Task<Void, Never>?

    private var selectedLeagueId: UUID? {
        get { UUID(uuidString: selectedLeagueIdRaw) }
        set { selectedLeagueIdRaw = newValue?.uuidString ?? "" }
    }

    private var selectedLeague: League? {
        guard let id = selectedLeagueId else { return nil }
        return leagueService.myLeagues.first { $0.id == id }
    }

    enum TimeframeFilter: String, CaseIterable {
        case overall = "Overall"
        case today = "Today"
        case lastWeek = "Last Week"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header: gradient, league selector, title, buttons
                        headerSection

                        // Timeframe filters (segmented control)
                        timeframeFilters
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 20)

                        // Leaderboard content area
                        if leagueService.myLeagues.isEmpty {
                            noLeagueEmptyState
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                        } else if selectedLeagueId == nil {
                            selectLeaguePrompt
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                        } else if isLoadingStandings {
                            loadingView
                                .padding(.top, 40)
                        } else if let error = standingsError {
                            errorView(error)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        } else if standings.isEmpty {
                            emptyStandingsView
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                        } else {
                            // Leaderboard list
                            leaderboardList
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                        }
                    }
                }
                .refreshable {
                    await loadStandings()
                }
                .background(
                    ZStack {
                        Color.black
                        RadialGradient(
                            colors: [Color(hex: "00EFEB").opacity(0.58), Color.clear],
                            center: UnitPoint(x: 0, y: 0.12),
                            startRadius: 0,
                            endRadius: 400
                        )
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
            .navigationBarHidden(true)
            .task(id: auth.currentUserId) {
                if let userId = auth.currentUserId {
                    await leagueService.loadMyLeagues(userId: userId)
                }
            }
            .task(id: selectedLeagueId) {
                // Cancel previous task when league changes
                loadTask?.cancel()
                await loadStandings()
            }
            .onDisappear {
                // Cancel any ongoing load when view disappears
                loadTask?.cancel()
            }
        }
    }

    // MARK: - Data Loading

    private func loadStandings() async {
        guard let leagueId = selectedLeagueId else {
            standings = []
            standingsError = nil
            return
        }

        // Cancel any existing load task
        loadTask?.cancel()
        
        isLoadingStandings = true
        standingsError = nil
        
        // Create a new task that can be cancelled
        let task = Task {
            defer { isLoadingStandings = false }
            
            do {
                // Testing mode: use season averages so adding players shows points immediately
                // Set useSeasonAverages: false for production (actual points after draft date only)
                let entries = try await LeaderboardService.shared.loadStandings(
                    leagueId: leagueId,
                    useSeasonAverages: true // Testing: season averages
                )
                
                // Check if task was cancelled before updating UI
                guard !Task.isCancelled else { return }
                
                print("📊 StandingsView: Loaded \(entries.count) standings entries")
                standings = entries
                standingsError = nil
            } catch {
                // Don't show cancellation errors to the user (they're expected)
                if (error as NSError).code == NSURLErrorCancelled {
                    print("⚠️ StandingsView: Load cancelled (expected)")
                    return
                }
                
                print("❌ StandingsView: Failed to load standings: \(error)")
                
                // Only update error if task wasn't cancelled
                guard !Task.isCancelled else { return }
                standingsError = error.localizedDescription
                standings = []
            }
        }
        
        loadTask = task
        await task.value
    }

    // MARK: - Header Section (Figma 19:266: league dropdown, Leaders title, Schedule Draft + menu)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // League selector (Figma: top-left, light grey + chevron)
            Menu {
                Button("No league") { selectedLeagueIdRaw = "" }
                ForEach(leagueService.myLeagues) { league in
                    Button(league.name) {
                        selectedLeagueIdRaw = league.id.uuidString
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLeague?.name ?? "Select league")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.top, 8)

            // "Leaders" title (Figma: large bold white)
            Text("Leaders")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // Schedule Draft + menu (Figma: white pill button, then circular dark menu)
            HStack(spacing: 12) {
                Button {
                    // TODO: Draft functionality
                } label: {
                    Text("Schedule Draft")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    // TODO: League settings menu
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "2C2C2E"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    // MARK: - Timeframe Filters (Figma 19:266: pill tabs, Overall selected = white)

    private var timeframeFilters: some View {
        HStack(spacing: 0) {
            ForEach(TimeframeFilter.allCases, id: \.self) { filter in
                Button {
                    selectedTimeframe = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTimeframe == filter ? .black : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedTimeframe == filter {
                                    RoundedRectangle(cornerRadius: 100)
                                        .fill(.white)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 100)
                                .stroke(selectedTimeframe == filter ? Color.white : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 100))
    }

    // MARK: - Empty States

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

    private var selectLeaguePrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.tap")
                .font(.system(size: 56))
                .foregroundStyle(Color.white.opacity(0.7))
            Text("Choose Your League")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Select a league above to see standings.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        LazyVStack(spacing: 8) {
            ForEach(standings) { entry in
                StandingsRow(entry: entry, isCurrentUser: entry.userId == auth.currentUserId)
                    .onTapGesture {
                        selectedUserRoster = entry
                    }
            }
        }
        .sheet(item: $selectedUserRoster) { entry in
            UserRosterView(
                userId: entry.userId,
                displayName: entry.displayName,
                leagueId: selectedLeagueId ?? UUID(), // Should never be nil when sheet is shown
                leagueDraftDate: selectedLeague?.draftDate
            )
        }
    }

    // MARK: - Loading and Error States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.white)
            Text("Loading standings...")
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
                Task { await loadStandings() }
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

    private var emptyStandingsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.number")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "8E8E93").opacity(0.7))
            Text("No Standings Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Standings will appear here once rosters are set up.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Standings Row (Figma 19:266: dark card, name + subtitle left, score right)

struct StandingsRow: View {
    let entry: LeagueStandingsEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Name + subtitle (Figma: team/roster name bold white, user name grey below)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Rank \(entry.rank)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score (Figma: large white number on right)
            Text(String(format: "%.0f", entry.totalFantasyPoints))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "1C1C1E").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StandingsView()
        .environmentObject(AuthViewModel())
}
