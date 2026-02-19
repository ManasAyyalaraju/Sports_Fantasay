//
//  DraftPlayerPoolView.swift
//  Sport_Tracker-Fantasy
//
//  Phase 5.4: Player pool for draft — exclude already-drafted players, tap to pick.
//

import SwiftUI
import Supabase

struct DraftPlayerPoolView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var draftService: DraftService
    let league: League

    @State private var players: [PlayerWithStats] = []
    @State private var draftedPlayerIds: Set<Int> = []
    @State private var isLoading = true
    @State private var isMakingPick = false
    @State private var searchText = ""
    @State private var selectedPlayer: PlayerWithStats?
    @State private var showConfirmPick = false
    @State private var pickError: String?
    @Environment(\.dismiss) private var dismiss

    private var availablePlayers: [PlayerWithStats] {
        players.filter { !draftedPlayerIds.contains($0.id) }
    }

    private var filteredPlayers: [PlayerWithStats] {
        let available = availablePlayers
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return available }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return available.filter { p in
            p.player.displayFullName.lowercased().contains(query)
                || p.player.teamAbbreviation.lowercased().contains(query)
                || p.player.firstName.lowercased().contains(query)
                || p.player.lastName.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.white)
                } else if availablePlayers.isEmpty {
                    Text("No players available — all players have been drafted.")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                        .padding()
                } else if !searchText.isEmpty && filteredPlayers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: "8E8E93"))
                        Text("No players match \"\(searchText)\"")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPlayers.prefix(200)) { p in
                                Button {
                                    selectedPlayer = p
                                    showConfirmPick = true
                                } label: {
                                    HStack(spacing: 12) {
                                        PlayerPhotoView(player: p.player, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.player.displayFullName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                            HStack(spacing: 6) {
                                                Text(p.player.teamAbbreviation)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color(hex: "8E8E93"))
                                                if !p.player.position.isEmpty {
                                                    Text("•")
                                                        .foregroundStyle(Color(hex: "8E8E93"))
                                                    Text(p.player.position)
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(Color(hex: "8E8E93"))
                                                }
                                            }
                                        }
                                        Spacer()
                                        if let avg = p.averages, avg.gamesPlayed > 0 {
                                            Text(String(format: "%.1f FPPG", avg.fantasyScore))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.white)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color(hex: "8E8E93"))
                                    }
                                    .padding(12)
                                    .background(Color(hex: "1C1C1E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .disabled(isMakingPick)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Select Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0A0A0A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search players")
            .task {
                await loadData()
            }
            .alert("Draft \(selectedPlayer?.player.displayFullName ?? "player")?", isPresented: $showConfirmPick) {
                Button("Cancel", role: .cancel) {
                    selectedPlayer = nil
                }
                Button("Draft", role: .destructive) {
                    if let player = selectedPlayer {
                        Task { await makePick(playerId: player.id) }
                    }
                }
            } message: {
                if let player = selectedPlayer {
                    Text("You will draft \(player.player.displayFullName) with this pick.")
                }
            }
            .alert("Pick failed", isPresented: Binding(
                get: { pickError != nil },
                set: { if !$0 { pickError = nil } }
            )) {
                Button("OK") { pickError = nil }
            } message: {
                if let err = pickError { Text(err) }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let playersTask = Task {
            try await SupabaseNBAService.shared.fetchPlayersWithStats()
        }
        async let draftedTask = Task {
            try await loadDraftedPlayers()
        }

        do {
            players = try await playersTask.value
            draftedPlayerIds = try await draftedTask.value
        } catch {
            pickError = error.localizedDescription
        }
    }

    private func loadDraftedPlayers() async throws -> Set<Int> {
        struct RosterPickRow: Decodable {
            let player_id: Int
        }
        let rows: [RosterPickRow] = try await SupabaseManager.shared.client
            .from("roster_picks")
            .select("player_id")
            .eq("league_id", value: league.id.uuidString.lowercased())
            .execute()
            .value
        return Set(rows.map(\.player_id))
    }

    private func makePick(playerId: Int) async {
        isMakingPick = true
        defer { isMakingPick = false }
        pickError = nil

        do {
            try await draftService.makePick(leagueId: league.id, playerId: playerId)
            dismiss()
        } catch {
            pickError = error.localizedDescription
            await loadData()
        }
    }
}

#Preview {
    DraftPlayerPoolView(
        draftService: DraftService(),
        league: League(
            id: UUID(),
            name: "Test League",
            capacity: 2,
            draftDate: Date(),
            inviteCode: "ABC123",
            creatorId: UUID(),
            status: "draft_in_progress",
            season: "2025",
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .environmentObject(AuthViewModel())
}
