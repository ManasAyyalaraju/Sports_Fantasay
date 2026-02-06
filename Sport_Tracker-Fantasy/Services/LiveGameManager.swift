//
//  LiveGameManager.swift
//  Sport_Tracker-Fantasy
//
//  Manages live game tracking with automatic refresh
//

import Foundation
import Combine
import UIKit

// MARK: - Live Game Manager

/// Manages live game tracking with automatic 60-second refresh
/// Only tracks favorite players to minimize API requests
@MainActor
final class LiveGameManager: ObservableObject {
    static let shared = LiveGameManager()
    
    /// Live stats for tracked players (playerId -> stats)
    @Published private(set) var livePlayerStats: [Int: LivePlayerStat] = [:]
    
    /// Currently live games
    @Published private(set) var liveGames: [LiveGame] = []
    
    /// Whether we're currently fetching
    @Published private(set) var isRefreshing = false
    
    /// Last successful refresh time
    @Published private(set) var lastRefreshed: Date?
    
    /// Error from last refresh attempt
    @Published private(set) var lastError: String?
    
    /// Whether auto-refresh is active
    @Published private(set) var isAutoRefreshEnabled = false
    
    /// Refresh interval in seconds
    private let refreshInterval: TimeInterval = 60
    
    /// Timer for auto-refresh
    private var refreshTimer: Timer?
    
    /// Player IDs to track (favorites)
    private var trackedPlayerIds: Set<Int> = []
    
    /// Cancellables for notification observers
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAppLifecycleObservers()
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleObservers() {
        // Pause when app goes to background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pauseAutoRefresh()
                }
            }
            .store(in: &cancellables)
        
        // Resume when app comes to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resumeAutoRefresh()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /// Start tracking live stats for favorite players
    /// - Parameter playerIds: Set of player IDs to track
    func startTracking(playerIds: Set<Int>) {
        trackedPlayerIds = playerIds
        
        guard !playerIds.isEmpty else {
            stopTracking()
            return
        }
        
        // Start auto-refresh
        isAutoRefreshEnabled = true
        startAutoRefresh()
        
        // Initial fetch
        Task {
            await refresh()
        }
    }
    
    /// Update the set of tracked players
    func updateTrackedPlayers(_ playerIds: Set<Int>) {
        let wasTracking = !trackedPlayerIds.isEmpty
        trackedPlayerIds = playerIds
        
        if playerIds.isEmpty {
            stopTracking()
        } else if !wasTracking {
            startTracking(playerIds: playerIds)
        }
    }
    
    /// Stop tracking and clean up
    func stopTracking() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        isAutoRefreshEnabled = false
        livePlayerStats.removeAll()
        liveGames.removeAll()
    }
    
    /// Manual refresh
    func refresh() async {
        guard !trackedPlayerIds.isEmpty else { return }
        guard !isRefreshing else { return }
        
        isRefreshing = true
        lastError = nil
        
        do {
            // Fetch live stats for tracked players
            let stats = try await LiveScoresAPI.shared.fetchLiveStatsForPlayers(playerIds: trackedPlayerIds)
            
            // Also get the live games list
            let games = try await LiveScoresAPI.shared.fetchLiveGames()
            
            livePlayerStats = stats
            liveGames = games
            lastRefreshed = Date()
            
        } catch {
            lastError = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    /// Check if a specific player is currently live
    func isPlayerLive(_ playerId: Int) -> Bool {
        livePlayerStats[playerId] != nil
    }
    
    /// Get live stats for a specific player
    func getLiveStats(for playerId: Int) -> LivePlayerStat? {
        livePlayerStats[playerId]
    }
    
    /// Pause auto-refresh (when app goes to background)
    func pauseAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Resume auto-refresh (when app comes to foreground)
    func resumeAutoRefresh() {
        guard isAutoRefreshEnabled && !trackedPlayerIds.isEmpty else { return }
        startAutoRefresh()
        
        // Refresh immediately when resuming
        Task {
            await refresh()
        }
    }
    
    // MARK: - Private
    
    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }
}
