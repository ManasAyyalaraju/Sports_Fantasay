//
//  DraftLobbyView.swift
//  Sport_Tracker-Fantasy
//
//  Phase 5.3: Draft lobby — round, pick #, "Your pick" / "Waiting for [name]".
//

import SwiftUI

struct DraftLobbyView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var draftService = DraftService()
    let league: League
    @State private var showPlayerPool = false

    var body: some View {
        Group {
            if draftService.isLoading && draftService.draftState == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Loading draft…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let state = draftService.draftState {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if state.draft.status == "completed" {
                            completedSection
                        } else {
                            roundAndPickSection(state: state)
                            whoseTurnSection(state: state)
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 12) {
                    Text("No draft in progress")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Start the draft from the league screen.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(hex: "0A0A0A"))
        .ignoresSafeArea()
        .navigationTitle("Draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0A0A0A"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: league.id) {
            await draftService.loadDraft(leagueId: league.id)
        }
        .refreshable {
            await draftService.loadDraft(leagueId: league.id)
        }
        .alert("Draft error", isPresented: Binding(
            get: { draftService.errorMessage != nil },
            set: { if !$0 { draftService.clearError() } }
        )) {
            Button("OK") { draftService.clearError() }
        } message: {
            if let err = draftService.errorMessage { Text(err) }
        }
        .sheet(isPresented: $showPlayerPool) {
            DraftPlayerPoolView(draftService: draftService, league: league)
                .environmentObject(auth)
                .onDisappear {
                    Task {
                        await draftService.loadDraft(leagueId: league.id)
                    }
                }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "00EFEB"))
                Text("Draft complete")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text("All picks have been made. View your roster on Home.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func roundAndPickSection(state: DraftState) -> some View {
        let globalPick = state.draft.totalPicksMade + 1
        let maxPicks = state.capacity * state.draft.totalRounds
        return VStack(alignment: .leading, spacing: 8) {
            Text("Round \(state.draft.currentRound) of \(state.draft.totalRounds)")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "8E8E93"))
            Text("Pick #\(globalPick) of \(maxPicks)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func whoseTurnSection(state: DraftState) -> some View {
        let isMyTurn = auth.currentUserId == state.whoseTurnUserId
        let name = state.whoseTurnDisplayName?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? state.whoseTurnDisplayName!
            : "Someone"
        return VStack(spacing: 16) {
            if isMyTurn {
                Text("Your pick")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Button {
                    showPlayerPool = true
                } label: {
                    Label("Select a player", systemImage: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "0073EF"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(draftService.isMakingPick)
            } else {
                Text("Waiting for \(name)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Pull down to refresh when they pick.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(isMyTurn ? Color(hex: "0073EF").opacity(0.25) : Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        DraftLobbyView(league: League(
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
        ))
        .environmentObject(AuthViewModel())
    }
}
