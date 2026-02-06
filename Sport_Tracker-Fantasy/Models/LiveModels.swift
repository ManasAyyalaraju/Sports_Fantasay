//
//  LiveModels.swift
//  Sport_Tracker-Fantasy
//
//  Live Game and Live Player Stats Models
//

import Foundation

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
