//
//  LiveScoresAPI.swift
//  Sport_Tracker-Fantasy
//
//  NBA Fantasy API Service
//  Fetches NBA players and their game statistics from API-Sports.
//

import Foundation
import Combine

// MARK: - Player Models

struct NBAPlayer: Identifiable, Codable, Hashable {
    let id: Int
    let firstName: String
    let lastName: String
    let position: String
    let height: String?
    let weight: String?
    let jerseyNumber: String?
    let college: String?
    let country: String?
    let draftYear: Int?
    let draftRound: Int?
    let draftNumber: Int?
    let team: NBATeam?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    /// Safe team abbreviation
    var teamAbbreviation: String {
        team?.abbreviation ?? "FA"
    }
    
    /// Safe team full name
    var teamFullName: String {
        team?.fullName ?? "Free Agent"
    }
    
    /// Safe team primary color
    var teamPrimaryColor: String {
        team?.primaryColor ?? "FF6B35"
    }
    
    /// Safe team secondary color
    var teamSecondaryColor: String {
        team?.secondaryColor ?? "F7931E"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NBAPlayer, rhs: NBAPlayer) -> Bool {
        lhs.id == rhs.id
    }
}

struct NBATeam: Codable, Hashable {
    let id: Int
    let conference: String
    let division: String
    let city: String
    let name: String
    let fullName: String
    let abbreviation: String
    
    /// Team primary color for avatar backgrounds
    var primaryColor: String {
        TeamColors.primary[abbreviation] ?? "FF6B35"
    }
    
    var secondaryColor: String {
        TeamColors.secondary[abbreviation] ?? "F7931E"
    }
}

struct PlayerGameStats: Identifiable, Codable {
    let id: Int
    let min: String?
    let pts: Int?
    let reb: Int?
    let ast: Int?
    let stl: Int?
    let blk: Int?
    let turnover: Int?
    let fgm: Int?
    let fga: Int?
    let fg3m: Int?
    let fg3a: Int?
    let ftm: Int?
    let fta: Int?
    let pf: Int?
    let game: GameInfo
    let player: PlayerInfo
    let team: TeamInfo
    
    struct GameInfo: Codable {
        let id: Int
        let date: String
        let homeTeamId: Int
        let visitorTeamId: Int
        let homeTeamScore: Int
        let visitorTeamScore: Int
        let season: Int
        let status: String
    }
    
    struct PlayerInfo: Codable {
        let id: Int
        let firstName: String
        let lastName: String
        let position: String
        let teamId: Int?
    }
    
    struct TeamInfo: Codable {
        let id: Int
        let abbreviation: String
        let fullName: String
    }
    
    var formattedDate: String {
        // API-Sports format: "2024-01-15T00:00:00.000Z"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = dateFormatter.date(from: game.date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        // Try alternate format
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: String(game.date.prefix(10))) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return game.date.prefix(10).description
    }
    
    var minutes: String {
        guard let min = min, !min.isEmpty else { return "0" }
        // Format like "32:45" -> "32"
        if let colonIndex = min.firstIndex(of: ":") {
            return String(min[..<colonIndex])
        }
        return min
    }
}

struct SeasonAverages: Identifiable {
    let id = UUID()
    let playerId: Int
    let pts: Double
    let reb: Double
    let ast: Double
    let stl: Double
    let blk: Double
    let gamesPlayed: Int
    let min: String
    let fgPct: Double
    let fg3Pct: Double
    let ftPct: Double
    
    /// Fantasy score calculation (simple formula)
    var fantasyScore: Double {
        pts + (reb * 1.2) + (ast * 1.5) + (stl * 3) + (blk * 3)
    }
}

/// Holds player with their season averages for sorting
struct PlayerWithStats: Identifiable {
    let player: NBAPlayer
    let averages: SeasonAverages?
    
    var id: Int { player.id }
    
    var fantasyScore: Double {
        averages?.fantasyScore ?? 0
    }
    
    var ppg: Double {
        averages?.pts ?? 0
    }
}

// MARK: - Team Colors

struct TeamColors {
    static let primary: [String: String] = [
        "ATL": "E03A3E", "BOS": "007A33", "BKN": "000000", "CHA": "1D1160",
        "CHI": "CE1141", "CLE": "860038", "DAL": "00538C", "DEN": "0E2240",
        "DET": "C8102E", "GSW": "1D428A", "HOU": "CE1141", "IND": "002D62",
        "LAC": "C8102E", "LAL": "552583", "MEM": "5D76A9", "MIA": "98002E",
        "MIL": "00471B", "MIN": "0C2340", "NOP": "0C2340", "NYK": "006BB6",
        "OKC": "007AC1", "ORL": "0077C0", "PHI": "006BB6", "PHX": "1D1160",
        "POR": "E03A3E", "SAC": "5A2D81", "SAS": "C4CED4", "TOR": "CE1141",
        "UTA": "002B5C", "WAS": "002B5C"
    ]
    
    static let secondary: [String: String] = [
        "ATL": "C1D32F", "BOS": "BA9653", "BKN": "FFFFFF", "CHA": "00788C",
        "CHI": "000000", "CLE": "041E42", "DAL": "002B5E", "DEN": "FEC524",
        "DET": "1D42BA", "GSW": "FFC72C", "HOU": "000000", "IND": "FDBB30",
        "LAC": "1D428A", "LAL": "FDB927", "MEM": "12173F", "MIA": "F9A01B",
        "MIL": "EEE1C6", "MIN": "236192", "NOP": "C8102E", "NYK": "F58426",
        "OKC": "EF3B24", "ORL": "C4CED4", "PHI": "ED174C", "PHX": "E56020",
        "POR": "000000", "SAC": "63727A", "SAS": "000000", "TOR": "000000",
        "UTA": "00471B", "WAS": "E31837"
    ]
}

// MARK: - Player Photo Service

/// Remote database response structure
struct RemotePlayerDatabase: Codable {
    let version: String
    let lastUpdated: String
    let players: [String: Int]  // "firstname_lastname" -> NBA.com ID
}

/// Service to get player headshot URLs from NBA.com CDN
/// Fetches player ID database from a remote JSON file
actor PlayerPhotoService {
    static let shared = PlayerPhotoService()
    
    // MARK: - Configuration
    
    /// URL to your hosted JSON file containing player IDs
    private let remoteDbUrl: String? = "https://raw.githubusercontent.com/ManasAyyalaraju/NBA_Player_ID-s/main/nba_player_ids.json"
    
    /// Local cache of player IDs (name -> NBA.com ID)
    private var playerIdCache: [String: Int] = [:]
    
    /// Last database fetch time
    private var lastFetched: Date?
    
    /// Whether currently fetching
    private var isFetching = false
    
    /// File URL for local cache
    private var localCacheURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("nba_player_ids_cache.json")
    }
    
    private init() {
        // Load from local cache first (instant)
        loadLocalCache()
        
        // Then fetch remote in background
        Task {
            await fetchRemoteDatabase()
        }
    }
    
    // MARK: - Public API
    
    /// Get a headshot URL for a player
    func getHeadshotURLWithLookup(firstName: String, lastName: String, teamAbbr: String = "") async -> URL? {
        // Ensure we have data
        if playerIdCache.isEmpty {
            await fetchRemoteDatabase()
        }
        
        // Normalize name for lookup
        let cacheKey = normalizeKey(firstName: firstName, lastName: lastName)
        
        // Try exact match
        if let nbaId = playerIdCache[cacheKey] {
            return URL(string: "https://cdn.nba.com/headshots/nba/latest/260x190/\(nbaId).png")
        }
        
        // Try simplified match (without special chars)
        let simplifiedKey = simplifyKey(cacheKey)
        for (key, nbaId) in playerIdCache {
            if simplifyKey(key) == simplifiedKey {
                return URL(string: "https://cdn.nba.com/headshots/nba/latest/260x190/\(nbaId).png")
            }
        }
        
        // Fall back to UI Avatars
        return getFallbackAvatarURL(firstName: firstName, lastName: lastName, teamAbbr: teamAbbr)
    }
    
    /// Force refresh from remote
    func refreshDatabase() async {
        await fetchRemoteDatabase(force: true)
    }
    
    /// Get database status
    func getDatabaseStatus() -> (playerCount: Int, lastFetched: Date?) {
        return (playerIdCache.count, lastFetched)
    }
    
    /// Clear local cache
    func clearCache() {
        playerIdCache.removeAll()
        lastFetched = nil
        try? FileManager.default.removeItem(at: localCacheURL)
        print("🗑️ Player photo cache cleared")
    }
    
    /// Get all verified player names from the database
    func getVerifiedPlayerNames() -> Set<String> {
        if playerIdCache.isEmpty {
            loadEmbeddedFallback()
        }
        
        var names = Set<String>()
        for key in playerIdCache.keys {
            names.insert(key)
            names.insert(simplifyKey(key))
        }
        return names
    }
    
    // MARK: - Remote Database Fetching
    
    private func fetchRemoteDatabase(force: Bool = false) async {
        guard !isFetching else { return }
        if !force, let lastFetched = lastFetched {
            let hoursSinceFetch = Date().timeIntervalSince(lastFetched) / 3600
            if hoursSinceFetch < 1 { return }
        }
        
        isFetching = true
        defer { isFetching = false }
        
        guard let urlString = remoteDbUrl, let url = URL(string: urlString) else {
            print("⚠️ No remote database URL configured, using embedded data")
            loadEmbeddedFallback()
            return
        }
        
        do {
            print("📡 Fetching player database from remote...")
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Remote database fetch failed, using local cache")
                return
            }
            
            let database = try JSONDecoder().decode(RemotePlayerDatabase.self, from: data)
            
            playerIdCache = database.players
            lastFetched = Date()
            
            saveLocalCache()
            
            print("✅ Loaded \(playerIdCache.count) players from remote database (v\(database.version))")
            
        } catch {
            print("⚠️ Remote fetch error: \(error.localizedDescription)")
            if playerIdCache.isEmpty {
                loadEmbeddedFallback()
            }
        }
    }
    
    // MARK: - Local Cache
    
    private func loadLocalCache() {
        guard FileManager.default.fileExists(atPath: localCacheURL.path) else {
            loadEmbeddedFallback()
            return
        }
        
        do {
            let data = try Data(contentsOf: localCacheURL)
            let database = try JSONDecoder().decode(RemotePlayerDatabase.self, from: data)
            playerIdCache = database.players
            print("✅ Loaded \(playerIdCache.count) players from local cache")
        } catch {
            print("⚠️ Failed to load local cache: \(error.localizedDescription)")
            loadEmbeddedFallback()
        }
    }
    
    private func saveLocalCache() {
        let database = RemotePlayerDatabase(
            version: "cached",
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            players: playerIdCache
        )
        
        do {
            let data = try JSONEncoder().encode(database)
            try data.write(to: localCacheURL)
            print("💾 Saved \(playerIdCache.count) players to local cache")
        } catch {
            print("⚠️ Failed to save local cache: \(error.localizedDescription)")
        }
    }
    
    private func loadEmbeddedFallback() {
        playerIdCache = Self.embeddedPlayerIds
        print("📦 Loaded \(playerIdCache.count) players from embedded fallback")
    }
    
    // MARK: - Helpers
    
    private func normalizeKey(firstName: String, lastName: String) -> String {
        "\(firstName.lowercased())_\(lastName.lowercased())"
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: " ", with: "_")
    }
    
    private func simplifyKey(_ key: String) -> String {
        key.replacingOccurrences(of: "'", with: "")
           .replacingOccurrences(of: "-", with: "")
           .replacingOccurrences(of: ".", with: "")
    }
    
    /// Embedded fallback - top 100 players
    private static let embeddedPlayerIds: [String: Int] = [
        "lebron_james": 2544, "stephen_curry": 201939, "kevin_durant": 201142,
        "giannis_antetokounmpo": 203507, "luka_doncic": 1629029, "nikola_jokic": 203999,
        "joel_embiid": 203954, "jayson_tatum": 1628369, "ja_morant": 1629630,
        "anthony_edwards": 1630162, "shai_gilgeous-alexander": 1628983,
        "donovan_mitchell": 1628378, "trae_young": 1629027, "devin_booker": 1626164,
        "jimmy_butler": 202710, "kawhi_leonard": 202695, "paul_george": 202331,
        "kyrie_irving": 202681, "damian_lillard": 203081, "anthony_davis": 203076,
        "james_harden": 201935, "bam_adebayo": 1628389, "jaylen_brown": 1627759,
        "tyrese_haliburton": 1630169, "de'aaron_fox": 1628368, "domantas_sabonis": 1627734,
        "karl-anthony_towns": 1626157, "jalen_brunson": 1628973, "julius_randle": 203944,
        "pascal_siakam": 1627783, "scottie_barnes": 1630567, "paolo_banchero": 1631094,
        "victor_wembanyama": 1641705, "chet_holmgren": 1631096, "tyrese_maxey": 1630178,
        "evan_mobley": 1630596, "desmond_bane": 1630217, "franz_wagner": 1630532,
        "alperen_sengun": 1630578, "jalen_williams": 1631114, "cade_cunningham": 1630595,
        "jalen_green": 1630224, "austin_reaves": 1630559, "russell_westbrook": 201566,
        "zion_williamson": 1629627, "lamelo_ball": 1630163, "dejounte_murray": 1628405,
        "fred_vanvleet": 1627832, "draymond_green": 203110, "klay_thompson": 202691,
        "chris_paul": 101108, "demar_derozan": 201942, "bradley_beal": 203078,
        "khris_middleton": 203114, "brandon_ingram": 1627742, "cj_mccollum": 203468,
        "mikal_bridges": 1628969, "lauri_markkanen": 1628374, "myles_turner": 1626167,
        "nikola_vucevic": 202696, "zach_lavine": 203897, "jarrett_allen": 1628386,
        "rudy_gobert": 203497, "tyler_herro": 1629639, "og_anunoby": 1628384,
        "andrew_wiggins": 203952, "cam_thomas": 1630560, "immanuel_quickley": 1630193,
        "anfernee_simons": 1629014, "josh_hart": 1628404, "coby_white": 1629632
    ]
    
    private func getFallbackAvatarURL(firstName: String, lastName: String, teamAbbr: String) -> URL? {
        let fullName = "\(firstName)+\(lastName)"
        let bgColor = TeamColors.primary[teamAbbr]?.replacingOccurrences(of: "#", with: "") ?? "FF6B35"
        return URL(string: "https://ui-avatars.com/api/?name=\(fullName)&background=\(bgColor)&color=ffffff&size=256&bold=true&format=png")
    }
}


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
    
    // Star player names for prioritization
    private let starPlayerNames: Set<String> = [
        "lebron james", "stephen curry", "kevin durant", "giannis antetokounmpo",
        "luka doncic", "nikola jokic", "joel embiid", "jayson tatum", "ja morant",
        "anthony edwards", "shai gilgeous-alexander", "donovan mitchell", "trae young",
        "devin booker", "jimmy butler", "kawhi leonard", "paul george", "kyrie irving",
        "damian lillard", "anthony davis", "james harden", "bam adebayo", "jaylen brown",
        "tyrese haliburton", "de'aaron fox", "domantas sabonis", "karl-anthony towns",
        "jalen brunson", "julius randle", "pascal siakam", "scottie barnes", "paolo banchero",
        "victor wembanyama", "chet holmgren", "tyrese maxey", "evan mobley", "desmond bane"
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
        request.timeoutInterval = 20
        
        #if DEBUG
        print("📡 API-Sports Request: \(endpoint)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            #if DEBUG
            print("   Status: \(httpResponse.statusCode)")
            #endif
            
            if httpResponse.statusCode == 429 {
                throw NSError(domain: "API", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded. Please wait."])
            }
            
            if httpResponse.statusCode != 200 {
                #if DEBUG
                if let raw = String(data: data, encoding: .utf8) {
                    print("   Error: \(raw.prefix(300))")
                }
                #endif
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
            }
        }
        
        return data
    }
    
    // MARK: - Fetch All Players with Stats
    
    func fetchPlayersWithStats() async throws -> [PlayerWithStats] {
        if let cached = playersWithStatsCache, cached.isValid(ttl: cacheTTL) {
            #if DEBUG
            print("✅ Using cached players with stats (\(cached.data.count) players)")
            #endif
            return cached.data
        }
        
        #if DEBUG
        print("📡 Fetching fresh players with stats...")
        #endif
        
        let players = try await fetchAllPlayers()
        
        // Filter to players with teams (current NBA players)
        let activePlayers = players.filter { player in
            player.team != nil
        }
        
        #if DEBUG
        print("📋 Filtered to \(activePlayers.count) active players with teams")
        #endif
        
        var starPlayers: [NBAPlayer] = []
        var otherPlayers: [NBAPlayer] = []
        
        for player in activePlayers {
            let fullName = player.fullName.lowercased()
            if starPlayerNames.contains(fullName) {
                starPlayers.append(player)
            } else {
                otherPlayers.append(player)
            }
        }
        
        var playersWithStats: [PlayerWithStats] = []
        
        // Pre-fetch regular season game IDs once before parallel requests
        _ = try? await fetchRegularSeasonGameIds()
        
        await withTaskGroup(of: (NBAPlayer, SeasonAverages?).self) { group in
            for player in starPlayers.prefix(30) {
                group.addTask {
                    let averages = try? await self.fetchSeasonAverages(playerId: player.id)
                    return (player, averages)
                }
            }
            
            for await (player, averages) in group {
                playersWithStats.append(PlayerWithStats(player: player, averages: averages))
            }
        }
        
        playersWithStats.sort { $0.fantasyScore > $1.fantasyScore }
        
        let fetchedIds = Set(playersWithStats.map { $0.player.id })
        for player in starPlayers where !fetchedIds.contains(player.id) {
            playersWithStats.append(PlayerWithStats(player: player, averages: nil))
        }
        for player in otherPlayers {
            playersWithStats.append(PlayerWithStats(player: player, averages: nil))
        }
        
        playersWithStatsCache = CacheEntry(data: playersWithStats, timestamp: Date())
        
        #if DEBUG
        print("✅ Cached \(playersWithStats.count) players with stats")
        #endif
        
        return playersWithStats
    }
    
    // MARK: - Fetch All Players
    
    func fetchAllPlayers() async throws -> [NBAPlayer] {
        if let cached = playersCache, cached.isValid(ttl: cacheTTL) {
            #if DEBUG
            print("✅ Using cached players list (\(cached.data.count) players)")
            #endif
            return cached.data
        }
        
        #if DEBUG
        print("📡 Fetching players from API-Sports...")
        #endif
        
        // First, fetch teams
        let teams = try await fetchTeams()
        
        // Filter to only NBA franchise teams (exclude All-Star, historical, etc.)
        let nbaTeams = teams.filter { team in
            team.nbaFranchise == true && team.allStar != true
        }
        
        #if DEBUG
        print("📋 Found \(nbaTeams.count) NBA franchise teams")
        #endif
        
        let season = getCurrentSeason()
        var allPlayers: [NBAPlayer] = []
        
        // Fetch players for each team in parallel (batched to avoid rate limits)
        let batchSize = 10
        for batchStart in stride(from: 0, to: nbaTeams.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, nbaTeams.count)
            let batch = Array(nbaTeams[batchStart..<batchEnd])
            
            await withTaskGroup(of: [NBAPlayer].self) { group in
                for team in batch {
                    group.addTask {
                        do {
                            let data = try await self.makeRequest(endpoint: "players", queryParams: [
                                "team": "\(team.id)",
                                "season": season
                            ])
                            let response = try self.decoder.decode(APISportsPlayersResponse.self, from: data)
                            return response.response.compactMap { apiPlayer in
                                self.convertToNBAPlayer(apiPlayer, teamOverride: team)
                            }
                        } catch {
                            #if DEBUG
                            print("⚠️ Failed to fetch players for team \(team.id): \(error.localizedDescription)")
                            #endif
                            return []
                        }
                    }
                }
                
                for await players in group {
                    allPlayers.append(contentsOf: players)
                }
            }
            
            #if DEBUG
            print("📥 Batch \(batchStart/batchSize + 1): Total players so far: \(allPlayers.count)")
            #endif
        }
        
        #if DEBUG
        print("✅ Fetched \(allPlayers.count) total players from \(nbaTeams.count) teams")
        #endif
        
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
        
        #if DEBUG
        print("✅ Fetched \(response.response.count) teams")
        #endif
        
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
        
        #if DEBUG
        print("📡 Fetching games to determine regular season...")
        #endif
        
        let data = try await makeRequest(endpoint: "games", queryParams: ["season": season])
        let response = try decoder.decode(APISportsGamesResponse.self, from: data)
        
        #if DEBUG
        print("📥 Games API returned \(response.response.count) games")
        #endif
        
        var regularGameIds = Set<Int>()
        var preseasonCount = 0
        var regularCount = 0
        var playoffsCount = 0
        var unknownStageCount = 0
        
        // Check if stage field is available in the data
        let hasStageField = response.response.first?.stage != nil
        
        #if DEBUG
        if let first = response.response.first {
            print("📋 Sample game - stage: \(first.stage ?? -1), league: \(first.league ?? "nil")")
        }
        #endif
        
        if hasStageField {
            // Use stage field for filtering (preferred method)
            // Stage 1 = Preseason, Stage 2 = Regular Season, Stage 3+ = Playoffs/Play-in
            for game in response.response {
                if let stage = game.stage {
                    switch stage {
                    case 1:
                        preseasonCount += 1
                        // Don't add to regularGameIds
                    case 2:
                        regularCount += 1
                        regularGameIds.insert(game.id)
                    default:
                        // Playoffs, play-in, etc. - include them
                        playoffsCount += 1
                        regularGameIds.insert(game.id)
                    }
                } else {
                    unknownStageCount += 1
                    regularGameIds.insert(game.id) // Include if unknown
                }
            }
            
            #if DEBUG
            print("✅ Using stage field: \(regularCount) regular + \(playoffsCount) playoffs (excluded \(preseasonCount) preseason)")
            #endif
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
            
            #if DEBUG
            print("⚠️ Stage field not available, using date cutoff: \(cutoffDate)")
            print("✅ Found \(regularGameIds.count) games after cutoff (from \(response.response.count) total)")
            #endif
        }
        
        regularSeasonGameIds = regularGameIds
        
        #if DEBUG
        print("📊 Total regular season game IDs cached: \(regularGameIds.count)")
        #endif
        
        return regularGameIds
    }
    
    // MARK: - Search Players
    
    func searchPlayers(query: String) async throws -> [NBAPlayer] {
        guard !query.isEmpty else { return [] }
        
        if let cached = playersCache, cached.isValid(ttl: cacheTTL) {
            let query = query.lowercased()
            let results = cached.data.filter { player in
                player.fullName.lowercased().contains(query) ||
                player.teamFullName.lowercased().contains(query) ||
                player.teamAbbreviation.lowercased().contains(query)
            }
            if !results.isEmpty {
                #if DEBUG
                print("✅ Search results from cache: \(results.count) players")
                #endif
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
            #if DEBUG
            print("✅ Using cached stats for player \(playerId)")
            #endif
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
        
        #if DEBUG
        print("📥 API returned \(response.response.count) game stat entries")
        #endif
        
        var stats = response.response.compactMap { convertToPlayerGameStats($0) }
        
        // Filter to only regular season games
        let beforeFilter = stats.count
        stats = stats.filter { regularGameIds.contains($0.game.id) }
        
        #if DEBUG
        print("📥 Filtered to \(stats.count) regular season games (removed \(beforeFilter - stats.count) preseason)")
        #endif
        
        // API-Sports returns stats in chronological order (oldest first)
        // Reverse to get most recent first
        stats.reverse()
        
        #if DEBUG
        print("📅 Last 5 games (most recent first):")
        for (i, stat) in stats.prefix(5).enumerated() {
            print("   \(i+1). Game #\(stat.game.id) - \(stat.pts ?? 0) PTS")
        }
        #endif
        
        if !stats.isEmpty {
            playerStatsCache[playerId] = CacheEntry(data: stats, timestamp: Date())
            #if DEBUG
            print("✅ Cached \(stats.count) game stats for player \(playerId)")
            #endif
        }
        
        return Array(stats.prefix(lastNGames))
    }
    
    // MARK: - Fetch Season Averages
    
    func fetchSeasonAverages(playerId: Int) async throws -> SeasonAverages? {
        if let cached = seasonAveragesCache[playerId], cached.isValid(ttl: cacheTTL) {
            #if DEBUG
            print("✅ Using cached averages for player \(playerId)")
            #endif
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
            #if DEBUG
            print("⚠️ No stats data for player \(playerId)")
            #endif
            return nil
        }
        
        // Get regular season game IDs to filter out preseason
        let regularGameIds = try await fetchRegularSeasonGameIds()
        
        #if DEBUG
        print("📊 Player \(playerId): \(response.response.count) total games, \(regularGameIds.count) regular season game IDs cached")
        if let firstStat = response.response.first, let gameId = firstStat.game?.id {
            print("   First game ID from stats: \(gameId), in regular set: \(regularGameIds.contains(gameId))")
        }
        #endif
        
        // Filter to only regular season games using actual game dates
        let allGames = response.response
        let gameStats = allGames.filter { stat in
            guard let gameId = stat.game?.id else { return false }
            return regularGameIds.contains(gameId)
        }
        let gamesPlayed = gameStats.count
        
        #if DEBUG
        print("📊 Calculating averages from \(gamesPlayed) regular season games (filtered from \(allGames.count) total)")
        #endif
        
        // If all games were filtered out, something is wrong - fall back to using all games
        guard gamesPlayed > 0 else {
            #if DEBUG
            print("⚠️ All games filtered out! Using all \(allGames.count) games as fallback")
            #endif
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
        
        #if DEBUG
        print("✅ Calculated & cached averages for player \(playerId) (\(gamesPlayed) games)")
        #endif
        
        return result
    }
    
    // MARK: - Fetch Live Games
    
    func fetchLiveGames() async throws -> [LiveGame] {
        let data = try await makeRequest(endpoint: "games", queryParams: ["live": "all"])
        let response = try decoder.decode(APISportsGamesResponse.self, from: data)
        
        #if DEBUG
        print("🔴 Live games found: \(response.response.count)")
        #endif
        
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
        
        #if DEBUG
        print("📊 Box score for game \(gameId): \(response.response.count) player entries")
        #endif
        
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
            #if DEBUG
            print("⚪ No live games currently")
            #endif
            return [:]
        }
        
        #if DEBUG
        print("🔴 \(liveGames.count) live games, fetching box scores for favorite players...")
        #endif
        
        // Step 2: Fetch box scores for all live games in parallel
        var allLiveStats: [Int: LivePlayerStat] = [:]
        
        await withTaskGroup(of: [LivePlayerStat].self) { group in
            for game in liveGames {
                group.addTask {
                    do {
                        return try await self.fetchGameBoxScore(gameId: game.id)
                    } catch {
                        #if DEBUG
                        print("⚠️ Failed to fetch box score for game \(game.id): \(error.localizedDescription)")
                        #endif
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
        
        #if DEBUG
        print("✅ Found \(allLiveStats.count) favorite players currently in live games")
        for (playerId, stat) in allLiveStats {
            print("   🏀 \(stat.playerName) (\(playerId)): \(stat.points) PTS, \(stat.rebounds) REB, \(stat.assists) AST")
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
        
        #if DEBUG
        print("🗑️ Cache cleared")
        #endif
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
        
        return NBAPlayer(
            id: apiPlayer.id,
            firstName: apiPlayer.firstname,
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
        
        let gameInfo = PlayerGameStats.GameInfo(
            id: gameId,
            date: stat.game?.date?.dateString ?? "",
            homeTeamId: stat.game?.teams?.home?.id ?? 0,
            visitorTeamId: stat.game?.teams?.visitors?.id ?? 0,
            homeTeamScore: stat.game?.scores?.home?.points ?? 0,
            visitorTeamScore: stat.game?.scores?.visitors?.points ?? 0,
            season: Int(getCurrentSeason()) ?? 2024,
            status: stat.game?.status?.long ?? "Finished"
        )
        
        let playerInfo = PlayerGameStats.PlayerInfo(
            id: stat.player?.id ?? 0,
            firstName: stat.player?.firstname ?? "",
            lastName: stat.player?.lastname ?? "",
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
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start tracking live stats for favorite players
    /// - Parameter playerIds: Set of player IDs to track
    func startTracking(playerIds: Set<Int>) {
        trackedPlayerIds = playerIds
        
        guard !playerIds.isEmpty else {
            stopTracking()
            return
        }
        
        #if DEBUG
        print("🎯 LiveGameManager: Starting to track \(playerIds.count) players")
        #endif
        
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
        
        #if DEBUG
        print("🎯 LiveGameManager: Updated to track \(playerIds.count) players")
        #endif
    }
    
    /// Stop tracking and clean up
    func stopTracking() {
        #if DEBUG
        print("⏹️ LiveGameManager: Stopping tracking")
        #endif
        
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
            
            #if DEBUG
            print("✅ LiveGameManager: Refreshed - \(stats.count) players live in \(games.count) games")
            #endif
            
        } catch {
            lastError = error.localizedDescription
            #if DEBUG
            print("❌ LiveGameManager: Refresh failed - \(error.localizedDescription)")
            #endif
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
        #if DEBUG
        print("⏸️ LiveGameManager: Auto-refresh paused")
        #endif
    }
    
    /// Resume auto-refresh (when app comes to foreground)
    func resumeAutoRefresh() {
        guard isAutoRefreshEnabled && !trackedPlayerIds.isEmpty else { return }
        startAutoRefresh()
        
        // Refresh immediately when resuming
        Task {
            await refresh()
        }
        
        #if DEBUG
        print("▶️ LiveGameManager: Auto-refresh resumed")
        #endif
    }
    
    // MARK: - Private
    
    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        
        #if DEBUG
        print("⏱️ LiveGameManager: Auto-refresh started (every \(Int(refreshInterval))s)")
        #endif
    }
}

// MARK: - Live Game Model

struct LiveGame: Identifiable {
    let id: Int
    let homeTeam: String
    let homeTeamCode: String
    let homeTeamId: Int
    let homeScore: Int
    let awayTeam: String
    let awayTeamCode: String
    let awayTeamId: Int
    let awayScore: Int
    let status: String
    let period: Int
    let clock: String
    
    var isLive: Bool {
        status.lowercased().contains("q") || status.lowercased().contains("half")
    }
    
    var periodDisplay: String {
        if status.lowercased().contains("half") {
            return "HALF"
        }
        switch period {
        case 1: return "Q1"
        case 2: return "Q2"
        case 3: return "Q3"
        case 4: return "Q4"
        default: return period > 4 ? "OT\(period - 4)" : "Q\(period)"
        }
    }
    
    var clockDisplay: String {
        if clock.isEmpty {
            return periodDisplay
        }
        return "\(periodDisplay) \(clock)"
    }
}

// MARK: - Live Player Stats Model

/// Real-time stats for a player currently in a live game
struct LivePlayerStat: Identifiable {
    var id: Int { playerId }
    
    let playerId: Int
    let playerName: String
    let teamId: Int
    let teamCode: String
    let gameId: Int
    
    // Live stats
    let points: Int
    let rebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let minutes: String
    let fgm: Int
    let fga: Int
    let fg3m: Int
    let fg3a: Int
    let ftm: Int
    let fta: Int
    let turnovers: Int
    
    // Game context
    let period: Int
    let clock: String
    let gameStatus: String
    let homeTeamCode: String
    let awayTeamCode: String
    let homeScore: Int
    let awayScore: Int
    let isHomeTeam: Bool
    
    /// e.g. "GSW 102 - LAL 98"
    var scoreDisplay: String {
        if isHomeTeam {
            return "\(homeTeamCode) \(homeScore) - \(awayTeamCode) \(awayScore)"
        } else {
            return "\(awayTeamCode) \(awayScore) @ \(homeTeamCode) \(homeScore)"
        }
    }
    
    /// e.g. "Q3 5:42"
    var gameClockDisplay: String {
        let periodStr: String
        if gameStatus.lowercased().contains("half") {
            periodStr = "HALF"
        } else {
            switch period {
            case 1: periodStr = "Q1"
            case 2: periodStr = "Q2"
            case 3: periodStr = "Q3"
            case 4: periodStr = "Q4"
            default: periodStr = period > 4 ? "OT\(period - 4)" : "Q\(period)"
            }
        }
        
        if clock.isEmpty {
            return periodStr
        }
        return "\(periodStr) \(clock)"
    }
    
    /// Fantasy points for this game
    var fantasyPoints: Double {
        Double(points) + (Double(rebounds) * 1.2) + (Double(assists) * 1.5) + (Double(steals) * 3) + (Double(blocks) * 3) - Double(turnovers)
    }
}

// MARK: - API-Sports Response Models

private struct APISportsPlayersResponse: Decodable {
    let response: [APISportsPlayer]
}

private struct APISportsPlayer: Decodable {
    let id: Int
    let firstname: String
    let lastname: String
    let birth: BirthInfo?
    let nba: NBAInfo?
    let height: HeightInfo?
    let weight: WeightInfo?
    let college: String?
    let affiliation: String?
    let leagues: [String: LeagueInfo]?
    let team: TeamInfo?
    
    struct BirthInfo: Decodable {
        let date: String?
        let country: String?
    }
    
    struct NBAInfo: Decodable {
        let start: Int?
        let pro: Int?
    }
    
    struct HeightInfo: Decodable {
        let feets: String?
        let inches: String?
        let meters: String?
    }
    
    struct WeightInfo: Decodable {
        let pounds: String?
        let kilograms: String?
    }
    
    struct LeagueInfo: Decodable {
        let jersey: Int?
        let active: Bool?
        let pos: String?
    }
    
    struct TeamInfo: Decodable {
        let id: Int
        let name: String
        let nickname: String?
        let code: String?
        let city: String?
        let logo: String?
    }
}

private struct APISportsTeamsResponse: Decodable {
    let response: [APISportsTeam]
}

private struct APISportsTeam: Decodable {
    let id: Int
    let name: String
    let nickname: String?
    let code: String?
    let city: String?
    let logo: String?
    let allStar: Bool?
    let nbaFranchise: Bool?
    let leagues: [String: TeamLeagueInfo]?
    
    struct TeamLeagueInfo: Decodable {
        let conference: String?
        let division: String?
    }
}

private struct APISportsStatsResponse: Decodable {
    let response: [APISportsPlayerStat]
}

private struct APISportsPlayerStat: Decodable {
    let player: PlayerRef?
    let team: TeamRef?
    let game: GameRef?
    let points: Int?
    let pos: String?
    let min: String?
    let fgm: Int?
    let fga: Int?
    let fgp: String?
    let ftm: Int?
    let fta: Int?
    let ftp: String?
    let tpm: Int?
    let tpa: Int?
    let tpp: String?
    let offReb: Int?
    let defReb: Int?
    let totReb: Int?
    let assists: Int?
    let pFouls: Int?
    let steals: Int?
    let turnovers: Int?
    let blocks: Int?
    let plusMinus: String?
    let comment: String?
    
    struct PlayerRef: Decodable {
        let id: Int
        let firstname: String?
        let lastname: String?
    }
    
    struct TeamRef: Decodable {
        let id: Int
        let name: String?
        let nickname: String?
        let code: String?
        let logo: String?
    }
    
    struct GameRef: Decodable {
        let id: Int
        let date: FlexibleDate?
        let teams: TeamsInfo?
        let scores: ScoresInfo?
        let status: StatusInfo?
        
        // Flexible date that can handle both string and nested object
        enum FlexibleDate: Decodable {
            case string(String)
            case object(DateInfo)
            
            var dateString: String? {
                switch self {
                case .string(let str): return str
                case .object(let info): return info.start
                }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                // Try string first
                if let str = try? container.decode(String.self) {
                    self = .string(str)
                    return
                }
                // Then try nested object
                if let obj = try? container.decode(DateInfo.self) {
                    self = .object(obj)
                    return
                }
                throw DecodingError.typeMismatch(FlexibleDate.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or DateInfo"))
            }
        }
        
        struct DateInfo: Decodable {
            let start: String?
            let end: String?
        }
        
        struct TeamsInfo: Decodable {
            let home: TeamRef?
            let visitors: TeamRef?
        }
        
        struct ScoresInfo: Decodable {
            let home: ScoreInfo?
            let visitors: ScoreInfo?
            
            struct ScoreInfo: Decodable {
                let points: Int?
            }
        }
        
        struct StatusInfo: Decodable {
            let long: String?
            let short: Int?
            let clock: String?
        }
    }
}

private struct APISportsGamesResponse: Decodable {
    let response: [APISportsGame]
}

private struct APISportsBoxScoreResponse: Decodable {
    let response: [APISportsBoxScoreStat]
}

private struct APISportsBoxScoreStat: Decodable {
    let player: PlayerRef?
    let team: TeamRef?
    let game: GameRef?
    let points: Int?
    let pos: String?
    let min: String?
    let fgm: Int?
    let fga: Int?
    let fgp: String?
    let ftm: Int?
    let fta: Int?
    let ftp: String?
    let tpm: Int?
    let tpa: Int?
    let tpp: String?
    let offReb: Int?
    let defReb: Int?
    let totReb: Int?
    let assists: Int?
    let pFouls: Int?
    let steals: Int?
    let turnovers: Int?
    let blocks: Int?
    let plusMinus: String?
    let comment: String?
    
    struct PlayerRef: Decodable {
        let id: Int
        let firstname: String?
        let lastname: String?
    }
    
    struct TeamRef: Decodable {
        let id: Int
        let name: String?
        let nickname: String?
        let code: String?
        let logo: String?
    }
    
    struct GameRef: Decodable {
        let id: Int
        let date: String?
        let teams: TeamsInfo?
        let scores: ScoresInfo?
        let status: StatusInfo?
        
        struct TeamsInfo: Decodable {
            let home: TeamRef?
            let visitors: TeamRef?
        }
        
        struct ScoresInfo: Decodable {
            let home: ScoreInfo?
            let visitors: ScoreInfo?
            
            struct ScoreInfo: Decodable {
                let points: Int?
            }
        }
        
        struct StatusInfo: Decodable {
            let long: String?
            let short: Int?
            let clock: String?
        }
    }
}

private struct APISportsGame: Decodable {
    let id: Int
    let date: DateInfo
    let status: StatusInfo
    let periods: PeriodsInfo
    let teams: TeamsInfo
    let scores: ScoresInfo
    let stage: Int?          // Stage ID (1=Preseason, 2=Regular Season, etc.)
    let league: String?      // League type (e.g., "standard")
    
    struct DateInfo: Decodable {
        let start: String?
        let end: String?
    }
    
    struct StatusInfo: Decodable {
        let long: String?
        let short: Int?
        let clock: String?
    }
    
    struct PeriodsInfo: Decodable {
        let current: Int?
        let total: Int?
    }
    
    struct TeamsInfo: Decodable {
        let home: TeamInfo
        let visitors: TeamInfo
        
        struct TeamInfo: Decodable {
            let id: Int
            let name: String
            let nickname: String?
            let code: String?
            let logo: String?
        }
    }
    
    struct ScoresInfo: Decodable {
        let home: ScoreInfo
        let visitors: ScoreInfo
        
        struct ScoreInfo: Decodable {
            let points: Int?
        }
    }
}
