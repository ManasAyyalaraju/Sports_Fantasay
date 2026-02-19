//
//  CreateLeagueView.swift
//  Sport_Tracker-Fantasy
//
//  Form to create a league; shows invite code/link on success.
//

import SwiftUI

struct CreateLeagueView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var leagueService: LeagueService
    var onDismiss: () -> Void

    @State private var name = ""
    @State private var capacity = 6
    @State private var draftDate = Date().addingTimeInterval(86400 * 7) // 1 week from now
    @State private var isSubmitting = false
    @State private var createdLeague: League?
    @Environment(\.dismiss) private var dismiss

    private let capacityOptions = [2, 3, 4, 5, 6, 7, 8, 9, 10]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0A")
                    .ignoresSafeArea()

                if let league = createdLeague {
                    inviteCodeSection(league: league)
                } else {
                    formSection
                }
            }
            .navigationTitle("Create League")
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
        }
    }

    private var formSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("League name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color(hex: "1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "3A3A3C"), lineWidth: 1)
                        )
                        .autocapitalization(.words)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of players")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    Picker("", selection: $capacity) {
                        ForEach(capacityOptions, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Draft date & time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    DatePicker("", selection: $draftDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(Color.white)
                }

                if let msg = leagueService.errorMessage {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "FF3B30"))
                }

                Button {
                    submitCreate()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Create League")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color(hex: "2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            }
            .padding(20)
        }
    }

    private func inviteCodeSection(league: League) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("League created")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                Text(league.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Invite code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                Text(league.inviteCode)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Share this code so others can join. Or use the link:")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "8E8E93"))

            Text("sporttracker://join?code=\(league.inviteCode)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(hex: "8E8E93"))
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer()

            Button {
                onDismiss()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(Color(hex: "2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
    }

    private func submitCreate() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let userId = auth.currentUserId else { return }
        isSubmitting = true
        leagueService.clearError()
        Task {
            do {
                let league = try await leagueService.createLeague(name: trimmed, capacity: capacity, draftDate: draftDate, creatorId: userId)
                await MainActor.run {
                    createdLeague = league
                    isSubmitting = false
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
    CreateLeagueView(leagueService: LeagueService(), onDismiss: {})
        .environmentObject(AuthViewModel())
}
