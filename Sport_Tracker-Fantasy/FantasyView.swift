//
//  FantasyView.swift
//  Sport_Tracker-Fantasy
//
//  Fantasy tab – create and manage fantasy squads. Backed by Supabase.
//

import SwiftUI

struct FantasyView: View {
    @State private var squads: [FantasySquad] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSquad = false
    @State private var newSquadName = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if !SupabaseConfig.isConfigured {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supabase not configured")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                        Text("Add your fantasyball Project URL and anon key in SupabaseConfig.swift to manage fantasy squads.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                } else if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AppColors.accent)
                        Text("Loading squads…")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if squads.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No fantasy squads yet")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                        Text("Create a squad to build your dream lineup across sports.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                        Button {
                            showCreateSquad = true
                        } label: {
                            Label("Create squad", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.accent)
                        .padding(.top, 8)
                    }
                } else {
                    List {
                        ForEach(squads) { squad in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(squad.name)
                                        .font(.subheadline.bold())
                                    Text(squad.sport ?? "basketball")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await deleteSquad(squad) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                }
                            }
                            .listRowBackground(AppColors.background)
                        }
                    }
                    .listStyle(.plain)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.background)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Fantasy")
            .toolbar {
                if SupabaseConfig.isConfigured && !squads.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreateSquad = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .task {
                await loadSquads()
            }
            .sheet(isPresented: $showCreateSquad) {
                NavigationStack {
                    Form {
                        TextField("Squad name", text: $newSquadName)
                    }
                    .navigationTitle("New squad")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreateSquad = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                Task { await createSquad() }
                            }
                            .disabled(newSquadName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func loadSquads() async {
        guard SupabaseConfig.isConfigured else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            squads = try await SupabaseService.shared.fetchFantasySquads()
        } catch {
            errorMessage = "Couldn't load squads. \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func createSquad() async {
        let name = newSquadName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            _ = try await SupabaseService.shared.createFantasySquad(name: name)
            showCreateSquad = false
            newSquadName = ""
            await loadSquads()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSquad(_ squad: FantasySquad) async {
        do {
            try await SupabaseService.shared.deleteFantasySquad(id: squad.id)
            await loadSquads()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    FantasyView()
}
