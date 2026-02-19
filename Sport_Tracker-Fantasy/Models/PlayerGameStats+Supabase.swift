//
//  PlayerGameStats+Supabase.swift
//  Sport_Tracker-Fantasy
//
//  Helpers to construct PlayerGameStats from Supabase rows.
//

import Foundation

extension PlayerGameStats {
    struct SupabaseRow: Decodable {
        let game_id: Int
        let player_id: Int
        let season: String
        let game_date: String?
        let home_team_id: Int?
        let visitor_team_id: Int?
        let home_team_score: Int?
        let visitor_team_score: Int?
        let game_status: String?
        let home_team_name: String?
        let home_team_abbreviation: String?
        let visitor_team_name: String?
        let visitor_team_abbreviation: String?
        let player_first_name: String?
        let player_last_name: String?
        let player_position: String?
        let player_team_id: Int?
        let team_id: Int?
        let team_abbreviation: String?
        let team_full_name: String?
        let min: String?
        let pts: Int?
        let reb: Int?
        let ast: Int?
        let stl: Int?
        let blk: Int?
        let turnovers: Int?
        let fgm: Int?
        let fga: Int?
        let fg3m: Int?
        let fg3a: Int?
        let ftm: Int?
        let fta: Int?
        let pf: Int?
    }

    init(fromSupabase row: SupabaseRow) {
        let gameInfo = GameInfo(
            id: row.game_id,
            date: row.game_date ?? "",
            homeTeamId: row.home_team_id ?? 0,
            visitorTeamId: row.visitor_team_id ?? 0,
            homeTeamScore: row.home_team_score ?? 0,
            visitorTeamScore: row.visitor_team_score ?? 0,
            season: Int(row.season) ?? 0,
            status: row.game_status ?? "Finished",
            homeTeamName: row.home_team_name ?? "",
            homeTeamAbbreviation: row.home_team_abbreviation ?? "",
            visitorTeamName: row.visitor_team_name ?? "",
            visitorTeamAbbreviation: row.visitor_team_abbreviation ?? ""
        )

        let playerInfo = PlayerInfo(
            id: row.player_id,
            firstName: row.player_first_name ?? "",
            lastName: row.player_last_name ?? "",
            position: row.player_position ?? "",
            teamId: row.player_team_id
        )

        let teamInfo = TeamInfo(
            id: row.team_id ?? 0,
            abbreviation: row.team_abbreviation ?? "",
            fullName: row.team_full_name ?? ""
        )

        self.init(
            id: row.game_id * 1000 + row.player_id,
            min: row.min,
            pts: row.pts,
            reb: row.reb,
            ast: row.ast,
            stl: row.stl,
            blk: row.blk,
            turnover: row.turnovers,
            fgm: row.fgm,
            fga: row.fga,
            fg3m: row.fg3m,
            fg3a: row.fg3a,
            ftm: row.ftm,
            fta: row.fta,
            pf: row.pf,
            game: gameInfo,
            player: playerInfo,
            team: teamInfo
        )
    }
}

