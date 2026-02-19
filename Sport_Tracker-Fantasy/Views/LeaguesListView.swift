//
//  LeaguesListView.swift
//  Sport_Tracker-Fantasy
//
//  My leagues list; Create league and Join league entry points.
//

import SwiftUI

struct LeaguesListView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var leagueService = LeagueService()
    @State private var showCreateLeague = false
    @State private var showJoinLeague = false
    @State private var selectedLeague: League?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        if leagueService.isLoading && leagueService.myLeagues.isEmpty {
                            loadingView
                        } else if leagueService.myLeagues.isEmpty {
                            emptyStateView
                        } else {
                            leaguesSection
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    if let userId = auth.currentUserId {
                        await leagueService.loadMyLeagues(userId: userId)
                    }
                }
            }
            .navigationTitle("Leagues")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(hex: "0A0A0A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    showCreateLeague = true
                } label: {
                    Label("Create League", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "1C1C1E"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    showJoinLeague = true
                } label: {
                    Label("Join League", systemImage: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "1C1C1E"))
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
        .padding(.top, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.white)
            Text("Loading leagues...")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sportscourt")
                .font(.system(size: 56))
                .foregroundStyle(Color.white.opacity(0.7))
            Text("No Leagues Yet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Create a league or join one with an invite code")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var leaguesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Leagues")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(leagueService.myLeagues) { league in
                LeagueRowView(league: league, dateFormatter: dateFormatter)
                    .onTapGesture {
                        selectedLeague = league
                    }
            }
        }
    }
}

struct LeagueRowView: View {
    let league: League
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(league.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(league.statusDisplay)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            HStack(spacing: 16) {
                Label("\(league.capacity) players", systemImage: "person.2")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
                Text("Draft: \(dateFormatter.string(from: league.draftDate))")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
        }
        .padding(16)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    LeaguesListView()
        .environmentObject(AuthViewModel())
}
