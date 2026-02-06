//
//  APIResponseModels.swift
//  Sport_Tracker-Fantasy
//
//  API-Sports Response Decodable Models
//

import Foundation

// MARK: - Players Response

struct APISportsPlayersResponse: Decodable {
    let response: [APISportsPlayer]
}

struct APISportsPlayer: Decodable {
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

// MARK: - Teams Response

struct APISportsTeamsResponse: Decodable {
    let response: [APISportsTeam]
}

struct APISportsTeam: Decodable {
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

// MARK: - Stats Response

struct APISportsStatsResponse: Decodable {
    let response: [APISportsPlayerStat]
}

struct APISportsPlayerStat: Decodable {
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

// MARK: - Games Response

struct APISportsGamesResponse: Decodable {
    let response: [APISportsGame]
}

struct APISportsGame: Decodable {
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

// MARK: - Box Score Response

struct APISportsBoxScoreResponse: Decodable {
    let response: [APISportsBoxScoreStat]
}

struct APISportsBoxScoreStat: Decodable {
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
