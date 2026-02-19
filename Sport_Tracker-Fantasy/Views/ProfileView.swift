//
//  ProfileView.swift
//  Sport_Tracker-Fantasy
//
//  Profile tab – My Profile header, Join/Create League, My Leagues list (Figma 19:431).
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var leagueService = LeagueService()
    @State private var showCreateLeague = false
    @State private var showJoinLeague = false
    @State private var selectedLeague: League?
    @State private var rankByLeagueId: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        actionButtonsSection
                        myLeaguesSection
                    }
                    .padding(20)
                    .padding(.bottom, 100)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateLeague) {
                CreateLeagueView(leagueService: leagueService) {
                    showCreateLeague = false
                    if let userId = auth.currentUserId {
                        Task { await leagueService.loadMyLeagues(userId: userId) }
                    }
                }
                .environmentObject(auth)
            }
            .sheet(isPresented: $showJoinLeague) {
                JoinLeagueView(leagueService: leagueService) {
                    showJoinLeague = false
                    if let userId = auth.currentUserId {
                        Task { await leagueService.loadMyLeagues(userId: userId) }
                    }
                }
                .environmentObject(auth)
            }
            .navigationDestination(item: $selectedLeague) { league in
                LeagueDetailView(leagueService: leagueService, league: league)
                    .environmentObject(auth)
            }
            .task(id: auth.currentUserId) {
                if let userId = auth.currentUserId {
                    await leagueService.loadMyLeagues(userId: userId)
                }
            }
            .task(id: leagueService.myLeagues.map(\.id)) {
                await loadRanksForMyLeagues()
            }
        }
    }

    // MARK: - Header (My Profile + user name)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Profile")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))

            Text(auth.currentUserDisplayName ?? auth.currentUserEmail ?? "Profile")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    // MARK: - Join League (white) + Create League (dark)

    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    showJoinLeague = true
                } label: {
                    Label("Join League", systemImage: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "1C1C1E"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    showCreateLeague = true
                } label: {
                    Label("Create League", systemImage: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if let msg = leagueService.errorMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "FF3B30"))
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - My Leagues list (league name, subtitle, rank)

    private var myLeaguesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Leagues")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))

            if leagueService.isLoading && leagueService.myLeagues.isEmpty {
                loadingView
            } else if leagueService.myLeagues.isEmpty {
                emptyStateView
            } else {
                ForEach(leagueService.myLeagues) { league in
                    ProfileLeagueRow(
                        league: league,
                        rank: rankByLeagueId[league.id]
                    )
                    .onTapGesture { selectedLeague = league }
                }
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
                .tint(Color(hex: "8E8E93"))
            Text("Loading leagues...")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: "8E8E93").opacity(0.7))
            Text("No leagues yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("Join or create a league to get started")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func loadRanksForMyLeagues() async {
        guard let userId = auth.currentUserId else { return }
        let leaderboard = LeaderboardService.shared
        var newRanks: [UUID: Int] = [:]
        for league in leagueService.myLeagues {
            do {
                let standings = try await leaderboard.loadStandings(leagueId: league.id)
                if let entry = standings.first(where: { $0.userId == userId }) {
                    newRanks[league.id] = entry.rank
                }
            } catch {
                // leave rank nil for this league
            }
        }
        rankByLeagueId = newRanks
    }
}

// MARK: - League row (Figma: name, team/subtitle, rank on right)

struct ProfileLeagueRow: View {
    let league: League
    let rank: Int?

    private var rankText: String {
        guard let r = rank else { return "—" }
        let suffix: String
        switch r % 10 {
        case 1 where r % 100 != 11: suffix = "st"
        case 2 where r % 100 != 12: suffix = "nd"
        case 3 where r % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(r)\(suffix)"
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(league.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(league.statusDisplay)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            Spacer(minLength: 12)
            Text(rankText)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
