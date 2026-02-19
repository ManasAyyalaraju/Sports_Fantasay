//
//  LeagueDetailView.swift
//  Sport_Tracker-Fantasy
//
//  League detail: info, add player (test for Phase 3), Phase 5.1 start draft.
//

import SwiftUI

struct LeagueDetailView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var leagueService: LeagueService
    @StateObject private var rosterService = RosterService.shared
    let league: League
    @State private var showAddPlayer = false
    @State private var draftStarted = false
    @State private var isStartingDraft = false
    @State private var startDraftError: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(league.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(league.statusDisplay)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 12) {
                    detailRow(label: "Players", value: "\(league.capacity)")
                    detailRow(label: "Draft", value: dateFormatter.string(from: league.draftDate))
                    detailRow(label: "Invite code", value: league.inviteCode)
                }
                .padding(16)
                .background(Color(hex: "1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                let canStartDraft = (league.status == "open" || league.status == "draft_scheduled")
                    && league.creatorId == auth.currentUserId
                let draftInProgress = league.status == "draft_in_progress" || draftStarted

                if canStartDraft && !draftInProgress {
                    Button {
                        Task { await startDraft() }
                    } label: {
                        HStack {
                            if isStartingDraft {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "1C1C1E")))
                            } else {
                                Label("Start draft", systemImage: "play.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(hex: "1C1C1E"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartingDraft)
                }

                if draftInProgress {
                    NavigationLink {
                        DraftLobbyView(league: league)
                            .environmentObject(auth)
                    } label: {
                        Label("Open draft", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "0073EF"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                if league.status == "open" && !draftInProgress {
                    Button {
                        showAddPlayer = true
                    } label: {
                        Label("Add player to roster (test)", systemImage: "person.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                    }
                    .buttonStyle(.plain)
                }

                if let err = startDraftError {
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "FF3B30"))
                }
            }
            .padding(20)
        }
        .background(Color(hex: "0A0A0A"))
        .ignoresSafeArea()
        .navigationTitle("League")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0A0A0A"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: league.id) {
            if let userId = auth.currentUserId {
                await rosterService.loadRoster(leagueId: league.id, userId: userId)
            }
        }
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerToRosterView(
                league: league,
                rosterPlayerIds: rosterService.rosterPlayerIds,
                onAdded: {
                    showAddPlayer = false
                    if let userId = auth.currentUserId {
                        Task { await rosterService.loadRoster(leagueId: league.id, userId: userId) }
                    }
                }
            )
            .environmentObject(auth)
        }
        .alert("Start draft failed", isPresented: Binding(
            get: { startDraftError != nil },
            set: { if !$0 { startDraftError = nil } }
        )) {
            Button("OK") { startDraftError = nil }
        } message: {
            if let err = startDraftError { Text(err) }
        }
    }

    private func startDraft() async {
        startDraftError = nil
        isStartingDraft = true
        defer { isStartingDraft = false }
        do {
            try await leagueService.startDraft(leagueId: league.id)
            draftStarted = true
            if let userId = auth.currentUserId {
                await leagueService.loadMyLeagues(userId: userId)
            }
        } catch {
            startDraftError = error.localizedDescription
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "8E8E93"))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationStack {
        LeagueDetailView(
            leagueService: LeagueService(),
            league: League(
                id: UUID(),
                name: "Test League",
                capacity: 8,
                draftDate: Date(),
                inviteCode: "ABC123",
                creatorId: UUID(),
                status: "open",
                season: "2025",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        .environmentObject(AuthViewModel())
    }
}
