//
//  LiveScoresAPI.swift
//  Sport_Tracker-Fantasy
//
//  LiveScoresAPI.swift
//  Aggregates live scores from multiple free providers (ESPN, API-SPORTS, BALLDONTLIE).
//
//  NOTE:
//  - ESPN endpoints are free and require no key – used by default so the app "just works".
//  - API-SPORTS and BALLDONTLIE require API keys; once you add them below the same
//    code will start pulling data from those providers too.
//  - For now we only surface a few matches (3–4) to validate the UI flow.

import Foundation

// MARK: - Models

struct LiveMatch: Identifiable, Sendable {
    let id = UUID()
    let league: String
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int?
    let awayScore: Int?
    let status: String   // e.g. "65'", "FT", "HT", or just "7:30 PM" for upcoming
}

// MARK: - Service

final class LiveScoresAPI: @unchecked Sendable {
    static let shared = LiveScoresAPI()
    
    // MARK: - Provider configuration
    
    /// Insert your API-SPORTS key here (or load it from a secure store).
    /// Docs: https://api-sports.io/documentation
    private let apiSportsApiKey: String = "6c8528dea3157cfa1411fbee172b19e6" // TODO: set your API-SPORTS key
    
    /// Insert your BALLDONTLIE key here.
    /// Docs: https://www.balldontlie.io/docs/
    private let ballDontLieApiKey: String = "a5169794-3c4b-4631-94ce-dfc14ecb9544" // TODO: set your BALLDONTLIE key
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let iso8601Formatter = ISO8601DateFormatter()
    
    private let ballDontLieDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    /// Simple in-memory cache so we don't hit free APIs on every tiny refresh.
    /// Keys are normalized (start-of-day) dates.
    private let nbaCacheTTL: TimeInterval = 60 // seconds
    private var nbaCache: [Date: (timestamp: Date, matches: [LiveMatch])] = [:]
    
    private init() {}
    
    /// Fetches a small sample of live / current matches from multiple providers.
    /// For now this:
    /// - Always uses ESPN's free scoreboards (NBA, NFL, EPL) – no keys required.
    /// - Optionally augments with BALLDONTLIE and API-SPORTS once keys are set.
    /// - Returns at most 4 matches so the Home screen can validate the layout.
    func fetchLiveMatches() async throws -> [LiveMatch] {
        var combined: [LiveMatch] = []
        
        // ESPN – completely free and keyless
        do {
            let nba = try await fetchEspnScoreboard(
                displayLeagueName: "NBA",
                sportPath: "basketball",
                leaguePath: "nba"
            )
            combined += nba
        } catch {
            #if DEBUG
            print("ESPN NBA error:", error)
            #endif
        }
        
        do {
            let nfl = try await fetchEspnScoreboard(
                displayLeagueName: "NFL",
                sportPath: "football",
                leaguePath: "nfl"
            )
            combined += nfl
        } catch {
            #if DEBUG
            print("ESPN NFL error:", error)
            #endif
        }
        
        do {
            let epl = try await fetchEspnScoreboard(
                displayLeagueName: "Premier League",
                sportPath: "soccer",
                leaguePath: "eng.1" // EPL code on ESPN
            )
            combined += epl
        } catch {
            #if DEBUG
            print("ESPN EPL error:", error)
            #endif
        }
        
        // Optional providers – only run if keys are configured.
        // For NBA we use today's date when aggregating into this generic list.
        do {
            let bdl = try await fetchBallDontLieNBAGames(on: Date())
            combined += bdl
        } catch {
            #if DEBUG
            print("BALLDONTLIE error:", error)
            #endif
        }
        
        do {
            let api = try await fetchApiSportsSample()
            combined += api
        } catch {
            #if DEBUG
            print("API-SPORTS error:", error)
            #endif
        }
        
        // Only show a few games to keep the list short in early versions.
        if combined.count > 4 {
            combined = Array(combined.prefix(4))
        }
        
        return combined
    }
    
    /// NBA-only helper used by the Home screen.
    func fetchNBAGames(for date: Date) async throws -> [LiveMatch] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        
        // Use cached result if it's still fresh to avoid rate limiting the APIs.
        if let cached = nbaCache[target],
           Date().timeIntervalSince(cached.timestamp) < nbaCacheTTL {
            return cached.matches
        }
        
        // If a BALLDONTLIE key is configured, prefer it for proper date-based NBA schedules.
        if !ballDontLieApiKey.isEmpty {
            do {
                let bdlGames = try await fetchBallDontLieNBAGames(on: target)
                // Cache and return even if it's an empty list – that's still a valid "no games" result.
                nbaCache[target] = (timestamp: Date(), matches: bdlGames)
                return bdlGames
            } catch {
                #if DEBUG
                print("BALLDONTLIE NBA fetch failed:", error)
                #endif
                // Intentionally fall through to ESPN fallback below instead of throwing.
            }
        }
        
        // ESPN fallback – only exposes today's scoreboard.
        guard calendar.isDate(target, inSameDayAs: today) else {
            let empty: [LiveMatch] = []
            nbaCache[target] = (timestamp: Date(), matches: empty)
            return empty
        }
        
        do {
            let games = try await fetchEspnScoreboard(
                displayLeagueName: "NBA",
                sportPath: "basketball",
                leaguePath: "nba",
                preferKickoffTime: true
            )
            nbaCache[target] = (timestamp: Date(), matches: games)
            return games
        } catch {
            #if DEBUG
            print("NBA today via ESPN failed:", error)
            #endif
            return []
        }
    }
}

// MARK: - ESPN (no key required)

private extension LiveScoresAPI {
    /// ESPN public scoreboard – no auth required.
    /// Example: https://site.api.espn.com/apis/v2/sports/basketball/nba/scoreboard
    func fetchEspnScoreboard(
        displayLeagueName: String,
        sportPath: String,
        leaguePath: String,
        preferKickoffTime: Bool = false
    ) async throws -> [LiveMatch] {
        guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/\(sportPath)/\(leaguePath)/scoreboard") else {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        // ESPN uses camelCase, so default decoding strategy works fine.
        let scoreboard = try decoder.decode(EspnScoreboard.self, from: data)
        
        var matches: [LiveMatch] = []
        
        for event in scoreboard.events {
            guard let competition = event.competitions.first else { continue }
            
            let competitors = competition.competitors
            guard competitors.count >= 2 else { continue }
            
            guard
                let home = competitors.first(where: { $0.homeAway == "home" }),
                let away = competitors.first(where: { $0.homeAway == "away" })
            else {
                continue
            }
            
            let type = competition.status.type
            var statusText: String
            
            if preferKickoffTime, let state = type.state {
                switch state {
                case "pre":
                    if let date = iso8601Formatter.date(from: event.date) {
                        let timeString = timeFormatter.string(from: date)
                        // For upcoming games we only show the local tip-off time.
                        statusText = timeString
                    } else {
                        statusText = type.shortDetail ?? "Upcoming"
                    }
                case "in":
                    statusText = type.shortDetail ?? "Live"
                case "post":
                    statusText = type.shortDetail ?? "Final"
                default:
                    statusText = type.shortDetail ?? state
                }
            } else {
                statusText = type.shortDetail ?? type.state ?? ""
            }
            
            let rawHomeScore = Int(home.score) ?? 0
            let rawAwayScore = Int(away.score) ?? 0
            let isPreGame = (type.state == "pre")
            
            let homeScore: Int?
            let awayScore: Int?
            if preferKickoffTime && isPreGame {
                // For upcoming games we only show tip-off time, not scores.
                homeScore = nil
                awayScore = nil
            } else {
                homeScore = rawHomeScore
                awayScore = rawAwayScore
            }
            
            matches.append(
                LiveMatch(
                    league: displayLeagueName,
                    homeTeam: home.team.displayName,
                    awayTeam: away.team.displayName,
                    homeScore: homeScore,
                    awayScore: awayScore,
                    status: statusText
                )
            )
        }
        
        return matches
    }
}

/// Minimal ESPN scoreboard model – we only decode what we need.
private struct EspnScoreboard: Decodable {
    let events: [Event]
    
    struct Event: Decodable {
        let id: String
        let name: String
        let shortName: String
        let date: String
        let competitions: [Competition]
    }
    
    struct Competition: Decodable {
        let competitors: [Competitor]
        let status: Status
    }
    
    struct Competitor: Decodable {
        let homeAway: String
        let team: Team
        let score: String
    }
    
    struct Team: Decodable {
        let displayName: String
        let shortDisplayName: String?
    }
    
    struct Status: Decodable {
        let type: StatusType
    }
    
    struct StatusType: Decodable {
        let state: String?
        let shortDetail: String?
    }
}

// MARK: - BALLDONTLIE (optional – requires key)

private extension LiveScoresAPI {
    /// NBA integration via BALLDONTLIE for a specific date.
    /// Once `ballDontLieApiKey` is set, this will return real schedules/results.
    func fetchBallDontLieNBAGames(on date: Date) async throws -> [LiveMatch] {
        guard !ballDontLieApiKey.isEmpty else {
            // Key not configured – skip silently.
            return []
        }
        
        let dateString = ballDontLieDateFormatter.string(from: date)
        
        // BALLDONTLIE base URL and path per latest docs: https://api.balldontlie.io/v1/games
        guard let url = URL(string: "https://api.balldontlie.io/v1/games?per_page=20&dates[]=\(dateString)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        // BALLDONTLIE expects the API key in the Authorization header.
        request.setValue(ballDontLieApiKey, forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let http = response as? HTTPURLResponse {
            print("BALLDONTLIE NBA status:", http.statusCode)
        }
        #endif
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let gamesResponse: BallDontLieGamesResponse
        do {
            gamesResponse = try decoder.decode(BallDontLieGamesResponse.self, from: data)
        } catch {
            #if DEBUG
            print("BALLDONTLIE NBA decode failed:", error)
            if let raw = String(data: data, encoding: .utf8) {
                print("BALLDONTLIE raw response (truncated):", raw.prefix(500))
            }
            #endif
            throw error
        }
        
        return gamesResponse.data.map { game in
            let lowerStatus = game.status.lowercased()
            let isFinished = lowerStatus.contains("final")
            let isLive = lowerStatus.contains("in progress") || lowerStatus.contains("live")
            
            let statusText: String
            let homeScore: Int?
            let awayScore: Int?
            
            if isFinished {
                statusText = "Final"
                homeScore = game.homeTeamScore
                awayScore = game.visitorTeamScore
            } else if isLive {
                statusText = "Live"
                homeScore = game.homeTeamScore
                awayScore = game.visitorTeamScore
            } else {
                // Upcoming – show local tip-off time only, no scores.
                if let date = iso8601Formatter.date(from: game.date) {
                    let timeString = timeFormatter.string(from: date)
                    statusText = timeString
                } else {
                    statusText = "Upcoming"
                }
                homeScore = nil
                awayScore = nil
            }
            
            return LiveMatch(
                league: "NBA",
                homeTeam: game.homeTeam.fullName,
                awayTeam: game.visitorTeam.fullName,
                homeScore: homeScore,
                awayScore: awayScore,
                status: statusText
            )
        }
    }
}

/// Minimal BALLDONTLIE response for games.
private struct BallDontLieGamesResponse: Decodable {
    struct Game: Decodable {
        struct Team: Decodable {
            let id: Int
            let fullName: String
        }
        
        let id: Int
        let date: String
        let status: String
        let homeTeam: Team
        let visitorTeam: Team
        let homeTeamScore: Int
        let visitorTeamScore: Int
    }
    
    let data: [Game]
}

// MARK: - API-SPORTS (optional – requires key)

private extension LiveScoresAPI {
    /// Placeholder sample for API-SPORTS integration.
    /// Once `apiSportsApiKey` is set, you can implement real calls here, e.g.:
    ///
    /// - Football fixtures: https://v3.football.api-sports.io/fixtures?live=all
    /// - Basketball games:  https://v1.basketball.api-sports.io/games?live=all
    ///
    /// For now this returns an empty list so the app runs without configuration.
    func fetchApiSportsSample() async throws -> [LiveMatch] {
        guard !apiSportsApiKey.isEmpty else {
            return []
        }
        
        // TODO: Implement real API-SPORTS decoding here.
        return []
    }
}