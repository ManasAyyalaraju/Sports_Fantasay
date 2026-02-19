//
//  ContentView.swift
//  Sport_Tracker-Fantasy
//
//  NBA Fantasy App - Main Content View. Favorites + Leagues + roster (Phase 3).
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var leagueService = LeagueService()
    @StateObject private var rosterService = RosterService.shared
    @AppStorage("selectedLeagueId") private var selectedLeagueIdRaw: String = ""
    @State private var selectedTab = 0

    private var selectedLeagueId: UUID? {
        get { UUID(uuidString: selectedLeagueIdRaw) }
        set { selectedLeagueIdRaw = newValue?.uuidString ?? "" }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    HomeView(
                        rosterService: rosterService,
                        selectedLeagueId: selectedLeagueId,
                        myLeagues: leagueService.myLeagues,
                        onSelectLeague: { id in selectedLeagueIdRaw = id?.uuidString ?? "" },
                        onRemoveFromRoster: { playerId in await removeFromRoster(playerId: playerId) },
                        favoritePlayerIds: favoritesService.favoritePlayerIds,
                        onToggleFavorite: { playerId in await toggleFavorite(playerId: playerId) }
                    )
                case 1:
                    StandingsView()
                case 2:
                    ProfileView()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar (Figma: pill-shaped bar, monochrome)
            customTabBar
        }
        .task(id: auth.currentUserId) {
            if let userId = auth.currentUserId {
                await favoritesService.load(userId: userId)
                await leagueService.loadMyLeagues(userId: userId)
            }
        }
        .task(id: "\(selectedLeagueIdRaw)_\(auth.currentUserId?.uuidString ?? "")") {
            if let leagueId = selectedLeagueId, let userId = auth.currentUserId {
                await rosterService.loadRoster(leagueId: leagueId, userId: userId)
            } else {
                rosterService.clearRoster()
            }
        }
    }

    // MARK: - Custom tab bar (Figma node 19:255 – no orange, monochrome)

    private var customTabBar: some View {
        HStack(alignment: .top, spacing: 0) {
            tabItem(tag: 0, iconSelected: "house.fill", iconNormal: "house", label: "Home")
            tabItem(tag: 1, iconSelected: "list.number", iconNormal: "list.number", label: "Standings")
            tabItem(tag: 2, iconSelected: "person.fill", iconNormal: "person", label: "Profile")
        }
        .padding(4)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 100))
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func tabItem(tag: Int, iconSelected: String, iconNormal: String, label: String) -> some View {
        let isSelected = selectedTab == tag
        let icon = isSelected ? iconSelected : iconNormal
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tag }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(hex: "8E8E93"))
                .padding(.horizontal, isSelected ? 27 : 16)
                .padding(.vertical, isSelected ? 11 : 10)
                .frame(width: isSelected ? 84 : nil, height: isSelected ? 50 : nil, alignment: .center)
                .accessibilityLabel(label)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 100)
                            .fill(.white.opacity(0.12))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func removeFromRoster(playerId: Int) async {
        guard let leagueId = selectedLeagueId else { return }
        rosterService.clearError()
        do {
            try await rosterService.removePlayerFromRoster(leagueId: leagueId, playerId: playerId)
        } catch {
            rosterService.setErrorMessage("Could not remove player: \(error.localizedDescription)")
        }
    }

    private func toggleFavorite(playerId: Int) async {
        guard let userId = auth.currentUserId else { return }
        await favoritesService.toggleFavorite(playerId: playerId, userId: userId)
    }

}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
