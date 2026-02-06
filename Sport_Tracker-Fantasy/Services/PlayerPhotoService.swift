//
//  PlayerPhotoService.swift
//  Sport_Tracker-Fantasy
//
//  Service for fetching NBA player headshot photos
//

import Foundation

// MARK: - Remote Database Response

/// Remote database response structure
struct RemotePlayerDatabase: Codable {
    let version: String
    let lastUpdated: String
    let players: [String: Int]  // "firstname_lastname" -> NBA.com ID
}

// MARK: - Player Photo Service

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
            mergeNameAliases()
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
            mergeNameAliases()
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
        mergeNameAliases()
        print("📦 Loaded \(playerIdCache.count) players from embedded fallback")
    }
    
    private func mergeNameAliases() {
        for (key, id) in Self.nameAliases {
            playerIdCache[key] = id
        }
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
    
    /// Aliases: API abbreviations, "Jr." name variants, and ID overrides (remote JSON uses ESPN IDs; headshots need NBA.com IDs).
    private static let nameAliases: [String: Int] = [
        "c_flagg": 1642843,           // Cooper Flagg – API returns "C"
        "giannis_antetokounmpo": 203507,  // Remote has 3032977 (ESPN); NBA.com headshot uses 203507
        "michael_porter_jr": 1629008,
        "michael_porter_jr.": 1629008,
        "kevin_porter_jr": 1629645,
        "kevin_porter_jr.": 1629645
    ]
    
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
        "anfernee_simons": 1629014, "josh_hart": 1628404,         "coby_white": 1629632,
        "cooper_flagg": 1642843,
        "michael_porter_jr": 1629008,
        "kevin_porter_jr": 1629645
    ]
    
    private func getFallbackAvatarURL(firstName: String, lastName: String, teamAbbr: String) -> URL? {
        let fullName = "\(firstName)+\(lastName)"
        let bgColor = TeamColors.primary[teamAbbr]?.replacingOccurrences(of: "#", with: "") ?? "FF6B35"
        return URL(string: "https://ui-avatars.com/api/?name=\(fullName)&background=\(bgColor)&color=ffffff&size=256&bold=true&format=png")
    }
}
