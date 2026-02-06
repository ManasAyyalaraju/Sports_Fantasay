//
//  FollowingView.swift
//  Sport_Tracker-Fantasy
//
//  Following tab – favourites across teams, players and leagues.
//  Backed by Supabase (fantasyball project).
//

import SwiftUI

struct FollowingView: View {
    @State private var followedTeams: [FollowedTeam] = []
    @State private var followedPlayers: [FollowedPlayer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = 0 // 0 = Teams, 1 = Players
    @State private var showAddTeam = false
    @State private var showAddPlayer = false
    @State private var newTeamName = ""
    @State private var newTeamLeague = "NBA"
    @State private var newPlayerName = ""
    @State private var newPlayerTeam = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if !SupabaseConfig.isConfigured {
                    configWarning
                } else {
                    Picker("", selection: $selectedTab) {
                        Text("Teams").tag(0)
                        Text("Players").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(AppColors.accent)
                            Text("Loading…")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if selectedTab == 0 {
                        teamsList
                    } else {
                        playersList
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.background)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Following")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if SupabaseConfig.isConfigured {
                        Button {
                            if selectedTab == 0 { showAddTeam = true }
                            else { showAddPlayer = true }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showAddTeam) {
                addTeamSheet
            }
            .sheet(isPresented: $showAddPlayer) {
                addPlayerSheet
            }
        }
    }

    private var configWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supabase not configured")
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Text("Add your fantasyball Project URL and anon key in SupabaseConfig.swift to sync followed teams and players.")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var teamsList: some View {
        Group {
            if followedTeams.isEmpty {
                Text("No teams followed yet. Tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                List {
                    ForEach(followedTeams) { team in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(team.teamName)
                                    .font(.subheadline.bold())
                                Text(team.league)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await removeTeam(team) }
                            } label: {
                                Image(systemName: "star.slash.fill")
                                    .font(.subheadline)
                            }
                        }
                        .listRowBackground(AppColors.background)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var playersList: some View {
        Group {
            if followedPlayers.isEmpty {
                Text("No players followed yet. Tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                List {
                    ForEach(followedPlayers) { player in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.playerName)
                                    .font(.subheadline.bold())
                                if let team = player.teamName, !team.isEmpty {
                                    Text(team)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await removePlayer(player) }
                            } label: {
                                Image(systemName: "star.slash.fill")
                                    .font(.subheadline)
                            }
                        }
                        .listRowBackground(AppColors.background)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var addTeamSheet: some View {
        NavigationStack {
            Form {
                TextField("Team name", text: $newTeamName)
                TextField("League", text: $newTeamLeague)
            }
            .navigationTitle("Follow team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTeam = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addTeam() }
                    }
                    .disabled(newTeamName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var addPlayerSheet: some View {
        NavigationStack {
            Form {
                TextField("Player name", text: $newPlayerName)
                TextField("Team (optional)", text: $newPlayerTeam)
            }
            .navigationTitle("Follow player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddPlayer = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addPlayer() }
                    }
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func loadData() async {
        guard SupabaseConfig.isConfigured else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            followedTeams = try await SupabaseService.shared.fetchFollowedTeams()
            followedPlayers = try await SupabaseService.shared.fetchFollowedPlayers()
        } catch {
            errorMessage = "Couldn't load data. \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func addTeam() async {
        let name = newTeamName.trimmingCharacters(in: .whitespaces)
        let league = newTeamLeague.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try await SupabaseService.shared.addFollowedTeam(
                teamName: name,
                league: league.isEmpty ? "NBA" : league
            )
            showAddTeam = false
            newTeamName = ""
            newTeamLeague = "NBA"
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addPlayer() async {
        let name = newPlayerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try await SupabaseService.shared.addFollowedPlayer(
                playerName: name,
                teamName: newPlayerTeam.isEmpty ? nil : newPlayerTeam
            )
            showAddPlayer = false
            newPlayerName = ""
            newPlayerTeam = ""
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeTeam(_ team: FollowedTeam) async {
        do {
            try await SupabaseService.shared.removeFollowedTeam(id: team.id)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removePlayer(_ player: FollowedPlayer) async {
        do {
            try await SupabaseService.shared.removeFollowedPlayer(id: player.id)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    FollowingView()
}
