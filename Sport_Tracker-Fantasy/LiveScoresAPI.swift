//
//  LiveScoresAPI.swift
//  Sport_Tracker-Fantasy
//
//  NBA Fantasy API Service
//  Fetches NBA players and their game statistics from API-Sports.
//

import Foundation
import Combine

// MARK: - Cache Entry

private struct CacheEntry<T> {
    let data: T
    let timestamp: Date
    
    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

// MARK: - API Service

final class LiveScoresAPI: @unchecked Sendable {
    static let shared = LiveScoresAPI()
    
    // =====================================================
    // API-Sports Configuration
    // =====================================================
    // Get your API key at: https://dashboard.api-football.com
    // 1. Create account or login
    // 2. Subscribe to NBA API PRO plan ($15/month)
    // 3. Copy your API key from the dashboard
    // 4. Replace the placeholder below with your key
    // =====================================================
    private let apiSportsKey: String = "6c8528dea3157cfa1411fbee172b19e6"
    
    /// Base URL for API-Sports NBA
    private let baseURL = "https://v2.nba.api-sports.io"
    
    private let decoder = JSONDecoder()
    
    // MARK: - Cache Configuration
    
    /// Cache duration: 10 minutes
    private let cacheTTL: TimeInterval = 600
    
    /// Stats cache duration: 5 minutes (shorter for live data)
    private let statsCacheTTL: TimeInterval = 300
    
    // MARK: - Caches
    
    private var playersCache: CacheEntry<[NBAPlayer]>?
    private var playersWithStatsCache: CacheEntry<[PlayerWithStats]>?
    private var seasonAveragesCache: [Int: CacheEntry<SeasonAverages>] = [:]
    private var playerStatsCache: [Int: CacheEntry<[PlayerGameStats]>] = [:]
    private var teamsCache: [Int: APISportsTeam] = [:]
    
    /// Set of regular season game IDs (excludes preseason)
    private var regularSeasonGameIds: Set<Int>?
    
    /// Cache of game details by game ID for enriching player stats
    private var gameDetailsCache: [Int: GameDetails] = [:]
    
    /// Upcoming games by team ID (next game per team). TTL matches cacheTTL.
    private var upcomingGamesCache: (data: [Int: UpcomingGameInfo], timestamp: Date)?
    
    /// Lightweight struct to cache game details
    struct GameDetails {
        let homeTeamId: Int
        let homeTeamName: String
        let homeTeamAbbreviation: String
        let homeTeamScore: Int
        let visitorTeamId: Int
        let visitorTeamName: String
        let visitorTeamAbbreviation: String
        let visitorTeamScore: Int
    }
    
    // Star player names for prioritization (150 players for fantasy coverage)
    private let starPlayerNames: Set<String> = [
        // Top 50
        "nikola jokic", "shai gilgeous-alexander", "luka doncic", "tyrese maxey",
        "victor wembanyama", "anthony edwards", "james harden", "jalen johnson",
        "cade cunningham", "alperen sengun", "jaylen brown", "pascal siakam",
        "donovan mitchell", "stephen curry", "mikal bridges", "kevin durant",
        "evan mobley", "lebron james", "jalen brunson", "michael porter jr.",
        "karl-anthony towns", "deni avdija", "austin reaves", "amen thompson",
        "franz wagner", "josh giddey", "jalen williams", "paolo banchero",
        "derrick white", "jamal murray", "giannis antetokounmpo", "kawhi leonard",
        "alex sarr", "domantas sabonis", "bam adebayo", "scottie barnes",
        "lauri markkanen", "nikola vucevic", "trey murphy iii", "joel embiid",
        "jalen duren", "keyonte george", "stephon castle", "jarrett allen",
        "brandon miller", "cooper flagg", "coby white", "chet holmgren",
        "lamelo ball", "zach lavine",
        // 51-100
        "demar derozan", "devin booker", "kyshawn george", "naz reid",
        "devin vassell", "jaden mcdaniels", "brandon ingram", "josh hart",
        "julius randle", "de'aaron fox", "anthony black", "rudy gobert",
        "og anunoby", "zion williamson", "norman powell", "donovan clingan",
        "nickeil alexander-walker", "rj barrett", "saddiq bey", "kristaps porzingis",
        "vj edgecombe", "ivica zubac", "paul george", "sam merrill",
        "ryan rollins", "keegan murray", "dillon brooks", "bennedict mathurin",
        "shaedon sharpe", "anthony davis", "payton pritchard", "robert williams iii",
        "isaiah hartenstein", "matas buzelis", "darius garland", "davion mitchell",
        "desmond bane", "deandre ayton", "dyson daniels", "andrew wiggins",
        "daniel gafford", "russell westbrook", "miles bridges", "bilal coulibaly",
        "kevin porter jr.", "tyler herro", "jrue holiday", "aaron gordon",
        "cam spencer", "kon knueppel",
        // 101-150
        "jabari smith jr.", "jalen suggs", "collin sexton", "luke kornet",
        "kel'el ware", "aaron wiggins", "cameron johnson", "wendell carter jr.",
        "dennis schroder", "myles turner", "santi aldama", "jonathan kuminga",
        "kelly oubre jr.", "t.j. mcconnell", "jaime jaquez jr.", "toumani camara",
        "donte divincenzo", "nic claxton", "dereck lively ii", "bogdan bogdanovic",
        "quentin grimes", "miles mcbride", "cj mccollum", "jusuf nurkic",
        "jonas valanciunas", "isaiah stewart", "mitchell robinson", "isaiah collier",
        "draymond green", "bub carrington", "collin murray-boyles", "tre jones",
        "royce o'neale", "naji marshall", "max christie", "reed sheppard",
        "neemias queta", "aaron nesmith", "immanuel quickley", "trae young",
        "luguentz dort", "peyton watson", "caris levert", "ayo dosunmu",
        "ausar thompson", "harrison barnes", "onyeka okongwu", "julian champagnie",
        "tari eason", "andre drummond"
    ]
    
    private init() {}
    
    // MARK: - API Request Helper
    
    private func makeRequest(endpoint: String, queryParams: [String: String] = [:]) async throws -> Data {
        var urlString = "\(baseURL)/\(endpoint)"
        
        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiSportsKey, forHTTPHeaderField: "x-apisports-key")
        request.timeoutInterval = 45  // API can be slow; avoid -1001 timeouts
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                throw NSError(domain: "API", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded. Please wait."])
            }
            
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
            }
        }
        
        return data
    }
    
    // MARK: - Fetch All Players with Stats
    
    func fetchPlayersWithStats() async throws -> [PlayerWithStats] {
        if let cached = playersWithStatsCache, cached.isValid(ttl: cacheTTL) {
            return cached.data
        }
        
        let players = try await fetchAllPlayers()
        
        // Filter to players with teams (current NBA players)
        let withTeams = players.filter { $0.team != nil }
        // Deduplicate by player id (API can return same player under multiple teams)
        var seenIds: Set<Int> = []
        let activePlayers = withTeams.filter { seenIds.insert($0.id).inserted }
        
        var starPlayers: [NBAPlayer] = []
        var otherPlayers: [NBAPlayer] = []
        
        for player in activePlayers {
            let fullName = player.displayFullName.lowercased()
            if starPlayerNames.contains(fullName) {
                starPlayers.append(player)
            } else {
                otherPlayers.append(player)
            }
        }
        
        var playersWithStats: [PlayerWithStats] = []
        
        // Pre-fetch regular season game IDs once before parallel requests
        _ = try? await fetchRegularSeasonGameIds()
        
        // Use dictionary to collect results (avoids non-deterministic ordering from task group)
        var averagesDict: [Int: SeasonAverages] = [:]
        
        // Batch requests to avoid API rate limiting and timeouts (2 concurrent per batch)
        // Fetch stats for top 100 star players to get good fantasy score coverage
        let batchSize = 2
        let playersToFetch = Array(starPlayers.prefix(100))
        
        for batchStart in stride(from: 0, to: playersToFetch.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, playersToFetch.count)
            let batch = Array(playersToFetch[batchStart..<batchEnd])
            
            await withTaskGroup(of: (Int, SeasonAverages?).self) { group in
                for player in batch {
                    group.addTask {
                        let averages = try? await self.fetchSeasonAverages(playerId: player.id)
                        return (player.id, averages)
                    }
                }
                
                for await (playerId, averages) in group {
                    if let avg = averages {
                        averagesDict[playerId] = avg
                    }
                }
            }
            
            // Delay between batches to avoid timeouts and rate limiting
            if batchEnd < playersToFetch.count {
                try? await Task.sleep(nanoseconds: 450_000_000) // 450ms
            }
        }
        
        // Retry for players that didn't get stats (timeout or rate limit)
        let missingPlayers = playersToFetch.filter { averagesDict[$0.id] == nil }
        if !missingPlayers.isEmpty {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s before retry
            
            for batchStart in stride(from: 0, to: missingPlayers.count, by: 2) {
                let batchEnd = min(batchStart + 2, missingPlayers.count)
                let batch = Array(missingPlayers[batchStart..<batchEnd])
                
                await withTaskGroup(of: (Int, SeasonAverages?).self) { group in
                    for player in batch {
                        group.addTask {
                            let averages = try? await self.fetchSeasonAverages(playerId: player.id)
                            return (player.id, averages)
                        }
                    }
                    
                    for await (playerId, averages) in group {
                        if let avg = averages {
                            averagesDict[playerId] = avg
                        }
                    }
                }
                
                if batchEnd < missingPlayers.count {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                }
            }
        }
        
        // Build list: all star players 1–100 with stats (we fetched stats for all of them)
        for player in starPlayers.prefix(100) {
            playersWithStats.append(PlayerWithStats(player: player, averages: averagesDict[player.id]))
        }
        
        // Sort by fantasy score, with secondary sort by name for stability
        playersWithStats.sort { p1, p2 in
            if p1.fantasyScore != p2.fantasyScore {
                return p1.fantasyScore > p2.fantasyScore
            }
            return p1.player.fullName < p2.player.fullName
        }
        
        // Add remaining star players (101–150) without stats
        let top100Ids = Set(starPlayers.prefix(100).map { $0.id })
        for player in starPlayers where !top100Ids.contains(player.id) {
            playersWithStats.append(PlayerWithStats(player: player, averages: nil))
        }
        // Add other players sorted by name for consistent ordering
        let sortedOtherPlayers = otherPlayers.sorted { $0.fullName < $1.fullName }
        for player in sortedOtherPlayers {
            playersWithStats.append(PlayerWithStats(player: player, averages: nil))
        }
        
        playersWithStatsCache = CacheEntry(data: playersWithStats, timestamp: Date())
        
        return playersWithStats
    }
    
    // MARK: - Fetch All Players
    
    func fetchAllPlayers() async throws -> [NBAPlayer] {
        if let cached = playersCache, cached.isValid(ttl: cacheTTL) {
            return cached.data
        }
        
        // First, fetch teams
        let teams = try await fetchTeams()
        
        // Filter to only NBA franchise teams (exclude All-Star, historical, etc.)
        let nbaTeams = teams.filter { team in
            team.nbaFranchise == true && team.allStar != true
        }
        
        let season = getCurrentSeason()
        
        // Track players by team ID to allow retry for failed teams
        var playersByTeam: [Int: [NBAPlayer]] = [:]
        
        // Helper function to fetch players for a team
        func fetchPlayersForTeam(_ team: APISportsTeam) async -> (Int, [NBAPlayer]) {
            do {
                let data = try await self.makeRequest(endpoint: "players", queryParams: [
                    "team": "\(team.id)",
                    "season": season
                ])
                let response = try self.decoder.decode(APISportsPlayersResponse.self, from: data)
                let players = response.response.compactMap { apiPlayer in
                    self.convertToNBAPlayer(apiPlayer, teamOverride: team)
                }
                return (team.id, players)
            } catch {
                return (team.id, [])
            }
        }
        
        // Fetch players for each team in batches of 5 (smaller to avoid rate limits)
        let batchSize = 5
        for batchStart in stride(from: 0, to: nbaTeams.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, nbaTeams.count)
            let batch = Array(nbaTeams[batchStart..<batchEnd])
            
            await withTaskGroup(of: (Int, [NBAPlayer]).self) { group in
                for team in batch {
                    group.addTask {
                        await fetchPlayersForTeam(team)
                    }
                }
                
                for await (teamId, players) in group {
                    playersByTeam[teamId] = players
                }
            }
            
            // Add delay between batches to avoid rate limiting
            if batchEnd < nbaTeams.count {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            }
        }
        
        // Identify teams that returned empty (possibly rate-limited)
        let failedTeams = nbaTeams.filter { team in
            playersByTeam[team.id]?.isEmpty ?? true
        }
        
        // Retry failed teams with longer delays
        if !failedTeams.isEmpty {
            // Wait before retry
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Retry in batches of 3 with longer delays
            for batchStart in stride(from: 0, to: failedTeams.count, by: 3) {
                let batchEnd = min(batchStart + 3, failedTeams.count)
                let batch = Array(failedTeams[batchStart..<batchEnd])
                
                await withTaskGroup(of: (Int, [NBAPlayer]).self) { group in
                    for team in batch {
                        group.addTask {
                            await fetchPlayersForTeam(team)
                        }
                    }
                    
                    for await (teamId, players) in group {
                        if !players.isEmpty {
                            playersByTeam[teamId] = players
                        }
                    }
                }
                
                if batchEnd < failedTeams.count {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                }
            }
        }
        
        // Combine all players
        var allPlayers: [NBAPlayer] = []
        for team in nbaTeams {
            if let players = playersByTeam[team.id] {
                allPlayers.append(contentsOf: players)
            }
        }
        
        if !allPlayers.isEmpty {
            playersCache = CacheEntry(data: allPlayers, timestamp: Date())
        }
        
        return allPlayers
    }
    
    // MARK: - Fetch Teams
    
    private func fetchTeams() async throws -> [APISportsTeam] {
        let data = try await makeRequest(endpoint: "teams", queryParams: [:])
        let response = try decoder.decode(APISportsTeamsResponse.self, from: data)
        
        // Cache teams by ID
        for team in response.response {
            teamsCache[team.id] = team
        }
        
        return response.response
    }
    
    // MARK: - Fetch Regular Season Game IDs
    
    /// Fetches all games for the season and caches which ones are regular season (not preseason)
    private func fetchRegularSeasonGameIds() async throws -> Set<Int> {
        // Return cached if available
        if let cached = regularSeasonGameIds {
            return cached
        }
        
        let season = getCurrentSeason()
        
        let data = try await makeRequest(endpoint: "games", queryParams: ["season": season])
        let response = try decoder.decode(APISportsGamesResponse.self, from: data)
        
        var regularGameIds = Set<Int>()
        
        // Check if stage field is available in the data
        let hasStageField = response.response.first?.stage != nil
        
        if hasStageField {
            // Use stage field for filtering (preferred method)
            // Stage 1 = Preseason, Stage 2 = Regular Season, Stage 3+ = Playoffs/Play-in
            for game in response.response {
                if let stage = game.stage {
                    switch stage {
                    case 1:
                        // Don't add preseason to regularGameIds
                        break
                    default:
                        // Regular season, playoffs, play-in, etc. - include them
                        regularGameIds.insert(game.id)
                    }
                } else {
                    regularGameIds.insert(game.id) // Include if unknown
                }
            }
        } else {
            // Fallback: Use date cutoff if stage field not available
            let seasonYear = Int(season) ?? 2025
            let calendar = Calendar.current
            var regularSeasonStart = DateComponents()
            regularSeasonStart.year = seasonYear
            regularSeasonStart.month = 10  // October
            regularSeasonStart.day = 18    // Before regular season start
            let cutoffDate = calendar.date(from: regularSeasonStart) ?? Date.distantPast
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            
            for game in response.response {
                guard let dateStr = game.date.start else { continue }
                
                let gameDate = dateFormatter.date(from: dateStr) 
                    ?? fallbackFormatter.date(from: dateStr)
                    ?? {
                        let simpleFormatter = DateFormatter()
                        simpleFormatter.dateFormat = "yyyy-MM-dd"
                        return simpleFormatter.date(from: String(dateStr.prefix(10)))
                    }()
                
                if let gameDate = gameDate, gameDate >= cutoffDate {
                    regularGameIds.insert(game.id)
                }
            }
        }
        
        regularSeasonGameIds = regularGameIds
        
        // Cache game details for all games (for enriching player stats)
        for game in response.response {
            gameDetailsCache[game.id] = GameDetails(
                homeTeamId: game.teams.home.id,
                homeTeamName: game.teams.home.name,
                homeTeamAbbreviation: game.teams.home.code ?? "",
                homeTeamScore: game.scores.home.points ?? 0,
                visitorTeamId: game.teams.visitors.id,
                visitorTeamName: game.teams.visitors.name,
                visitorTeamAbbreviation: game.teams.visitors.code ?? "",
                visitorTeamScore: game.scores.visitors.points ?? 0
            )
        }
        
        return regularGameIds
    }
    
    // MARK: - Upcoming Games (next game per team for home roster)
    
    /// Fetches the next upcoming game for each given team from the season schedule.
    /// Uses the same "games" endpoint (full season); filters to games on or after today, excludes preseason.
    func fetchUpcomingGamesForTeams(_ teamIds: Set<Int>) async throws -> [Int: UpcomingGameInfo] {
        guard !teamIds.isEmpty else { return [:] }
        // Only use cache if we have next game for every requested team (avoids stale cache when user switches league)
        if let cached = upcomingGamesCache, Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            let fromCache = teamIds.reduce(into: [Int: UpcomingGameInfo]()) { result, id in
                if let info = cached.data[id] { result[id] = info }
            }
            if fromCache.count == teamIds.count {
                return fromCache
            }
        }
        let season = getCurrentSeason()
        let data = try await makeRequest(endpoint: "games", queryParams: ["season": season])
        let response = try decoder.decode(APISportsGamesResponse.self, from: data)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        var upcoming: [(date: Date, game: APISportsGame)] = []
        for game in response.response {
            if game.stage == 1 { continue }
            guard let dateStr = game.date.start else { continue }
            let gameDate = isoFormatter.date(from: dateStr)
                ?? fallbackFormatter.date(from: dateStr)
                ?? { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: String(dateStr.prefix(10))) }()
            guard let d = gameDate, d >= todayStart else { continue }
            upcoming.append((d, game))
        }
        upcoming.sort { $0.date < $1.date }
        var byTeam: [Int: UpcomingGameInfo] = [:]
        var assignedTeams: Set<Int> = []
        for (date, game) in upcoming {
            let homeId = game.teams.home.id
            let visId = game.teams.visitors.id
            let homeCode = game.teams.home.code ?? ""
            let visCode = game.teams.visitors.code ?? ""
            let timeStr = timeFormatter.string(from: date)
            let info = UpcomingGameInfo(visitorAbbreviation: visCode, homeAbbreviation: homeCode, timeString: timeStr)
            if teamIds.contains(homeId), !assignedTeams.contains(homeId) {
                byTeam[homeId] = info
                assignedTeams.insert(homeId)
            }
            if teamIds.contains(visId), !assignedTeams.contains(visId) {
                byTeam[visId] = info
                assignedTeams.insert(visId)
            }
            if assignedTeams.count >= teamIds.count { break }
        }
        upcomingGamesCache = (byTeam, Date())
        return byTeam
    }
    
    // MARK: - Search Players
    
    func searchPlayers(query: String) async throws -> [NBAPlayer] {
        guard !query.isEmpty else { return [] }
        
        if let cached = playersCache, cached.isValid(ttl: cacheTTL) {
            let query = query.lowercased()
            let results = cached.data.filter { player in
                player.displayFullName.lowercased().contains(query) ||
                player.teamFullName.lowercased().contains(query) ||
                player.teamAbbreviation.lowercased().contains(query)
            }
            if !results.isEmpty {
                return results
            }
        }
        
        let data = try await makeRequest(endpoint: "players", queryParams: ["search": query])
        let response = try decoder.decode(APISportsPlayersResponse.self, from: data)
        
        return response.response.compactMap { convertToNBAPlayer($0) }
    }
    
    // MARK: - Fetch Player Stats (Last N Games)
    
    func fetchPlayerStats(playerId: Int, lastNGames: Int = 5) async throws -> [PlayerGameStats] {
        if let cached = playerStatsCache[playerId], cached.isValid(ttl: statsCacheTTL) {
            return Array(cached.data.prefix(lastNGames))
        }
        
        // Get regular season game IDs to filter out preseason
        let regularGameIds = try await fetchRegularSeasonGameIds()
        
        let season = getCurrentSeason()
        
        let data = try await makeRequest(endpoint: "players/statistics", queryParams: [
            "id": "\(playerId)",
            "season": "\(season)"
        ])
        
        let response = try decoder.decode(APISportsStatsResponse.self, from: data)
        
        var stats = response.response.compactMap { convertToPlayerGameStats($0) }
        
        // Filter to only regular season games
        stats = stats.filter { regularGameIds.contains($0.game.id) }
        
        // API-Sports returns stats in chronological order (oldest first)
        // Reverse to get most recent first
        stats.reverse()
        
        if !stats.isEmpty {
            playerStatsCache[playerId] = CacheEntry(data: stats, timestamp: Date())
        }
        
        return Array(stats.prefix(lastNGames))
    }
    
    // MARK: - Fetch Season Averages
    
    func fetchSeasonAverages(playerId: Int) async throws -> SeasonAverages? {
        if let cached = seasonAveragesCache[playerId], cached.isValid(ttl: cacheTTL) {
            return cached.data
        }
        
        let season = getCurrentSeason()
        
        // API-Sports returns all game stats, we calculate averages
        let data = try await makeRequest(endpoint: "players/statistics", queryParams: [
            "id": "\(playerId)",
            "season": "\(season)"
        ])
        
        let response = try decoder.decode(APISportsStatsResponse.self, from: data)
        
        guard !response.response.isEmpty else {
            return nil
        }
        
        // Get regular season game IDs to filter out preseason
        let regularGameIds = try await fetchRegularSeasonGameIds()
        
        // Filter to only regular season games using actual game dates
        let allGames = response.response
        let gameStats = allGames.filter { stat in
            guard let gameId = stat.game?.id else { return false }
            return regularGameIds.contains(gameId)
        }
        let gamesPlayed = gameStats.count
        
        // If all games were filtered out, something is wrong - fall back to using all games
        guard gamesPlayed > 0 else {
            // Fall back to using all games
            let fallbackStats = allGames
            var totalPts = 0, totalReb = 0, totalAst = 0, totalStl = 0, totalBlk = 0
            var totalFgm = 0, totalFga = 0, totalFg3m = 0, totalFg3a = 0, totalFtm = 0, totalFta = 0
            var totalMin = 0
            
            for stat in fallbackStats {
                totalPts += stat.points ?? 0
                totalReb += stat.totReb ?? 0
                totalAst += stat.assists ?? 0
                totalStl += stat.steals ?? 0
                totalBlk += stat.blocks ?? 0
                totalFgm += stat.fgm ?? 0
                totalFga += stat.fga ?? 0
                totalFg3m += stat.tpm ?? 0
                totalFg3a += stat.tpa ?? 0
                totalFtm += stat.ftm ?? 0
                totalFta += stat.fta ?? 0
                
                if let minStr = stat.min, let colonIdx = minStr.firstIndex(of: ":") {
                    if let mins = Int(minStr[..<colonIdx]) {
                        totalMin += mins
                    }
                }
            }
            
            let g = Double(fallbackStats.count)
            let avgMin = fallbackStats.count > 0 ? totalMin / fallbackStats.count : 0
            
            let result = SeasonAverages(
                playerId: playerId,
                pts: g > 0 ? Double(totalPts) / g : 0,
                reb: g > 0 ? Double(totalReb) / g : 0,
                ast: g > 0 ? Double(totalAst) / g : 0,
                stl: g > 0 ? Double(totalStl) / g : 0,
                blk: g > 0 ? Double(totalBlk) / g : 0,
                gamesPlayed: fallbackStats.count,
                min: "\(avgMin)",
                fgPct: totalFga > 0 ? Double(totalFgm) / Double(totalFga) * 100 : 0,
                fg3Pct: totalFg3a > 0 ? Double(totalFg3m) / Double(totalFg3a) * 100 : 0,
                ftPct: totalFta > 0 ? Double(totalFtm) / Double(totalFta) * 100 : 0
            )
            
            seasonAveragesCache[playerId] = CacheEntry(data: result, timestamp: Date())
            return result
        }
        
        var totalPts = 0, totalReb = 0, totalAst = 0, totalStl = 0, totalBlk = 0
        var totalFgm = 0, totalFga = 0, totalFg3m = 0, totalFg3a = 0, totalFtm = 0, totalFta = 0
        var totalMin = 0
        
        for stat in gameStats {
            totalPts += stat.points ?? 0
            totalReb += stat.totReb ?? 0
            totalAst += stat.assists ?? 0
            totalStl += stat.steals ?? 0
            totalBlk += stat.blocks ?? 0
            totalFgm += stat.fgm ?? 0
            totalFga += stat.fga ?? 0
            totalFg3m += stat.tpm ?? 0
            totalFg3a += stat.tpa ?? 0
            totalFtm += stat.ftm ?? 0
            totalFta += stat.fta ?? 0
            
            if let minStr = stat.min, let colonIdx = minStr.firstIndex(of: ":") {
                if let mins = Int(minStr[..<colonIdx]) {
                    totalMin += mins
                }
            }
        }
        
        let g = Double(gamesPlayed)
        let avgMin = gamesPlayed > 0 ? totalMin / gamesPlayed : 0
        
        let result = SeasonAverages(
            playerId: playerId,
            pts: g > 0 ? Double(totalPts) / g : 0,
            reb: g > 0 ? Double(totalReb) / g : 0,
            ast: g > 0 ? Double(totalAst) / g : 0,
            stl: g > 0 ? Double(totalStl) / g : 0,
            blk: g > 0 ? Double(totalBlk) / g : 0,
            gamesPlayed: gamesPlayed,
            min: "\(avgMin)",
            fgPct: totalFga > 0 ? Double(totalFgm) / Double(totalFga) * 100 : 0,
            fg3Pct: totalFg3a > 0 ? Double(totalFg3m) / Double(totalFg3a) * 100 : 0,
            ftPct: totalFta > 0 ? Double(totalFtm) / Double(totalFta) * 100 : 0
        )
        
        seasonAveragesCache[playerId] = CacheEntry(data: result, timestamp: Date())
        
        return result
    }
    
    // MARK: - Fetch Live Games
    
    func fetchLiveGames() async throws -> [LiveGame] {
        let data = try await makeRequest(endpoint: "games", queryParams: ["live": "all"])
        let response = try decoder.decode(APISportsGamesResponse.self, from: data)
        
        return response.response.map { game in
            LiveGame(
                id: game.id,
                homeTeam: game.teams.home.name,
                homeTeamCode: game.teams.home.code ?? "",
                homeTeamId: game.teams.home.id,
                homeScore: game.scores.home.points ?? 0,
                awayTeam: game.teams.visitors.name,
                awayTeamCode: game.teams.visitors.code ?? "",
                awayTeamId: game.teams.visitors.id,
                awayScore: game.scores.visitors.points ?? 0,
                status: game.status.long ?? "Unknown",
                period: game.periods.current ?? 0,
                clock: game.status.clock ?? ""
            )
        }
    }
    
    // MARK: - Fetch Game Box Score
    
    /// Fetches all player statistics for a specific game (live or completed)
    func fetchGameBoxScore(gameId: Int) async throws -> [LivePlayerStat] {
        let data = try await makeRequest(endpoint: "players/statistics", queryParams: [
            "game": "\(gameId)"
        ])
        
        let response = try decoder.decode(APISportsBoxScoreResponse.self, from: data)
        
        return response.response.compactMap { stat -> LivePlayerStat? in
            guard let playerId = stat.player?.id,
                  let firstName = stat.player?.firstname,
                  let lastName = stat.player?.lastname,
                  let teamId = stat.team?.id,
                  let teamCode = stat.team?.code else {
                return nil
            }
            
            return LivePlayerStat(
                playerId: playerId,
                playerName: "\(firstName) \(lastName)",
                teamId: teamId,
                teamCode: teamCode,
                gameId: gameId,
                points: stat.points ?? 0,
                rebounds: stat.totReb ?? 0,
                assists: stat.assists ?? 0,
                steals: stat.steals ?? 0,
                blocks: stat.blocks ?? 0,
                minutes: stat.min ?? "0",
                fgm: stat.fgm ?? 0,
                fga: stat.fga ?? 0,
                fg3m: stat.tpm ?? 0,
                fg3a: stat.tpa ?? 0,
                ftm: stat.ftm ?? 0,
                fta: stat.fta ?? 0,
                turnovers: stat.turnovers ?? 0,
                period: stat.game?.status?.short ?? 0,
                clock: stat.game?.status?.clock ?? "",
                gameStatus: stat.game?.status?.long ?? "",
                homeTeamCode: stat.game?.teams?.home?.code ?? "",
                awayTeamCode: stat.game?.teams?.visitors?.code ?? "",
                homeScore: stat.game?.scores?.home?.points ?? 0,
                awayScore: stat.game?.scores?.visitors?.points ?? 0,
                isHomeTeam: teamId == stat.game?.teams?.home?.id
            )
        }
    }
    
    // MARK: - Fetch Live Stats for Favorite Players
    
    /// Efficiently fetches live stats for a set of player IDs
    /// Only makes requests for games that are currently live
    func fetchLiveStatsForPlayers(playerIds: Set<Int>) async throws -> [Int: LivePlayerStat] {
        guard !playerIds.isEmpty else { return [:] }
        
        // Step 1: Get all live games (1 request)
        let liveGames = try await fetchLiveGames()
        
        guard !liveGames.isEmpty else {
            return [:]
        }
        
        // Step 2: Fetch box scores for all live games in parallel
        var allLiveStats: [Int: LivePlayerStat] = [:]
        
        await withTaskGroup(of: [LivePlayerStat].self) { group in
            for game in liveGames {
                group.addTask {
                    do {
                        return try await self.fetchGameBoxScore(gameId: game.id)
                    } catch {
                        return []
                    }
                }
            }
            
            for await stats in group {
                // Filter to only players we care about
                for stat in stats where playerIds.contains(stat.playerId) {
                    allLiveStats[stat.playerId] = stat
                }
            }
        }
        
        // Enrich each stat with live game context (scores, quarter, clock — box score API may omit or use wrong values)
        let gameById = Dictionary(uniqueKeysWithValues: liveGames.map { ($0.id, $0) })
        for (playerId, stat) in allLiveStats {
            if let game = gameById[stat.gameId] {
                allLiveStats[playerId] = stat.withGameContext(from: game)
            }
        }
        
        #if DEBUG
        if !allLiveStats.isEmpty {
            print("🔴 \(allLiveStats.count) favorites playing live")
        }
        #endif
        
        return allLiveStats
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        playersCache = nil
        playersWithStatsCache = nil
        seasonAveragesCache.removeAll()
        playerStatsCache.removeAll()
        regularSeasonGameIds = nil
        upcomingGamesCache = nil
    }
    
    // MARK: - Helper Methods
    
    /// Returns season in API-Sports format: "YYYY" (e.g., "2024" for 2024-25 season)
    private func getCurrentSeason() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let month = calendar.component(.month, from: Date())
        // NBA season starts in October, so if before October use previous year
        let seasonYear = month >= 10 ? year : year - 1
        return "\(seasonYear)"
    }
    
    /// Expands abbreviated first names from the API for display (e.g. "C" + "Flagg" → "Cooper").
    private func expandFirstNameForDisplay(_ firstName: String, lastName: String) -> String {
        let key = "\(firstName.lowercased())_\(lastName.lowercased())"
        switch key {
        case "c_flagg": return "Cooper"
        default: return firstName
        }
    }
    
    private func convertToNBAPlayer(_ apiPlayer: APISportsPlayer, teamOverride: APISportsTeam? = nil) -> NBAPlayer? {
        var team: NBATeam? = nil
        
        // Use team override if provided, otherwise try to get from player data
        if let t = teamOverride {
            let conference = t.leagues?["standard"]?.conference ?? ""
            let division = t.leagues?["standard"]?.division ?? ""
            team = NBATeam(
                id: t.id,
                conference: conference,
                division: division,
                city: t.city ?? "",
                name: t.name,
                fullName: "\(t.city ?? "") \(t.name)",
                abbreviation: t.code ?? ""
            )
        } else if let teamInfo = apiPlayer.team {
            team = NBATeam(
                id: teamInfo.id,
                conference: "",
                division: "",
                city: teamInfo.city ?? "",
                name: teamInfo.name,
                fullName: "\(teamInfo.city ?? "") \(teamInfo.name)",
                abbreviation: teamInfo.code ?? ""
            )
        }
        
        var height: String? = nil
        if let h = apiPlayer.height {
            if let feet = h.feets, let inches = h.inches {
                height = "\(feet)-\(inches)"
            }
        }
        
        var weight: String? = nil
        if let w = apiPlayer.weight?.pounds {
            weight = w
        }
        
        var jerseyNumber: String? = nil
        var position = ""
        if let standard = apiPlayer.leagues?["standard"] {
            if let jersey = standard.jersey {
                jerseyNumber = "\(jersey)"
            }
            position = standard.pos ?? ""
        }
        
        let displayFirstName = expandFirstNameForDisplay(apiPlayer.firstname, lastName: apiPlayer.lastname)
        return NBAPlayer(
            id: apiPlayer.id,
            firstName: displayFirstName,
            lastName: apiPlayer.lastname,
            position: position,
            height: height,
            weight: weight,
            jerseyNumber: jerseyNumber,
            college: apiPlayer.college,
            country: apiPlayer.birth?.country,
            draftYear: apiPlayer.nba?.start,
            draftRound: nil,
            draftNumber: nil,
            team: team
        )
    }
    
    private func convertToPlayerGameStats(_ stat: APISportsPlayerStat) -> PlayerGameStats? {
        guard let gameId = stat.game?.id else { return nil }
        
        // Try to get game details from cache first (more reliable)
        // Fall back to API response data if cache miss
        let cachedGame = gameDetailsCache[gameId]
        
        let gameInfo = PlayerGameStats.GameInfo(
            id: gameId,
            date: stat.game?.date?.dateString ?? "",
            homeTeamId: cachedGame?.homeTeamId ?? stat.game?.teams?.home?.id ?? 0,
            visitorTeamId: cachedGame?.visitorTeamId ?? stat.game?.teams?.visitors?.id ?? 0,
            homeTeamScore: cachedGame?.homeTeamScore ?? stat.game?.scores?.home?.points ?? 0,
            visitorTeamScore: cachedGame?.visitorTeamScore ?? stat.game?.scores?.visitors?.points ?? 0,
            season: Int(getCurrentSeason()) ?? 2024,
            status: stat.game?.status?.long ?? "Finished",
            homeTeamName: cachedGame?.homeTeamName ?? stat.game?.teams?.home?.name ?? "",
            homeTeamAbbreviation: cachedGame?.homeTeamAbbreviation ?? stat.game?.teams?.home?.code ?? "",
            visitorTeamName: cachedGame?.visitorTeamName ?? stat.game?.teams?.visitors?.name ?? "",
            visitorTeamAbbreviation: cachedGame?.visitorTeamAbbreviation ?? stat.game?.teams?.visitors?.code ?? ""
        )
        
        let rawFirst = stat.player?.firstname ?? ""
        let rawLast = stat.player?.lastname ?? ""
        let displayFirst = expandFirstNameForDisplay(rawFirst, lastName: rawLast)
        let playerInfo = PlayerGameStats.PlayerInfo(
            id: stat.player?.id ?? 0,
            firstName: displayFirst,
            lastName: rawLast,
            position: stat.pos ?? "",
            teamId: stat.team?.id
        )
        
        let teamInfo = PlayerGameStats.TeamInfo(
            id: stat.team?.id ?? 0,
            abbreviation: stat.team?.code ?? "",
            fullName: stat.team?.name ?? ""
        )
        
        return PlayerGameStats(
            id: gameId * 1000 + (stat.player?.id ?? 0),
            min: stat.min,
            pts: stat.points,
            reb: stat.totReb,
            ast: stat.assists,
            stl: stat.steals,
            blk: stat.blocks,
            turnover: stat.turnovers,
            fgm: stat.fgm,
            fga: stat.fga,
            fg3m: stat.tpm,
            fg3a: stat.tpa,
            ftm: stat.ftm,
            fta: stat.fta,
            pf: stat.pFouls,
            game: gameInfo,
            player: playerInfo,
            team: teamInfo
        )
    }
}
