//
//  JoinLeagueView.swift
//  Sport_Tracker-Fantasy
//
//  Enter invite code to join a league.
//

import SwiftUI

struct JoinLeagueView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var leagueService: LeagueService
    var onDismiss: () -> Void

    @State private var inviteCode = ""
    @State private var isSubmitting = false
    @FocusState private var codeFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                        TextField("", text: $inviteCode)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color(hex: "1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "3A3A3C"), lineWidth: 1)
                            )
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .focused($codeFocused)
                    }

                    if let msg = leagueService.errorMessage {
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "FF3B30"))
                    }

                    Button {
                        submitJoin()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color(hex: "1C1C1E"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Join League")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(hex: "1C1C1E"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Join League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0A0A0A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(Color.white)
                }
            }
            .onAppear {
                codeFocused = true
            }
        }
    }

    private func submitJoin() {
        guard let userId = auth.currentUserId else { return }
        isSubmitting = true
        leagueService.clearError()
        Task {
            do {
                try await leagueService.joinLeague(inviteCode: inviteCode, userId: userId)
                await MainActor.run {
                    isSubmitting = false
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    leagueService.setErrorMessage(error.localizedDescription)
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    JoinLeagueView(leagueService: LeagueService(), onDismiss: {})
        .environmentObject(AuthViewModel())
}
