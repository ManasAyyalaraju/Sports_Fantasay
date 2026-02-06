//
//  NBAModels.swift
//  Sport_Tracker-Fantasy
//
//  NBA Player and Stats Data Models
//

import Foundation

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

// MARK: - Team Model

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

// MARK: - Player Game Stats

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
        // Team details for display
        let homeTeamName: String
        let homeTeamAbbreviation: String
        let visitorTeamName: String
        let visitorTeamAbbreviation: String
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

// MARK: - Season Averages

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

// MARK: - Player With Stats

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
