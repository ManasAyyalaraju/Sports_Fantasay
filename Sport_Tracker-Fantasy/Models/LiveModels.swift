//
//  LiveModels.swift
//  Sport_Tracker-Fantasy
//
//  Live Game and Live Player Stats Models
//

import Foundation

// MARK: - Upcoming Game Info

/// Next game for a team (from season schedule). Used to show "VIS @ HOM, 7:00pm" on home roster.
struct UpcomingGameInfo {
    let visitorAbbreviation: String
    let homeAbbreviation: String
    /// Display time e.g. "7:00pm"
    let timeString: String
    /// Full display line e.g. "LAL @ OKC, 7:00pm"
    var displayLine: String {
        if timeString.isEmpty { return "\(visitorAbbreviation) @ \(homeAbbreviation)" }
        return "\(visitorAbbreviation) @ \(homeAbbreviation), \(timeString)"
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
    
    /// e.g. "Q3" (quarter only, no game clock)
    var gameClockDisplay: String {
        if gameStatus.lowercased().contains("half") {
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
    
    /// Fantasy points for this game
    var fantasyPoints: Double {
        Double(points) + (Double(rebounds) * 1.2) + (Double(assists) * 1.5) + (Double(steals) * 3) + (Double(blocks) * 3) - Double(turnovers)
    }
    
    /// Returns a copy with updated game context (scores, quarter, clock) from the live games endpoint.
    func withGameContext(from game: LiveGame) -> LivePlayerStat {
        LivePlayerStat(
            playerId: playerId,
            playerName: playerName,
            teamId: teamId,
            teamCode: teamCode,
            gameId: gameId,
            points: points,
            rebounds: rebounds,
            assists: assists,
            steals: steals,
            blocks: blocks,
            minutes: minutes,
            fgm: fgm,
            fga: fga,
            fg3m: fg3m,
            fg3a: fg3a,
            ftm: ftm,
            fta: fta,
            turnovers: turnovers,
            period: game.period,
            clock: game.clock,
            gameStatus: game.status,
            homeTeamCode: homeTeamCode,
            awayTeamCode: awayTeamCode,
            homeScore: game.homeScore,
            awayScore: game.awayScore,
            isHomeTeam: isHomeTeam
        )
    }
}
