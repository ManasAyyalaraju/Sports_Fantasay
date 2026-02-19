//
//  AddPlayerToRosterView.swift
//  Sport_Tracker-Fantasy
//
//  Phase 3 test: pick a player to add to your roster for the league.
//

import SwiftUI

/// Wrapper for value-based navigation so navigationDestination is resolved reliably (same type as link value).
private struct AddPlayerNavValue: Hashable {
    let player: NBAPlayer
    func hash(into hasher: inout Hasher) { hasher.combine(player.id) }
    static func == (l: AddPlayerNavValue, r: AddPlayerNavValue) -> Bool { l.player.id == r.player.id }
}

struct AddPlayerToRosterView: View {
    @EnvironmentObject var auth: AuthViewModel
    let league: League
    let rosterPlayerIds: Set<Int>
    let onAdded: () -> Void

    @State private var players: [PlayerWithStats] = []
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var searchText = ""
    @State private var addedPlayerName: String? = nil
    @State private var path = NavigationPath()
    @Environment(\.dismiss) private var dismiss

    private func navValue(for player: NBAPlayer) -> AddPlayerNavValue { AddPlayerNavValue(player: player) }

    private var availablePlayers: [PlayerWithStats] {
        players.filter { !rosterPlayerIds.contains($0.id) }
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
        NavigationStack(path: $path) {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.white)
                } else if availablePlayers.isEmpty {
                    Text("No players left to add, or everyone is already on your roster.")
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
                                NavigationLink(value: navValue(for: p.player)) {
                                    HStack(spacing: 12) {
                                        PlayerPhotoView(player: p.player, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.player.displayFullName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Text(p.player.teamAbbreviation)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color(hex: "8E8E93"))
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
                                .disabled(isAdding)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationDestination(for: AddPlayerNavValue.self) { nav in
                PlayerDetailView(
                    player: nav.player,
                    isFavorite: false,
                    onFavoriteToggle: { },
                    league: league,
                    isOnRoster: false,
                    onAddToRoster: { addPlayer(nav.player) },
                    isPushed: true
                )
            }
            .navigationTitle("Add player")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name or team")
            .toolbarBackground(Color(hex: "0A0A0A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.white)
                }
            }
            .task {
                await loadPlayers()
            }
            .alert("Added to roster", isPresented: Binding(get: { addedPlayerName != nil }, set: { if !$0 { addedPlayerName = nil } })) {
                Button("OK") {
                    confirmAddedAndDismiss()
                }
            } message: {
                if let name = addedPlayerName {
                    Text("\(name) has been added to your roster.")
                }
            }
        }
    }

    private func confirmAddedAndDismiss() {
        addedPlayerName = nil
        onAdded()
        dismiss()
    }

    private func loadPlayers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            players = try await SupabaseNBAService.shared.fetchPlayersWithStats()
        } catch {}
    }

    private func addPlayer(_ player: NBAPlayer) {
        guard let userId = auth.currentUserId else { return }
        isAdding = true
        Task {
            do {
                try await RosterService.shared.addPlayerToRoster(leagueId: league.id, userId: userId, playerId: player.id, pickNumber: 1, round: 1)
                await MainActor.run {
                    isAdding = false
                    if !path.isEmpty { path.removeLast() }
                    addedPlayerName = player.displayFullName
                }
            } catch {
                await MainActor.run { isAdding = false }
            }
        }
    }
}

#Preview {
    AddPlayerToRosterView(
        league: League(id: UUID(), name: "Test", capacity: 6, draftDate: Date(), inviteCode: "ABC", creatorId: UUID(), status: "open", season: "2025", createdAt: Date(), updatedAt: Date()),
        rosterPlayerIds: [],
        onAdded: {}
    )
    .environmentObject(AuthViewModel())
}
