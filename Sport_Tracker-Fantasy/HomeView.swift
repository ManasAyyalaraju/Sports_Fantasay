//
//  HomeView.swift
//  Sport_Tracker-Fantasy
//
//  Home tab – overview of scores, schedules and leagues.
//

import SwiftUI

struct HomeView: View {
    @State private var matches: [LiveMatch] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDay: DaySelection = .today
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColors.text)
                    
                    Text("NBA results, live scores and upcoming tip-offs.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
                
                // Day selector
                Picker("", selection: $selectedDay) {
                    Text("Yesterday").tag(DaySelection.yesterday)
                    Text("Today").tag(DaySelection.today)
                    Text("Tomorrow").tag(DaySelection.tomorrow)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
                .onChange(of: selectedDay) { _ in
                    Task {
                        await loadMatches()
                    }
                }
                
                // Content
                Group {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(AppColors.accent)
                            Text("Loading live scores…")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if matches.isEmpty {
                        Text("No NBA games found for this day.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    } else {
                        List(matches) { match in
                            MatchRow(match: match)
                                .listRowBackground(AppColors.background)
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding()
            .background(AppColors.background)
            .ignoresSafeArea(edges: .bottom)
            .task {
                await loadMatches()
            }
        }
    }
    
    // MARK: - Data loading
    
    private func loadMatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let offset: Int
            switch selectedDay {
            case .yesterday:
                offset = -1
            case .today:
                offset = 0
            case .tomorrow:
                offset = 1
            }
            if let targetDate = calendar.date(byAdding: .day, value: offset, to: today) {
                matches = try await LiveScoresAPI.shared.fetchNBAGames(for: targetDate)
            } else {
                matches = []
            }
        } catch {
            errorMessage = "Couldn't load scores. Please try again later."
        }
        
        isLoading = false
    }
}

// MARK: - Day selection

private enum DaySelection: String, CaseIterable, Identifiable {
    case yesterday
    case today
    case tomorrow
    
    var id: Self { self }
}

// MARK: - Row

private struct MatchRow: View {
    let match: LiveMatch
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.league)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(match.homeTeam)
                        Spacer()
                        if let score = match.homeScore {
                            Text("\(score)")
                                .bold()
                        } else {
                            // For upcoming games (no score yet), show the game time instead of a score.
                            Text(match.status)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    
                    HStack {
                        Text(match.awayTeam)
                        Spacer()
                        if let score = match.awayScore {
                            Text("\(score)")
                                .bold()
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.text)
            }
            
            Text(match.status)
                .font(.caption.bold())
                .foregroundStyle(AppColors.accent)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    HomeView()
}